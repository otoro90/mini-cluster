f# 🔵 Cilium CNI

Reemplazar Flannel con Cilium para mejor seguridad y observabilidad.

---

## **¿Qué es Cilium?**

CNI moderno que reemplaza Flannel:

- ✅ eBPF-based (kernel level, muy eficiente)
- ✅ Network Policies funcionales
- ✅ Observabilidad (ver qué se comunica)
- ✅ Load balancing avanzado
- ✅ Seguridad (encryption, isolation)

---

## **Antes de Instalar**

### Verificar que Flannel no interfiera

```bash
# Ver CNI actual
kubectl get daemonset -n kube-system

# Si ves flannel, Cilium debería reemplazarlo automáticamente
```

---

## **Instalación con Helm**

### 1. Instalar Helm (si no tienes)

```bash
# En tu PC
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verificar
helm version
```

### 2. Agregar repositorio de Cilium

```bash
helm repo add cilium https://helm.cilium.io
helm repo update
```

### 3. Instalar Cilium

```bash
helm install cilium cilium/cilium \
  --namespace kube-system \
  --set nodePort.enabled=true \
  --set kubeProxyReplacement=partial \
  --set k8sServiceHost=192.168.1.254 \
  --set k8sServicePort=6443 \
  --set containerRuntime.integration=containerd \
  --set bpf.masquerade=true \
  --set encryption.enabled=true \
  --set encryption.type=ipsec \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true
```

### 4. Verificar instalación

```bash
# Ver pods
kubectl get pods -n kube-system -l k8s-app=cilium

# Debería mostrar cilium-xxxxx en todos los nodos

# Esperar a que todos estén Ready (puede tomar 2-3 minutos)
kubectl rollout status daemonset/cilium -n kube-system

# Verificar estado
kubectl -n kube-system exec cilium-XXXXX -- cilium status

# Debe mostrar
# Status:     OK

# Hubble UI (observabilidad)
kubectl get pods -n kube-system | grep hubble
```

---

## **Usar Cilium**

### Verificar que funciona

```bash
# Crear deployments
kubectl apply -f - << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-a
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-a
  template:
    metadata:
      labels:
        app: app-a
    spec:
      containers:
      - name: app
        image: busybox
        command: ["sleep", "1000"]

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-b
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-b
  template:
    metadata:
      labels:
        app: app-b
    spec:
      containers:
      - name: app
        image: busybox
        command: ["sleep", "1000"]

---
apiVersion: v1
kind: Service
metadata:
  name: app-b-svc
spec:
  selector:
    app: app-b
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
EOF

# Verificar
kubectl get pods
```

### Network Policy (Ahora funciona con Cilium)

```bash
# Denegar TODO tráfico por defecto
kubectl apply -f - << 'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
EOF

# Permitir solo desde app-a a app-b
kubectl apply -f - << 'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-app-a-to-app-b
spec:
  podSelector:
    matchLabels:
      app: app-b
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: app-a
EOF

# Probar
kubectl exec -it deployment/app-a -- wget -O- http://app-b-svc

# Debe funcionar (permitida)

# Ahora denegar
kubectl exec -it deployment/app-b -- wget -O- http://169.254.169.254
# Debería fallar (denegada)
```

---

## **Hubble UI (Observabilidad)**

Ver qué pods se comunican.

### Acceder a Hubble

```bash
# Port-forward
kubectl port-forward -n kube-system svc/hubble-ui 8081:80

# En tu navegador
# http://localhost:8081
```

Verás:
- Nodos del cluster
- Pods comunicándose
- Conexiones permitidas/denegadas
- Flujo de tráfico en tiempo real

### Ejemplos

```bash
# Ver conectividad
kubectl exec -it deployment/app-a -- ping deployment/app-b

# En Hubble UI verás la conexión

# Aplicar policy
kubectl apply -f networkpolicy.yaml

# En Hubble UI verás que la conexión se deniega
```

---

## **Cilium CLI (Opcional)**

Más control desde línea de comando.

### Instalar

```bash
curl -L https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz | tar xz
sudo mv cilium /usr/local/bin/
```

### Usar

```bash
# Ver estado
cilium status

# Ver policies
cilium policy ls

# Ver conectividad
cilium connectivity test

# Ver logs
cilium logs
```

---

## **Configuración Avanzada**

### Encryption (IPSec)

```bash
# Ya instalado con --set encryption.enabled=true

# Verificar
kubectl exec -n kube-system cilium-XXXXX -- cilium encrypt status
```

### Load Balancing

Cilium reemplaza kube-proxy para mejor performance:

```bash
# Ya incluido con kubeProxyReplacement=partial
```

### DNS Filtering

Controlar qué dominios pueden acceder los pods:

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-dns-only-google
spec:
  endpointSelector:
    matchLabels:
      app: restricted
  egressDeny:
  - toFQDNs:
    - matchName: google.com
```

---

## **Troubleshooting de Cilium**

### Cilium no inicia

```bash
# Ver logs
kubectl logs -n kube-system -l k8s-app=cilium -f

# Ver si hay conflicto con otra CNI
kubectl get daemonset -n kube-system

# Eliminar Flannel si sigue activa
kubectl delete daemonset -n kube-system kube-flannel-ds
```

### Network Policy no funciona

```bash
# Verificar que cilium esté funcionando
kubectl exec -n kube-system cilium-XXXXX -- cilium status

# Ver policies aplicadas
kubectl exec -n kube-system cilium-XXXXX -- cilium policy ls

# Debug de una connection
kubectl exec -n kube-system cilium-XXXXX -- cilium dbg endpoint list
```

### Alto consumo de CPU

```bash
# Cilium usa eBPF (kernel), no debería consumir mucho
# Pero si lo hace:

# Ver CPU usage
kubectl top pod -n kube-system -l k8s-app=cilium

# Reducir verbosity
kubectl set env daemonset/cilium -n kube-system LOG_LEVEL=info
```

---

## **Desinstalar Cilium (si necesario)**

```bash
# No recomendado, pero si:
helm uninstall cilium -n kube-system

# Flannel se reinstalará automáticamente
```

---

## **Comparación: Flannel vs Cilium**

| Feature | Flannel | Cilium |
|---|---|---|
| **Simplicidad** | ✅ Muy simple | ✅ Compleja pero potente |
| **Network Policies** | ❌ NO | ✅ SÍ |
| **Encryption** | ❌ NO | ✅ IPSec, mTLS |
| **Observabilidad** | ❌ NO | ✅ Hubble |
| **Performance** | ✅ Bueno | ✅✅ Excelente (eBPF) |
| **Resource Usage** | ✅ Bajo | ✅ Bajo (eBPF) |
| **Load Balancing** | ❌ kube-proxy | ✅ Nativo |

---

## **Próximos Pasos**

1. ✅ Cilium instalado
2. ⏳ Network Policies funcionando (verifica con Hubble UI)
3. ⏳ Instalar Longhorn para storage distribuido

Lee: `../deployment/LONGHORN-STORAGE.md`

