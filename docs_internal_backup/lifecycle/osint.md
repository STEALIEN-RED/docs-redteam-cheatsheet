# OSINT / External Recon

작전 시작 전에 target의 외부 자산, 인력, tech stack을 긁어모으는 단계.
레드팀 lifecycle 상 "초기 정찰" 에 해당하고, 이후 phishing이나 외부망 취약점 공격, Assumed Breach 진입점 선정이 전부 여기서 나온 결과물 위에서 돌아간다.

!!! info "reconnaissance.md 와의 분담"
    - **이 문서**: Passive OSINT 중심. target에 직접 패킷을 쏘지 않고 3rd-party / public 데이터로 긁어오는 작업.
    - [외부 정찰 (Active)](reconnaissance.md): Nmap, directory fuzzing, subdomain bruteforce 처럼 target에 직접 붙는 Active scan.
    - 순서는 항상 **Passive → Active**. OPSEC 상 당연한 얘기.

---

## 수집 범위 checklist

- [ ] root domain / subdomain (서비스 표면)
- [ ] 외부 IP range (ASN / SPF / MX / WHOIS)
- [ ] Cloud asset (S3 / Azure Blob / GCS / Tenant ID)
- [ ] Mobile app (Play Store / App Store / APK / IPA)
- [ ] 조직도 / 임직원 (LinkedIn, 채용공고, 보도자료)
- [ ] email 주소 포맷 및 valid 계정
- [ ] 과거 유출 credential (breach data)
- [ ] Tech stack (HTTP header, CDN, WAF, CMS, framework 버전)
- [ ] Git / public repo 유출 (source, secret)
- [ ] VPN / remote access portal (Citrix, Pulse, FortiGate 등)

---

## Domain / Subdomain 열거

```bash
# Passive (탐지 회피 우선)
amass enum -passive -d target.com -o amass.txt
subfinder -d target.com -silent -o subfinder.txt
findomain -t target.com -q

# Certificate Transparency
curl -s "https://crt.sh/?q=%25.target.com&output=json" | jq -r '.[].name_value' | sort -u

# DNS Bruteforce - 로그에 흔적 남기 때문에 passive로 먼저 다 긁고 마지막 보강용
shuffledns -d target.com -w resolvers.txt -list subdomains.txt
puredns bruteforce wordlist.txt target.com -r resolvers.txt

# Subdomain takeover 점검
subjack -w subs.txt -t 20 -o takeover.txt -ssl
```

!!! tip "OPSEC"
    Active DNS / port scan은 반드시 redirector나 VPS 같은 ops infra에서 돌린다. 공격자 IP가 target DNS log에 박히지 않게, recursive resolver는 public resolver (1.1.1.1, 8.8.8.8) 또는 crawling 기반 source 위주로 간다.

---

## ASN / IP range / CDN Bypass

```bash
# ASN 조회 - Cloudflare / AWS 뒤에 숨어있는지 확인용
whois -h whois.cymru.com " -v target.com"

# 과거 IP 이력에서 origin 노출 확인
curl -s "https://securitytrails.com/domain/target.com/history/a"   # SecurityTrails API

# CDN 뒤 origin 추적 (SSL 인증서 기반)
cloudflair -d target.com
```

---

## Email / 임직원 OSINT

```bash
# Email 수집
theHarvester -d target.com -b all -l 500

# LinkedIn → username 생성
linkedin2username -c "Target Corp" -o users.txt
# 이후 first.last@target.com, f.last@target.com 등 포맷으로 변환

# O365 / Azure 계정 유효성 확인 (logon은 안 함, validate만)
o365spray --validate -d target.com
o365spray --enum --userlist users.txt -d target.com --legacy
# --legacy : Basic Auth (EWS / Autodiscover)
# --adfs   : 연동 domain

# Breach data 조회
holehe user@target.com                     # 어디에 가입되어 있는지
h8mail -t user@target.com -ch dehashed.txt # leaked password 검색
```

!!! warning "탐지"
    `o365spray --enum`은 Sign-in Log (Event 4625 / UAL) 에 대량 로그인 시도로 박힌다.
    기업 환경에서는 `--timeout` 키우고 `--sleep 30`으로 간격 벌리는 편. jitter 필수.

---

## Tech stack 식별

```bash
# Web stack
whatweb -a 3 https://target.com
wappalyzer https://target.com

# HTTP header / server / WAF
curl -sI https://target.com
wafw00f https://target.com

# Favicon hash로 asset 검색 (Shodan, ZoomEye 에서 동일 hash 서버 찾기)
python3 favup.py -u https://target.com
# shodan: http.favicon.hash:<hash>
```

---

## Public repo / secret 유출

```bash
# GitHub dork
github-search -q "target.com password"
github-dorks -t $GITHUB_TOKEN -u TargetOrg

# Org / repo 전수 스캔
trufflehog github --org=TargetOrg
gitleaks detect --source=. --verbose

# 노출된 .env / .git / dockerfile
nuclei -u https://target.com -t http/exposures/
```

---

## Shodan / Censys 로 자산 발견

```bash
# Shodan
shodan search 'ssl.cert.subject.cn:"target.com"'
shodan search 'org:"Target Corp" port:445'
shodan search 'http.favicon.hash:<hash>'

# Censys
censys search 'services.tls.certificates.leaf_data.subject.common_name:"target.com"'
```

!!! tip "공격 포인트 후보"
    - `port:3389` → 외부 노출 RDP
    - `port:443 ssl.cert.subject.cn:"*.target.com"` → 원래 내부용인데 외부로 새어나온 포털
    - `http.title:"Citrix"` / `"Pulse Secure"` → VPN 컴포넌트 N-day 대상

---

## Cloud asset 열거

```bash
# S3 / Azure Blob / GCS bucket 추측
cloud_enum -k target -k targetcorp
s3scanner scan --bucket target-backup
gcp_bucket_brute -k target

# Azure AD / M365 Tenant 식별
python3 AADInternals-Endpoints.py --tenant target.com
curl -s "https://login.microsoftonline.com/target.com/.well-known/openid-configuration" | jq
```

---

## 산출물 checklist

recon 끝에 이런 파일들이 남아있으면 이후 단계로 넘어갈 준비 완료.

| 산출물 | 용도 |
|---|---|
| `subdomains.txt` | 외부 서비스 공격 표면 |
| `users.txt` / `emails.txt` | Phishing / Password Spray |
| `tech-stack.md` | CVE 매핑, 1-day 검색 |
| `breach-creds.csv` | Credential Stuffing |
| `cloud-assets.md` | Cloud 공격 (S3 / Azure / GCP) |
| `vpn-portals.md` | 외부망 initial access 시도 |

---

## 관련 문서

- [초기 침투](initial-access.md)
- [외부 정찰 (Active)](reconnaissance.md)
- [Phishing](phishing.md)
