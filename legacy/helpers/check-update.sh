#!/bin/bash

# Check GitHub for a newer version and cache the answer.
#
# The xbar plugin never calls the network itself — it only reads the cache this
# script writes, and fires this script detached when the cache goes stale. That
# keeps a slow or unreachable GitHub from stalling the menu bar.
#
# Usage: check-update.sh [--force]
# Prints the cache contents on exit.

source "$(dirname "$0")/common.sh"

GITHUB_REPO="mdrzn/claude-screenshot-uploader"
CACHE_MAX_AGE=86400   # re-check at most once a day

mkdir -p "$CSU_CONFIG_DIR"

if [ "$1" != "--force" ] && [ -f "$CSU_UPDATE_CACHE" ] &&
   [ "$(csu_file_age "$CSU_UPDATE_CACHE")" -lt "$CACHE_MAX_AGE" ]; then
    cat "$CSU_UPDATE_CACHE"
    exit 0
fi

api() {
    curl -fsSL -m 8 -H 'Accept: application/vnd.github+json' \
        "https://api.github.com/repos/$GITHUB_REPO/$1" 2>/dev/null
}

# Prefer a published release; fall back to the highest semver tag, so the check
# still works on a repo that only tags and never creates Release objects.
LATEST="$(api releases/latest | python3 -c '
import json, sys
try:
    print(json.load(sys.stdin).get("tag_name") or "")
except Exception:
    pass
' 2>/dev/null)"

if [ -z "$LATEST" ]; then
    LATEST="$(api 'tags?per_page=100' | python3 -c '
import json, re, sys

def key(tag):
    parts = re.findall(r"\d+", tag)
    return tuple(int(p) for p in parts[:3]) + (0,) * (3 - len(parts[:3]))

try:
    tags = [t["name"] for t in json.load(sys.stdin)
            if re.match(r"^v?\d+(\.\d+)*$", t.get("name", ""))]
    print(max(tags, key=key) if tags else "")
except Exception:
    pass
' 2>/dev/null)"
fi

LATEST="${LATEST#v}"
CURRENT="$(csu_version)"

if [ -z "$LATEST" ]; then
    # Nothing published yet, or the network/API was unavailable. Record the
    # attempt so we don't retry on every single menu refresh.
    {
        echo "checked=$(date +%s)"
        echo "current=$CURRENT"
        echo "latest="
        echo "update=unknown"
    } > "$CSU_UPDATE_CACHE"
    cat "$CSU_UPDATE_CACHE"
    exit 0
fi

if python3 -c '
import re, sys

def key(v):
    parts = re.findall(r"\d+", v)
    return tuple(int(p) for p in parts[:3]) + (0,) * (3 - len(parts[:3]))

sys.exit(0 if key(sys.argv[1]) > key(sys.argv[2]) else 1)
' "$LATEST" "$CURRENT" 2>/dev/null; then
    UPDATE="yes"
else
    UPDATE="no"
fi

{
    echo "checked=$(date +%s)"
    echo "current=$CURRENT"
    echo "latest=$LATEST"
    echo "update=$UPDATE"
} > "$CSU_UPDATE_CACHE"

cat "$CSU_UPDATE_CACHE"
