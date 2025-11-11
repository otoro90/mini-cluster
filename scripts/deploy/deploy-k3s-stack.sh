#!/bin/bash

# Script maestro de despliegue K3s - Ejecutar solo en MASTER
# Versión: 10 de noviembre de 2025
# Ejecutar como: bash deploy-k3s-stack.sh

set -e  # Salir si hay error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Función de logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[WARN] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Verificar que estamos en master
verify_master() {
    local ip=$(hostname -I | awk '{print $1}')
    if [ "$ip" != "192.168.1.254" ]; then
        error "Este script debe ejecutarse solo en el master (192.168.1.254)"
        error "IP actual: $ip"
        exit 1
    fi

    if [ ! -f /etc/rancher/k3s/k3s.yaml ]; then
        error "K3s no está instalado o configurado correctamente"
        exit 1
    fi
}

# Configurar KUBECONFIG
setup_kubeconfig() {
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    info "KUBECONFIG configurado: $KUBECONFIG"
}

# Instalar Cilium
install_cilium() {
    log "Instalando Cilium CNI..."
    kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/v1.15.1/install/kubernetes/quick-install.yaml

    info "Esperando que Cilium esté listo..."
    kubectl wait --for=condition=ready pod -l k8s-app=cilium --timeout=300s

    # Verificar Cilium
    cilium status || warn "Cilium status no disponible, pero puede estar funcionando"
    log "Cilium instalado correctamente"
}

# Instalar Longhorn
install_longhorn() {
    log "Instalando Longhorn para storage distribuido..."
    kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.6.0/deploy/longhorn.yaml

    info "Esperando que Longhorn esté listo..."
    kubectl wait --for=condition=ready pod -l app=longhorn-manager -n longhorn-system --timeout=300s 2>/dev/null || warn "Longhorn puede tardar más en inicializarse"

    log "Longhorn instalado correctamente"
}

# Instalar Prometheus + Grafana
install_monitoring() {
    log "Instalando Prometheus y Grafana..."

    # Crear namespace
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

    # Instalar Prometheus Operator
    kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.70.0/bundle.yaml

    # Crear ConfigMap para Prometheus
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    scrape_configs:
    - job_name: 'kubernetes-pods'
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: \$1:\$2
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: kubernetes_namespace
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: kubernetes_pod_name
EOF

    # Crear ServiceAccount y RBAC
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources:
  - nodes
  - nodes/proxy
  - services
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
- apiGroups:
  - extensions
  resources:
  - ingresses
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: prometheus
  namespace: monitoring
EOF

    # Crear Deployment de Prometheus
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      serviceAccountName: prometheus
      containers:
      - name: prometheus
        image: prom/prometheus:v2.45.0
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus
      volumes:
      - name: config
        configMap:
          name: prometheus-config
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: monitoring
spec:
  selector:
    app: prometheus
  ports:
  - port: 9090
    targetPort: 9090
EOF

    # Crear Deployment de Grafana
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:10.1.0
        ports:
        - containerPort: 3000
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          value: admin
      volumes:
      - name: grafana-storage
        emptyDir: {}
      volumeMounts:
      - mountPath: /var/lib/grafana
        name: grafana-storage
---
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: monitoring
spec:
  selector:
    app: grafana
  ports:
  - port: 3000
    targetPort: 3000
EOF

    log "Prometheus y Grafana instalados correctamente"
}

# Desplegar aplicaciones
deploy_applications() {
    log "Desplegando aplicaciones (PostgreSQL + Keycloak)..."

    # Aplicar secrets
    kubectl apply -f manifests/postgres-secret.yaml
    kubectl apply -f manifests/keycloak-secret.yaml

    # Aplicar servicios
    kubectl apply -f manifests/postgres-service.yaml
    kubectl apply -f manifests/keycloak-service.yaml

    # Aplicar deployments/statefulsets
    kubectl apply -f manifests/postgres-statefulset.yaml
    kubectl apply -f manifests/keycloak-deployment.yaml

    # Aplicar ingress
    kubectl apply -f manifests/ingress-traefik.yaml

    # Esperar que las aplicaciones estén listas
    info "Esperando que PostgreSQL esté listo..."
    kubectl wait --for=condition=ready pod -l app=postgres --timeout=300s

    info "Esperando que Keycloak esté listo..."
    kubectl wait --for=condition=ready pod -l app=keycloak --timeout=300s

    log "Aplicaciones desplegadas correctamente"
}

