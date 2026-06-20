#!/bin/bash
set -Eeuo pipefail

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
    ARCH="arm64"
fi

if [[ "$OS" == "unknown" || -z "${ARCH:-}" ]]; then
    echo "Unsupported platform: ${UNAME}-${UNAME_ARCHITECTURE}"
    exit -1
fi

PUBLISH_DIR="$HOME/violet/hsync/hsync/bin/Release/net8.0/${OS}-${ARCH}/publish"
LOCK_FILE="$PUBLISH_DIR/lock"

if [[ -f "$LOCK_FILE" ]];then
    echo "Another instance is running."
    exit -1
fi

cleanup() {
    rm -f "$LOCK_FILE"
}
trap cleanup EXIT

mkdir -p "$PUBLISH_DIR"
echo "" > "$LOCK_FILE"

GITHUB_USERNAME="$(gh api user --jq .login)"

cd hsync
dotnet publish -r ${OS}-${ARCH} -c Release /p:PublishSingleFile=true /p:PublishTrimmed=false /p:PublishReadyToRun=false
cd bin/Release/net8.0/${OS}-${ARCH}/publish
if ( ls rawdata/data.db 1> /dev/null 2>&1 ); then
    export DB_EXISTS="true"
else
    export DB_EXISTS="false"
fi
if [[ "$DB_EXISTS" == "true" ]]; then
    cp rawdata/data.db rawdata.db.bak
fi

if [[ "$UNAME_ARCHITECTURE" == "aarch64" ]]; then
    ./hsync
elif [[ "$UNAME_ARCHITECTURE" == "arm64" ]]; then
    ./hsync
elif [[ "$UNAME_ARCHITECTURE" == "x86_64" ]]; then
    ./hsync
fi
TIMESTAMP="$(python3 -c 'import datetime; print(int(datetime.datetime.now().timestamp()))')"
sqlite3 rawdata/data.db << EOF
    DELETE FROM HitomiColumnModel WHERE Type = 'anime';
    VACUUM;
EOF
sqlite3 rawdata-chinese/data.db << EOF
    DELETE FROM HitomiColumnModel WHERE Type = 'anime';
    VACUUM;
EOF
sqlite3 rawdata-japanese/data.db << EOF
    DELETE FROM HitomiColumnModel WHERE Type = 'anime';
    VACUUM;
EOF
sqlite3 rawdata-english/data.db << EOF
    DELETE FROM HitomiColumnModel WHERE Type = 'anime';
    VACUUM;
EOF
sqlite3 rawdata-korean/data.db << EOF
    DELETE FROM HitomiColumnModel WHERE Type = 'anime';
    VACUUM;
EOF

if [[ "$DB_EXISTS" == "true" ]]; then
rm -rf chunk
export MAX_ID="$(sqlite3 rawdata.db.bak << EOF
    SELECT MAX(Id) FROM HitomiColumnModel;
EOF
)"
if [[ -z "$MAX_ID" ]]; then
    echo "Failed to get MAX_ID from the database."
    export MAX_ID="0"
else
    export MAX_ID="$(echo $MAX_ID | tr -d '\n')"
fi
cp rawdata/data.db data-${TIMESTAMP}.db

echo "MAX_ID: $MAX_ID"
sqlite3 data-${TIMESTAMP}.db << EOF
    DELETE FROM HitomiColumnModel WHERE Id < $MAX_ID OR Id = $MAX_ID;
    VACUUM;
EOF
CHUNK_COUNT="$(sqlite3 data-${TIMESTAMP}.db << EOF
    SELECT COUNT(*) FROM HitomiColumnModel;
EOF
)"
if [[ "$CHUNK_COUNT" == "0" ]];then
    rm -f data-${TIMESTAMP}.db
    cd "$PUBLISH_DIR"
    exit -1
fi
python3 << EOF
import sqlite3
import json
import os

conn = sqlite3.connect(f"data-${TIMESTAMP}.db")
conn.row_factory = sqlite3.Row
cursor = conn.cursor()

