#!/bin/bash

REPO_OWNER="velikrus"
REPO_NAME="stash"
BRANCH="main"
LOCAL_SHA_FILE="last_commit_sha.txt"
RAW_URL="https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/$BRANCH/Default.yaml"
LOCAL_FILE="Default.yaml"

LATEST_SHA=$(curl -s https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/commits/$BRANCH | grep '"sha"' | head -1 | cut -d '"' -f 4)

if [ ! -f "$LOCAL_SHA_FILE" ]; then
    echo "null" > "$LOCAL_SHA_FILE"
fi

CURRENT_SHA=$(cat "$LOCAL_SHA_FILE")

if [ "$CURRENT_SHA" != "$LATEST_SHA" ]; then
    echo "Обнаружено обновление. Обновляем файл..."
    curl -sL "$RAW_URL" -o "$LOCAL_FILE"
    echo "$LATEST_SHA" > "$LOCAL_SHA_FILE"
    echo "✅ Обновление завершено."
else
    echo "Нет новых коммитов. Обновление не требуется."
fi