#!/usr/bin/env bash
###############################################################################
#  auto_commit.sh — PROD  (лог в auto_commit.log, 10 последних блоков)
###############################################################################

set -euo pipefail
cd "$(dirname "$0")"

FILES=(auto_commit.sh update_from_github.sh Default.yaml)
LOG="auto_commit.log"
TMP_LOG=$(mktemp)

##############################################################################
# Функция журналирования  —  объявлена ПЕРВОЙ
goto_log() {
  {
    cat "$TMP_LOG"
    [[ -f $LOG ]] && cat "$LOG"
  } > "${LOG}.new"

  # оставляем 10 последних «==== … START ====»
  awk '/==== .* START ====/ {blk++} blk<=10' "${LOG}.new" > "$LOG"
  rm -f "$TMP_LOG" "${LOG}.new"
}
##############################################################################

echo "==== $(date '+%F %T') START ====" | tee  "$TMP_LOG"

# 0. Лог не должен трекаться
git rm --cached --ignore-unmatch "$LOG" 2>/dev/null || true

# 1. Есть ли изменения?
git fetch origin main
need_push=false
for f in "${FILES[@]}"; do
  if ! git diff --quiet origin/main -- "$f"; then need_push=true; break; fi
done
if [ "$need_push" = false ]; then
  echo "нет изменений — выход" | tee -a "$TMP_LOG"
  goto_log; exit 0
fi

# 2. Коммитим локальные «висяки», если есть
if ! git diff --quiet || ! git diff --cached --quiet; then
  git add -A
  git commit -m "🛠 локальный автокоммит" | tee -a "$TMP_LOG"
fi

# 3. Подтягиваем origin/main (merge)
git pull origin main --no-edit | tee -a "$TMP_LOG"

# 4. Формируем commit-msg (add/remove service)
diff_line=$(git diff origin/main -- Default.yaml \
            | grep -E '^[-+]\s*(DOMAIN-KEYWORD|PROCESS-NAME)' | head -n1)
case "$diff_line" in
  +*) action=add    ; service=${diff_line#*,} ;;
  -*) action=remove ; service=${diff_line#*,} ;;
  *)  action=update ; service=Default.yaml    ;;
esac
MSG="$action ${service%%,*}"

# 5. Итоговый коммит + push
git add "${FILES[@]}"
git commit -m "$MSG" | tee -a "$TMP_LOG" \
  || echo "skip commit (diff пуст)" | tee -a "$TMP_LOG"
git push origin main | tee -a "$TMP_LOG"

echo "✅ push complete — $MSG" | tee -a "$TMP_LOG"
echo "==== $(date '+%F %T') END ====" | tee -a "$TMP_LOG"

goto_log