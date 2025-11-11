#!/bin/bash

################################################################################
# INSTALL-K3S-WORKER-CLEAN.sh - Instala K3s Agent en Worker (Raspberry Pi)
################################################################################
#
# Uso: bash INSTALL-K3S-WORKER-CLEAN.sh
# Ejecutar en: Raspberry Pi (Worker)
#
# Este script instala K3s agent directamente en un sistema limpio
# Configura conexión al master y valida que funciona
#
################################################################################

set -e

LOG_FILE="/var/log/k3s-install-worker.log"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        INSTALACIÓN K3S WORKER (Raspberry Pi)                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Log: $LOG_FILE"
echo ""

{
    echo "=== INICIO INSTALACIÓN K3S WORKER ==="
    echo "Timestamp: $(date)"
    echo ""

    ################################################################################
    # 1. Obtener datos del master
    ################################################################################

    echo "[1/5] Obteniendo datos del master..."
    echo ""
    
    echo "IP del Master (default: 192.168.1.254):"
    read -r MASTER_IP
    MASTER_IP="${MASTER_IP:-192.168.1.254}"
    
    echo "Token del Master (K1...):"
    read -r K3S_TOKEN
    
    echo ""
    echo "Master IP: $MASTER_IP"
    echo "Token: ${K3S_TOKEN:0:20}..."
    echo ""

    ################################################################################
    # 2. Actualizar sistema
    ################################################################################

    echo "[2/5] Actualizando sistema..."
    sudo apt update
    sudo apt upgrade -y
    echo "✓ Sistema actualizado"
    echo ""

    ################################################################################
    # 3. Instalar dependencias
    ################################################################################

    echo "[3/5] Instalando dependencias..."
    sudo apt install -y curl wget net-tools htop vim
    echo "✓ Dependencias instaladas"
    echo ""

    ################################################################################
    # 4. Instalar K3s Agent
    ################################################################################

    echo "[4/5] Instalando K3s agent..."
    
    export K3S_URL="https://$MASTER_IP:6443"
    export K3S_TOKEN="$K3S_TOKEN"
    
    curl -sfL https://get.k3s.io | sh -
    
    echo "✓ K3s agent instalado"
    echo ""

    ################################################################################
    # 5. Esperar y validar
    ################################################################################

    echo "[5/5] Validando instalación..."
    
    for i in {1..30}; do
        if sudo systemctl is-active --quiet k3s-agent.service; then
            echo "✓ K3s agent iniciado correctamente"
            break
        fi
        echo "  Intento $i/30..."
        sleep 2
    done
    
    echo ""
    echo "Ver logs de conexión:"
    sudo journalctl -u k3s-agent.service -n 20 --no-pager
    echo ""
    
    ################################################################################
    # RESUMEN
    ################################################################################
    
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║            INSTALACIÓN COMPLETADA                           ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "✓ K3s agent instalado"
    echo "✓ Conectando al master: $MASTER_IP"
    echo ""
    echo "Próximos pasos:"
    echo "1. Desde tu PC, ejecuta:"
    echo "   ssh root@192.168.1.254 \"kubectl get nodes\""
    echo "2. Deberías ver ambos nodos como Ready"
    echo ""
    echo "Para ver logs: sudo journalctl -u k3s-agent.service -f"
    echo ""
    
    echo "=== FIN INSTALACIÓN K3S WORKER ==="
    echo "Timestamp: $(date)"

} | tee "$LOG_FILE"

exit 0