results = cursor.execute(
    "SELECT * FROM HitomiColumnModel ORDER BY Id DESC"
).fetchall()

data = [dict(row) for row in results]

with open("data-${TIMESTAMP}.json", "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, separators=(",", ":"))

conn.close()
EOF


mkdir -p chunk
mv data-${TIMESTAMP}.db chunk/
mv data-${TIMESTAMP}.json chunk/

echo "sync: create chunk $TIMESTAMP"
gh release create $TIMESTAMP --repo ${GITHUB_USERNAME}/chunk --title "chunk $TIMESTAMP" --notes "" chunk/data-${TIMESTAMP}.db chunk/data-${TIMESTAMP}.json || exit -1
echo "chunk $TIMESTAMP created"

echo "chunk $TIMESTAMP https://github.com/${GITHUB_USERNAME}/chunk/releases/download/$TIMESTAMP/data-${TIMESTAMP}.db $(python3 -c "import os; print(os.path.getsize('chunk/data-${TIMESTAMP}.db'))")" >> syncversion.txt
echo "chunk $TIMESTAMP https://github.com/${GITHUB_USERNAME}/chunk/releases/download/$TIMESTAMP/data-${TIMESTAMP}.json $(python3 -c "import os; print(os.path.getsize('chunk/data-${TIMESTAMP}.json'))")" >> syncversion.txt
rm -rf chunk
fi

cp syncversion.txt ~/sync-data/syncversion.txt
cd ~/sync-data
git config user.name "github-actions"
git config user.email "github-actions@github.com"
git add -A
git commit -m "sync: update syncversion.txt $TIMESTAMP"
git push


cd "$PUBLISH_DIR"

rm -f *.7z
rm -f *.7z.*

7za a rawdata.7z rawdata/* '-xr!*.db-jounal'
ls -la 
echo "sync: create db $TIMESTAMP"
gh release create $TIMESTAMP --repo ${GITHUB_USERNAME}/db --title "db $TIMESTAMP" --notes "" $HOME/violet/hsync/hsync/bin/Release/net8.0/${OS}-${ARCH}/publish/rawdata.7z || exit -1
rm rawdata.7z
7za a rawdata-chinese.7z rawdata-chinese/* '-xr!*.db-journal'
ls -la 
gh release upload $TIMESTAMP --repo ${GITHUB_USERNAME}/db --clobber $HOME/violet/hsync/hsync/bin/Release/net8.0/${OS}-${ARCH}/publish/rawdata-chinese.7z || exit -1
rm rawdata-chinese.7z
7za a rawdata-english.7z rawdata-english/* '-xr!*.db-journal'
ls -la 
gh release upload $TIMESTAMP --repo ${GITHUB_USERNAME}/db --clobber $HOME/violet/hsync/hsync/bin/Release/net8.0/${OS}-${ARCH}/publish/rawdata-english.7z || exit -1
rm rawdata-english.7z
7za a rawdata-japanese.7z rawdata-japanese/* '-xr!*.db-journal'
ls -la
gh release upload $TIMESTAMP --repo ${GITHUB_USERNAME}/db --clobber $HOME/violet/hsync/hsync/bin/Release/net8.0/${OS}-${ARCH}/publish/rawdata-japanese.7z || exit -1
rm rawdata-japanese.7z
7za a rawdata-korean.7z rawdata-korean/* '-xr!*.db-journal'
ls -la 
gh release upload $TIMESTAMP --repo ${GITHUB_USERNAME}/db --clobber $HOME/violet/hsync/hsync/bin/Release/net8.0/${OS}-${ARCH}/publish/rawdata-korean.7z || exit -1
rm rawdata-korean.7z
echo "db $TIMESTAMP https://github.com/${GITHUB_USERNAME}/db/releases/download/$TIMESTAMP/rawdata" >> syncversion.txt
cp syncversion.txt ~/sync-data/syncversion.txt

cd ~/sync-data
git config user.name "github-actions"
git config user.email "github-actions@github.com"
git add -A
git commit -m "sync: update syncversion.txt $(date +%s)"
git push

cd "$PUBLISH_DIR"
