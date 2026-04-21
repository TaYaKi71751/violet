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

cd hsync
dotnet publish -r ${OS}-${ARCH} -c Release /p:PublishSingleFile=true /p:PublishTrimmed=false /p:PublishReadyToRun=false
cp ../sync.py bin/Release/net8.0/${OS}-${ARCH}/publish
cd bin/Release/net8.0/${OS}-${ARCH}/publish
if [[ "$UNAME_ARCHITECTURE" == "aarch64" ]]; then
    ./hsync
elif [[ "$UNAME_ARCHITECTURE" == "arm64" ]]; then
    arch -x86_64 ./hsync
elif [[ "$UNAME_ARCHITECTURE" == "x86_64" ]]; then
    ./hsync
fi
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
rm *.7z
rm *.7z.*

7za a rawdata.7z rawdata/* '-xr!*.db-jounal'
ls -la 
TIMESTAMP="$(python3 -c 'import datetime; print(int(datetime.datetime.now().timestamp()))')"
echo "sync: create db $TIMESTAMP"
gh release create $TIMESTAMP --repo TaYaKi71751/db --title "db $TIMESTAMP" --notes "" $HOME/violet/hsync/hsync/bin/Release/net8.0/${OS}-${ARCH}/publish/rawdata.7z || exit -1
rm rawdata.7z
7za a rawdata-chinese.7z rawdata-chinese/* '-xr!*.db-journal'
ls -la 
gh release upload $TIMESTAMP --repo TaYaKi71751/db --clobber $HOME/violet/hsync/hsync/bin/Release/net8.0/${OS}-${ARCH}/publish/rawdata-chinese.7z || exit -1
7za a rawdata-english.7z rawdata-english/* '-xr!*.db-journal'
ls -la 
gh release upload $TIMESTAMP --repo TaYaKi71751/db --clobber $HOME/violet/hsync/hsync/bin/Release/net8.0/${OS}-${ARCH}/publish/rawdata-english.7z || exit -1
rm rawdata-english.7z
7za a rawdata-japanese.7z rawdata-japanese/* '-xr!*.db-journal'
ls -la
gh release upload $TIMESTAMP --repo TaYaKi71751/db --clobber $HOME/violet/hsync/hsync/bin/Release/net8.0/${OS}-${ARCH}/publish/rawdata-japanese.7z || exit -1
rm rawdata-japanese.7z
7za a rawdata-korean.7z rawdata-korean/* '-xr!*.db-journal'
ls -la 
gh release upload $TIMESTAMP --repo TaYaKi71751/db --clobber $HOME/violet/hsync/hsync/bin/Release/net8.0/${OS}-${ARCH}/publish/rawdata-korean.7z || exit -1
rm rawdata-korean.7z
echo "db https://github.com/TaYaKi71751/db/releases/download/$TIMESTAMP/rawdata" >> syncversion.txt
cp syncversion.txt ~/sync-data/syncversion.txt

cd ~/sync-data
git config user.name "github-actions"
git config user.email "github-actions@github.com"
git add -A
git commit -m "sync: update syncversion.txt $(date +%s)"
git push