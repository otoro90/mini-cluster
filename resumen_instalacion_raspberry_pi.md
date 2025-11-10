# Resumen Paso a Paso: Instalación de Kubernetes en Raspberry Pi 4 Model B con Armbian Ubuntu Noble

## Fecha
6 de noviembre de 2025

## Introducción
Esta guía resume la instalación completa de Kubernetes en Raspberry Pi 4 Model B con Armbian Ubuntu Noble (24.04 LTS). Incluye errores comunes en orden de aparición y sus soluciones. El proceso resultó exitoso después de ajustes de kernel.

## Requisitos Previos
- Raspberry Pi 4 Model B con Armbian Ubuntu Noble (24.04 LTS).
- Acceso root o sudo.
- Conexión a internet.
- Al menos 2 GB RAM (recomendado).

## Paso 1: Preparar el Sistema
```bash
# Actualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar paquetes esenciales
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Desactivar swap (temporal, pero zram puede reactivarse)
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Configurar módulos (overlay puede fallar inicialmente)
sudo modprobe overlay
sudo modprobe br_netfilter
echo 'overlay' | sudo tee -a /etc/modules-load.d/containerd.conf
echo 'br_netfilter' | sudo tee -a /etc/modules-load.d/containerd.conf

# Configurar sysctl para networking
sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

# Habilitar overlay en kernel (crítico para Raspberry Pi)
echo 'extraargs=overlay' >> /boot/armbianEnv.txt
sudo reboot  # Reiniciar para aplicar
```

## Paso 2: Instalar Containerd
```bash
# Instalar containerd
sudo apt install -y containerd

# Configurar containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# Verificar
sudo systemctl status containerd
```

## Paso 3: Instalar Kubernetes (kubelet, kubeadm, kubectl)
```bash
# Agregar repositorio
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Instalar
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Habilitar kubelet
sudo systemctl enable kubelet
sudo systemctl start kubelet

# Verificar versiones
kubelet --version
kubeadm version
kubectl version --client
```

## Paso 4: Inicializar el Clúster
```bash
# Inicializar (puede fallar por swap o overlay)
sudo kubeadm init --apiserver-advertise-address=192.168.1.100 --pod-network-cidr=192.168.0.0/16 --cri-socket=unix:///var/run/containerd/containerd.sock

# Si falla por swap: Editar /var/lib/kubelet/config.yaml y agregar failSwapOn: false, reiniciar kubelet
echo 'failSwapOn: false' >> /var/lib/kubelet/config.yaml
sudo systemctl restart kubelet

# Si el init falla en wait-control-plane: Los pods del control plane pueden estar corriendo, aplicar addons manualmente
sudo kubeadm init phase addon all  # Instala CoreDNS y kube-proxy

# Configurar kubectl
export KUBECONFIG=/etc/kubernetes/admin.conf
# O copiar a ~/.kube/config para uso persistente
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

## Paso 5: Instalar Red de Pods (Calico)
```bash
# Si overlay no está cargado: Cargar manualmente
sudo modprobe overlay

# Aplicar Calico
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml --validate=false
```

## Paso 6: Verificar y Probar
```bash
# Verificar (esperar 1-2 min si NotReady)
kubectl get nodes
kubectl get pods -A

# Desplegar prueba
kubectl create deployment nginx --image=nginx:arm64v8
kubectl expose deployment nginx --port=80 --type=NodePort

# Si Pending por taint: kubectl taint nodes <nodo> node-role.kubernetes.io/control-plane:NoSchedule-
kubectl get services
```

## Errores Comunes en Orden de Aparición y Soluciones

1. **Módulos overlay/br_netfilter no encontrados:** Ignorar inicialmente, overlay se habilita en kernel.
2. **IP forwarding no habilitado:** Ejecutar sysctl commands (Paso 1).
3. **Swap activo (zram):** Agregar `failSwapOn: false` en kubelet config y reiniciar kubelet.
4. **Overlay no disponible:** Agregar `extraargs=overlay` en `/boot/armbianEnv.txt` y reiniciar, o cargar manualmente con `modprobe overlay`.
5. **Puertos/archivos en uso en init:** Reset completo con `kubeadm reset -f`.
6. **Init falla en wait-control-plane:** Los pods del control plane pueden estar corriendo; aplicar addons con `kubeadm init phase addon all`.
7. **kubectl forbidden (User kubernetes-admin cannot...):** Aplicar addons primero (CoreDNS, kube-proxy) para inicializar RBAC.
8. **Nodo NotReady después de Calico:** Esperar 1-2 min; verificar módulos overlay.
9. **Pods Pending por taint:** Quitar taint del control-plane con `kubectl taint nodes <nodo> node-role.kubernetes.io/control-plane:NoSchedule-`.
10. **ImagePullBackOff en pods:** Verificar conectividad; usar imágenes compatibles con ARM64 como `nginx` en lugar de `nginx:arm64v8`.

## Resultado Final
- Nodo: Ready
- Pods del sistema: Running (incluyendo CoreDNS, kube-proxy, Calico)
- Nginx: Accesible en NodePort (puerto asignado dinámicamente)
- Clúster funcional para desarrollo en ARM64.

## Notas Finales
- Para multi-nodo: Usa el comando de join desde Orange Pi.
- Monitorea recursos en Raspberry Pi (4GB RAM).
- Compatible con ARM64.
- Si el init falla parcialmente, aplicar addons manualmente con `kubeadm init phase addon all`.