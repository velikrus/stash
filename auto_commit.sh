#!/bin/bash
cd "$(dirname "$0")"

LOG=".git/auto_commit.log"           # лог невидим для Git
exec >>"$LOG" 2>&1
echo "----- $(date '+%F %T') START -----"

FILES=(auto_commit.sh update_from_github.sh Default.yaml)

git fetch origin main

# Проверяем изменения ТОЛЬКО в whitelisted-файлах
CHANGED=false
for f in "${FILES[@]}"; do
  if ! git diff --quiet origin/main -- "$f"; then
    CHANGED=true; break
  fi
done

if [ "$CHANGED" = false ]; then
  echo "Нет изменений — выход"
  exit 0
fi

# Коммит-сообщение: имя первого изменённого файла
for f in "${FILES[@]}"; do
  if ! git diff --quiet origin/main -- "$f"; then
    COMMIT_MSG="update $f"; break
  fi
done

# Обновляем локальную ветку со stash-автообъединением
git pull --rebase --autostash origin main        || { echo "pull failed"; exit 1; }

# Добавляем и пушим только whitelisted-файлы
git add "${FILES[@]}"
git commit -m "$COMMIT_MSG"
git push origin main                             || { echo "push failed"; exit 1; }

echo "✅ Пуш завершён: $COMMIT_MSG"
echo "----- $(date '+%F %T') END -----"