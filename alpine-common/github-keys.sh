#!/bin/sh

# Usage: github-keys.sh <github-raw-url>
# Example: github-keys.sh https://raw.githubusercontent.com/ragibkl/homelab-vm/master/ssh-users/vmbr1.txt

# GitHub raw URL for users file
if [ -n "$1" ]; then
    USERS_URL="$1"
elif [ -n "$USERS_URL" ]; then
    USERS_URL="$USERS_URL"
else
    echo "ERROR: No users URL specified" >&2
    echo "Usage: github-keys.sh <github-raw-url>" >&2
    exit 1
fi

CACHE_FILE="/var/cache/github-keys.txt"
CACHE_DURATION=3600

mkdir -p "$(dirname "$CACHE_FILE")"

# Check cache validity
if [ -f "$CACHE_FILE" ]; then
    CURRENT_TIME=$(date +%s)
    FILE_TIME=$(date -r "$CACHE_FILE" +%s 2>/dev/null || echo 0)
    CACHE_AGE=$((CURRENT_TIME - FILE_TIME))
    
    if [ "$CACHE_AGE" -lt "$CACHE_DURATION" ]; then
        # Cache still valid
        cat "$CACHE_FILE"
        exit 0
    fi
fi

# Fetch users file from GitHub
USERS_CONTENT=$(curl -sf --max-time 5 "$USERS_URL")

if [ $? -ne 0 ] || [ -z "$USERS_CONTENT" ]; then
    echo "ERROR: Failed to fetch users file from: $USERS_URL" >&2
    
    # Fallback to cached keys if available
    if [ -f "$CACHE_FILE" ]; then
        echo "WARN: Using cached keys" >&2
        cat "$CACHE_FILE"
        exit 0
    fi
    
    exit 1
fi

# Parse GitHub usernames (ignore comments and empty lines)
GITHUB_USERS=$(echo "$USERS_CONTENT" | grep -v '^#' | grep -v '^$' | tr '\n' ' ')

if [ -z "$GITHUB_USERS" ]; then
    echo "ERROR: No users found in users file" >&2
    
    # Fallback to cached keys if available
    if [ -f "$CACHE_FILE" ]; then
        echo "WARN: Using cached keys" >&2
        cat "$CACHE_FILE"
        exit 0
    fi
    
    exit 1
fi

# Fetch keys from all users
ALL_KEYS=""
for USER in $GITHUB_USERS; do
    KEYS=$(curl -sf --max-time 5 "https://github.com/${USER}.keys")
    
    if [ $? -eq 0 ] && [ -n "$KEYS" ]; then
        # Add comment to identify which user
        COMMENTED_KEYS=$(echo "$KEYS" | sed "s/$/ # github:${USER}/")
        ALL_KEYS="${ALL_KEYS}${COMMENTED_KEYS}
"
    else
        echo "WARN: Failed to fetch keys for user: $USER" >&2
    fi
done

# Save and output
if [ -n "$ALL_KEYS" ]; then
    echo "$ALL_KEYS" > "$CACHE_FILE"
    chmod 600 "$CACHE_FILE"
    echo "$ALL_KEYS"
    exit 0
else
    echo "ERROR: Failed to fetch any keys from GitHub" >&2
    
    # Fallback to cached keys if available
    if [ -f "$CACHE_FILE" ]; then
        echo "WARN: Using cached keys" >&2
        cat "$CACHE_FILE"
        exit 0
    fi
    
    exit 1
fi
