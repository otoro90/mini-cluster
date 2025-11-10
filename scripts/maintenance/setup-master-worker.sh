#!/bin/bash

# Script para configurar el master como worker de emergencia
# Fecha: 6 de noviembre de 2025

echo "🔧 Configurando master como worker de emergencia..."

# Configurar KUBECONFIG
export KUBECONFIG=/etc/kubernetes/admin.conf

# Obtener el nombre del nodo master
MASTER_NODE=$(kubectl get nodes -l node-role.kubernetes.io/control-plane= -o jsonpath='{.items[0].metadata.name}')

if [ -z "$MASTER_NODE" ]; then
    echo "❌ No se encontró el nodo master"
    exit 1
fi

echo "📍 Nodo master identificado: $MASTER_NODE"

# Verificar taints actuales
echo "🔍 Verificando taints actuales..."
kubectl describe node $MASTER_NODE | grep -A 5 "Taints:"

# Quitar taint de control-plane si existe
echo "🧹 Removiendo taint de control-plane..."
kubectl taint nodes $MASTER_NODE node-role.kubernetes.io/control-plane:NoSchedule- 2>/dev/null || echo "ℹ️  No había taint de control-plane o ya fue removido"

# Verificar que el nodo acepte pods
echo "✅ Verificando configuración final..."
kubectl describe node $MASTER_NODE | grep -A 5 "Taints:"

echo ""
echo "🎉 Master configurado como worker de emergencia!"
echo "📊 Ahora puede ejecutar pods de usuario además del control plane."
echo ""
echo "💡 Para verificar: kubectl get pods -o wide"