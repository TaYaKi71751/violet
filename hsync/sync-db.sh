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
python3 sync.py