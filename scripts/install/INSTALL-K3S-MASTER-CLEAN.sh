#!/bin/bash

################################################################################
# INSTALL-K3S-MASTER-CLEAN.sh - Instala K3s Server en Master (Orange Pi)
################################################################################
#
# Uso: bash INSTALL-K3S-MASTER-CLEAN.sh
# Ejecutar en: Orange Pi (Master)
#
# Este script instala K3s server directamente en un sistema limpio
# Configura IP, tokens, y valida que funciona
#
################################################################################

set -e

LOG_FILE="/var/log/k3s-install-master.log"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        INSTALACIÓN K3S MASTER (Orange Pi)                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Log: $LOG_FILE"
echo ""

{
    echo "=== INICIO INSTALACIÓN K3S MASTER ==="
    echo "Timestamp: $(date)"
    echo ""

    ################################################################################
    # 1. Actualizar sistema
    ################################################################################

    echo "[1/5] Actualizando sistema..."
    sudo apt update
    sudo apt upgrade -y
    echo "✓ Sistema actualizado"
    echo ""

    ################################################################################
    # 2. Instalar dependencias
    ################################################################################

    echo "[2/5] Instalando dependencias..."
    sudo apt install -y curl wget net-tools htop vim
    echo "✓ Dependencias instaladas"
    echo ""

    ################################################################################
    # 3. Instalar K3s
    ################################################################################

    echo "[3/5] Instalando K3s server..."
    
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
      --cluster-cidr=192.168.0.0/16 \
      --service-cidr=10.43.0.0/16 \
      --disable=traefik \
      --disable=servicelb \
      --disable=local-storage" sh -
    
    echo "✓ K3s server instalado"
    echo ""

    ################################################################################
    # 4. Esperar a que inicie
    ################################################################################

    echo "[4/5] Esperando a que K3s inicie..."
    
    for i in {1..30}; do
        if sudo systemctl is-active --quiet k3s.service; then
            echo "✓ K3s iniciado correctamente"
            break
        fi
        echo "  Intento $i/30..."
        sleep 2
    done
    
    echo ""

    ################################################################################
    # 5. Validar y obtener token
    ################################################################################

    echo "[5/5] Validando instalación..."
    
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    
    # Esperar a que API responda
    for i in {1..30}; do
        if kubectl get nodes >/dev/null 2>&1; then
            echo "✓ API K3s respondiendo"
            break
        fi
        echo "  Esperando API ($i/30)..."
        sleep 2
    done
    
    echo ""
    echo "Estado del master:"
    kubectl get nodes
    echo ""
    
    echo "Token para workers (GUARDA ESTO):"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    sudo cat /var/lib/rancher/k3s/server/node-token
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Guardar token en archivo
    sudo cat /var/lib/rancher/k3s/server/node-token > /tmp/k3s-worker-token.txt
    echo "Token guardado en: /tmp/k3s-worker-token.txt"
    echo ""
    
    ################################################################################
    # RESUMEN
    ################################################################################
    
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║            INSTALACIÓN COMPLETADA                           ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "✓ K3s server instalado y corriendo"
    echo "✓ API disponible en puerto 6443"
    echo "✓ Token generado para workers"
    echo ""
    echo "Próximos pasos:"
    echo "1. Copia el token mostrado arriba"
    echo "2. Ve a Raspberry Pi (worker)"
    echo "3. Ejecuta: INSTALL-K3S-WORKER-CLEAN.sh"
    echo "4. Pega el token cuando se te pida"
    echo ""
    echo "Para ver logs: sudo journalctl -u k3s.service -f"
    echo ""
    
    echo "=== FIN INSTALACIÓN K3S MASTER ==="
    echo "Timestamp: $(date)"

} | tee "$LOG_FILE"

exit 0
