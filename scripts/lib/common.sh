#!/bin/bash

set -Eeuo pipefail

log() {
  printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

require_file() {
  local file="$1"

  if [ ! -s "$file" ]; then
    die "$file is missing or empty"
  fi
}

wait_for_ssh() {
  local host="$1"

  for i in {1..30}; do
    if ssh \
      -o StrictHostKeyChecking=accept-new \
      -o ConnectTimeout=3 \
      "admin@${host}" true 2>/dev/null; then
      return 0
    fi

    sleep 5
  done

  die "SSH not ready for ${host}"
}

remote_sudo_install() {
  local host="$1"
  local source_file="$2"
  local destination="$3"
  local mode="$4"

  local base
  base="$(basename "$source_file")"

  scp \
    -o StrictHostKeyChecking=accept-new \
    "$source_file" \
    "admin@${host}:/tmp/${base}"

  ssh \
    -o StrictHostKeyChecking=accept-new \
    "admin@${host}" \
    "sudo install -o root -g root -m ${mode} /tmp/${base} ${destination} && rm -f /tmp/${base}"
}
