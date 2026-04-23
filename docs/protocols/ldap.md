# LDAP (389/636)

Lightweight Directory Access Protocol. AD 환경의 디렉토리 서비스 쿼리에 사용. 636은 LDAPS (SSL/TLS).

---

## 열거

### 인증 없이 (Anonymous Bind)

```bash
# Anonymous bind 가능 여부 확인
ldapsearch -x -H ldap://TARGET -b '' -s base namingContexts

# Base DN 확인
ldapsearch -x -H ldap://TARGET -b '' -s base defaultNamingContext

# 전체 도메인 덤프 (anonymous bind 허용 시)
ldapsearch -x -H ldap://TARGET -b 'DC=domain,DC=local'

# nxc anonymous 확인
nxc ldap TARGET -u '' -p ''
```

### 인증 후

```bash
# 전체 사용자 열거
ldapsearch -x -H ldap://TARGET -D 'DOMAIN\user' -w 'pass' -b 'DC=domain,DC=local' '(objectClass=user)' sAMAccountName

# 사용자 상세 정보 (설명 필드에 비밀번호가 있는 경우 많음)
ldapsearch -x -H ldap://TARGET -D 'user@domain.local' -w 'pass' -b 'DC=domain,DC=local' '(objectClass=person)' sAMAccountName description memberOf

# 관리자 그룹 멤버
ldapsearch -x -H ldap://TARGET -D 'user@domain.local' -w 'pass' -b 'DC=domain,DC=local' '(memberOf=CN=Domain Admins,CN=Users,DC=domain,DC=local)' sAMAccountName

# 컴퓨터 계정
ldapsearch -x -H ldap://TARGET -D 'user@domain.local' -w 'pass' -b 'DC=domain,DC=local' '(objectClass=computer)' name operatingSystem

# SPN 설정된 계정 (Kerberoastable)
ldapsearch -x -H ldap://TARGET -D 'user@domain.local' -w 'pass' -b 'DC=domain,DC=local' '(&(objectClass=user)(servicePrincipalName=*))' sAMAccountName servicePrincipalName

# Pre-Auth 비활성화 계정 (AS-REP Roastable)
ldapsearch -x -H ldap://TARGET -D 'user@domain.local' -w 'pass' -b 'DC=domain,DC=local' '(userAccountControl:1.2.840.113556.1.4.803:=4194304)' sAMAccountName

# 비활성화된 계정
ldapsearch -x -H ldap://TARGET -D 'user@domain.local' -w 'pass' -b 'DC=domain,DC=local' '(userAccountControl:1.2.840.113556.1.4.803:=2)' sAMAccountName

# LAPS 비밀번호

ldapsearch -x -H ldap://TARGET -D 'user@domain.local' -w 'pass' -b 'DC=domain,DC=local' '(ms-Mcs-AdmPwd=*)' ms-Mcs-AdmPwd sAMAccountName
```

### nxc LDAP 열거

```bash
nxc ldap DC_IP -u user -p pass --users
nxc ldap DC_IP -u user -p pass --groups
nxc ldap DC_IP -u user -p pass --kerberoasting
nxc ldap DC_IP -u user -p pass --asreproast
nxc ldap DC_IP -u user -p pass -M laps
nxc ldap DC_IP -u user -p pass -M adcs
nxc ldap DC_IP -u user -p pass -M get-desc-users  # description 필드 탐색
```

### windapsearch

```bash
# 사용자 열거
windapsearch -d domain.local --dc DC_IP -u user@domain.local -p pass -U

# 관리자 열거
windapsearch -d domain.local --dc DC_IP -u user@domain.local -p pass --da

# 그룹 멤버
windapsearch -d domain.local --dc DC_IP -u user@domain.local -p pass -G

# Unconstrained Delegation
windapsearch -d domain.local --dc DC_IP -u user@domain.local -p pass --unconstrained
```

---

## LDAP 필터 구문

```text
# 기본 구문
(attribute=value)              # 일치
(attribute=*value*)            # 와일드카드
(!(attribute=value))           # NOT
(&(cond1)(cond2))             # AND
(|(cond1)(cond2))             # OR

# UserAccountControl 비트 필터 (OID: 1.2.840.113556.1.4.803)
(userAccountControl:1.2.840.113556.1.4.803:=2)        # ACCOUNTDISABLE
(userAccountControl:1.2.840.113556.1.4.803:=512)      # NORMAL_ACCOUNT
(userAccountControl:1.2.840.113556.1.4.803:=4194304)  # DONT_REQUIRE_PREAUTH
(userAccountControl:1.2.840.113556.1.4.803:=524288)   # TRUSTED_FOR_DELEGATION
(userAccountControl:1.2.840.113556.1.4.803:=16777216) # TRUSTED_TO_AUTH_FOR_DELEGATION
```

### 유용한 LDAP 필터 예시

```bash
# 최근 생성된 계정 (7일 이내)
'(&(objectClass=user)(whenCreated>=20260328000000.0Z))'

# 비밀번호 만료 안 되는 계정
'(userAccountControl:1.2.840.113556.1.4.803:=65536)'

# 관리자 그룹 재귀적 멤버
'(memberOf:1.2.840.113556.1.4.1941:=CN=Domain Admins,CN=Users,DC=domain,DC=local)'
```

---

## LDAP Signing

LDAP Signing이 비활성화되면 NTLM Relay via LDAP이 가능하다.

```bash
# LDAP Signing 확인
nxc ldap DC_IP -u user -p pass -M ldap-checker

# Channel Binding 확인 (LDAPS)
# ldap-checker 모듈이 확인해줌
```

---

## Nmap NSE

```bash
nmap --script=ldap-rootdse -p 389 TARGET
nmap --script=ldap-search -p 389 TARGET
nmap --script=ldap-brute -p 389 TARGET
```
