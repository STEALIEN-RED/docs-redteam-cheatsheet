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

# ffuf (VHOST 퍼징)
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
