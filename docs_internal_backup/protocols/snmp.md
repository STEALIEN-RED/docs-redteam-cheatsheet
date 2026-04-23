# SNMP (161/162)

Simple Network Management Protocol. 네트워크 장비/서버 관리. Community String이 약하면 대량의 정보 노출.

---

## 열거

```bash
# 기본 community string 확인 (public, private)
onesixtyone -c /usr/share/seclists/Discovery/SNMP/common-snmp-community-strings.txt TARGET

# 대량 호스트 스캔
onesixtyone -c community.txt -i targets.txt
```

---

## 정보 수집

### snmpwalk

```bash
# 전체 MIB dump
snmpwalk -v2c -c public TARGET

# SNMPv1
snmpwalk -v1 -c public TARGET

# 특정 OID
snmpwalk -v2c -c public TARGET 1.3.6.1.2.1.1     # 시스템 정보
snmpwalk -v2c -c public TARGET 1.3.6.1.4.1.77.1.2.25  # Windows 사용자
snmpwalk -v2c -c public TARGET 1.3.6.1.2.1.25.4.2.1.2 # 실행 중인 프로세스
snmpwalk -v2c -c public TARGET 1.3.6.1.2.1.6.13.1.3   # TCP 열린 포트
snmpwalk -v2c -c public TARGET 1.3.6.1.2.1.25.6.3.1.2 # 설치된 소프트웨어
```

### 주요 OID

| OID | 정보 |
|-----|------|
| `1.3.6.1.2.1.1.1` | 시스템 설명 |
| `1.3.6.1.2.1.1.5` | 호스트명 |
| `1.3.6.1.4.1.77.1.2.25` | Windows 사용자 계정 |
| `1.3.6.1.2.1.25.4.2.1.2` | 실행 중인 프로세스 |
| `1.3.6.1.2.1.25.6.3.1.2` | 설치된 소프트웨어 |
| `1.3.6.1.2.1.6.13.1.3` | TCP 열린 포트 |
| `1.3.6.1.2.1.25.2.3.1` | 스토리지 유닛 |
| `1.3.6.1.2.1.2.2.1.2` | 네트워크 인터페이스 |

### snmp-check

```bash
# 종합 정보 수집
snmp-check TARGET -c public
```

---

## Community String Brute Force

```bash
# onesixtyone
onesixtyone -c /usr/share/seclists/Discovery/SNMP/common-snmp-community-strings.txt TARGET

# Hydra
hydra -P community.txt TARGET snmp

# nmap
nmap --script=snmp-brute -p 161 TARGET
```

---

## SNMPv3

```bash
# SNMPv3 사용자 열거
snmpwalk -v3 -l noAuthNoPriv -u USER TARGET

# 인증 + 암호화
snmpwalk -v3 -l authPriv -u USER -a SHA -A AUTH_PASS -x AES -X PRIV_PASS TARGET
```

---

## SNMP Write (private community)

```bash
# write community string이 있으면 설정 변경 가능
# 예: TFTP를 통한 설정 파일 추출 (Cisco)
snmpset -v2c -c private TARGET 1.3.6.1.4.1.9.9.96.1.1.1.1.2.1 i 1
```

---

## Nmap NSE

```bash
nmap --script=snmp-info,snmp-sysdescr,snmp-processes,snmp-interfaces -sU -p 161 TARGET
nmap --script=snmp-brute -sU -p 161 TARGET
nmap --script=snmp-win32-users -sU -p 161 TARGET
```
