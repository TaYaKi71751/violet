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
elif [[ "$UNAME_ARCHITECTURE" == "arm64" ]]; then
    ARCH="arm64"
fi

cd hsync
dotnet publish -r ${OS}-${ARCH} -c Release /p:PublishSingleFile=true /p:PublishTrimmed=false /p:PublishReadyToRun=false
cp ../sync.py bin/Release/net8.0/${OS}-${ARCH}/publish
cd bin/Release/net8.0/${OS}-${ARCH}/publish
./hsync