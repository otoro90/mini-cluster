# Resumen Paso a Paso: Instalación de Kubernetes en Orange Pi 5 con Armbian Ubuntu Noble

## Fecha
6 de noviembre de 2025

## Introducción
Esta guía resume la instalación completa de Kubernetes en Orange Pi 5, basada en la experiencia real. Incluye errores comunes en orden de aparición y sus soluciones. El proceso resultó exitoso para un clúster de un solo nodo.

## Requisitos Previos
- Orange Pi 5 con Armbian Ubuntu Noble (24.04 LTS).
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

# Configurar módulos (pueden fallar, ignorar si built-in)
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
# Inicializar (puede fallar por swap o residuos)
sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --cri-socket=unix:///var/run/containerd/containerd.sock

# Si falla por swap: Editar /var/lib/kubelet/config.yaml y agregar failSwapOn: false, reiniciar kubelet
# Si falla por residuos: sudo kubeadm reset --force; rm -rf /etc/kubernetes/ /var/lib/kubelet/ /var/lib/etcd/ $HOME/.kube/; systemctl restart containerd kubelet

# Configurar kubectl
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

## Paso 5: Instalar Red de Pods (Calico)
```bash
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

## Paso 6: Verificar y Probar
```bash
# Verificar (esperar 1-2 min si NotReady)
kubectl get nodes
kubectl get pods -A

# Desplegar prueba
kubectl create deployment nginx --image=nginx:arm64v8
kubectl expose deployment nginx --port=80 --type=NodePort

# Si Pending por taint: kubectl taint nodes orangepi5 node-role.kubernetes.io/control-plane:NoSchedule-
kubectl get services
```

## Errores Comunes en Orden de Aparición y Soluciones

1. **Módulos overlay/br_netfilter no encontrados:** Ignorar, built-in en kernel Armbian.
2. **IP forwarding no habilitado:** Ejecutar sysctl commands (Paso 1).
3. **Swap activo (zram):** Agregar `failSwapOn: false` en kubelet config.
4. **Puertos/archivos en uso en init:** Reset completo (ver Paso 4).
5. **Nodo NotReady después de Calico:** Esperar 1-2 min.
6. **Pods Pending por taint:** Quitar taint del control-plane.

## Resultado Final
- Nodo: Ready
- Pods del sistema: Running
- Nginx: Accesible en NodePort
- Clúster funcional para desarrollo.

## Notas Finales
- Para multi-nodo: Usa el comando de join en workers.
- Monitorea recursos en Orange Pi.
- Para Raspberry Pi: Similar, pero resuelve conflictos con K3s si presente.