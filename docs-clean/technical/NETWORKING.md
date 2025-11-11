# 🌐 Redes en K3s

Cómo funciona la conectividad de pods y servicios.

---

## **CNI: Container Network Interface**

K3s usa **Flannel** por defecto (ligero, simple).

```bash
# Ver CNI instalado
kubectl get daemonset -n kube-system

# Debería mostrar: coredns y flannel-xxx
```

---

## **3 Tipos de Redes en K3s**

### 1. Pod Network (192.168.0.0/16)

Red donde **viven los pods**.

```
Master Node (192.168.1.254)
├─ Pod A (192.168.0.10)
├─ Pod B (192.168.0.11)
└─ Pod C (192.168.0.12)

Worker Node (192.168.1.250)
├─ Pod X (192.168.0.20)
├─ Pod Y (192.168.0.21)
└─ Pod Z (192.168.0.22)
```

- Rango asignado por Flannel automáticamente
- Cada pod obtiene una IP de este rango
- **Pods pueden comunicarse entre nodos** (Flannel encapsula tráfico)

---

### 2. Service Network (10.43.0.0/16)

Red **virtual** donde viven los servicios (no son reales).

```bash
# Crear un service
kubectl expose deployment nginx --port=80 --type=ClusterIP

# Obtiene IP como 10.43.0.45
# Pero NO es real - solo es un "punto de entrada"

# Internamente, kube-proxy redirige ese tráfico a los pods
```

Tipos de Services:

| Tipo | Acceso | Uso |
|---|---|---|
| **ClusterIP** | Solo interno | Apps internas |
| **NodePort** | Externa (Puerto en nodo) | Acceso externo simple |
| **LoadBalancer** | Externa (LB) | Producción |
| **ExternalName** | Maps a hostname | DNS externo |

---

### 3. Host Network

Red del dispositivo físico (192.168.1.0/24).

```bash
# Ver IPs
ifconfig
# o
ip addr

# Master: eth0 = 192.168.1.254
# Worker: eth0 = 192.168.1.250
```

---

## **Conectividad Entre Pods**

### Mismo nodo

```
Pod A (192.168.0.10) ──> Pod B (192.168.0.11)
           ↓
      (local bridge cbr0)
           ↓
      Comunicación DIRECTA
```

### Diferentes nodos

```
Pod A en Master (192.168.0.10)
           ↓
    Flannel en Master
    ├─> Encapsula paquete
    └─> Envía a Worker (192.168.1.250)
           ↓
    Flannel en Worker
    ├─> Desencapsula
    └─> Entrega a Pod Z (192.168.0.20)
```

Flannel usa **VXLAN** (Virtual Extensible LAN) para esto.

---

## **Conectividad de Servicios**

### Dentro del cluster

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: app
        image: myapp:latest
        ports:
        - containerPort: 3000
---
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
spec:
  selector:
    app: backend
  ports:
  - port: 8080
    targetPort: 3000
  type: ClusterIP
```

Uso desde otro pod:

```bash
# URL: http://[service-name].[namespace].svc.cluster.local:[port]
# En el mismo namespace: http://backend-svc:8080

# Otros pods pueden hacer:
curl http://backend-svc:8080/api/data
```

---

### Desde internet

Necesitas **Ingress**:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
spec:
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: backend-svc
            port:
              number: 8080
```

Luego:

```bash
# En tu PC
# Editar C:\Windows\System32\drivers\etc\hosts
# Agregar:
192.168.1.254 myapp.local

# Abrir navegador
http://myapp.local
```

---

## **DNS en K3s**

K3s incluye **CoreDNS** (reemplaza dnsmasq):

```bash
# Ver CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Ver que resuelve
kubectl exec -it <pod-name> -- nslookup kubernetes.default
```

Nombres especiales:

```
kubernetes          = API Server del cluster
kubernetes.default  = En namespace 'default'
service.namespace   = Cualquier servicio
```

---

## **DNS Externo**

Pods acceden a DNS externo automáticamente:

```bash
# Desde un pod
nslookup google.com

# Resolverá a través de /etc/resolv.conf del nodo:
nameserver 8.8.8.8
nameserver 1.1.1.1
```

---

## **Network Policies (Seguridad)**

Controlar tráfico entre pods:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  # Esto NIEGA todo tráfico entrante

---
# Permitir solo desde specific label
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-frontend
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 3000
```

⚠️ **Nota**: Flannel + Network Policies requieren plugin adicional. Cilium (veremos después) lo incluye.

---

## **Troubleshooting de Red**

### Verificar conectividad de pod

```bash
# Ver pods
kubectl get pods

# Conectar a un pod
kubectl exec -it <pod-name> -- bash

# Dentro del pod:
ping 8.8.8.8                        # Internet
nslookup google.com                 # DNS
curl http://backend-svc:8080        # Otro servicio
```

### Ver rutas de red

```bash
# En master
ip route

# En worker
ip route

# Debería mostrar rutas a través de eth0 y vxlan0 (Flannel)
```

### Ver interfaces de red

```bash
ip link show

# Debería haber:
# eth0      = Red física
# cbr0      = Bridge para pods
# vxlan0    = Túnel VXLAN de Flannel
# flannel.1 = Interfaz de Flannel
```

### Ver logs de Flannel

```bash
kubectl logs -n kube-system -l app=flannel

# O en el nodo:
sudo journalctl -u k3s-agent.service -f | grep flannel
```

---

## **Mejorar Red: Cilium (Opcional)**

Cilium es un CNI moderno que reemplaza a Flannel:

**Ventajas:**
- ✅ eBPF-based (más eficiente)
- ✅ Incluye Network Policies
- ✅ Mejor debugging
- ✅ Load balancing avanzado

Veremos instalación en: `../deployment/CILIUM-CNI.md`

---

## **Puertos Abiertos para Flannel**

Asegúrate que estos puertos estén disponibles entre nodos:

| Puerto | Protocolo | Uso |
|---|---|---|
| 8472 | UDP | VXLAN (Flannel) |
| 6783 | TCP/UDP | Flannel control |

```bash
# Ver puertos escuchando
sudo ss -tlnp
```

---

## 📖 Siguiente

Lee: `../technical/STORAGE.md` para almacenamiento.

