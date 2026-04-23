# OSINT / 외부 정찰

!!! abstract "개요"
    공격 시작 전, 타겟 기관의 외부 자산·인력·기술 스택을 수집하는 단계.  
    **레드팀 라이프사이클상 "초기 정찰"** 에 해당하며, 이후의 피싱, 외부망 취약점 공격, Assumed Breach 진입점 선정의 근거가 된다.

!!! info "문서 분담"
    - **이 문서**: Passive OSINT 중심 (타겟에 직접 패킷을 보내지 않고 3rd-party/공개 데이터로 수집)
    - [외부 정찰 (Active)](reconnaissance.md): Nmap/디렉토리 퍼징/서브도메인 브루트포스 등 **Active 스캔**
    - 진행 순서: **Passive → Active** (OPSEC 우선)

---

## 수집 범위 체크리스트

- [ ] 루트 도메인 및 서브도메인 (서비스 표면)
- [ ] 외부 IP 대역 (ASN / SPF / MX / WHOIS)
- [ ] 클라우드 자산 (S3 / Azure Blob / GCS / Tenant ID)
- [ ] 모바일 앱 (Play Store / App Store / APK / IPA)
- [ ] 회사 조직도 / 임직원 (LinkedIn, 채용공고, 보도자료)
- [ ] 이메일 주소 포맷 및 유효 계정
- [ ] 과거 유출된 크리덴셜 (Breach Data)
- [ ] 기술 스택 (HTTP 헤더, CDN, WAF, CMS, 프레임워크 버전)
- [ ] Git / 공개 저장소 유출 (소스 / 시크릿)
- [ ] VPN / 원격 근무 인프라 (Citrix, Pulse, FortiGate 등)

---

## 도메인 / 서브도메인 열거

```bash
# Passive (탐지 회피 최우선)
amass enum -passive -d target.com -o amass.txt
subfinder -d target.com -silent -o subfinder.txt
findomain -t target.com -q

# Certificate Transparency
curl -s "https://crt.sh/?q=%25.target.com&output=json" | jq -r '.[].name_value' | sort -u

# DNS Bruteforce (로그에 흔적 남음, 레드팀 OPSEC 주의)
shuffledns -d target.com -w resolvers.txt -list subdomains.txt
puredns bruteforce wordlist.txt target.com -r resolvers.txt

# 서브도메인 테이크오버 점검
subjack -w subs.txt -t 20 -o takeover.txt -ssl
```

!!! tip "OPSEC"
    Active DNS/포트 스캔은 반드시 **레드팀 인프라(점프박스 or VPS)**에서 수행. 공격자 IP가 타겟의 DNS 로그에 남지 않도록 `dnspython` 재귀 조회 대신 퍼블릭 리졸버 및 크롤링 기반 소스를 우선 사용한다.

---

## ASN / IP 대역 / CDN Bypass

```bash
# ASN 조회 (clouflare/aws 우회 가능성 판단)
whois -h whois.cymru.com " -v target.com"

# IP 이력 기반 origin server 노출 확인
curl -s "https://securitytrails.com/domain/target.com/history/a"
# (API: securitytrails)

# CDN 뒤 origin 추적
cloudflair -d target.com  # ssl 인증서로 origin ip 검색
```

---

## 이메일 / 임직원 OSINT

```bash
# 이메일 수집
theHarvester -d target.com -b all -l 500

# LinkedIn 기반 이메일 추측 (회사 직원 → 이메일 포맷 + 이름)
linkedin2username -c "Target Corp" -o users.txt
# 이후 포맷 주입: first.last@target.com, f.last@target.com 등

# O365/Azure 계정 유효성 확인 (Validate Only)
o365spray --validate -d target.com
o365spray --enum --userlist users.txt -d target.com --legacy
# --legacy: Basic Auth (EWS/Autodiscover), --adfs: 연동 도메인

# 이메일 유출 / Breach 조회
holehe user@target.com                    # 서비스 가입 여부
h8mail -t user@target.com -ch dehashed.txt # 유출 패스워드 검색
```

!!! warning "탐지"
    `o365spray --enum` 은 Sign-in Log(`Event 4625 / UAL`)에 대량 로그인 시도로 기록될 수 있음.  
    기업 환경에서는 `--timeout` 늘리고, `--sleep 30` 등으로 속도 조절. jitter 필수.

---

## 기술 스택 식별

```bash
# 웹 스택
whatweb -a 3 https://target.com
wappalyzer https://target.com

# HTTP 헤더 / 서버 / WAF
curl -sI https://target.com
wafw00f https://target.com

# 파비콘 해시 기반 asset 검색 (Shodan / ZoomEye)
python3 favup.py -u https://target.com
# shodan: http.favicon.hash:<hash>
```

---

## 공개 저장소 / 시크릿 유출

```bash
# GitHub dork
github-search -q "target.com password"
github-dorks -t $GITHUB_TOKEN -u TargetOrg

# 조직/저장소 전수 스캔
trufflehog github --org=TargetOrg
gitleaks detect --source=. --verbose

# 유출된 .env / .git / dockerfile
nuclei -u https://target.com -t http/exposures/
```

---

## Shodan / Censys 기반 자산 발견

```bash
# Shodan
shodan search 'ssl.cert.subject.cn:"target.com"'
shodan search 'org:"Target Corp" port:445'
shodan search 'http.favicon.hash:<hash>'

# Censys
censys search 'services.tls.certificates.leaf_data.subject.common_name:"target.com"'
```

!!! tip "공격 포인트 후보 식별"
    - `port:3389` → 외부 노출 RDP
    - `port:443 ssl.cert.subject.cn:"*.target.com"` → 내부용 포털의 외부 노출
    - `http.title:"Citrix"` / `"Pulse Secure"` → VPN 컴포넌트 취약점 스캔 대상

---

## 클라우드 자산 열거

```bash
# S3 / Azure Blob / GCS 버킷 추측
cloud_enum -k target -k targetcorp
s3scanner scan --bucket target-backup
gcp_bucket_brute -k target

# Azure AD / M365 Tenant 식별
python3 AADInternals-Endpoints.py --tenant target.com
# https://login.microsoftonline.com/<domain>/.well-known/openid-configuration
curl -s "https://login.microsoftonline.com/target.com/.well-known/openid-configuration" | jq
```

---

## 참고 체크리스트 (산출물)

| 산출물 | 용도 |
|---|---|
| `subdomains.txt` | 외부 서비스 공격 표면 |
| `users.txt` / `emails.txt` | Phishing / Password Spray |
| `tech-stack.md` | CVE 매핑 / 1-day 검색 |
| `breach-creds.csv` | Credential Stuffing |
| `cloud-assets.md` | 클라우드 공격 (S3 / Azure / GCP) |
| `vpn-portals.md` | 외부망 초기 침투 시도 |

---

## 관련 문서

- [초기 접근](initial-access.md)
- [Reconnaissance (내부 정찰)](reconnaissance.md)
- [Phishing](phishing.md)
