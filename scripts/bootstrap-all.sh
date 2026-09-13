#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Starting Lab 02"
"${SCRIPT_DIR}/02-jumpbox.sh"

echo "Starting Lab 03"
"${SCRIPT_DIR}/03-compute-resources.sh"

echo "Starting Lab 04"
"${SCRIPT_DIR}/04-pki.sh"

echo "Starting Lab 05"
"${SCRIPT_DIR}/05-kubeconfigs.sh"

echo "Starting Lab 06"
"${SCRIPT_DIR}/06-encryption.sh"

echo "Starting Lab 07"
"${SCRIPT_DIR}/07-etcd.sh"

echo "Starting Lab 08"
"${SCRIPT_DIR}/08-control-plane.sh"

echo "Starting Lab 09"
"${SCRIPT_DIR}/09-workers.sh"

echo "Starting Lab 10"
"${SCRIPT_DIR}/10-kubectl.sh"

echo "Starting Lab 11"
"${SCRIPT_DIR}/11-routes.sh"

echo "Starting Lab 12"
"${SCRIPT_DIR}/12-smoke-test.sh"

echo
echo "Kubernetes The Hard Way automation completed successfully."