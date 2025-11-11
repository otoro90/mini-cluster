#!/bin/bash

################################################################################
# VALIDATE-K3S-CLUSTER.sh - Valida que el cluster funciona correctamente
################################################################################
#
# Uso: bash VALIDATE-K3S-CLUSTER.sh
# Ejecutar en: Master
#
################################################################################

set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          VALIDACIÓN DEL CLUSTER K3S                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

ERRORS=0
WARNINGS=0

################################################################################
# 1. Verificar nodos
################################################################################

echo "[1/8] Verificando nodos..."
echo ""

NODES=$(kubectl get nodes --no-headers | wc -l)
echo "Nodos encontrados: $NODES"

if [ "$NODES" -lt 2 ]; then
    echo "⚠ Se esperaban 2 nodos (master + worker)"
    WARNINGS=$((WARNINGS + 1))
fi

kubectl get nodes
echo ""

READY_NODES=$(kubectl get nodes --no-headers | grep -c "Ready" || echo 0)
if [ "$READY_NODES" -eq "$NODES" ]; then
    echo "✓ Todos los nodos Ready"
else
    echo "✗ Algunos nodos no están Ready"
    ERRORS=$((ERRORS + 1))
fi

echo ""

################################################################################
# 2. Verificar componentes kube-system
################################################################################

echo "[2/8] Verificando componentes del sistema..."
echo ""

RUNNING_PODS=$(kubectl get pods -n kube-system --no-headers | grep -c "Running" || echo 0)
TOTAL_PODS=$(kubectl get pods -n kube-system --no-headers | wc -l)

echo "Pods en kube-system: $RUNNING_PODS/$TOTAL_PODS corriendo"

if [ "$RUNNING_PODS" -lt 3 ]; then
    echo "⚠ Menos de 3 pods corriendo (puede estar inicializando)"
    WARNINGS=$((WARNINGS + 1))
else
    echo "✓ Pods del sistema corriendo"
fi

kubectl get pods -n kube-system
echo ""

################################################################################
# 3. Verificar API Server
################################################################################

echo "[3/8] Verificando API Server..."
echo ""

if kubectl get componentstatuses >/dev/null 2>&1; then
    echo "✓ API Server respondiendo"
else
    echo "✗ API Server no responde"
    ERRORS=$((ERRORS + 1))
fi

echo ""

################################################################################
# 4. Verificar kubelet en cada nodo
################################################################################

echo "[4/8] Verificando kubelet..."
echo ""

for node in $(kubectl get nodes --no-headers | awk '{print $1}'); do
    STATUS=$(kubectl get node "$node" -o jsonpath='{.status.conditions[0].status}')
    if [ "$STATUS" = "True" ]; then
        echo "✓ Kubelet en $node: OK"
    else
        echo "✗ Kubelet en $node: PROBLEMA"
        ERRORS=$((ERRORS + 1))
    fi
done

echo ""

################################################################################
# 5. Verificar CNI (Flannel)
################################################################################

echo "[5/8] Verificando CNI (Flannel)..."
echo ""

FLANNEL_PODS=$(kubectl get pods -n kube-flannel --no-headers 2>/dev/null | grep -c "Running" || echo 0)

if [ "$FLANNEL_PODS" -gt 0 ]; then
    echo "✓ Flannel corriendo ($FLANNEL_PODS pods)"
else
    echo "⚠ Flannel no encontrado (usará CNI por defecto)"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""

################################################################################
# 6. Verificar servicios
################################################################################

echo "[6/8] Verificando servicios..."
echo ""

kubectl get svc -A --no-headers
echo ""

SERVICES=$(kubectl get svc -A --no-headers | wc -l)
if [ "$SERVICES" -gt 0 ]; then
    echo "✓ Servicios disponibles ($SERVICES)"
else
    echo "✗ No hay servicios"
    ERRORS=$((ERRORS + 1))
fi

echo ""

################################################################################
# 7. Verificar certifi...

cados
################################################################################

echo "[7/8] Verificando certificados..."
echo ""

# Verificar certificado del servidor
CERT_EXPIRY=$(sudo openssl x509 -in /var/lib/rancher/k3s/server/tls/server-crt.pem -noout -enddate 2>/dev/null | cut -d= -f2)

echo "Certificado del servidor expira: $CERT_EXPIRY"

if echo "$CERT_EXPIRY" | grep -q "2026\|2027\|2028"; then
    echo "✓ Certificados válidos"
else
    echo "⚠ Certificados podrían expirar pronto"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""

################################################################################
# 8. Verificar almacenamiento
################################################################################

echo "[8/8] Verificando almacenamiento..."
echo ""

kubectl get storageclass
echo ""

SC_COUNT=$(kubectl get storageclass --no-headers | wc -l)
if [ "$SC_COUNT" -gt 0 ]; then
    echo "✓ StorageClass disponible ($SC_COUNT)"
else
    echo "⚠ No hay StorageClass (necesaria para persistencia)"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""

################################################################################
# RESUMEN FINAL
################################################################################

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    RESUMEN DE VALIDACIÓN                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo "✓ CLUSTER EN BUEN ESTADO"
else
    echo "✗ CLUSTER CON ERRORES: $ERRORS"
fi

if [ $WARNINGS -gt 0 ]; then
    echo "⚠ ADVERTENCIAS: $WARNINGS"
fi

echo ""
echo "Estadísticas:"
echo "  Nodos: $NODES (Ready: $READY_NODES)"
echo "  Pods kube-system: $RUNNING_PODS/$TOTAL_PODS"
echo "  Servicios: $SERVICES"
echo "  StorageClass: $SC_COUNT"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo "¡Cluster listo para usar!"
    exit 0
else
    echo "Revisa los errores anteriores"
    exit 1
fi