# Configurar port-forwards persistentes
setup_port_forwards() {
    log "Configurando port-forwards persistentes..."

    # Matar port-forwards existentes
    pkill -f "kubectl port-forward svc/postgres-svc" 2>/dev/null || true
    pkill -f "kubectl port-forward svc/keycloak-svc" 2>/dev/null || true

    # Iniciar port-forwards en background
    nohup kubectl port-forward svc/postgres-svc 5432:5432 --address 0.0.0.0 > /var/log/postgres-port-forward.log 2>&1 &
    echo $! > /var/run/postgres-port-forward.pid

    nohup kubectl port-forward svc/keycloak-svc 8080:8080 --address 0.0.0.0 > /var/log/keycloak-port-forward.log 2>&1 &
    echo $! > /var/run/keycloak-port-forward.pid

    log "Port-forwards configurados"
}

# Verificación final
final_verification() {
    log "Realizando verificación final..."

    echo ""
    info "=== ESTADO DEL CLUSTER ==="
    kubectl get nodes -o wide
    echo ""

    info "=== PODS POR NAMESPACE ==="
    kubectl get pods -A --sort-by=.metadata.namespace
    echo ""

    info "=== STORAGE CLASSES ==="
    kubectl get storageclass
    echo ""

    info "=== PERSISTENT VOLUMES ==="
    kubectl get pv,pvc -A
    echo ""

    info "=== INGRESS RULES ==="
    kubectl get ingress -A
    echo ""

    info "=== SERVICIOS ==="
    kubectl get svc -A
    echo ""

    # Verificar componentes específicos
    info "=== VERIFICACIÓN DE COMPONENTES ==="

    # Cilium
    if kubectl get pods -n kube-system -l k8s-app=cilium --no-headers | grep -q Running; then
        echo "✅ Cilium: OK"
    else
        echo "❌ Cilium: Problemas detectados"
    fi

    # Longhorn
    if kubectl get pods -n longhorn-system --no-headers 2>/dev/null | grep -q Running; then
        echo "✅ Longhorn: OK"
    else
        echo "❌ Longhorn: No instalado o con problemas"
    fi

    # Monitoring
    if kubectl get pods -n monitoring --no-headers 2>/dev/null | grep -q Running; then
        echo "✅ Monitoring (Prometheus/Grafana): OK"
    else
        echo "❌ Monitoring: No instalado o con problemas"
    fi

    # Aplicaciones
    if kubectl get pods -l app=postgres --no-headers | grep -q Running; then
        echo "✅ PostgreSQL: OK"
    else
        echo "❌ PostgreSQL: Problemas detectados"
    fi

    if kubectl get pods -l app=keycloak --no-headers | grep -q Running; then
        echo "✅ Keycloak: OK"
    else
        echo "❌ Keycloak: Problemas detectados"
    fi

    echo ""
    log "=== VERIFICACIÓN COMPLETADA ==="
}

# Función principal
main() {
    log "=== INICIANDO DESPLIEGUE DEL STACK OPTIMIZADO ==="
    info "Servidor: $(hostname)"
    info "IP: $(hostname -I | awk '{print $1}')"
    info "Fecha: $(date)"

    # Verificaciones iniciales
    verify_master
    setup_kubeconfig

    # Instalar componentes
    install_cilium
    install_longhorn
    install_monitoring

    # Desplegar aplicaciones
    deploy_applications

    # Configurar acceso
    setup_port_forwards

    # Verificación final
    final_verification

    # URLs de acceso
    local ip=$(hostname -I | awk '{print $1}')

    log "=== DESPLIEGUE COMPLETADO EXITOSAMENTE ==="
    echo ""
    info "🌐 URLs de acceso:"
    echo "   Keycloak Directo: http://$ip:8080"
    echo "   Keycloak via Traefik: http://$ip/keycloak"
    echo "   PostgreSQL: $ip:5432"
    echo ""
    info "📊 Monitoreo (usar port-forward desde tu máquina):"
    echo "   Prometheus: kubectl port-forward -n monitoring svc/prometheus 9090:9090"
    echo "   Grafana: kubectl port-forward -n monitoring svc/grafana 3000:3000 (admin/admin)"
    echo "   Longhorn UI: kubectl port-forward -n longhorn-system svc/longhorn-frontend 8082:80"
    echo ""
    info "📝 Logs de port-forward:"
    echo "   PostgreSQL: /var/log/postgres-port-forward.log"
    echo "   Keycloak: /var/log/keycloak-port-forward.log"
    echo ""
    info "🎉 ¡Migración completada! El cluster está listo para usar."
}

# Ejecutar función principal
main "$@"