#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/deploy/set-headscale-oidc-allowlist.sh admin@forjanova.com ops@forjanova.com
# Requires sshpass installed locally.

MASTER_USER="root"
MASTER_IP="192.168.1.210"
MASTER_PASS="123456"
NAMESPACE="headscale"

if [[ $# -lt 1 ]]; then
  echo "Uso: $0 <email1> [email2 ...]"
  exit 1
fi

for email in "$@"; do
  if [[ ! "$email" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]; then
    echo "Email invalido: $email"
    exit 1
  fi
done

allow_users_block=""
for email in "$@"; do
  allow_users_block+="    - ${email}"$'\n'
done

allowed_file="/tmp/headscale-allowed-users.txt"
printf "%s" "$allow_users_block" > "$allowed_file"

echo "Aplicando allowlist OIDC en headscale para: $*"

# Get current config locally, then render locally to avoid complex remote quoting.
sshpass -p "$MASTER_PASS" ssh -o StrictHostKeyChecking=no "$MASTER_USER@$MASTER_IP" \
  "KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n headscale get configmap headscale-config -o jsonpath='{.data.config\\.yaml}'" \
  > /tmp/headscale-config-current.yaml

cp /tmp/headscale-config-current.yaml /tmp/headscale-config-updated.yaml

# Replace allowed_users section, preserving other settings.
awk -v allowed_file="$allowed_file" '
  BEGIN { in_users=0; replaced=0 }
  /^  allowed_users:/ {
    print "  allowed_users:"
    while ((getline line < allowed_file) > 0) {
      print line
    }
    close(allowed_file)
    in_users=1
    replaced=1
    next
  }
  in_users {
    if ($0 ~ /^  [a-z_]+:/ || $0 ~ /^log:/ || $0 ~ /^    [^ -]/) {
      in_users=0
      print $0
    }
    next
  }
  { print }
  END {
    if (!replaced) {
      print "  allowed_users:"
      while ((getline line < allowed_file) > 0) {
        print line
      }
      close(allowed_file)
    }
  }
' /tmp/headscale-config-current.yaml > /tmp/headscale-config-updated.yaml

{
  echo 'apiVersion: v1'
  echo 'kind: ConfigMap'
  echo 'metadata:'
  echo '  name: headscale-config'
  echo '  namespace: headscale'
  echo 'data:'
  echo '  config.yaml: |'
  sed 's/^/    /' /tmp/headscale-config-updated.yaml
} > /tmp/headscale-config-cm.yaml

sshpass -p "$MASTER_PASS" scp -o StrictHostKeyChecking=no /tmp/headscale-config-cm.yaml "$MASTER_USER@$MASTER_IP:/tmp/headscale-config-cm.yaml" >/dev/null

sshpass -p "$MASTER_PASS" ssh -o StrictHostKeyChecking=no "$MASTER_USER@$MASTER_IP" '
  KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl apply -f /tmp/headscale-config-cm.yaml && \
  KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n headscale rollout restart deployment/headscale && \
  KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n headscale rollout status deployment/headscale --timeout=3m && \
  KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n headscale get configmap headscale-config -o jsonpath="{.data.config\\.yaml}" | grep -n "allowed_groups:\|allowed_users:" 
'

echo "Allowlist aplicada. Solo los usuarios permitidos podran autenticarse por OIDC."
