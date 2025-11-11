# 🏗️ Arquitectura de K3s

Explicación técnica de cómo funciona K3s.

---

## **¿Qué es K3s?**

**Kubernetes Ligero**: Distribución oficial de K8s optimizada para:
- ✅ Bajo consumo de recursos (RAM, CPU)
- ✅ Rápida instalación (< 5 minutos)
- ✅ ARM64 compatible (Raspberry Pi, Orange Pi)
- ✅ Minimal pero completo

---

## **Componentes Principales**

```
┌─────────────────────────────────────────────────────┐
│           K3S Master (Orange Pi)                    │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌──────────────────────────────────────────────┐  │
│  │         API Server (puerto 6443)             │  │
│  │  ↳ Centro de control del cluster             │  │
│  │  ↳ Recibe comandos kubectl                   │  │
│  └──────────────────────────────────────────────┘  │
│                        ↓                            │
│  ┌──────────────────────────────────────────────┐  │
│  │    etcd (base de datos embebida)             │  │
│  │  ↳ Almacena estado del cluster               │  │
│  │  ↳ Replicado en workers                      │  │
│  └──────────────────────────────────────────────┘  │
│                        ↓                            │
│  ┌──────────────────────────────────────────────┐  │
│  │  Controller Manager + Scheduler              │  │
│  │  ↳ Gestiona réplicas de pods                 │  │
│  │  ↳ Asigna pods a nodos                       │  │
│  └──────────────────────────────────────────────┘  │
│                                                     │
│  + kube-proxy, CNI (Flannel), coredns              │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│        K3S Agent (Raspberry Pi Worker)              │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌──────────────────────────────────────────────┐  │
│  │    Kubelet (puerto 10250)                    │  │
│  │  ↳ Ejecuta pods en este nodo                 │  │
│  │  ↳ Reporta estado al master                  │  │
│  └──────────────────────────────────────────────┘  │
│                        ↓                            │
│  ┌──────────────────────────────────────────────┐  │
│  │  Container Runtime (containerd)              │  │
│  │  ↳ Ejecuta contenedores realmente            │  │
│  │  ↳ No USA Docker (más ligero)                │  │
│  └──────────────────────────────────────────────┘  │
│                                                     │
│  + kube-proxy, CNI, metrics-server                │
└─────────────────────────────────────────────────────┘
```

---

## **Flujo de Creación de un Pod**

```
1. Usuario en PC
   └─> kubectl apply -f deployment.yaml
   
2. Se envía al API Server (Master)
   ├─> Valida el YAML
   ├─> Lo guarda en etcd
   └─> Notifica a Controller Manager

3. Controller Manager (Master)
   ├─> Ve que se necesitan 3 replicas
   └─> Crea 3 objetos Pod

4. Scheduler (Master)
   ├─> Ve 3 pods sin asignar
   ├─> Elige qué nodo para cada uno
   └─> Marca: "este pod va al worker"

5. Kubelet en Worker
   ├─> Ve que se le asignó un pod
   ├─> Descarga imagen del contenedor
   ├─> Crea contenedor vía containerd
   └─> Informa "Pod Running"

6. kube-proxy en Worker
   ├─> Ve servicios asociados
   ├─> Configura iptables
   └─> Tráfico llega al pod correctamente
```

---

## **Diferencias K3s vs K8s Completo**

| Aspecto | K3s | K8s Completo |
|---|---|---|
| **Tamaño** | ~40 MB | ~1 GB |
| **RAM Mínima** | 256 MB | 2 GB |
| **Instalación** | 1 comando | Compleja |
| **CNI** | Flannel (integrado) | Elegir plugin |
| **Almacenamiento** | Soporte local | Múltiples opciones |
| **Container Runtime** | containerd | Docker o CRI-O |

---

## **Puertos Utilizados**

### Master (192.168.1.200)

| Puerto | Protocolo | Servicio |
|---|---|---|
| 6443 | TCP | API Server |
| 10250 | TCP | Kubelet API |
| 10259 | TCP | Scheduler |
| 10257 | TCP | Controller Manager |
| 2379-2380 | TCP | etcd |

### Worker (192.168.1.100)

| Puerto | Protocolo | Servicio |
|---|---|---|
| 10250 | TCP | Kubelet API |
| 6783 | TCP/UDP | Flannel VXLAN |

---

## **Namespaces (Separación Lógica)**

K3s agrupa pods por **namespace**:

```bash
# Namespaces por defecto
kube-system       # Componentes de K3s (coredns, flannel, etc)
kube-public       # Recursos públicos (no muchos)
kube-node-lease   # Health checks entre nodos
default           # Donde van tus aplicaciones por defecto
```

Ver pods:

```bash
kubectl get pods -A              # Todos en todos los namespaces
kubectl get pods -n kube-system  # Solo en kube-system
kubectl get pods                 # Solo en 'default'
```

---

## **Objetos Principales**

### Pod

Unidad básica. Ejecuta 1+ contenedores.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mi-pod
spec:
  containers:
  - name: app
    image: nginx:latest
    ports:
    - containerPort: 80
```

### Deployment

Gestiona réplicas de pods.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 3  # ← 3 copias del pod
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
```

### Service

Expone pods a la red.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-svc
spec:
  type: ClusterIP  # Interno solamente
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
```

### Ingress

Expone servicios a internet.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
spec:
  rules:
  - host: nginx.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-svc
            port:
              number: 80
```

---

## **StorageClass (Almacenamiento)**

Define cómo K3s gestiona datos persistentes.

K3s por defecto tiene: `local-path`

```bash
# Ver storage classes
kubectl get storageclass

# Crear PersistentVolumeClaim
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pvc
spec:
  storageClassName: local-path
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

(Más adelante instalaremos **Longhorn** para mejorar almacenamiento distribuido)

---

## **RBAC (Control de Acceso)**

K3s incluye RBAC por defecto:

```bash
# Ver roles
kubectl get roles -A

# Ver role bindings
kubectl get rolebindings -A

# Tu usuario normalmente es 'admin' en namespace 'default'
```

---

## **Monitoring**

K3s viene con **metrics-server** integrado:

```bash
# Ver uso de recursos
kubectl top nodes
kubectl top pods -A

# O crear Prometheus+Grafana (veremos después)
```

---

## **Control del Cluster**

### Master controla Workers

Master **NO ejecuta** tus pods (a menos que lo específiques).

```bash
# Ver nodos disponibles
kubectl get nodes

# Ver taints (restricciones)
kubectl describe node <node-name>

# El master típicamente tiene taint "control-plane:NoSchedule"
# Esto evita que se ejecuten apps en master (solo sistema)
```

---

## **Upgrades y Updates**

K3s facilita actualizar versiones:

```bash
# En master
sudo systemctl stop k3s
curl -sfL https://get.k3s.io | K3S_VERSION=v1.33.5+k3s1 sh -

# En worker
sudo systemctl stop k3s-agent
curl -sfL https://get.k3s.io | K3S_VERSION=v1.33.5+k3s1 K3S_URL=https://192.168.1.200:6443 K3S_TOKEN=<token> sh -
```

---

## 📖 Siguiente

Lee: `../technical/NETWORKING.md` para detalles de red.

