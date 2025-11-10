#!/bin/bash

# Script para redistribuir pods en el clúster
# Fuerza la reprogramación de pods para mejor distribución
# Fecha: 6 de noviembre de 2025

echo "🔄 Redistribuyendo pods para alta disponibilidad..."

# Configurar KUBECONFIG
export KUBECONFIG=/etc/kubernetes/admin.conf

# Lista de aplicaciones a redistribuir
APPS=("nginx" "keycloak" "postgres")

for app in "${APPS[@]}"; do
    echo "📦 Redistribuyendo $app..."
    kubectl delete pods -l app=$app --ignore-not-found=true
    sleep 2
done

echo "⏳ Esperando reprogramación..."
sleep 10

echo "✅ Verificando distribución final..."
kubectl get pods -o wide | grep -E "(${APPS[*]})"

echo ""
echo "🎯 Redistribución completada!"
echo "💡 Ejecuta '/root/check-status.sh' para ver el estado final."