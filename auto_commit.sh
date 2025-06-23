#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

FILES=(auto_commit.sh update_from_github.sh Default.yaml)
LOG="auto_commit.log"
TMP_LOG=$(mktemp)

##############################################################################
goto_log() {                             # функция определена ДО первого вызова
  { cat "$TMP_LOG"; [[ -f $LOG ]] && cat "$LOG"; } > "${LOG}.new"
  # оставляем 10 последних блоков
  awk '/==== .* START ====/ {c++} c<=10' "${LOG}.new" > "$LOG"
  rm -f "$TMP_LOG" "${LOG}.new"
}
##############################################################################

echo "==== $(date '+%F %T') START ====" | tee  "$TMP_LOG"

# 0. убираем лог из индекса (на всякий)
git rm --cached --ignore-unmatch "$LOG" 2>/dev/null || true

# 1. есть ли изменения
git fetch origin main
need_push=false
for f in "${FILES[@]}"; do
  if ! git diff --quiet origin/main -- "$f"; then need_push=true; break; fi
done
if [ "$need_push" = false ]; then
  echo "нет изменений — выход" | tee -a "$TMP_LOG"
  goto_log
  exit 0
fi

# 2. локальные «висяки»
if ! git diff --quiet || ! git diff --cached --quiet; then
  git add -A
  git commit -m "🛠 локальный автокоммит" | tee -a "$TMP_LOG"
fi

# 3. pull (merge)
git pull origin main --no-edit | tee -a "$TMP_LOG"

# 4. формируем сообщение
diff_line=$(git diff origin/main -- Default.yaml |
            grep -E '^[-+]\s*(DOMAIN-KEYWORD|PROCESS-NAME)' | head -n1)

case "$diff_line" in
  +*) action="add"    ; service=${diff_line#*,} ;;
  -*) action="remove" ; service=${diff_line#*,} ;;
  *)  action="update" ; service="Default.yaml"  ;;
esac
MSG="$action ${service%%,*}"

# 5. финальный коммит + push
git add "${FILES[@]}"
git commit -m "$MSG" 2>/dev/null && echo "commit → $MSG" | tee -a "$TMP_LOG" \
  || echo "skip commit (diff пуст)" | tee -a "$TMP_LOG"
git push origin main | tee -a "$TMP_LOG"

echo "✅ push complete — $MSG" | tee -a "$TMP_LOG"
echo "==== $(date '+%F %T') END ====" | tee -a "$TMP_LOG"

goto_log