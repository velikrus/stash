#!/usr/bin/env bash
###############################################################################
#  auto_commit.sh — PROD
#  • лог: auto_commit.log (в корне репо, свежие блоки сверху, не более 10)
#  • отслеживаются только: auto_commit.sh, update_from_github.sh, Default.yaml
#  • commit-msg: «add monolead» / «remove AdsPower Global»
###############################################################################

set -euo pipefail
cd "$(dirname "$0")"

FILES=(auto_commit.sh update_from_github.sh Default.yaml)
LOG="auto_commit.log"
TMP_LOG="$(mktemp)"

##############################################################################
# Функция prepend-лога (сверху) + обрезка до 10 блоков
goto_log() {
  { cat "$TMP_LOG"; [[ -f $LOG ]] && cat "$LOG"; } > "${LOG}.new"
  awk '
    BEGIN { cnt = 0 }
    /^==== .* START ====/ { cnt++ }
    cnt <= 10
  ' "${LOG}.new" > "$LOG"
  rm -f "$TMP_LOG" "${LOG}.new"
}

log() { echo "$@" | tee -a "$TMP_LOG"; }

log "==== $(date '+%F %T') START ===="

##############################################################################
# 0. убираем auto_commit.log из индекса (если был добавлен)
git rm --cached --ignore-unmatch "$LOG" 2>/dev/null || true

##############################################################################
# 1. синхронизируемся с удаленным репозиторием
log "Получение последних изменений из GitHub..."
git fetch origin main

##############################################################################
# 2. проверяем локальные незакоммиченные изменения и сохраняем их
local_changes=false
if ! git diff --quiet || ! git diff --cached --quiet; then
  log "Обнаружены локальные незакоммиченные изменения, сохраняем их..."
  git add -A
  local_changes=true
fi

##############################################################################
# 3. делаем pull с merge (избегаем конфликтов)
log "Синхронизация с удаленным репозиторием..."
if ! git pull origin main --no-edit 2>&1 | tee -a "$TMP_LOG"; then
  log "❌ Ошибка при pull - возможны конфликты"
  log "==== $(date '+%F %T') ERROR END ===="
  goto_log
  exit 1
fi

##############################################################################
# 4. проверяем есть ли изменения в отслеживаемых файлах после синхронизации
need_push=false
changed_files=()

for f in "${FILES[@]}"; do
  # Проверяем изменения относительно последнего коммита или индекса
  if ! git diff --quiet HEAD -- "$f" 2>/dev/null || ! git diff --quiet --cached -- "$f" 2>/dev/null; then
    need_push=true
    changed_files+=("$f")
    log "Обнаружены изменения в: $f"
  fi
done

if [ "$need_push" = false ]; then
  log "Нет изменений в отслеживаемых файлах — выход"
  log "==== $(date '+%F %T') END ===="
  goto_log
  exit 0
fi

##############################################################################
# 5. определяем commit-msg на основе изменений
MSG="update configuration"

if [[ " ${changed_files[*]} " =~ " Default.yaml " ]]; then
  log "Анализируем изменения в Default.yaml..."
  
  # Получаем diff из staged изменений
  diff_output=$(git diff --cached -- Default.yaml 2>/dev/null || echo "")
  
  if [[ -n "$diff_output" ]]; then
    log "Найдены staged изменения, ищем сервисы..."
    
    # Упрощенный поиск добавленных строк с DOMAIN-KEYWORD
    added_service=""
    removed_service=""
    
    # Ищем добавленные строки
    while IFS= read -r line; do
      if [[ $line =~ ^\+.*DOMAIN-KEYWORD,([^,]+) ]]; then
        added_service="${BASH_REMATCH[1]}"
        break
      fi
    done <<< "$diff_output"
    
    # Ищем удаленные строки
    while IFS= read -r line; do
      if [[ $line =~ ^\-.*DOMAIN-KEYWORD,([^,]+) ]]; then
        removed_service="${BASH_REMATCH[1]}"
        break
      fi
    done <<< "$diff_output"
    
    if [[ -n "$added_service" ]]; then
      MSG="add $added_service"
      log "Обнаружено добавление сервиса: $added_service"
    elif [[ -n "$removed_service" ]]; then
      MSG="remove $removed_service"
      log "Обнаружено удаление сервиса: $removed_service"
    else
      MSG="update Default.yaml"
      log "Обнаружены другие изменения в Default.yaml"
    fi
  else
    MSG="update Default.yaml"
    log "Staged diff пустой"
  fi
else
  MSG="update scripts"
  log "Изменения только в скриптах"
fi

log "Итоговое сообщение коммита: '$MSG'"

##############################################################################
# 6. создаем коммит если есть staged изменения или новые изменения
if git diff --cached --quiet; then
  log "Нет staged изменений для коммита"
else
  log "Создание коммита: '$MSG'"
  if git commit -m "$MSG" 2>&1 | tee -a "$TMP_LOG"; then
    log "✅ Коммит создан успешно"
  else
    log "❌ Ошибка при создании коммита"
    log "==== $(date '+%F %T') ERROR END ===="
    goto_log
    exit 1
  fi
fi

##############################################################################
# 7. пушим изменения
log "Отправка изменений в GitHub..."
if git push origin main 2>&1 | tee -a "$TMP_LOG"; then
  log "✅ Push выполнен успешно — $MSG"
else
  log "❌ Ошибка при push"
  log "==== $(date '+%F %T') ERROR END ===="
  goto_log
  exit 1
fi

log "==== $(date '+%F %T') END ===="
goto_log