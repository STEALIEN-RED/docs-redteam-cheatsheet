# Red Team Cheat Sheet

레드팀 / 모의침투 현장에서 쓰는 명령어·기법·도구를 공격 라이프사이클 순서로 정리한 [MkDocs](https://www.mkdocs.org/) 기반 문서 사이트이다.

실무에서 바로 가져다 쓸 수 있도록 **명령어 중심**으로 구성했으며, `Material for MkDocs` 테마를 사용한다.

---

## 프로젝트 구조

```
docs-redteam-cheatsheet/
├── mkdocs.yml                   # 현재 빌드에 사용되는 설정 (기본 = internal)
├── mkdocs_internal_backup.yml   # 사내(internal) 버전 설정 백업
├── mkdocs_external_backup.yml   # 외부 공유(external) 버전 설정 백업
│
├── docs/                        # 현재 빌드에 사용되는 문서 소스 (기본 = internal)
├── docs_internal_backup/        # 사내 버전 문서 백업 (상세 버전)
├── docs_external_backup/        # 외부 공유 버전 문서 백업 (축약 버전)
│
└── site/                        # `mkdocs build` 결과물 (정적 HTML)
```

> `mkdocs build` / `mkdocs serve` 는 항상 루트의 `mkdocs.yml` 과 `docs/` 를 바라본다.
> 따라서 두 버전 중 원하는 쪽을 `mkdocs.yml` + `docs/` 위치로 교체해서 사용하는 구조이다.

---

## Internal vs External

두 가지 배포 버전을 관리한다. 같은 주제를 다루지만 **대상 독자**와 **상세도**가 다르다.

### Internal (사내용) — 기본값

- **용도**: 사내 레드팀 / 펜테스터와 팀 내부 공유용 상세 치트시트.
- **파일**: [mkdocs_internal_backup.yml](mkdocs_internal_backup.yml), [docs_internal_backup/](docs_internal_backup/)
- **특징**
  - `공격 라이프사이클`, `프로토콜`, `AD`, `Web`, `Cloud`, `방어 우회`, `인프라`, `도구` 전 항목을 **카테고리별로 세분화**해서 페이지 단위로 나눔.
  - 프로토콜 15종 (SMB/LDAP/HTTP/WinRM/SSH/FTP/RDP/DNS/Kerberos/RPC/MSSQL/MySQL/SNMP/NFS/SMTP) 을 각각 별도 페이지로 제공.
  - AD 공격은 `ad-environment`, `adcs` 로 분리하고 ADCS ESC1~ESC16 등 세부 기법 포함.
  - `navigation.sections`, `navigation.expand` 등 사이드바 확장 옵션 활성화.
  - 민감할 수 있는 내부 OPSEC 노하우 / 상세 페이로드 포함.

### External (외부 공유용)

- **용도**: 블로그·세미나·발표자료 등 **외부 공개** 시 사용하는 축약 버전.
- **파일**: [mkdocs_external_backup.yml](mkdocs_external_backup.yml), [docs_external_backup/](docs_external_backup/)
- **특징**
  - 카테고리별로 **단일 파일(`lifecycle.md`, `protocols.md`, `ad.md`, `web.md`, `cloud.md`, `infra.md`, `tools.md`)** 로 통합되어 전체적인 흐름만 빠르게 훑어볼 수 있도록 구성.
  - 네비게이션이 평탄화(tab만 사용, `sections` / `expand` 미사용)되어 있어 가볍게 공개하기 적합.
  - 내부 전용 팁·민감 페이로드·사내 도구 레퍼런스는 제거되거나 요약된다.

### 비교 요약

| 구분 | Internal | External |
|------|----------|----------|
| mkdocs 설정 | `mkdocs_internal_backup.yml` | `mkdocs_external_backup.yml` |
| 문서 폴더 | `docs_internal_backup/` | `docs_external_backup/` |
| 페이지 구성 | 주제별 **다중 파일** (30+ md) | 카테고리별 **단일 파일** (8 md) |
| 사이드바 | sections + expand | tabs only |
| 대상 | 내부 팀 | 외부 공개 |
| 상세도 | 상세 / 실전 명령어 중심 | 개요 / 흐름 위주 |

---

## 사용법

### 1. 저장소 클론 & 환경 준비

처음 저장소를 받은 뒤 아래 순서대로 의존성을 설치한다.

```bash
git clone <this-repo-url> docs-redteam-cheatsheet
cd docs-redteam-cheatsheet

# 가상환경 생성 (권장)
python3 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate

# 의존성 설치
pip install -r requirements.txt
```

#### 필수 패키지 ([requirements.txt](requirements.txt))

| 패키지 | 용도 |
|--------|------|
| `mkdocs` | 정적 사이트 생성기 본체 (`mkdocs serve` / `build` 제공) |
| `mkdocs-material` | `mkdocs.yml` 에서 사용하는 Material 테마 (`theme.name: material`) |
| `pymdown-extensions` | `admonition`, `pymdownx.superfences`(mermaid), `pymdownx.tabbed`, `pymdownx.highlight` 등 마크다운 확장 제공 |

> Python 3.9+ 권장. 시스템에 `graphviz` 등 추가 바이너리는 필요하지 않다 (Mermaid 는 브라우저에서 렌더링됨).

### 2. 버전 전환

[scripts/swap.sh](scripts/swap.sh) 로 internal / external 을 자동으로 교체한다.

```bash
./scripts/swap.sh status     # 현재 활성 mode 확인
./scripts/swap.sh toggle     # 현재 mode 반대로 교체 (기본 동작)
./scripts/swap.sh internal   # 내부 버전으로 강제 전환
./scripts/swap.sh external   # 외부 버전으로 강제 전환
```

스크립트는 `docs/` · `mkdocs.yml` 이 둘 중 한 쪽 backup 과 **완전히 일치**할 때만 동작한다 (즉, 작업 중 dirty 상태에서 실수로 덮어쓰는 사고 방지). dirty 상태라면 먼저 해당 backup 디렉토리로 sync 하거나 commit 해야 한다.

수동 전환이 필요하면:

```bash
# Internal
cp mkdocs_internal_backup.yml mkdocs.yml && rm -rf docs && cp -r docs_internal_backup docs

# External
cp mkdocs_external_backup.yml mkdocs.yml && rm -rf docs && cp -r docs_external_backup docs
```

### 3. 로컬 서빙

```bash
mkdocs serve
# http://127.0.0.1:8000
```

### 4. 정적 사이트 빌드

```bash
mkdocs build
# 결과물은 site/ 에 생성된다
```

---

## 콘텐츠 개요 (Internal 기준)

- **공격 라이프사이클**: 외부 정찰 → 초기 침투 → 내부 정찰/열거 → 자격 증명 탈취 → 권한 상승 → 횡적 이동 → 지속성 유지
- **프로토콜별 펜테스트**: 포트 스캔 후 발견된 서비스별 공격 가이드 (15종)
- **Active Directory**: AD 환경 공격 / ADCS (ESC1~ESC16)
- **Web 공격**: SQLi, XSS, SSRF, SSTI, JWT, Deserialization 등
- **Cloud 공격**: AWS / Azure 환경
- **방어 우회**: AV/EDR 우회, AMSI / AppLocker bypass
- **오퍼레이션 인프라**: 리버스 쉘, 파일 전송, Pivot·터널링, C2 프레임워크
- **도구 레퍼런스**: 주요 도구 명령어 모음

자세한 인덱스는 [docs/index.md](docs/index.md) 참고.

---

## 주의사항

본 문서는 **합법적으로 허가된 범위 내의 레드팀 / 모의침투 활동**을 위한 참고 자료이다. 무단 시스템에 대한 사용은 금지되며, 외부 공유 시에는 반드시 External 버전을 사용하고 민감 정보가 포함되지 않았는지 검토 후 배포한다.
