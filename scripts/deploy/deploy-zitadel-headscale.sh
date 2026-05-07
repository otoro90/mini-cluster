#!/usr/bin/env bash
set -euo pipefail

MASTER_IP="${MASTER_IP:-192.168.1.210}"
MASTER_USER="${MASTER_USER:-root}"
MASTER_PASS="${MASTER_PASS:-123456}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST_DIR="$REPO_ROOT/manifests/security/zitadel-headscale"

if ! command -v sshpass >/dev/null 2>&1; then
  echo "ERROR: sshpass no esta instalado en esta maquina." >&2
  exit 1
fi

run_remote() {
  sshpass -p "$MASTER_PASS" ssh -o StrictHostKeyChecking=no "$MASTER_USER@$MASTER_IP" "$@"
}

echo "[1/6] Verificando acceso al cluster..."
run_remote "KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get nodes -o wide"

echo "[2/6] Aplicando PostgreSQL externo para ZITADEL..."
sshpass -p "$MASTER_PASS" ssh -o StrictHostKeyChecking=no "$MASTER_USER@$MASTER_IP" \
  "cat > /tmp/zitadel-postgres.yaml" < "$MANIFEST_DIR/zitadel-postgres.yaml"
run_remote "KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl apply -f /tmp/zitadel-postgres.yaml"

echo "[3/6] Creando masterkey de ZITADEL (si no existe)..."
if ! run_remote "KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n zitadel get secret zitadel-masterkey >/dev/null 2>&1"; then
  if [[ -n "${ZITADEL_MASTERKEY:-}" ]]; then
    MASTERKEY="$ZITADEL_MASTERKEY"
  else
    set +o pipefail
    MASTERKEY="$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)"
    set -o pipefail
  fi
  run_remote "KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n zitadel create secret generic zitadel-masterkey --from-literal=masterkey='$MASTERKEY'"
  echo "  Secret zitadel-masterkey creado."
else
  echo "  Secret zitadel-masterkey ya existe, se conserva."
fi

echo "[4/6] Instalando/actualizando ZITADEL con Helm..."
sshpass -p "$MASTER_PASS" ssh -o StrictHostKeyChecking=no "$MASTER_USER@$MASTER_IP" \
  "cat > /tmp/zitadel-values.yaml" < "$MANIFEST_DIR/zitadel-values.yaml"
run_remote "helm repo add zitadel https://charts.zitadel.com >/dev/null 2>&1 || true"
run_remote "helm repo update >/dev/null 2>&1"
run_remote "KUBECONFIG=/etc/rancher/k3s/k3s.yaml helm upgrade --install zitadel zitadel/zitadel -n zitadel -f /tmp/zitadel-values.yaml --create-namespace --wait --timeout 20m"

echo "[5/6] Aplicando Headscale..."
sshpass -p "$MASTER_PASS" ssh -o StrictHostKeyChecking=no "$MASTER_USER@$MASTER_IP" \
  "cat > /tmp/headscale.yaml" < "$MANIFEST_DIR/headscale.yaml"
run_remote "KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl apply -f /tmp/headscale.yaml"
run_remote "KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n headscale rollout status deployment/headscale --timeout=10m"

echo "[6/6] Validacion final..."
run_remote "KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get pods -n zitadel -o wide"
run_remote "KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get pods -n headscale -o wide"
run_remote "KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get ingress -n zitadel"
run_remote "KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get ingress -n headscale"

echo "Listo."
echo "ZITADEL:   http://zitadel.192.168.1.210.nip.io"
echo "Headscale: http://headscale.192.168.1.210.nip.io"
