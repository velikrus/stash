#!/usr/bin/env bash
###############################################################################
#  auto_commit.sh  —  PROD
#  · лог: auto_commit.log (свежие блоки сверху, хранится 10 последних)
#  · отслеживает: auto_commit.sh, update_from_github.sh, Default.yaml
#  · commit-msg: «add monolead» · «remove AdsPower Global» · «update Default.yaml»
###############################################################################

set -euo pipefail
cd "$(dirname "$0")"

FILES=(auto_commit.sh update_from_github.sh Default.yaml)
LOG="auto_commit.log"
TMP_LOG="$(mktemp)"

##############################################################################
#  Ф-ция prepend-лога (всегда вызывается через trap)
##############################################################################
goto_log() {
  { cat "$TMP_LOG"; echo; [[ -f $LOG ]] && cat "$LOG"; } > "${LOG}.new"

  # оставляем 10 последних блоков «==== … START ===="
  awk '
    /^==== .* START ====/ {blk++}
    {buf[blk] = buf[blk] $0 ORS}
    END {for (i = blk; i > blk-10 && i > 0; i--) printf "%s", buf[i]}
  ' "${LOG}.new" > "$LOG"

  rm -f "$TMP_LOG" "${LOG}.new"
}
trap goto_log EXIT   # лог пишется даже при ошибке / exit

##############################################################################
echo "==== $(date '+%F %T') START ====" | tee  "$TMP_LOG"

# 0. лог не должен трекаться
git rm --cached --ignore-unmatch "$LOG" 2>/dev/null || true

# 1. есть ли изменения?
git fetch origin main
need_push=false
for f in "${FILES[@]}"; do
  if ! git diff --quiet origin/main -- "$f"; then need_push=true; break; fi
done
if [[ "$need_push" = false ]]; then
  echo "нет изменений — выход" | tee -a "$TMP_LOG"
  exit 0
fi

# 2. локальные «висяки»
if ! git diff --quiet || ! git diff --cached --quiet; then
  git add -A
  git commit -m "🛠 локальный автокоммит" | tee -a "$TMP_LOG"
fi

# 3. pull (merge)
git pull origin main --no-edit | tee -a "$TMP_LOG"

# 4. commit-msg из первой изменённой строки Default.yaml
diff_line=$(git diff origin/main -- Default.yaml \
            | grep -E '^[-+]\s*(DOMAIN-KEYWORD|PROCESS-NAME)' | head -n1 || true)
case "$diff_line" in
  +*) MSG="add    $(echo "$diff_line" | cut -d',' -f2 | xargs)";;
  -*) MSG="remove $(echo "$diff_line" | cut -d',' -f2 | xargs)";;
   *) MSG="update Default.yaml";;
esac

# 5. финальный коммит + push
git add "${FILES[@]}"
if ! git diff --cached --quiet; then
  git commit -m "$MSG" | tee -a "$TMP_LOG"
else
  echo "skip commit (diff пуст)" | tee -a "$TMP_LOG"
fi

if git push origin main 2>&1 | tee -a "$TMP_LOG"; then
  echo "✅ push complete — $MSG" | tee -a "$TMP_LOG"
else
  echo "❌ push failed"         | tee -a "$TMP_LOG"
fi

echo "==== $(date '+%F %T') END ====" | tee -a "$TMP_LOG"