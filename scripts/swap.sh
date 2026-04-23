#!/usr/bin/env bash
# Swap active documentation between internal and external variants.
#
# Repo layout:
#   docs/                       + mkdocs.yml                   <- 현재 active
#   docs_internal_backup/       + mkdocs_internal_backup.yml   <- 내부용 전체 문서
#   docs_external_backup/       + mkdocs_external_backup.yml   <- 외부 공유용 축약본
#
# Usage:
#   scripts/swap.sh            # 현재 mode 반대로 토글
#   scripts/swap.sh internal   # 내부 버전으로 강제 전환
#   scripts/swap.sh external   # 외부 버전으로 강제 전환
#   scripts/swap.sh status     # 현재 상태만 출력

set -euo pipefail

cd "$(dirname "$0")/.."

DOCS=docs
YML=mkdocs.yml
INT_DOCS=docs_internal_backup
INT_YML=mkdocs_internal_backup.yml
EXT_DOCS=docs_external_backup
EXT_YML=mkdocs_external_backup.yml

detect_mode() {
    if diff -rq "$DOCS" "$INT_DOCS" >/dev/null 2>&1 && diff -q "$YML" "$INT_YML" >/dev/null 2>&1; then
        echo internal
    elif diff -rq "$DOCS" "$EXT_DOCS" >/dev/null 2>&1 && diff -q "$YML" "$EXT_YML" >/dev/null 2>&1; then
        echo external
    else
        echo unknown
    fi
}

save_current() {
    # active 가 한쪽 backup 과 완전히 동일해야 swap 이 안전함
    local mode
    mode=$(detect_mode)
    if [[ "$mode" == "unknown" ]]; then
        echo "[!] docs/ 또는 mkdocs.yml 이 어느 backup 과도 일치하지 않습니다." >&2
        echo "    먼저 작업 중 내용을 해당 backup 디렉토리에 동기화하거나 커밋하세요." >&2
        echo "    (예: rsync -a --delete docs/ docs_internal_backup/)" >&2
        exit 1
    fi
    echo "$mode"
}

switch_to() {
    local target=$1
    local src_docs src_yml
    case "$target" in
        internal) src_docs=$INT_DOCS; src_yml=$INT_YML ;;
        external) src_docs=$EXT_DOCS; src_yml=$EXT_YML ;;
        *) echo "Unknown target: $target" >&2; exit 1 ;;
    esac

    echo "[*] Switching active docs -> $target"
    rm -rf "$DOCS"
    cp -a "$src_docs" "$DOCS"
    cp -a "$src_yml" "$YML"
    echo "[+] Now active: $target"
    echo "    mkdocs serve 로 확인하세요."
}

cmd=${1:-toggle}

case "$cmd" in
    status)
        mode=$(detect_mode)
        echo "Current active mode: $mode"
        ;;
    internal|external)
        save_current >/dev/null
        switch_to "$cmd"
        ;;
    toggle)
        current=$(save_current)
        if [[ "$current" == "internal" ]]; then
            switch_to external
        else
            switch_to internal
        fi
        ;;
    -h|--help|help)
        sed -n '2,15p' "$0"
        ;;
    *)
        echo "Unknown command: $cmd" >&2
        echo "Usage: $0 [status|internal|external|toggle]" >&2
        exit 1
        ;;
esac
