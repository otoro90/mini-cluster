#!/bin/bash

# Script de despliegue para mini-cluster Kubernetes
# Fecha: 6 de noviembre de 2025

# set -e  # Removido para ser más tolerante a fallos temporales

echo "🚀 Iniciando despliegue del mini-cluster..."

# Configurar KUBECONFIG
export KUBECONFIG=/etc/kubernetes/admin.conf

echo "📦 Aplicando manifests..."

# Aplicar secrets primero
kubectl apply -f manifests/postgres-secret.yaml
kubectl apply -f manifests/keycloak-secret.yaml

# Aplicar servicios
kubectl apply -f manifests/postgres-service.yaml
kubectl apply -f manifests/keycloak-service.yaml

# Aplicar deployments/statefulsets
kubectl apply -f manifests/postgres-statefulset.yaml
kubectl apply -f manifests/keycloak-deployment.yaml

echo "🌐 Instalando NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/baremetal/deploy.yaml

# Aplicar ingress
kubectl apply -f manifests/ingress.yaml

echo "⏳ Esperando que los deployments estén listos..."

# Esperar a que keycloak esté listo (deployment)
kubectl wait --for=condition=ready pod -l app=keycloak --timeout=300s

# Esperar a que ingress-nginx esté listo (opcional, puede tardar)
echo "⏳ Esperando ingress controller (hasta 60s)..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=ingress-nginx -n ingress-nginx --timeout=60s 2>/dev/null || echo "⚠️  Ingress controller aún inicializando, continuará en background"

echo "✅ Deployments listos. El StatefulSet de PostgreSQL puede tardar más en provisionar storage."

echo "🔗 Iniciando port-forwards persistentes..."

# Matar port-forwards existentes si los hay
pkill -f "kubectl port-forward svc/postgres-svc" || true
pkill -f "kubectl port-forward svc/keycloak-svc" || true

# Iniciar port-forwards en background
nohup kubectl port-forward svc/postgres-svc 5432:5432 --address 0.0.0.0 > /var/log/postgres-port-forward.log 2>&1 &
echo $! > /var/run/postgres-port-forward.pid

nohup kubectl port-forward svc/keycloak-svc 8080:8080 --address 0.0.0.0 > /var/log/keycloak-port-forward.log 2>&1 &
echo $! > /var/run/keycloak-port-forward.pid

echo "✅ Verificando estado final..."

# Verificar estado
kubectl get pods
kubectl get svc

echo ""
echo "🎉 Despliegue completado!"
echo "📊 PostgreSQL: http://$(hostname -I | awk '{print $1}'):5432"
echo "🔐 Keycloak: http://$(hostname -I | awk '{print $1}'):8080"
echo "   Usuario: admin"
echo "   Password: admin"
echo ""
echo "📝 Logs de port-forward:"
echo "   PostgreSQL: /var/log/postgres-port-forward.log"
echo "   Keycloak: /var/log/keycloak-port-forward.log"