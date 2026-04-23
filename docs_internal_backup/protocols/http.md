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

## directory / 파일 열거

```bash
# gobuster
gobuster dir -u http://TARGET -w /usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt -t 50
gobuster dir -u http://TARGET -w wordlist.txt -x php,asp,aspx,jsp,txt,bak,old,config -t 50

# feroxbuster (재귀적)
feroxbuster -u http://TARGET -w wordlist.txt --depth 3

# ffuf
ffuf -u http://TARGET/FUZZ -w wordlist.txt -mc 200,301,302,403 -t 50
```

## subdomain 열거

```bash
# DNS 기반
gobuster dns -d domain.com -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt -t 50

# VHOST 기반 (Host header)
ffuf -u http://TARGET -H "Host: FUZZ.domain.com" -w subdomains.txt -fs SIZE
gobuster vhost -u http://TARGET -w subdomains.txt --append-domain
```

## parameter 퍼징

```bash
# GET parameter 발견
ffuf -u "http://TARGET/page?FUZZ=test" -w /usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt -fs SIZE

# POST parameter 발견
ffuf -u http://TARGET/page -X POST -d "FUZZ=test" -w params.txt -fs SIZE
```

---

## 인증 공격

```bash
# 기본 credential 시도
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
□ 기본 credential (admin 패널, 관리 콘솔)
□ directory 열거 (숨겨진 페이지, 백업 파일)
□ 기술 스택 식별 (CMS, 프레임워크, 버전)
□ 소스 코드 내 주석, API 키, 비밀번호
□ .git, .svn, .env, backup 파일 노출
□ API endpoint 발견 및 문서화
□ Cookie, JWT, Session 관리 방식
□ CORS 설정, CSP header
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
