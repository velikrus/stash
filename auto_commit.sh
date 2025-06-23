#!/usr/bin/env bash
###############################################################################
#  auto_commit.sh — PROD
#  • лог: auto_commit.log (в корне репо, свежие блоки сверху, не более 10)
#  • отслеживаются только: auto_commit.sh, update_from_github.sh, Default.yaml
#  • commit-msg: «add monolead» / «remove AdsPower Global»
###############################################################################
set -euo pipefail
cd "$(dirname "$0")"

FILES=(auto_commit.sh update_from_github.sh Default.yaml)
LOG="auto_commit.log"
TMP_LOG="$(mktemp)"

log() { echo "$@" | tee -a "$TMP_LOG"; }

log "==== $(date '+%F %T') START ===="

##############################################################################
# 0. убираем auto_commit.log из индекса
git rm --cached --ignore-unmatch "$LOG" 2>/dev/null || true

##############################################################################
# 1. есть ли изменения в whitelisted-файлах?
git fetch origin main
need_push=false
for f in "${FILES[@]}"; do
  if ! git diff --quiet origin/main -- "$f"; then
    need_push=true; break
  fi
done

if [ "$need_push" = false ]; then
  log "нет изменений — выход"
  goto_log
  exit 0
fi

##############################################################################
# 2. локальные незакоммиченные правки
if ! git diff --quiet || ! git diff --cached --quiet; then
  git add -A
  git commit -m "🛠 локальный автокоммит" | tee -a "$TMP_LOG"
fi

##############################################################################
# 3. pull c auto-merge
git pull origin main --no-edit | tee -a "$TMP_LOG"

##############################################################################
# 4. определяем diff-строку для коммита
diff_line=$(git diff origin/main -- Default.yaml | grep -E '^[-+]\s*(DOMAIN-KEYWORD|PROCESS-NAME)' | head -n1)

if [[ $diff_line == +* ]]; then
  action="add"
  service=$(echo "$diff_line" | cut -d',' -f2)
elif [[ $diff_line == -* ]]; then
  action="remove"
  service=$(echo "$diff_line" | cut -d',' -f2)
else
  action="update"
  service="Default.yaml"
fi

MSG="$action $(echo "$service" | sed 's/^[[:space:]]*//')"

##############################################################################
# 5. коммит + пуш
git add "${FILES[@]}"
if git diff --cached --quiet; then
  log "skip commit (diff пуст)"
else
  git commit -m "$MSG" | tee -a "$TMP_LOG"
fi
git push origin main | tee -a "$TMP_LOG"

log "✅ push complete — $MSG"
log "==== $(date '+%F %T') END ===="

##############################################################################
# 6. prepend-лог (сверху) + не более 10 блоков
goto_log() {
  { cat "$TMP_LOG"; [[ -f $LOG ]] && cat "$LOG"; } > "${LOG}.new"
  awk '
    BEGIN { cnt = 0 }
    /^==== .* START ====/ { cnt++; }
    cnt <= 10
  ' "${LOG}.new" > "$LOG"
  rm -f "$TMP_LOG" "${LOG}.new"
}

goto_log