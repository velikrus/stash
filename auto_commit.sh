#!/bin/bash

cd "$(dirname "$0")"

# Путь до yaml-файла
FILE="Default.yaml"

# Проверяем изменения
git pull origin main &>/dev/null
git fetch origin main &>/dev/null
git diff origin/main -- "$FILE" > changes.diff

# Если нет изменений — выходим
if ! grep -q '^\+' changes.diff; then
  echo "Нет изменений"
  exit 0
fi

# Извлекаем первую строку с ключом из новых
COMMIT_MSG=$(grep '^+  \?-\s*\(DOMAIN-KEYWORD\|PROCESS-NAME\)' changes.diff \
  | sed -E 's/.*(DOMAIN-KEYWORD|PROCESS-NAME),([^,]+).*/\2/' \
  | head -n 1)

# Подставляем fallback, если не нашли
if [ -z "$COMMIT_MSG" ]; then
  COMMIT_MSG="Auto update"
fi

# Коммитим и пушим
git add "$FILE"
git commit -m "$COMMIT_MSG"
git push origin main
echo "✅ Отправлено с коммитом: $COMMIT_MSG"

# Удаляем временный файл
rm changes.diff