# 내부 정찰 / Enumeration

일단 발 하나 걸쳤으면 주변부터 둘러본다. 어떤 사용자 / 그룹이 살아있고, 공유 폴더에 뭐가 있고, 어떤 서비스가 도는지 정리해 두면 다음 공격 경로가 저절로 그려진다.

내부 정찰을 건너뛰고 바로 공격부터 가는 건 거의 항상 사고로 이어지는 편.

---

## SMB Enumeration

### NetExec (nxc)

nxc(구 crackmapexec)는 SMB, LDAP, WinRM, MSSQL 등 다양한 프로토콜에 대한 정보 수집 및 공격을 지원하는 도구다.

```bash
# SMB 기본 정보 확인 (OS, hostname, domain, signing 여부)
nxc smb <ip>

# 공유 폴더 목록 확인 (익명)
nxc smb <ip> --shares

# credential을 사용한 공유 폴더 확인 (READ/WRITE 권한 표시)
nxc smb <ip> -u <user> -p <pass> --shares

# Password Spray (lockout 정책 먼저 확인할 것)
nxc smb <ip> -u users.txt -p 'Password123!' --continue-on-success

# SSH Password Spray
nxc ssh <ip> -u users.txt -p passwords.txt
```

### smbclient

```bash
# 공유 폴더 목록 나열
smbclient -L <ip>
smbclient -L <ip> -U <user>

# 익명(null session)으로 접근
smbclient //<ip>/<share> -N

# credential로 접근
smbclient //<ip>/<share> -U '<user>%<password>'

# 재귀적으로 파일 download
smb: \> recurse ON
smb: \> prompt OFF
smb: \> mget *
```

### smbmap

```bash
# 공유 폴더 Permission 확인
smbmap -H <ip>

# credential 사용
smbmap -H <ip> -u <user> -p <pass>

# 재귀적으로 파일 목록 확인
smbmap -H <ip> -u <user> -p <pass> -R
```

---

## LDAP Enumeration

LDAP(Lightweight Directory Access Protocol)은 AD 환경에서 directory 정보를 질의하는데 사용된다. 389(LDAP), 636(LDAPS) 포트를 사용한다.

### ldapsearch

```bash
# 기본 LDAP 질의 (익명 binding, -x 옵션은 Simple Authentication)
ldapsearch -x -H ldap://<ip>:389 -b "dc=<domain>,dc=<tld>"

# 결과를 파일로 저장 후 사용자 추출
ldapsearch -x -H ldap://<ip>:389 -b "dc=<domain>,dc=<tld>" > ldap_raw.txt
grep "dn: C" ldap_raw.txt | cut -d',' -f1 | cut -d'=' -f2 > users.txt

# 사용자 계정만 조회 (objectClass=user 필터)
ldapsearch -x -b "dc=<domain>,dc=<tld>" "(objectClass=user)" \
  -H ldap://<ip> | grep sAMAccountName

# credential을 사용한 LDAP 질의
ldapsearch -x -H ldap://<ip> -D "<domain>\<user>" -w '<password>' \
  -b "dc=<domain>,dc=<tld>" "(sAMAccountName=<target_user>)"
```

**ldapsearch 주요 필터:**

| 필터 | 용도 |
|------|------|
| `(objectClass=user)` | 사용자 계정만 조회 |
| `(objectClass=computer)` | 컴퓨터 객체만 조회 |
| `(objectClass=group)` | 그룹만 조회 |
| `(sAMAccountName=<user>)` | 특정 사용자 조회 |
| `(memberOf=CN=<group>,...)` | 특정 그룹 소속 사용자 |
| `(userAccountControl:1.2.840.113556.1.4.803:=2)` | 비활성화된 계정 |

**LDAP 주요 속성:**

- `sAMAccountName` — 로그인 ID (가장 많이 사용)
- `userPrincipalName (UPN)` — 이메일 형식 ID (user@domain)
- `displayName` — 사용자 이름
- `memberOf` — 소속 그룹
- `userAccountControl` — 계정 상태 (512=정상 활성)
- `servicePrincipalName (SPN)` — Kerberoasting 대상 판별에 사용

### nxc LDAP

```bash
# LDAP 사용자 열거
nxc ldap <ip> --users

# password 정책 확인 (lockout threshold, 최소 길이 등)
nxc ldap <ip> -u '' -p '' --pass-pol

# ADCS 서비스 실행 여부 확인
nxc ldap <ip> -u <user> -p <pass> -M adcs
# 또는 hash 사용
nxc ldap <ip> -u <user> -H <ntlm_hash> -M adcs
```

