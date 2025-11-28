#!/bin/sh

GITHUB_USERNAME=ragibkl
CACHE_FILE="/root/.ssh/github-keys.txt"
CACHE_DURATION=3600

mkdir -p "$(dirname "$CACHE_FILE")"

if [ -f "$CACHE_FILE" ]; then
    CURRENT_TIME=$(date +%s)
    FILE_TIME=$(date -r "$CACHE_FILE" +%s 2>/dev/null || echo 0)
    CACHE_AGE=$((CURRENT_TIME - FILE_TIME))
    
    if [ "$CACHE_AGE" -lt "$CACHE_DURATION" ]; then
        cat "$CACHE_FILE"
        exit 0
    fi
fi

KEYS=$(curl -sf --max-time 5 "https://github.com/${GITHUB_USERNAME}.keys")

if [ $? -eq 0 ] && [ -n "$KEYS" ]; then
    echo "$KEYS" > "$CACHE_FILE"
    chmod 600 "$CACHE_FILE"
    echo "$KEYS"
else
    if [ -f "$CACHE_FILE" ]; then
        cat "$CACHE_FILE"
    else
        cat /root/.ssh/authorized_keys 2>/dev/null || true
    fi
fi
