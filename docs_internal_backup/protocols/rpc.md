# RPC / MSRPC (135/111)

Remote Procedure Call. Windows 135(MSRPC), Linux 111(RPCbind). AD 열거에 핵심적.

---

## MSRPC (135)

### 열거

```bash
# 엔드포인트 매핑
impacket-rpcdump TARGET
impacket-rpcdump TARGET | grep -i 'MS-'

# nmap
nmap --script=msrpc-enum -p 135 TARGET

# rpcinfo (Linux RPC)
rpcinfo -p TARGET
```

### rpcclient

```bash
# NULL Session
rpcclient -U '' -N TARGET

# 인증 접속
rpcclient -U 'DOMAIN\user%pass' TARGET

# 주요 명령어
rpcclient $> srvinfo              # 서버 정보
rpcclient $> enumdomusers         # 사용자 열거
rpcclient $> enumdomgroups        # 그룹 열거
rpcclient $> querygroupmem 0x200  # 그룹 멤버 (0x200 = Domain Admins)
rpcclient $> queryuser 0x1f4      # 사용자 상세 (0x1f4 = Administrator RID)
rpcclient $> querydominfo         # 도메인 정보
rpcclient $> getdompwinfo         # 비밀번호 정책
rpcclient $> enumprivs            # 권한 열거
rpcclient $> netshareenum         # 공유 폴더
rpcclient $> netshareenumall      # 모든 공유 폴더

# 비밀번호 변경 (ForceChangePassword 권한)
rpcclient $> setuserinfo2 target 23 'NewPassword1!'

# SID 조회
rpcclient $> lookupnames admin
rpcclient $> lookupsids S-1-5-21-...
```

### SID Brute Force

```bash
# Impacket
impacket-lookupsid DOMAIN/user:pass@TARGET

# nxc
nxc smb TARGET -u user -p pass --rid-brute
nxc smb TARGET -u user -p pass --rid-brute 10000  # 범위 확장
```

### IOXIDResolver

```bash
# 네트워크 인터페이스 정보 노출 (인증 불필요)
# 내부 IP 주소, 호스트명 등 확인 가능
python3 IOXIDResolver.py -t TARGET
```

---

## enum4linux / enum4linux-ng

```bash
# 전체 열거
enum4linux -a TARGET
enum4linux-ng -A TARGET

# 특정 항목
enum4linux -U TARGET    # 사용자
enum4linux -G TARGET    # 그룹
enum4linux -S TARGET    # 공유
enum4linux -P TARGET    # 비밀번호 정책
enum4linux -o TARGET    # OS 정보

# 인증 포함
enum4linux -u user -p pass -a TARGET
```

---

## RPCbind (111) - Linux/NFS

```bash
# RPC 서비스 목록
rpcinfo -p TARGET

# NFS 공유 확인
showmount -e TARGET

# NFS 마운트
mkdir /tmp/nfs
mount -t nfs TARGET:/share /tmp/nfs
mount -o vers=3 TARGET:/share /tmp/nfs  # NFSv3 지정

# uid/gid 스푸핑 (파일 접근 우회)
# nfspy 또는 직접 uid 변경
```

---

## Nmap NSE

```bash
# MSRPC
nmap --script=msrpc-enum -p 135 TARGET

# RPC
nmap --script=rpcinfo -p 111 TARGET
nmap --script=rpc-grind -p 111 TARGET
```
