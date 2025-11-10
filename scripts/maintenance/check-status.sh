#!/bin/bash

# Script de verificación para mini-cluster Kubernetes
# Fecha: 6 de noviembre de 2025

echo "🔍 Verificando estado del mini-cluster..."

# Configurar KUBECONFIG
export KUBECONFIG=/etc/kubernetes/admin.conf

echo "📊 Estado de pods:"
kubectl get pods -o wide

echo ""
echo "🌐 Estado de servicios:"
kubectl get svc

echo ""
echo "💾 Estado de PVCs:"
kubectl get pvc

echo ""
echo "🔗 Port-forwards activos:"
ps aux | grep "kubectl port-forward" | grep -v grep || echo "Ninguno activo"

echo ""
echo "📝 Logs recientes de Keycloak:"
kubectl logs -l app=keycloak --tail=5

echo ""
echo "🗄️ Logs recientes de PostgreSQL:"
kubectl logs -l app=postgres --tail=5

echo ""
echo "🌐 Puertos abiertos:"
netstat -tlnp 2>/dev/null | grep -E "(5432|8080)" || ss -tlnp | grep -E "(5432|8080)" || echo "netstat/ss no disponible"

echo ""
echo "✅ Verificación completada!"