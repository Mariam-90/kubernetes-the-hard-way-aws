#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

REPO_DIR="/home/admin/kubernetes-the-hard-way"

cd "${REPO_DIR}"

log "Generating encryption configuration"

ENCRYPTION_KEY="$(
  head -c 32 /dev/urandom \
  | base64 \
  | tr -d '\n'
)"

sed "s|\${ENCRYPTION_KEY}|${ENCRYPTION_KEY}|g" \
  configs/encryption-config.yaml \
  > encryption-config.yaml

require_file encryption-config.yaml
grep "secret:" encryption-config.yaml

SECRET_VALUE="$(
  awk '/secret:/ {print $2}' encryption-config.yaml
)"

if [ -z "$SECRET_VALUE" ]; then
  echo "ERROR: encryption key is missing from encryption-config.yaml" >&2
  exit 1
fi

echo "$SECRET_VALUE" | base64 -d >/dev/null

log "Distributing encryption configuration"

scp \
  encryption-config.yaml \
  admin@server:/tmp/

ssh admin@server "
  sudo mkdir -p /var/lib/kubernetes

  sudo install \
    -o root \
    -g root \
    -m 0600 \
    /tmp/encryption-config.yaml \
    /var/lib/kubernetes/encryption-config.yaml

  rm -f /tmp/encryption-config.yaml
"

log "Verifying encryption configuration"

ssh admin@server "
  sudo test -s /var/lib/kubernetes/encryption-config.yaml
"

log "Lab 06 complete"