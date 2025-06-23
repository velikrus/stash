#!/usr/bin/env bash
set -euo pipefail
REPO="velikrus/stash"
BRANCH="main"
LOCAL_FILE="Default.yaml"
SHA_FILE=".last_sha"

# 1. Получаем SHA HEAD-коммита
LATEST_SHA=$(curl -s https://api.github.com/repos/$REPO/commits/$BRANCH \
              | jq -r '.sha')

# 2. Если SHA не изменился — выходим
[[ -f $SHA_FILE ]] && [[ $(<"$SHA_FILE") == "$LATEST_SHA" ]] \
  && { echo "Нет новых коммитов"; exit 0; }

# 3. Скачиваем файл **по конкретному SHA**
TMP=$(mktemp)
RAW_URL="https://raw.githubusercontent.com/$REPO/$LATEST_SHA/Default.yaml"
curl -sL -H 'Cache-Control: no-cache' "$RAW_URL" -o "$TMP"

# 4. Заменяем только если контент отличается
if ! cmp -s "$TMP" "$LOCAL_FILE"; then
    echo "⚙️  Обновляю $LOCAL_FILE (commit $LATEST_SHA)"
    cp "$LOCAL_FILE" "${LOCAL_FILE}.bak.$(date +%s)"   # бэкап
    mv "$TMP" "$LOCAL_FILE"
else
    echo "Файл не изменился — обновление не требуется"
    rm "$TMP"
fi

echo "$LATEST_SHA" > "$SHA_FILE"