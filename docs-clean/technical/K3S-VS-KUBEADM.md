# ⚖️ K3s vs Kubeadm

Comparación entre instalaciones.

---

## **¿Por qué migramos de Kubeadm a K3s?**

Decisión estratégica después de encontrar problemas en la migración.

---

## **Kubeadm (Lo Anterior)**

### Características

| Aspecto | Kubeadm |
|---|---|
| **Qué es** | Herramienta para bootstrappear K8s |
| **Instalación** | Manual: componentes separados |
| **Componentes** | kubelet, kube-proxy, etcd, apiserver, controller-manager, scheduler (todo separado) |
| **Tamaño** | ~1 GB |
| **RAM Mínima** | 2 GB |
| **CNI** | NO incluido - debes elegir (Flannel, Weave, Cilium, etc) |
| **Container Runtime** | Debes instalar Docker / containerd |
| **Distribución** | Upstream puro (difícil en ARM) |
| **Complexidad** | Alta - muchos pasos |

### Instalación Kubeadm

```bash
# 1. Instalar dependencias
sudo apt install -y kubelet kubeadm kubectl

# 2. Inicializar master
sudo kubeadm init --pod-network-cidr=192.168.0.0/16

# 3. Copiar kubeconfig
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config

# 4. Instalar CNI
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# 5. Generar token para workers
sudo kubeadm token create --print-join-command

# 6. En workers
sudo kubeadm join --token [token] --discovery-token-ca-cert-hash [hash]
```

### Problemas que Encontramos

1. **CA Hash Mismatch**: Token viejo causaba que worker no se conectara
2. **Networking Issues**: Ping bloqueaba interface entera
3. **Residuos Post-Install**: Difícil limpiar completamente kubeadm
4. **ARM64 Incompatibilidades**: Algunos componentes no funcionaban bien
5. **Complexity**: Demasiados pasos, demasiadas cosas que podían fallar

---

## **K3s (Actual)**

### Características

| Aspecto | K3s |
|---|---|
| **Qué es** | Distribución ligera de Kubernetes |
| **Instalación** | Un comando (curl) |
| **Componentes** | TODO integrado en un binario único |
| **Tamaño** | ~40 MB |
| **RAM Mínima** | 256 MB |
| **CNI** | Flannel integrado por defecto |
| **Container Runtime** | containerd integrado (ligero) |
| **Distribución** | Optimizada para ARM (oficial) |
| **Complexidad** | Muy baja - 1 comando por nodo |

### Instalación K3s

```bash
# Master
curl -sfL https://get.k3s.io | sh -

# Workers
curl -sfL https://get.k3s.io | K3S_TOKEN=[token] K3S_URL=https://master:6443 sh -
```

¡Eso es todo!

---

## **Comparación Directa**

### Instalación

```
Kubeadm:
├── Instalar kubelet
├── Instalar kubeadm
├── Instalar kubectl
├── Instalar container runtime (Docker/containerd)
├── kubeadm init
├── Instalar CNI
├── Configurar DNS
├── Esperar a que nodes pasen Ready
└── Generar tokens
TIEMPO: 30-60 minutos (con errores)

K3s:
├── curl ... | sh -
└── Esperar 30 segundos
TIEMPO: 5 minutos
```

### Configuración

```
Kubeadm: Múltiples archivos en /etc/kubernetes/
K3s:    Un archivo /etc/rancher/k3s/k3s.yaml
```

### Storage

```
Kubeadm:    Debes instalar (NFS, Longhorn, etc)
K3s:        local-path integrado (suficiente para testing)
```

### CNI

```
Kubeadm:    Debes elegir e instalar manualmente
K3s:        Flannel integrado, fácil de reemplazar
```

---

## **Tabla de Componentes**

| Componente | Kubeadm | K3s | Ubicación K3s |
|---|---|---|---|
| kubelet | Separado | Integrado | `/usr/local/bin/k3s` |
| kube-proxy | Separado | Integrado | `/usr/local/bin/k3s` |
| kube-apiserver | Separado | Integrado | `/usr/local/bin/k3s` |
| kube-controller-manager | Separado | Integrado | `/usr/local/bin/k3s` |
| kube-scheduler | Separado | Integrado | `/usr/local/bin/k3s` |
| etcd | Separado | Integrado* | `sqlite3` o embedded etcd |
| coredns | Addon | Integrado | Pod en kube-system |
| metrics-server | Addon | Integrado | Pod en kube-system |
| flannel (CNI) | Manual | Integrado | Pod en kube-system |
| traefik (Ingress) | Manual | Integrado | Pod en kube-system |

*K3s usa sqlite3 por defecto (ligero) pero soporta etcd externo

---

## **Caso de Uso: ¿Cuándo usar cada uno?**

### Usa **Kubeadm** si:
- ❌ Necesitas K8s puro upstream
- ❌ Cluster production enterprise (> 100 nodos)
- ❌ Necesitas customización profunda
- ❌ Team grande con expertise K8s

### Usa **K3s** si:
- ✅ Desarrollando/testing (como nosotros)
- ✅ Edge computing (ARM, recursos limitados)
- ✅ IoT/Embebido
- ✅ Home lab
- ✅ Prototipado rápido
- ✅ CI/CD pipelines
- ✅ Principiante en K8s

---

## **Decisión Final**

### Por qué formateamos y recomenzamos con K3s:

1. **Problemas de Kubeadm persistían**: CA hash, networking
2. **K3s es la mejor opción para ARM64**: Soporte oficial, optimizado
3. **Tiempo vs Benefit**: 30 min de formateo vs 2h debugging kubeadm
4. **Learnings**:
   - La migración parcial dejó residuos
   - K3s desde cero es más simple
   - Documentación K3s es mejor
   - Comunidad K3s es activa

---

## **Nota Importante**

**K3s es K8s puro**. No es "versión lite" en features, es la misma API.

```bash
# Ambos hacen lo mismo
kubectl apply -f deployment.yaml
kubectl get pods
kubectl logs pod-name

# La diferencia es instalación y overhead, no funcionalidad
```

---

## 📖 Siguiente

Lee: `../getting-started/01-INICIO.md` para volver al resumen.

