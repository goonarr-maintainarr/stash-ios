#!/usr/bin/env bash
set -eo pipefail

echo "🔍 Scanning repository for potential PII and sensitive data..."

FAIL=0

# 1. Check for internal IP addresses (e.g. 192.168.x.x)
if git grep -EI "192\.168\.[0-9]+\.[0-9]+" -- ':!scripts/check-pii.sh' ':!AGENTS.md' ':!.github/*'; then
    echo "❌ Error: Found local IP address (192.168.x.x) in tracked files!"
    FAIL=1
fi

# 2. Check for personal emails (excluding official project email)
if git grep -EI "[a-zA-Z0-9_.+-]+@(gmail|yahoo|hotmail|outlook)\.com" -- ':!scripts/check-pii.sh' ':!AGENTS.md' ':!.github/*' | grep -v "goonarrstash@gmail.com"; then
    echo "❌ Error: Found personal email address in tracked files!"
    FAIL=1
fi

# 3. Check for specific developer usernames
if git grep -EI "/Users/(jeremy|stookey)/" -- ':!scripts/check-pii.sh' ':!AGENTS.md' ':!.github/*'; then
    echo "❌ Error: Found local user file path in tracked files!"
    FAIL=1
fi

# 4. Check for Apple Developer Team IDs
if git grep -EI "DEVELOPMENT_TEAM = [A-Z0-9]{10};" -- ':!scripts/check-pii.sh'; then
    echo "❌ Error: Found DEVELOPMENT_TEAM ID in project configuration!"
    FAIL=1
fi

if [ $FAIL -eq 0 ]; then
    echo "✅ No PII or internal infrastructure data found. Clean to commit!"
    exit 0
else
    echo "🚨 PII check failed! Please scrub the detected patterns before committing."
    exit 1
fi
