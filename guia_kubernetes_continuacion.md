# Guía de Instalación de Kubernetes en Orange Pi 5 - Continuación

## Fecha
6 de noviembre de 2025

## Estado Actual
- Containerd instalado y configurado correctamente.
- Sistema preparado (swap desactivado inicialmente, pero zram puede estar activo; módulos configurados, sysctl ajustado).

## Paso 3: Instalar Kubernetes (kubelet, kubeadm, kubectl)

Ejecuta los siguientes comandos en la Orange Pi:

```bash
# Agregar clave GPG de Kubernetes
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Agregar repositorio de Kubernetes
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Actualizar e instalar paquetes
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Habilitar e iniciar kubelet
sudo systemctl enable kubelet
sudo systemctl start kubelet
```

### Verificación:
```bash
kubelet --version
kubeadm version
kubectl version --client
```

## Paso 4: Inicializar el Clúster de Kubernetes

Como nodo maestro/control plane (para clúster de un solo nodo):

```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --cri-socket=unix:///var/run/containerd/containerd.sock
```

- Este comando puede tardar varios minutos.
- Al final, mostrará un comando para unir nodos adicionales (guárdalo si planeas expandir).
- **Nota:** Si hay errores de swap o IP forwarding, resuélvelos primero (ver Solución de Problemas).

### Configurar kubectl para el usuario actual:
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

## Paso 5: Instalar una Red de Pods (Calico)

```bash
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

## Paso 6: Verificación del Clúster

```bash
# Ver estado de nodos
kubectl get nodes

# Ver pods del sistema
kubectl get pods -A

# Verificar componentes del clúster
kubectl get componentstatuses
```

### Despliegue de Prueba (Opcional):
```bash
kubectl create deployment nginx --image=nginx:arm64v8
kubectl expose deployment nginx --port=80 --type=NodePort
kubectl get services
```

- Accede a la aplicación en `http://<IP_ORANGE_PI>:<PUERTO>`

## Solución de Problemas Comunes (En Orden de Aparición)

### 1. Error: Module overlay/br_netfilter not found (Inicial)
- **Causa:** Módulos no disponibles en kernel Armbian.
- **Solución:** Ignorar, ya que suelen estar built-in. Proceder con containerd.

### 2. Error: /proc/sys/net/ipv4/ip_forward contents are not set to 1
- **Causa:** IP forwarding no habilitado.
- **Solución:**
  ```bash
  sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
  net.bridge.bridge-nf-call-ip6tables = 1
  net.bridge.bridge-nf-call-iptables = 1
  net.ipv4.ip_forward = 1
  EOF
  sudo sysctl --system
  ```
  Verifica: `sysctl net.ipv4.ip_forward` (debe ser 1).

### 3. Error: running with swap on is not supported (Kubelet falla)
- **Causa:** Swap activo (zram en Armbian).
- **Solución:** Permitir swap en kubelet editando `/var/lib/kubelet/config.yaml` y agregando `failSwapOn: false`. Reinicia kubelet.

### 4. Error: Puertos en uso / Archivos existentes en kubeadm init
- **Causa:** Residuos de inicialización anterior.
- **Solución:** Reset completo:
  ```bash
  sudo kubeadm reset --force
  sudo rm -rf /etc/kubernetes/ /var/lib/kubelet/ /var/lib/etcd/ $HOME/.kube/
  sudo systemctl restart containerd kubelet
  ```
  Luego reintenta init.

### 5. Nodo NotReady / Pods Pending después de Calico
- **Causa:** Calico configurando red (tarda 1-2 min).
- **Solución:** Espera y verifica con `kubectl get nodes` y `kubectl get pods -A`.

### 6. Nginx Pending (Taint en control-plane)
- **Causa:** Taint `node-role.kubernetes.io/control-plane:NoSchedule`.
- **Solución:** Quita taint: `kubectl taint nodes <nodo> node-role.kubernetes.io/control-plane:NoSchedule-`.

### Si kubeadm init falla:
- Verifica que containerd esté corriendo: `sudo systemctl status containerd`
- Revisa logs: `journalctl -u kubelet`
- Asegúrate de que no haya procesos previos: `sudo kubeadm reset`

### Si Calico no se instala:
- Espera 1-2 minutos para que los pods se inicien.
- Verifica: `kubectl get pods -n kube-system`

### Para reiniciar desde cero:
```bash
sudo kubeadm reset
sudo systemctl stop kubelet
sudo rm -rf /etc/kubernetes/
sudo rm -rf $HOME/.kube/
# Luego reinicia desde el Paso 4
```

## Notas para Orange Pi
- Usa imágenes ARM64 (ej. `nginx:arm64v8`).
- Monitorea el uso de recursos (RAM, CPU) ya que es limitado.
- Para producción, considera un clúster multi-nodo.

Si encuentras errores en algún paso, comparte la salida y te ayudo a resolverlos.