### windapsearch

Python 기반 LDAP 열거 도구. 익명 binding이 허용된 환경에서 유용하다.

```bash
# 도메인 사용자 열거
python3 windapsearch.py -u "" --dc-ip <dc_ip> -U

# 특정 그룹 검색
python3 windapsearch.py -u "" --dc-ip <dc_ip> --groups | grep -i "Remote"

# 특정 그룹 멤버 조회
python3 windapsearch.py -u "" --dc-ip <dc_ip> -U -m "Remote Management Users"
```

---

## RPC Enumeration

### rpcclient

```bash
# NULL session으로 연결
rpcclient -N -U '' <ip>

# 연결 후 명령어
rpcclient $> enumdomusers      # 도메인 사용자 열거
rpcclient $> enumdomgroups     # 도메인 그룹 열거
rpcclient $> queryuser <rid>   # 특정 사용자 정보
rpcclient $> querygroupmem <rid>  # 그룹 멤버 정보
rpcclient $> getdompwinfo      # password 정책
```

### enum4linux

Windows 및 Samba 호스트의 시스템 정보를 열거하기 위한 도구. enum.exe의 Linux 대안.

```bash
# 전체 열거 (사용자, 그룹, 공유, OS 정보)
enum4linux -a <ip>

# enum4linux-ng (Python 개선판)
enum4linux-ng -A <ip>
```

---

## AD Enumeration

### BloodHound

AD 환경의 권한 관계를 시각화하는 도구. 공격 경로를 찾는 데 핵심적이다. 단, 대량의 LDAP 쿼리를 발생시키므로 SIEM에서 탐지될 수 있다.

```bash
# Linux에서 데이터 수집 (bloodhound-python)
bloodhound-python -u <user> -p <pass> -d <domain> \
  -dc <dc_hostname> -c all -ns <dc_ip>
```

```powershell
# Windows에서 데이터 수집 (SharpHound)
.\SharpHound.exe -c All
```

수집된 JSON/ZIP 파일을 BloodHound GUI에 upload하면 공격 경로 분석이 가능하다.

### 수동 AD 열거 (PowerShell)

```powershell
# 현재 도메인 정보
$env:USERDOMAIN
Get-WmiObject -Namespace root\cimv2 -Class Win32_ComputerSystem | Select Name, Domain

# 사용자 열거
net user
net user /domain
net user <username> /domain

# 그룹 열거
net group /domain
net localgroup
net localgroup Administrators

# 도메인 컨트롤러 확인
nltest /dclist:<domain>
```

---

## 호스트 정보 수집 (Post-Exploitation)

내부 호스트에 접근한 후 수행하는 로컬 정보 수집. 현재 환경을 파악하고 다음 행동을 결정하기 위한 단계다.

### 시스템 정보

```powershell
# OS 및 패치 정보
systeminfo
Get-HotFix

# 호스트 이름
hostname

# 네트워크
ipconfig /all
route print
arp -a

# 프로세스 (AV/EDR 확인용)
tasklist /V
Get-Process
wmic process get ProcessId,Description,ParentProcessId
```

### credential 탐색

```powershell
# 파일에서 평문 password 검색
findstr /si password *.txt *.xml *.ini *.config

# PowerShell 히스토리
type $env:USERPROFILE\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt

# Unattend/Sysprep 파일 (설치 시 사용된 credential 포함 가능)
# 확인 경로:
#   C:\unattend.xml
#   C:\Windows\Panther\Unattend.xml
#   C:\Windows\Panther\Unattend\Unattend.xml
#   C:\Windows\system32\sysprep.inf
#   C:\Windows\system32\sysprep\sysprep.xml
```

### PowerShell session

```powershell
# 현재 PowerShell session ID (0=SYSTEM 서비스, 1+=유저 session)
(Get-Process -PID $PID).SessionId
```

---

## Linux Enumeration

```bash
# 시스템 정보
uname -a
cat /etc/os-release
hostname

# 사용자 정보
whoami
id
cat /etc/passwd
cat /etc/shadow  # root 권한 필요

# 네트워크
ip a
ss -tlnp
netstat -tlnp

# SUID binary
find / -perm -4000 -type f 2>/dev/null

# cron jobs
crontab -l
ls -la /etc/cron*
cat /etc/crontab

# 실행 중 프로세스
ps auxww

# 쓰기 가능한 directory
find / -writable -type d 2>/dev/null
```
