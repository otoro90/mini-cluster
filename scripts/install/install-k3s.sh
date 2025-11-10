#!/bin/bash

# Script para instalar K3s en ARM64 (Orange Pi/Raspberry Pi)
# Fecha: 10 de noviembre de 2025

echo "🐄 Instalando K3s en ARM64..."

# Instalar dependencias
echo "📦 Instalando dependencias..."
apt update
apt install -y curl wget

# Instalar K3s server (para master)
echo "🚀 Instalando K3s server..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--cluster-init --pod-network-cidr=192.168.0.0/16 --disable=traefik" sh -

# Esperar a que K3s esté listo
echo "⏳ Esperando que K3s esté listo..."
sleep 30

# Verificar instalación
echo "✅ Verificando instalación..."
kubectl get nodes
kubectl get pods -A

# Configurar KUBECONFIG
echo "🔧 Configurando KUBECONFIG..."
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> ~/.bashrc

echo ""
echo "🎉 K3s instalado exitosamente!"
echo "📋 Comandos útiles:"
echo "   kubectl get nodes"
echo "   kubectl get pods -A"
echo "   k3s kubectl get nodes"
echo ""
echo "🔗 Para agregar workers:"
echo "   En worker: curl -sfL https://get.k3s.io | K3S_URL=https://MASTER_IP:6443 K3S_TOKEN=\$(cat /var/lib/rancher/k3s/server/node-token) sh -"