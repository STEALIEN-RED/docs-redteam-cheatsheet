# 모바일 (Android / iOS)

!!! abstract "개요"
    레드팀 시 모바일 앱은 **백엔드 API 키 / 인증 토큰 / 내부 URL** 이 하드코딩된 진입점이 되는 경우가 많다.  
    본 페이지는 **정찰 및 시크릿 추출 관점**에 집중한다. 풀스택 모바일 앱 모의해킹은 MSTG/MASVS 참조.

---

## 앱 수집

```bash
# Google Play (APK)
# 1. apkcombo / apkpure / google play 공식 → gplay-api (non-root)
# 2. adb pull
adb shell pm list packages | grep target
adb shell pm path com.target.app
adb pull /data/app/com.target.app-1/base.apk

# App Store (IPA)
# - jailbreak된 기기에서 frida-ios-dump
frida-ios-dump -l           # 설치된 앱 목록
frida-ios-dump com.target.app
```

---

## 정적 분석 (Android APK)

```bash
# 디컴파일
apktool d base.apk -o out/
jadx-gui base.apk          # Java 소스 뷰어 (추천)

# 시크릿/엔드포인트 스캔
grep -r -E 'https?://[^"]+' out/ | sort -u
grep -r -E 'AKIA|aws_|api[_-]?key|bearer|secret' out/

# mobsf (자동화)
docker run -it --rm -p 8000:8000 opensecurity/mobile-security-framework-mobsf

# Network Security Config 확인
cat out/res/xml/network_security_config.xml
# → cleartextTrafficPermitted / trust-anchors 체크
```

---

## 런타임 조작 (Frida)

```bash
# Android
adb push frida-server /data/local/tmp/
adb shell /data/local/tmp/frida-server &
frida -U -n com.target.app -l bypass.js

# SSL Pinning 우회
frida -U -f com.target.app -l frida-ssl-bypass.js --no-pause
# 스크립트: https://codeshare.frida.re/@akabe1/frida-multiple-unpinning/

# Root / Jailbreak detection 우회
frida -U -n com.target.app --codeshare dzonerzy/fridantiroot
```

---

## 인증서 피닝 / 프록시

```bash
# BurpSuite CA → 시스템 trust store에 주입 (Android 7+ 제한)
# 1. PEM → DER 변환
openssl x509 -in burp.pem -outform DER -out burp.der
# 2. 해시 이름
HASH=$(openssl x509 -inform DER -subject_hash_old -in burp.der | head -1)
mv burp.der ${HASH}.0
# 3. 시스템 영역에 복사 (root 필요)
adb push ${HASH}.0 /system/etc/security/cacerts/
adb shell chmod 644 /system/etc/security/cacerts/${HASH}.0
```

---

## 시크릿 / API 키 하드코딩 체크리스트

- [ ] AWS Access Key (`AKIA...`)
- [ ] Firebase DB URL (`*.firebaseio.com`) - 읽기/쓰기 규칙 오픈 여부
- [ ] Google Maps / Places API key
- [ ] Backend 내부 URL (`https://dev-api.target.com`)
- [ ] Hardcoded Bearer Token
- [ ] 암호화 키 (AES 하드코딩)
- [ ] 디버그 플래그 (`android:debuggable="true"`)

```bash
# Firebase 오픈 DB 체크
curl https://<PROJECT_ID>.firebaseio.com/.json

# Android 매니페스트 점검
aapt dump badging base.apk | grep -E 'debuggable|launchable'
```

---

## iOS 정적 분석

```bash
# .ipa → Payload/<App>.app
unzip app.ipa -d ipa/
cd ipa/Payload/<App>.app

# Info.plist 
plutil -convert xml1 Info.plist -o -
# → NSAppTransportSecurity, URL Schemes, Entitlements 확인

# 바이너리 분석
otool -L <App>                           # 동적 라이브러리
class-dump -H <App>                      # Objective-C 헤더 (Swift 는 제한적)
rabin2 -z <App> | grep -Ei 'http|api|key'
```

---

## 백엔드 API 공격 (레드팀 본론)

모바일 앱의 **API 엔드포인트**는 공식 웹에는 노출되지 않은 내부 기능을 제공하는 경우가 많음.

1. 프록시로 API 호출 캡처 (`/login`, `/profile`, `/internal/admin`)
2. IDOR / 권한 분기 / BFLA (Broken Function Level Authorization) 체크
3. 하드코딩된 Admin JWT / Test 계정 발견 시 바로 에스컬레이션
4. `/v1/` 만 공식, `/v2/internal/` 는 인증 누락 등 경로 혼합 취약점 확인

---

## 참고

- [Web 공격](../web/index.md) (API 측면)
- OWASP MASVS: <https://mas.owasp.org/MASVS/>
- MobSF: <https://github.com/MobSF/Mobile-Security-Framework-MobSF>
