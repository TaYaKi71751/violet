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
    ARCH="x64"
elif [[ "$UNAME_ARCHITECTURE" == "aarch64" ]]; then
    ARCH="arm64"
elif [[ "$UNAME_ARCHITECTURE" == "arm64" ]]; then
    ARCH="x64"
fi

cp sync.py hsync/bin/Release/net8.0/${OS}-${ARCH}/publish/
cd hsync/bin/Release/net8.0/${OS}-${ARCH}/publish/
pkill -9 sqlite3
rm *.7z
rm *.7z.*
rm -rf chunk
if [[ "$UNAME_ARCHITECTURE" == "aarch64" ]]; then
    ./hsync -ls --sync-only
elif [[ "$UNAME_ARCHITECTURE" == "arm64" ]]; then
    arch -x86_64 ./hsync -ls --sync-only
elif [[ "$UNAME_ARCHITECTURE" == "x86_64" ]]; then
    ./hsync -ls --sync-only
fi
cd chunk
DB_CHUNK_FILE="$(ls *.db)"
JSON_CHUNK_FILE="$(ls *.json)"
cd ../

TIMESTAMP="$(python3 -c 'import datetime; print(int(datetime.datetime.now().timestamp()))')"
echo "sync: create chunk $TIMESTAMP"

gh release create $TIMESTAMP --repo TaYaKi71751/chunk --title "chunk $TIMESTAMP" --notes "" chunk/$DB_CHUNK_FILE chunk/$JSON_CHUNK_FILE || exit -1
echo "chunk https://github.com/TaYaKi71751/chunk/releases/download/$TIMESTAMP/$DB_CHUNK_FILE.db $(python3 -c "import os; print(os.path.getsize('chunk/$DB_CHUNK_FILE'))")" >> syncversion.txt
echo "chunk https://github.com/TaYaKi71751/chunk/releases/download/$TIMESTAMP/$JSON_CHUNK_FILE $(python3 -c "import os; print(os.path.getsize('chunk/$JSON_CHUNK_FILE'))")" >> syncversion.txt

7za a rawdata.7z rawdata/* '-xr!*.db-jounal'
7za a rawdata-chinese.7z rawdata-chinese/* '-xr!*.db-journal'
7za a rawdata-english.7z rawdata-english/* '-xr!*.db-journal'
7za a rawdata-japanese.7z rawdata-japanese/* '-xr!*.db-journal'
7za a rawdata-korean.7z rawdata-korean/* '-xr!*.db-journal'
TIMESTAMP="$(python3 -c 'import datetime; print(int(datetime.datetime.now().timestamp()))')"
echo "sync: create db $TIMESTAMP"
gh release create $TIMESTAMP --repo TaYaKi71751/db --title "db $TIMESTAMP" --notes "" rawdata.7z rawdata-chinese.7z rawdata-english.7z rawdata-japanese.7z rawdata-korean.7z || exit -1
echo "db https://github.com/TaYaKi71751/db/releases/download/$TIMESTAMP/rawdata" >> syncversion.txt
cp syncversion.txt ~/sync-data/syncversion.txt
cd ~/sync-data
git config user.name "github-actions"
git config user.email "github-actions@github.com"
git add -A
git commit -m "sync: update syncversion.txt $(date +%s)"
git push