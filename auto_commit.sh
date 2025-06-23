#!/bin/bash
###############################################################################
#  auto_commit.sh — debug edition
#  Лог:  auto_commit_dbg.log  (в корне репо и на экране)
###############################################################################
set -euo pipefail          # падаем на любой ошибке
exec > >(tee -a auto_commit_dbg.log) 2>&1
set -x                     # выводим каждую команду

echo "==== $(date '+%F %T') START ===="

FILES=(auto_commit.sh update_from_github.sh Default.yaml)

# 0. Убираем из-под контроля всё лишнее (на случай, если кто-то снова добавил)
git rm --cached --ignore-unmatch auto_commit.log || true

# 1. Проверяем, есть ли изменения в whitelisted-файлах
git fetch origin main
NEED_PUSH=false
for f in "${FILES[@]}"; do
  if ! git diff --quiet origin/main -- "$f"; then
    NEED_PUSH=true; break
  fi
done
"$NEED_PUSH" || { echo "нет изменений — выход"; echo "==== END ===="; exit 0; }

# 2. Коммитим локальные «висяки», если есть
if ! git diff --quiet || ! git diff --cached --quiet; then
  git add -A
  git commit -m "🛠 локальный автокоммит"
fi

# 3. Подтягиваем origin/main через merge
git pull origin main --no-edit

# 4. Итоговый коммит и push
MSG="auto-update: $(date '+%H:%M:%S')"
git add "${FILES[@]}"
git commit -m "$MSG" || echo "skip commit (diff пуст)"
git push origin main

echo "==== $(date '+%F %T') END ===="