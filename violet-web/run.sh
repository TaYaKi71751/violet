#!/bin/bash

PODMAN_BIN="$(which podman)"
DOCKER_BIN="$(which docker)"
CONTAINER_RUNTIME=""
if [ -x "$PODMAN_BIN" ]; then
  echo "Using Podman to run the container."
  CONTAINER_RUNTIME="$PODMAN_BIN"
elif [ -x "$DOCKER_BIN" ]; then
  echo "Using Docker to run the container."
  CONTAINER_RUNTIME="$DOCKER_BIN"
fi

${CONTAINER_RUNTIME} build -t violet-web .
${CONTAINER_RUNTIME} rm -f violet-web || true
${CONTAINER_RUNTIME} run -d \
  --name violet-web \
  -p 3001:3001 \
  violet-web
