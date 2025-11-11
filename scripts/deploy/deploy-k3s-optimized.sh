#!/bin/bash

# Script de despliegue optimizado para mini-cluster K3s ARM64
# Fecha: 10 de noviembre de 2025
# Mejoras: K3s, Cilium, Longhorn, Traefik, Prometheus

echo "🚀 Iniciando despliegue optimizado del mini-cluster K3s..."

# Configurar KUBECONFIG para K3s
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "📦 Instalando componentes optimizados..."

# Instalar Cilium (mejor CNI que Calico)
echo "🔗 Instalando Cilium CNI..."
kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/v1.15.1/install/kubernetes/quick-install.yaml

# Esperar a que Cilium esté listo
kubectl wait --for=condition=ready pod -l k8s-app=cilium --timeout=300s

# Instalar Longhorn (storage distribuido)
echo "💾 Instalando Longhorn para storage HA..."
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.6.0/deploy/longhorn.yaml

# Instalar Prometheus + Grafana
echo "📊 Instalando Prometheus y Grafana..."
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.70.0/bundle.yaml

# Crear namespace para monitoring
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Instalar Prometheus
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
---
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
        replacement: $1:$2
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: kubernetes_namespace
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: kubernetes_pod_name
---
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
---
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

echo "📦 Aplicando manifests de aplicación..."

# Aplicar secrets
kubectl apply -f manifests/postgres-secret.yaml
kubectl apply -f manifests/keycloak-secret.yaml

# Aplicar servicios
kubectl apply -f manifests/postgres-service.yaml
kubectl apply -f manifests/keycloak-service.yaml

# Aplicar deployments/statefulsets
kubectl apply -f manifests/postgres-statefulset.yaml
kubectl apply -f manifests/keycloak-deployment.yaml

# K3s incluye Traefik por defecto, aplicar ingress
kubectl apply -f manifests/ingress.yaml

echo "⏳ Esperando que los deployments estén listos..."

# Esperar a que keycloak esté listo
kubectl wait --for=condition=ready pod -l app=keycloak --timeout=300s

# Esperar a que PostgreSQL esté listo
kubectl wait --for=condition=ready pod -l app=postgres --timeout=300s

echo "🔗 Iniciando port-forwards persistentes..."

# Matar port-forwards existentes
pkill -f "kubectl port-forward svc/postgres-svc" || true
pkill -f "kubectl port-forward svc/keycloak-svc" || true

# Iniciar port-forwards en background
nohup kubectl port-forward svc/postgres-svc 5432:5432 --address 0.0.0.0 > /var/log/postgres-port-forward.log 2>&1 &
echo $! > /var/run/postgres-port-forward.pid

nohup kubectl port-forward svc/keycloak-svc 8080:8080 --address 0.0.0.0 > /var/log/keycloak-port-forward.log 2>&1 &
echo $! > /var/run/keycloak-port-forward.pid

echo "✅ Verificando estado final..."

# Verificar estado
kubectl get pods -A
kubectl get svc -A

echo ""
echo "🎉 Despliegue optimizado completado!"
echo "📊 PostgreSQL: $(hostname -I | awk '{print $1}'):5432"
echo "🔐 Keycloak: http://$(hostname -I | awk '{print $1}'):8080"
echo "   Usuario: admin"
echo "   Password: admin"
echo ""
echo "🌐 Acceso via Traefik:"
echo "   Keycloak: http://$(hostname -I | awk '{print $1}')/keycloak"
echo ""
echo "📈 Monitoreo (usar port-forward):"
echo "   kubectl port-forward -n monitoring svc/prometheus 9090:9090"
echo "   kubectl port-forward -n monitoring svc/grafana 3000:3000"
echo "   Prometheus: http://localhost:9090"
echo "   Grafana: http://localhost:3000 (admin/admin)"
echo ""
echo "💾 Longhorn UI (usar port-forward):"
echo "   kubectl port-forward -n longhorn-system svc/longhorn-frontend 8082:80"
echo "   Longhorn UI: http://localhost:8082"
echo ""
echo "📝 Logs de port-forward:"
echo "   PostgreSQL: /var/log/postgres-port-forward.log"
echo "   Keycloak: /var/log/keycloak-port-forward.log"