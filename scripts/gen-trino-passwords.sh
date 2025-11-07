#!/bin/bash

#
# Generate password.db file for Trino authentication
# --------------------------------

FORCE_GENERATE=${1:-false}

# alpine:latest size is ~8MB
DOCKER_IMAGE="alpine@sha256:4b7ce07002c69e8f3d704a9c5d6fd3053be500b7f1c69fc0d80990c2ad8dd412"
TARGET_DIR="./trino/etc"
mkdir -p "$TARGET_DIR"

if [ -f "$TARGET_DIR/password.db" ] && [ "$FORCE_GENERATE" != true ]; then
    echo "Password file '$TARGET_DIR/password.db' already exists. Skipping generation."
    exit 0
fi

if docker image inspect "$DOCKER_IMAGE" > /dev/null 2>&1; then
    echo "Docker image $DOCKER_IMAGE found locally."
else
    echo "Pulling Docker image $DOCKER_IMAGE..."
    docker pull "$DOCKER_IMAGE"
fi

# shellcheck disable=SC2046
docker run --rm -it \
  -v "$TARGET_DIR:/secrets" \
  $DOCKER_IMAGE sh -c "
    apk add --no-cache apache2-utils && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /app/trino/etc && \
    htpasswd -bBC 10 -c /app/trino/etc/password.db admin adminpassword && \
    htpasswd -bB /app/trino/etc/password.db airflow_user airflowpassword && \
    htpasswd -bB /app/trino/etc/password.db superset_user supersetpassword && \
    cp /app/trino/etc/password.db /secrets/
  "