#!/bin/bash

# Script de limpieza para mini-cluster Kubernetes
# Fecha: 6 de noviembre de 2025

echo "🧹 Iniciando limpieza del mini-cluster..."

# Configurar KUBECONFIG
export KUBECONFIG=/etc/kubernetes/admin.conf

echo "🗑️ Eliminando pods fallidos..."
kubectl delete pod --field-selector=status.phase!=Running --ignore-not-found=true

echo "🗑️ Eliminando PVCs no utilizados..."
kubectl delete pvc --field-selector=status.phase!=Bound --ignore-not-found=true

echo "🔄 Reiniciando port-forwards..."
# Matar port-forwards existentes
pkill -f "kubectl port-forward" || true

# Reiniciar port-forwards
nohup kubectl port-forward svc/postgres-svc 5432:5432 --address 0.0.0.0 > /var/log/postgres-port-forward.log 2>&1 &
echo $! > /var/run/postgres-port-forward.pid

nohup kubectl port-forward svc/keycloak-svc 8080:8080 --address 0.0.0.0 > /var/log/keycloak-port-forward.log 2>&1 &
echo $! > /var/run/keycloak-port-forward.pid

echo "✅ Limpieza completada!"
echo "📊 Ejecuta '/root/check-status.sh' para verificar el estado."