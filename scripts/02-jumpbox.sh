#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

REPO_DIR="/home/admin/kubernetes-the-hard-way"
REPO_URL="https://github.com/kelseyhightower/kubernetes-the-hard-way.git"

log "Preparing jumpbox repository"

if [ ! -d "${REPO_DIR}/.git" ]; then

	log "Cloning Kubernetes The Hard Way repository"

	git clone \
		--depth 1 \
		"${REPO_URL}" \
		"${REPO_DIR}"

else

	log "Repository already exists, skipping clone"

fi

cd "${REPO_DIR}"

ARCH="$(dpkg --print-architecture)"

log "Downloading Kubernetes binaries"

mkdir -p downloads

wget \
	-q \
	--show-progress \
	--https-only \
	--timestamping \
	-P downloads \
	-i "downloads-${ARCH}.txt"

log "Extracting archives"

for archive in downloads/*.tar.gz downloads/*.tgz; do

	[ -e "$archive" ] || continue

	tar -xf "$archive" \
		-C downloads

done

log "Installing kubectl"

require_file downloads/kubectl

sudo install \
	-m 0755 \
	downloads/kubectl \
	/usr/local/bin/kubectl

log "Verifying kubectl"

kubectl version --client

log "Lab 02 complete"
