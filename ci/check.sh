#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
#  ci/check.sh — гейт риса Lunar Eclipse: локально и в CI.
#
#  Что проверяю:
#    1) синтаксис shell-скриптов (bash -n);
#    2) синтаксис python-скриптов (py_compile);
#    3) дрейф токенов Theme.qml ↔ AGENTS.md §5 / DESIGN.md §2.4;
#    4) smoke: eclipse-palette.py в dry-run (без --apply) — exit 0.
#
#  Запуск из корня репо:  bash ci/check.sh
#  Провал любого шага → exit 1.
# ════════════════════════════════════════════════════════════════
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

FAIL=0
step() { printf '\n[ci] %s\n' "$1"; }
ok()   { printf '  ✓ %s\n' "$1"; }
bad()  { printf '  ✗ %s\n' "$1"; FAIL=1; }

# 1) синтаксис shell
step "Синтаксис shell (bash -n)"
for f in lunar doctor.sh reload.sh install.sh get-deps.sh ui.sh \
         release.sh sync.sh bump.sh install/*.sh deps/snapshot.sh \
         systemd/libexec/*.sh packaging/*/*.install .config/hypr/scripts/*.sh; do
    [ -e "$f" ] || continue
    if err=$(bash -n "$f" 2>&1); then
        ok "$f"
    else
        bad "$f"
        printf '%s\n' "$err" | sed 's/^/      /'
    fi
done

# 2) синтаксис python
step "Синтаксис Python (py_compile)"
if out=$(python3 -m py_compile .config/hypr/scripts/*.py 2>&1); then
    ok ".config/hypr/scripts/*.py"
else
    bad ".config/hypr/scripts/*.py"
    printf '%s\n' "$out" | sed 's/^/      /'
fi
# py_compile сыпет кэш в дерево — подчищаю (в .gitignore, но чистота важна)
rm -rf .config/hypr/scripts/__pycache__

# 3) дрейф токенов Theme.qml ↔ доки
step "Дрейф токенов Theme.qml ↔ доки"
if out=$(python3 ci/check-tokens.py "$ROOT" 2>&1); then
    ok "AGENTS.md §5 / DESIGN.md §2.4 совпадают с Theme.qml"
else
    bad "токены разошлись с доками"
    printf '%s\n' "$out" | sed 's/^/      /'
fi

# 4) smoke: палитра в dry-run не должна ничего ломать
step "Smoke: eclipse-palette.py (dry-run)"
if out=$(python3 .config/hypr/scripts/eclipse-palette.py 2>&1); then
    ok "dry-run exit 0"
else
    bad "dry-run упал"
    printf '%s\n' "$out" | tail -20 | sed 's/^/      /'
fi

if [ "$FAIL" -eq 0 ]; then
    printf '\n[ci] OK\n'
    exit 0
fi
printf '\n[ci] FAIL\n'
exit 1
