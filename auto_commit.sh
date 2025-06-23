#!/usr/bin/env bash
###############################################################################
#  auto_commit.sh — PROD
#  • лог: auto_commit.log (в корне репо, свежие блоки сверху, не более 10)
#  • отслеживаются только: auto_commit.sh, update_from_github.sh, Default.yaml
#  • commit-msg: «add monolead» / «remove AdsPower Global» и т.д.
###############################################################################
set -euo pipefail
cd "$(dirname "$0")"

FILES=(auto_commit.sh update_from_github.sh Default.yaml)
LOG="auto_commit.log"
TMP_LOG="$(mktemp)"

log() { echo "$1" | tee -a "$TMP_LOG"; }

log "==== $(date '+%F %T') START ===="

# Убираем лог из индекса на всякий случай
git rm --cached --ignore-unmatch "$LOG" 2>/dev/null || true

# Обновляем локальную ветку
git fetch origin main

# Проверка: есть ли изменения в whitelisted-файлах?
need_push=false
for f in "${FILES[@]}"; do
  if ! git diff --quiet origin/main -- "$f"; then
    need_push=true
    break
  fi
done

if ! $need_push; then
  log "нет изменений — выход"
  goto_log() {
    {
      cat "$TMP_LOG"
      [[ -f $LOG ]] && cat "$LOG"
    } > "${LOG}.new"
    awk '/==== .* START ====/ {cnt++} cnt<=10' "${LOG}.new" > "$LOG"
    rm -f "$TMP_LOG" "${LOG}.new"
  }
  goto_log
  exit 0
fi

# Автокоммит незакоммиченных локальных изменений
if ! git diff --quiet || ! git diff --cached --quiet; then
  git add -A
  git commit -m "🛠 локальный автокоммит" | tee -a "$TMP_LOG"
fi

# Pull без rebase
git pull origin main --no-edit | tee -a "$TMP_LOG"

# Определяем commit-msg по изменению в Default.yaml
diff_line=$(git diff origin/main -- Default.yaml \
  | grep -E '^[-+]\s*(DOMAIN-KEYWORD|PROCESS-NAME)' \
  | head -n1)

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

# Финальный коммит + push
git add "${FILES[@]}"
git commit -m "$MSG" | tee -a "$TMP_LOG" || log "skip commit (diff пуст)"
git push origin main | tee -a "$TMP_LOG"
log "✅ push complete — $MSG"
log "==== $(date '+%F %T') END ===="

# Препенд лог: оставляем максимум 10 блоков
goto_log() {
  {
    cat "$TMP_LOG"
    [[ -f $LOG ]] && cat "$LOG"
  } > "${LOG}.new"
  awk '/==== .* START ====/ {cnt++} cnt<=10' "${LOG}.new" > "$LOG"
  rm -f "$TMP_LOG" "${LOG}.new"
}
goto_log