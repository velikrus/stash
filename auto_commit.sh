#!/bin/bash
cd "$(dirname "$0")"

LOG="auto_commit.log"
exec >>"$LOG" 2>&1
echo "----- $(date '+%Y-%m-%d %H:%M:%S') -----  START"

FILE="Default.yaml"

# 0. Коммитим незакоммиченные изменения, если они есть
if ! git diff --quiet; then
  echo "⚠️ Обнаружены несохранённые изменения — коммичу"
  git add -A
  git commit -m "🛠 Автокоммит несохранённых изменений" || echo "❗ Уже закоммичено"
fi

# 1. Подтягиваем свежую ветку
echo "[pull]"
git pull --rebase origin main || {
  echo "❌ pull/rebase failed"; exit 1;
}

# 2. Сравниваем yaml-файл с origin/main
git fetch origin main
git diff origin/main -- "$FILE" > changes.diff

if ! grep -q '^\+' changes.diff; then
  echo "Нет изменений в $FILE — выход"
  rm changes.diff
  exit 0
fi

# 3. Формируем meaningful commit message
COMMIT_MSG=$(grep '^+  \?-\s*\(DOMAIN-KEYWORD\|PROCESS-NAME\)' changes.diff \
              | sed -E 's/.*(DOMAIN-KEYWORD|PROCESS-NAME),([^,]+).*/\2/' \
              | head -n 1)
[[ -z "$COMMIT_MSG" ]] && COMMIT_MSG="Auto update"

# 4. Коммит и пуш
echo "[add]";         git add "$FILE"
echo "[commit] $COMMIT_MSG"
git commit -m "$COMMIT_MSG" || echo "❗ Commit failed, возможно — без изменений"

echo "[push]"
git push origin main || {
  echo "❌ push failed"; exit 1;
}

# Очистка
rm changes.diff
echo "✅ Завершено: $COMMIT_MSG"
echo "----- $(date '+%Y-%m-%d %H:%M:%S') -----  END"