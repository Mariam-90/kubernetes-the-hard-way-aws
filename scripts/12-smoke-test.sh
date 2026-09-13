#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

log "Running smoke tests"

kubectl delete deployment nginx --ignore-not-found

kubectl delete service nginx --ignore-not-found

kubectl create deployment nginx \
  --image=nginx

kubectl wait \
  --for=condition=Available \
  deployment/nginx \
  --timeout=180s

POD_NAME="$(
  kubectl get pods \
    -l app=nginx \
    -o jsonpath='{.items[0].metadata.name}'
)"

test -n "$POD_NAME"

log "Testing pod logs"

kubectl logs "$POD_NAME" >/dev/null

log "Testing kubectl exec"

kubectl exec "$POD_NAME" -- nginx -v

log "Creating NodePort service"

kubectl expose deployment nginx \
  --port 80 \
  --type NodePort

NODE_PORT="$(
  kubectl get svc nginx \
    -o jsonpath='{.spec.ports[0].nodePort}'
)"

NODE_NAME="$(
  kubectl get pod "$POD_NAME" \
    -o jsonpath='{.spec.nodeName}'
)"

test -n "$NODE_PORT"
test -n "$NODE_NAME"

log "Testing NodePort connectivity"

curl \
  --fail \
  --head \
  "http://${NODE_NAME}:${NODE_PORT}"

log "Final cluster state"

kubectl get nodes
kubectl get pods -o wide
kubectl get svc nginx

log "Lab 12 complete"