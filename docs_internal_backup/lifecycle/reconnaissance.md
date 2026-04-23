# 외부 정찰

작전 시작하면 제일 먼저 붙드는 단계. target 의 외부 자산 / 네트워크 / 서비스 / 호스트 를 훑어서 공격 표면이 어디까지 펼쳐져 있는지 그림을 그린다.

OSINT 로 넓게 뿌리고 → 포트 스캔 / 서비스 식별 / directory·subdomain 열거로 좁혀 들어가는 순서.

!!! info "문서 분담"
    - **이 문서**: Active 스캔 중심 (Nmap, directory 퍼징, 서비스 식별 등 **패킷을 직접 target에 보내는** 작업)
    - [OSINT / 외부 정찰 상세](osint.md): Passive 정찰 중심 (CT 로그, Shodan, GitHub 시크릿, LinkedIn, Breach 데이터 등 **target에 직접 닿지 않고** 수집하는 작업)
    - 레드팀 OPSEC 관점에서는 Passive → Active 순으로 진행한다.

---

## Nmap

### 기본 스캔

```bash
# TCP SYN 스캔 (기본, root 권한 필요)
nmap -sS -Pn -n --open -p- --min-rate 5000 <target> -oA tcp_scan

# 상세 스캔 (서비스/버전 + 기본 스크립트)
nmap -sV -sC -Pn -n --open -p <ports> <target> -oA detailed_scan

# UDP 스캔 (시간 오래 걸림, 주요 포트만)
nmap -sU -Pn --top-ports 100 <target> -oA udp_scan
```

### 실무 패턴

```bash
# 1단계: 빠른 포트 스캔으로 열린 포트 확인
nmap -sS -Pn -n --open -p- --min-rate 5000 -oA allports <target>

# 2단계: 열린 포트에 대해 상세 스캔
nmap -sV -sC -Pn -n --open -p 53,88,135,139,389,445,636,3268 \
  --max-retries 1 --min-rate 2000 -oA detailed <target>
```

### 주요 옵션

| 옵션 | 설명 |
|------|------|
| `-sS` | TCP SYN 스캔 (half-open, 빠르고 로그 적음) |
| `-sV` | 서비스 버전 탐지 |
| `-sC` | 기본 NSE 스크립트 실행 |
| `-Pn` | 호스트 discovery 생략 (ping 안 보냄) |
| `-n` | DNS 역 조회 안 함 |
| `--open` | 열린 포트만 표시 |
| `-p-` | 전체 포트 (1-65535) |
| `-oA` | 모든 형식으로 출력 (nmap/xml/gnmap) |
| `--min-rate` | 초당 최소 패킷 수 |
| `-sU` | UDP 스캔 |

### NSE 스크립트

```bash
# SMB 취약점 스캔
nmap --script smb-vuln* -p 445 <target>

# LDAP 열거
nmap --script ldap-search -p 389 <target>

# MS-SQL 정보
nmap --script ms-sql-info -p 1433 <target>
```

---

## DNS Enumeration

```bash
# Zone Transfer 시도
dig axfr @<dns_server> <domain>

# subdomain 열거
dig any <domain> @<dns_server>

# reverse lookup
nmap -sL <subnet> | grep "(" | cut -d"(" -f2 | cut -d")" -f1
```

---

## Web Directory Enumeration

### Gobuster

```bash
# directory 스캔
gobuster dir -u http://<target> -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -t 50

# 확장자 포함
gobuster dir -u http://<target> -w <wordlist> -x php,asp,aspx,txt,html,bak -t 50

# vhost 스캔
gobuster vhost -u http://<domain> -w <wordlist> --append-domain
```

### Feroxbuster

```bash
feroxbuster -u http://<target> -w <wordlist> -t 50 -d 2 -x php,asp,aspx
```

### ffuf

```bash
# directory 퍼징
ffuf -u http://<target>/FUZZ -w <wordlist> -mc 200,301,302,403

# subdomain 퍼징
ffuf -u http://<target> -H "Host: FUZZ.<domain>" -w <wordlist> -fs <filter_size>

# POST parameter 퍼징
ffuf -u http://<target>/login -X POST -d "username=admin&password=FUZZ" -w <wordlist>
```

---

## OSINT

### 도메인/IP 정보

