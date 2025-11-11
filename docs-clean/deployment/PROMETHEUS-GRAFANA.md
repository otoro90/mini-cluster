# 📊 Prometheus + Grafana

Monitoring y visualización del cluster.

---

## **¿Qué es?**

- **Prometheus**: Recolecta métricas del cluster
- **Grafana**: Visualiza gráficos y dashboards

### Qué monitoreamos

```
┌─────────────────────────────┐
│   Prometheus scrapes:       │
├─────────────────────────────┤
│ - kubelet en nodos          │ → CPU, RAM, red de pods
│ - kube-apiserver            │ → Requests a API
│ - etcd                       │ → Health de data store
│ - node-exporter             │ → CPU, RAM, disco del nodo
│ - kube-state-metrics        │ → Estado de Deployments, etc
└─────────────────────────────┘
           ↓
        Prometheus DB
           ↓
       (Queries PromQL)
           ↓
        Grafana Dashboards
```

---

## **Instalación**

### 1. Agregar repos

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

### 2. Crear namespace

```bash
kubectl create namespace monitoring
```

### 3. Instalar Prometheus

```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.retention=15d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.accessModes[0]=ReadWriteOnce \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=10Gi \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=longhorn \
  --set grafana.persistence.enabled=true \
  --set grafana.persistence.size=5Gi \
  --set grafana.persistence.storageClassName=longhorn \
  --set grafana.adminPassword=admin123 \
  --set prometheusOperator.manageCrds=true
```

Este comando instala:
- ✅ Prometheus (métricas)
- ✅ Grafana (visualización)
- ✅ AlertManager (alertas)
- ✅ node-exporter (métricas de nodos)
- ✅ kube-state-metrics (métricas de K8s)

### 4. Verificar

```bash
# Ver pods
kubectl get pods -n monitoring

# Esperar a que todos sean Running
kubectl rollout status statefulset/prometheus-kube-prometheus-prometheus -n monitoring

# Ver servicios
kubectl get svc -n monitoring
```

---

## **Acceder a Grafana**

### Port-forward

```bash
# Opción 1: Via kubectl
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Opción 2: Via service externo
kubectl patch svc prometheus-grafana -n monitoring -p '{"spec":{"type":"NodePort"}}'
kubectl get svc -n monitoring prometheus-grafana

# Ir a http://localhost:3000 (opción 1)
# O http://192.168.1.200:3XXXX (opción 2, ver puerto)
```

### Login

```
Usuario: admin
Contraseña: admin123 (la que configuramos)
```

### Cambiar contraseña

En Grafana:
1. Click en avatar (arriba derecha)
2. Profile
3. Change Password

---

## **Dashboards Predefinidos**

Grafana viene con dashboards listos:

1. **Kubernetes Cluster Monitoring**
   - Estado general del cluster
   - Nodos, pods, CPU, memoria

2. **Node Exporter for Prometheus**
   - Métricas de cada nodo

3. **Prometheus**
   - Health de Prometheus mismo

### Importar más dashboards

```
Dashboard → Import
Buscar "Kubernetes" en grafana.com/dashboards

Popular:
- 6417: Kubernetes Cluster Monitoring
- 1471: exporter-node
- 6781: Kubernetes Metrics (Advanced)
```

---

## **Crear Custom Dashboard**

### Ejemplo: CPU de nodos

```
1. Click "Create" → Dashboard → Add Panel
2. Query: node_cpu_seconds_total
3. Legend: {{instance}}
4. Title: "Node CPU Usage"
5. Save
```

### Queries PromQL (Prometheus Query Language)

```promql
# CPU del cluster
sum(rate(container_cpu_usage_seconds_total[5m]))

# Memoria usada
sum(container_memory_usage_bytes) / (1024^3)

# Pods activos por nodo
count(kube_pod_info) by (node)

# Pods en Pending
count(kube_pod_status_phase{phase="Pending"})
```

---

## **Alertas**

### Crear alerta en Prometheus

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: k8s-alerts
  namespace: monitoring
spec:
  groups:
  - name: k8s-alerts
    interval: 30s
    rules:
    - alert: HighMemoryUsage
      expr: |
        (sum(container_memory_usage_bytes) / sum(machine_memory_bytes)) > 0.85
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High memory usage detected"
        description: "Memory usage is above 85%"
    
    - alert: NodeNotReady
      expr: |
        kube_node_status_condition{condition="Ready",status="true"} == 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Node not ready"
```

### Alertas comunes

```
- Pod CrashLoopBackOff
- Node status NotReady
- Persistente volumen near full
- API latency alta
- etcd sync issues
```

---

## **Troubleshooting**

### Prometheus no scrape

```bash
# Ver targets
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Ir a http://localhost:9090/targets
# Ver si targets están "Up" o "Down"

# Si Down, ver logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus
```

### Grafana no muestra datos

```bash
# Verificar conexión a Prometheus
Grafana → Configuration → Data Sources
# Debería mostrar "Prometheus" como "green"

# Si está rojo, verificar URL
# Debería ser: http://prometheus-kube-prometheus-prometheus.monitoring:9090
```

### Alto consumo de disco

```bash
# Prometheus almacena métricas en disco
# Si se llena:

# Reducir retention
kubectl edit statefulset prometheus-kube-prometheus-prometheus -n monitoring

# Buscar: --storage.tsdb.retention.time=15d
# Cambiar a: 7d (o menos)

# Redeploy
kubectl rollout restart statefulset/prometheus-kube-prometheus-prometheus -n monitoring
```

### AlertManager no envía alertas

```bash
# Configurar canales (email, Slack, etc)

# En AlertManager config
kubectl edit secret alertmanager-kube-prometheus-alertmanager -n monitoring

# Agregar config para Slack, PagerDuty, etc
# Documentación: https://prometheus.io/docs/alerting/latest/configuration/
```

---

## **Exportar Métricas**

### Descargar datos

```
Grafana → Panel → More options → Export data
```

### APIs

```bash
# Query Prometheus directamente
curl 'http://192.168.1.200:9090/api/v1/query?query=up'

# Scrape targets
curl 'http://192.168.1.200:9090/api/v1/targets'

# Series metadata
curl 'http://192.168.1.200:9090/api/v1/label/__name__/values'
```

---

## **Performance con Recursos Limitados**

Para ARM64 con RAM limitada:

```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.retention=7d \
  --set prometheus.prometheusSpec.resources.limits.memory=512Mi \
  --set prometheus.prometheusSpec.resources.limits.cpu=500m \
  --set grafana.resources.limits.memory=256Mi \
  --set grafana.resources.limits.cpu=250m \
  --set alertmanager.resources.limits.memory=128Mi \
  ... (resto de flags)
```

---

## **PromQL Queries (Referencia)**

```promql
# Nodos disponibles
count(kube_node_status_condition{condition="Ready",status="true"})

# Pods en error
count(kube_pod_status_phase{phase!~"Running|Succeeded"})

# Disk usage por nodo
node_filesystem_size_bytes{fstype!~"tmpfs|fuse.lowerfs|squashfs|vfat"} - node_filesystem_avail_bytes

# Network IO (bytes/s)
rate(node_network_receive_bytes_total[5m])

# API latency
histogram_quantile(0.99, rate(apiserver_request_duration_seconds_bucket[5m]))
```

---

## **Próximos Pasos**

1. ✅ Prometheus + Grafana instalados
2. ⏳ Configurar alertas personalizadas
3. ⏳ Instalar PostgreSQL + Keycloak (aplicaciones)

Lee: `../deployment/POSTGRESQL-KEYCLOAK.md`

