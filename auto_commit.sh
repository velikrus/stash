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

echo "==== $(date '+%F %T') START ====" | tee "$TMP_LOG"

##############################################################################
# 0. убираем лог из Git, на всякий случай
git rm --cached --ignore-unmatch "$LOG" 2>/dev/null || true

##############################################################################
# 1. есть ли изменения в отслеживаемых файлах?
git fetch origin main
need_push=false
for f in "${FILES[@]}"; do
  if ! git diff --quiet origin/main -- "$f"; then
    need_push=true; break
  fi
done
$need_push || { echo "нет изменений — выход" | tee -a "$TMP_LOG"; goto_log; exit 0; }

##############################################################################
# 2. определяем commit-msg ДО коммитов (по diff c HEAD, не origin!)
diff_line=$(git diff -- Default.yaml \
            | grep -E '^[-+]\s*(DOMAIN-KEYWORD|PROCESS-NAME)' \
            | head -n1 || true)

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
# 3. автокоммит незастейдженных изменений (если есть)
if ! git diff --quiet || ! git diff --cached --quiet; then
  git add -A
  git commit -m "🛠 локальный автокоммит" | tee -a "$TMP_LOG"
fi

##############################################################################
# 4. pull без rebase
git pull origin main --no-edit | tee -a "$TMP_LOG"

##############################################################################
# 5. финальный коммит и пуш
git add "${FILES[@]}"
git commit -m "$MSG" | tee -a "$TMP_LOG" || echo "skip commit (diff пуст)" | tee -a "$TMP_LOG"
git push origin main | tee -a "$TMP_LOG"

echo "✅ push complete — $MSG" | tee -a "$TMP_LOG"
echo "==== $(date '+%F %T') END ====" | tee -a "$TMP_LOG"

##############################################################################
# 6. prepend лог, обрезаем до 10 блоков START
goto_log() {
  { cat "$TMP_LOG"; [[ -f $LOG ]] && cat "$LOG"; } > "${LOG}.new"
  awk '/==== .* START ====/ {cnt++} cnt<=10' "${LOG}.new" > "$LOG"
  rm -f "$TMP_LOG" "${LOG}.new"
}
goto_log