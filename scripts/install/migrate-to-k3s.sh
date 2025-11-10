#!/bin/bash

# Script para migrar de kubeadm a K3s
# Fecha: 10 de noviembre de 2025
# ¡CUIDADO: Esto resetea el cluster actual!

echo "⚠️  ADVERTENCIA: Esta migración reseteará tu cluster kubeadm actual"
echo "   Asegúrate de tener backups de datos importantes"
echo ""
read -p "¿Continuar? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Migración cancelada."
    exit 1
fi

echo "🔄 Iniciando migración kubeadm → K3s..."

# Backup de configs importantes (opcional)
echo "💾 Creando backup de configs..."
mkdir -p /root/kubeadm-backup
cp -r /etc/kubernetes /root/kubeadm-backup/ 2>/dev/null || true
cp /etc/rancher/k3s/k3s.yaml /root/kubeadm-backup/ 2>/dev/null || true

# Resetear kubeadm
echo "🧹 Reseteando kubeadm..."
kubeadm reset --force
rm -rf /etc/kubernetes/
rm -rf /var/lib/kubelet/
rm -rf /var/lib/etcd/

# Limpiar iptables y networking
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
systemctl stop containerd
systemctl disable containerd

# Instalar K3s
echo "🐄 Instalando K3s..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--cluster-init --pod-network-cidr=192.168.0.0/16 --disable=traefik" sh -

# Esperar a que K3s esté listo
echo "⏳ Esperando que K3s esté listo..."
sleep 60

# Configurar KUBECONFIG
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> ~/.bashrc

# Verificar migración
echo "✅ Verificando migración..."
kubectl get nodes
kubectl get pods -A

echo ""
echo "🎉 Migración completada!"
echo "📋 Tu cluster K3s está listo"
echo "   kubectl get nodes"
echo "   kubectl get pods -A"
echo ""
echo "💡 Próximos pasos:"
echo "   1. Ejecutar: /root/deploy-k3s-optimized.sh"
echo "   2. Verificar que las apps funcionan"
echo "   3. Re-agregar workers si es necesario"
echo ""
echo "🔄 Backup guardado en: /root/kubeadm-backup/"