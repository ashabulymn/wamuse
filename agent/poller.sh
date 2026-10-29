#!/usr/bin/env bash
# Polls the n8n "Muse Bridge" inbox for wamuse WhatsApp standby (cheap detector).
# The inbox URL (random token path) is read from ~/workspace/wamuse/config/n8n-bridge.conf.
# The inbox returns {"pending": [ ...messages... ]}; we only count the array here —
# message bodies are fetched only when a worker actually wakes (keeps this check cheap).
# Wake the worker only when the pending count changed and is above zero.
set -euo pipefail
source "$HATCH_HOOK_RUNTIME"

CONF="$HOME/workspace/wamuse/config/n8n-bridge.conf"
STATE_DIR="$HOME/hooks/state/wamuse-standby"
LAST_FILE="$STATE_DIR/last_pending"
LAST_WAKE_FILE="$STATE_DIR/last_wake"
WAKE_COOLDOWN_SECS=600
mkdir -p "$STATE_DIR"

if [[ ! -r "$CONF" ]]; then
  log "n8n-bridge.conf missing or unreadable"
  silent "n8n bridge not configured" '{}'
fi

INBOX_URL="$(grep -E '^INBOX_URL=' "$CONF" | head -n1 | cut -d= -f2- | tr -d ' \t\r\n')"
if [[ -z "$INBOX_URL" ]]; then
  log "INBOX_URL not found in n8n-bridge.conf"
  silent "n8n inbox url missing" '{}'
fi

resp="$(curl --fail --silent --show-error --max-time 10 "$INBOX_URL" 2>/dev/null || true)"
if [[ -z "$resp" ]]; then
  log "n8n inbox unreachable or non-2xx"
  silent "n8n inbox unreachable" '{}'
fi

pending="$(printf '%s' "$resp" | jq -r 'if (.pending | type) == "array" then (.pending | length) else 0 end' 2>/dev/null || echo 0)"
if ! [[ "$pending" =~ ^[0-9]+$ ]]; then
  log "unexpected inbox payload"
  silent "unexpected inbox payload, staying silent" '{}'
fi

last=0
if [[ -f "$LAST_FILE" ]]; then
  last="$(cat "$LAST_FILE" 2>/dev/null || echo 0)"
fi
if ! [[ "$last" =~ ^[0-9]+$ ]]; then
  last=0
fi

if [[ "$HATCH_HOOK_DRY_RUN" != "1" ]]; then
  echo "$pending" > "$LAST_FILE"
fi

last_wake=0
if [[ -f "$LAST_WAKE_FILE" ]]; then
  last_wake="$(cat "$LAST_WAKE_FILE" 2>/dev/null || echo 0)"
fi
if ! [[ "$last_wake" =~ ^[0-9]+$ ]]; then
  last_wake=0
fi
now="$(date +%s)"

# Wake when there are pending messages AND (count changed since last poll,
# or cooldown elapsed since last wake). The cooldown covers the case where a
# worker woke but failed to clear the queue (count unchanged) — without it,
# those messages would never surface again.
should_wake=0
if [[ "$pending" -gt 0 ]]; then
  if [[ "$pending" != "$last" ]]; then
    should_wake=1
  elif (( now - last_wake >= WAKE_COOLDOWN_SECS )); then
    log "pending unchanged ($pending) but cooldown elapsed, re-waking for retry"
    should_wake=1
  fi
fi

if [[ "$should_wake" -eq 1 ]]; then
  if [[ "$HATCH_HOOK_DRY_RUN" != "1" ]]; then
    echo "$now" > "$LAST_WAKE_FILE"
  fi
  wake "new whatsapp messages waiting in n8n queue" "{\"pending\": $pending}"
else
  silent "no new messages" "{\"pending\": $pending}"
fi
