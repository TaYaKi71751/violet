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
pkill -9 sqlite3
rm *.7z
rm *.7z.*
rm -rf chunk
if [[ "$UNAME_ARCHITECTURE" == "aarch64" ]]; then
    ./hsync
elif [[ "$UNAME_ARCHITECTURE" == "arm64" ]]; then
    arch -x86_64 ./hsync
elif [[ "$UNAME_ARCHITECTURE" == "x86_64" ]]; then
    ./hsync
fi
./hsync
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