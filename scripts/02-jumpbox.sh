#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

REPO_DIR="/home/admin/kubernetes-the-hard-way"
REPO_URL="https://github.com/kelseyhightower/kubernetes-the-hard-way.git"

log "Waiting for jumpbox"
wait_for_ssh jumpbox

log "Preparing jumpbox repository"

ssh admin@jumpbox bash <<'REMOTE'
set -Eeuo pipefail

REPO_DIR="/home/admin/kubernetes-the-hard-way"
REPO_URL="https://github.com/kelseyhightower/kubernetes-the-hard-way.git"

if [ ! -d "${REPO_DIR}/.git" ]; then
  git clone --depth 1 "${REPO_URL}" "${REPO_DIR}"
fi

cd "${REPO_DIR}"

ARCH="$(dpkg --print-architecture)"

mkdir -p downloads/{client,cni-plugins,controller,worker}

wget -q --show-progress \
  --https-only \
  --timestamping \
  -P downloads \
  -i "downloads-${ARCH}.txt"

find downloads -type f -name '*.tar.gz' -print

for archive in downloads/*.tar.gz; do
  [ -e "$archive" ] || continue
  tar -xf "$archive" -C downloads
done

find downloads -type f -perm /111 -exec chmod +x {} \;

if [ -f downloads/kubectl ]; then
  chmod +x downloads/kubectl
  sudo install -m 0755 downloads/kubectl /usr/local/bin/kubectl
fi

kubectl version --client
REMOTE

log "Lab 02 complete"
