#!/bin/bash

UNAME=$(uname)
UNAME_ARCHITECTURE=$(uname -m)
OS="unknown"
if [[ "$UNAME" == "Darwin" ]]; then
    OS="osx"
elif [[ "$UNAME" == "Linux" ]]; then
    OS="linux"
fi

if [[ "$UNAME_ARCHITECTURE" == "x86_64" ]]; then
    ARCH="amd64"
elif [[ "$UNAME_ARCHITECTURE" == "aarch64" ]]; then
    ARCH="arm64"
fi

cp sync.py hsync/bin/Release/net8.0/${OS}-${ARCH}/publish/
cd hsync/bin/Release/net8.0/${OS}-${ARCH}/publish/
pkill -9 sqlite3
python3 sync.py
cp dbmeta.txt ~/sync-data/syncversion.txt
cd ~/sync-data
git config user.name "github-actions"
git config user.email "github-actions@github.com"
git add -A
git commit -m "sync: update dbmeta.txt $(date +%s)"
git push