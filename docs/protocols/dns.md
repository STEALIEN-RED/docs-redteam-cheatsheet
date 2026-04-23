# DNS (53)

Domain Name System. 도메인-IP 변환. Zone Transfer, subdomain 열거 등에 활용.

---

## 열거

```bash
# 기본 정보
nslookup TARGET
dig TARGET
host TARGET

# 특정 레코드 타입
dig TARGET A          # IPv4
dig TARGET AAAA       # IPv6
dig TARGET MX         # 메일 서버
dig TARGET NS         # 네임서버
dig TARGET TXT        # TXT 레코드 (SPF, DKIM 등)
dig TARGET ANY        # 모든 레코드
dig TARGET SOA        # Start of Authority

# 역방향 DNS
dig -x IP_ADDRESS
nslookup IP_ADDRESS

# 특정 DNS 서버에 쿼리
dig @DNS_SERVER domain.com
nslookup domain.com DNS_SERVER
```

---

## Zone Transfer (AXFR)

DNS 서버 설정이 잘못되면 전체 DNS 레코드를 가져올 수 있다.

```bash
# Zone Transfer 시도
dig axfr domain.com @DNS_SERVER
host -l domain.com DNS_SERVER

# nmap
nmap --script=dns-zone-transfer --script-args dns-zone-transfer.domain=domain.com -p 53 DNS_SERVER
```

---

## subdomain 열거

```bash
# DNSRecon
dnsrecon -d domain.com -t brt -D /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt

# gobuster
gobuster dns -d domain.com -w subdomains.txt -t 50

# ffuf (VHOST fuzzing)
ffuf -u http://TARGET -H "Host: FUZZ.domain.com" -w subdomains.txt -fs SIZE

# fierce
fierce --domain domain.com

# amass
amass enum -d domain.com
amass enum -d domain.com -passive  # Passive only
```

---

## AD 환경 DNS

```bash
# SRV 레코드로 DC 찾기
dig SRV _ldap._tcp.dc._msdcs.domain.com @DC_IP
dig SRV _kerberos._tcp.domain.com @DC_IP
dig SRV _gc._tcp.domain.com @DC_IP

# DC의 호스트네임 확인
nslookup -type=SRV _ldap._tcp.dc._msdcs.domain.com DC_IP
```

---

## DNS 캐시 스누핑

```bash
# 내부 DNS 서버가 캐시한 레코드 확인 (정보 수집)
dig @DNS_SERVER domain.com A +norecurse
```

---

## Nmap NSE

```bash
nmap --script=dns-brute -p 53 TARGET
nmap --script=dns-cache-snoop -p 53 TARGET
nmap --script=dns-zone-transfer --script-args dns-zone-transfer.domain=domain.com -p 53 TARGET
```

---

## 모던 subdomain 수집

Passive + Active 를 모두 조합해야 누락이 줄어든다.

```bash
# Passive: 공개 소스(CT logs, passive DNS) 에서 수집
subfinder -d domain.com -all -silent -o subs.txt
assetfinder --subs-only domain.com
amass enum -passive -d domain.com

# Active: 수집한 목록 + bruteforce + resolver 검증
puredns bruteforce subdomains.txt domain.com -r resolvers.txt -w brute.txt
puredns resolve subs.txt -r resolvers.txt -w live.txt

# CT 로그 직접 조회
curl -s "https://crt.sh/?q=%25.domain.com&output=json" | jq -r '.[].name_value' | sort -u
```

### 와일드카드 탐지

```bash
# 와일드카드가 설정되어 있으면 FP 가 대량 발생 → bruteforce 결과를 반드시 필터
dig 'random-nonexistent-123456.domain.com'
# → A 레코드가 응답되면 와일드카드. puredns 는 기본적으로 감지/제외
```

---

## subdomain 탈취 (Dangling DNS)

CNAME 이 해제된 외부 서비스(S3, Azure, Heroku, GitHub Pages 등)를 가리키고 있으면 공격자가 해당 서비스를 재등록해 subdomain을 탈취할 수 있다.

```bash
# 취약 CNAME 자동 탐지
subjack -w subs.txt -t 50 -timeout 30 -ssl -c /opt/subjack/fingerprints.json -v
nuclei -l subs.txt -t http/takeovers/

# 대표 지문
# "NoSuchBucket"       → AWS S3
# "There isn't a GitHub Pages site here"
# "Do you want to register *.azurewebsites.net?"
# "The request could not be satisfied" → CloudFront
```

---

## 기타

```bash
# DoH(DNS over HTTPS) 를 이용한 차단 우회 / 탐지 회피
curl -s 'https://cloudflare-dns.com/dns-query?name=domain.com&type=A' -H 'accept: application/dns-json'

# dnsx - 대량 해상도/레코드 타입 확인
dnsx -l subs.txt -a -resp -silent
dnsx -l subs.txt -cname -resp -silent | grep -iE 'cloudfront|s3|azure|github'
```
