# Mobile (Android / iOS)

최근 레드팀 scope 에 internal mobile app 이 포함되는 경우가 많다. 주 목적은 하드코딩된 credential / API endpoint / JWT secret 같은 backend infra 정보 추출이다.

---

## Android

### APK 추출 / 정적 분석

```bash
# 기기에서 APK 뽑기 (root 없어도 가능)
adb shell pm list packages | grep target
adb shell pm path com.target.app
adb pull /data/app/com.target.app-1/base.apk

# decompile
apktool d base.apk -o out/
jadx-gui base.apk          # GUI
jadx -d out_jadx base.apk  # CLI

# 자동화 정적 분석
mobsf      # docker run -it -p 8000:8000 opensecurity/mobile-security-framework-mobsf

# secret / endpoint 하드코딩 grep
cd out/
grep -rnE 'https?://|api[_-]?key|secret|token|Bearer' .
```

### 동적 분석 (Frida)

```bash
# frida-server push
adb push frida-server /data/local/tmp/
adb shell "su -c chmod 755 /data/local/tmp/frida-server && /data/local/tmp/frida-server &"

# process 리스팅
frida-ps -U

# SSL pinning bypass (universal)
frida -U -f com.target.app -l frida-ssl-pin-bypass.js --no-pause

# Root 탐지 우회 / 자주 쓰는 스크립트 모음
# https://codeshare.frida.re/
frida --codeshare fdciabdul/android-ssl-pinning-bypass -U -f com.target.app
```

### BurpSuite 로 트래픽 intercept

```bash
# 1. Burp CA 추출 → DER 변환 → system CA 로 push (Android 7+ 은 user CA 무시)
openssl x509 -inform PEM -outform DER -in cacert.pem -out cacert.der
hash=$(openssl x509 -inform DER -subject_hash_old -in cacert.der | head -1)
adb root && adb remount
adb push cacert.der /system/etc/security/cacerts/${hash}.0
adb shell chmod 644 /system/etc/security/cacerts/${hash}.0
adb reboot

# 2. Network Security Config 무시 우회는 frida 또는 apktool 로 재패키징
```

### 주요 점검 항목

| 항목 | 확인 방법 |
|---|---|
| Hardcoded secret | `grep api_key / AccessKey / Bearer / password` |
| Debuggable flag | `AndroidManifest.xml → android:debuggable="true"` |
| Backup 허용 | `allowBackup="true"` → `adb backup` 으로 데이터 탈취 |
| Exported Activity / Service | `exported="true"` → `am start` 로 직접 호출 |
| WebView | `setJavaScriptEnabled(true)` + `addJavascriptInterface` → RCE |
| Root / Frida detection | frida 로 무력화 가능 |

---

## iOS

### IPA 추출

```bash
# 탈옥 기기 필요
# frida-ios-dump
git clone https://github.com/AloneMonkey/frida-ios-dump
./dump.py com.target.app

# 정적 분석
otool -L Payload/target.app/target     # 링크된 library
class-dump -H Payload/target.app/target -o headers/
strings Payload/target.app/target | grep -E 'https?://|api'
```

### Frida (iOS)

```bash
# 탈옥 기기에 frida-server 설치 (Cydia)
frida-ps -U

# SSL pinning bypass
frida -U -f com.target.app -l ios-ssl-bypass.js
```

### Info.plist 주요 항목

| Key | 의미 |
|---|---|
| `NSAppTransportSecurity.NSAllowsArbitraryLoads` | HTTP 허용 여부 |
| `URL Schemes` | deep link → IDOR / open redirect |
| `NSFaceIDUsageDescription` | 생체 인증 우회 표적 |

---

## 공통 — API Backend 공격

모바일 앱을 뜯는 진짜 이유. 대부분 결국 backend API 가 본 target.

```bash
# 1. 정적 분석으로 endpoint 리스트 확보
# 2. 해당 endpoint 를 외부에서 직접 호출 가능한지 검증 (IDOR / auth bypass)
# 3. JWT 비밀키 하드코딩 확인 → 토큰 위조
# 4. Firebase / S3 / GCS bucket URL 노출 여부 확인
```

Firebase 오픈 DB 체크:

```bash
curl https://<project>.firebaseio.com/.json
```

S3 / GCS 는 [Cloud](../cloud/index.md) 의 bucket 체크 흐름을 그대로 적용.

---

## 참고

- [Cloud - bucket enumeration](../cloud/index.md)
- [Web - API / JWT](../web/index.md)