```bash
# whois
whois <domain>

# theHarvester - 이메일, subdomain 수집
theHarvester -d <domain> -b google,bing,linkedin

# Amass - subdomain 열거
amass enum -d <domain> -passive
amass enum -d <domain> -active  # DNS 해석 포함
```

### Google Dorking

```text
# 민감 파일 탐색
site:<domain> filetype:pdf | filetype:xlsx | filetype:docx
site:<domain> filetype:sql | filetype:bak | filetype:log
site:<domain> filetype:env | filetype:cfg | filetype:conf

# 로그인 페이지
site:<domain> inurl:login | inurl:admin | inurl:portal

# directory 리스팅
site:<domain> intitle:"index of"

# 에러 메시지 (정보 유출)
site:<domain> "sql syntax" | "mysql_fetch" | "ORA-" | "syntax error"

# 노출된 설정 파일
site:<domain> ext:xml | ext:json | ext:yaml inurl:config

# 기타
site:<domain> "password" | "passwd" | "credentials" filetype:txt
```

### 인증서 투명성 (Certificate Transparency)

```bash
# crt.sh - 인증서에 등록된 subdomain 검색
curl -s "https://crt.sh/?q=%25.<domain>&output=json" | jq -r '.[].name_value' | sort -u

# certspotter
curl -s "https://api.certspotter.com/v1/issuances?domain=<domain>&include_subdomains=true" | jq -r '.[].dns_names[]' | sort -u
```

### Shodan / Censys

```bash
# Shodan CLI
shodan search "hostname:<domain>"
shodan host <ip>
shodan search "org:\"Company Name\""

# Shodan 웹 검색 구문
hostname:<domain>
ssl.cert.subject.CN:<domain>
org:"Company Name" port:443

# Censys
censys search "<domain>"
censys view <ip>
```

### GitHub / 소스코드 정찰

```bash
# truffleHog - Git 히스토리에서 시크릿 탐지
trufflehog git https://github.com/org/repo

# git-secrets
git secrets --scan

# GitHub Dorking (웹 검색)
# org:<org_name> password
# org:<org_name> api_key
# org:<org_name> secret
# org:<org_name> token
# org:<org_name> filename:.env
# org:<org_name> filename:id_rsa

# GitDorker
python3 GitDorker.py -t TOKEN -org <org_name>

# gitleaks
gitleaks detect --source /path/to/repo
```

### 인증정보 검색

- 유출된 credential DB 확인 (dehashed, haveibeenpwned 등)
- GitHub/GitLab에서 하드코딩된 credential 검색
- Paste 사이트 모니터링 (PasteBin, GhostBin)

### Cloud 자산 정찰

```bash
# AWS S3 버킷 열거
aws s3 ls s3://<bucket> --no-sign-request
# 도구: cloud_enum, S3Scanner, bucket_finder

# Azure Blob
https://<storage>.blob.core.windows.net/<container>?restype=container&comp=list
# 도구: MicroBurst

# GCP
# 도구: GCPBucketBrute

# 통합 도구
python3 cloud_enum.py -k <keyword>
```

### 이메일 수집

```bash
# theHarvester (종합)
theHarvester -d <domain> -b all

# hunter.io API
curl "https://api.hunter.io/v2/domain-search?domain=<domain>&api_key=KEY" | jq '.data.emails[].value'

# LinkedIn 기반 이름 → 이메일 패턴 추측
# firstname.lastname@domain.com
# f.lastname@domain.com
# 도구: linkedin2username, CrossLinked
```

---

## 주요 포트 참고

| 포트 | 서비스 | 비고 |
|------|--------|------|
| 21 | FTP | anonymous 로그인 확인 |
| 22 | SSH | banner grab, 버전 확인 |
| 25 | SMTP | relay 확인, 사용자 열거 |
| 53 | DNS | zone transfer |
| 80/443 | HTTP/HTTPS | 웹 어플리케이션 |
| 88 | Kerberos | AD 환경 확인 지표 |
| 135 | MSRPC | Windows RPC |
| 139/445 | SMB | 공유 폴더, null session |
| 389/636 | LDAP/LDAPS | AD 정보 열거 |
| 1433 | MSSQL | impacket-mssqlclient |
| 3268/3269 | Global Catalog | AD 포리스트 질의 |
| 3389 | RDP | 원격 데스크톱 |
| 5985/5986 | WinRM | evil-winrm |
| 8080 | HTTP Proxy | 웹 서버/프록시 |
