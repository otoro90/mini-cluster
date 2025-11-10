# Informe de Instalación de Containerd en Orange Pi 5

## Fecha del Informe
6 de noviembre de 2025

## Sistema Operativo
- **Dispositivo**: Orange Pi 5
- **SO**: Armbian Ubuntu Noble (24.04 LTS)
- **Kernel**: 6.12.49-current-rockchip64
- **Arquitectura**: ARM64

## Objetivo
Instalar y configurar containerd como runtime de contenedores para Kubernetes en Orange Pi 5.

## Pasos Ejecutados

### 1. Instalación de Containerd
- Comando: `sudo apt install -y containerd`
- Paquetes instalados adicionalmente: `runc`
- Tamaño descargado: 35.4 MB
- Espacio adicional usado: 145 MB
- Velocidad de descarga: 9,437 kB/s
- Estado: Instalación exitosa

### 2. Creación del Directorio de Configuración
- Comando: `sudo mkdir -p /etc/containerd`
- Estado: Directorio creado correctamente

### 3. Generación de Configuración por Defecto
- Comando: `containerd config default | sudo tee /etc/containerd/config.toml`
- Estado: Archivo de configuración generado
- Ubicación: `/etc/containerd/config.toml`

### 4. Modificación de Configuración para Systemd
- Comando: `sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml`
- Cambio: Habilitado el uso de cgroups de systemd
- Estado: Modificación aplicada

### 5. Reinicio del Servicio
- Comando: `sudo systemctl restart containerd`
- Estado: Servicio reiniciado correctamente

### 6. Habilitación del Servicio
- Comando: `sudo systemctl enable containerd`
- Estado: Servicio habilitado para inicio automático

## Configuración Generada (Resumen)
La configuración por defecto incluye:
- **Versión**: 2
- **Raíz**: `/var/lib/containerd`
- **Estado**: `/run/containerd`
- **Plugins principales**:
  - CRI (Container Runtime Interface) configurado para Kubernetes
  - Snapshotter: overlayfs
  - Runtime: runc
  - Sandbox image: registry.k8s.io/pause:3.8
- **CNI**: Configurado para usar `/opt/cni/bin` y `/etc/cni/net.d`
- **Plataforma**: linux/arm64/v8
- **Systemd Cgroup**: Habilitado

## Estado del Servicio
- **Servicio**: containerd
- **Estado**: Activo (running)
- **Tiempo activo**: Desde 2025-11-06 15:02:22 -05 (52 segundos al momento del reporte)
- **PID Principal**: 2200
- **Uso de Memoria**: 14.0M (pico: 14.0M)
- **Uso de CPU**: 184ms
- **CGroup**: /system.slice/containerd.service
- **Logs principales**:
  - Suscripción a eventos iniciada
  - Recuperación de estado completada
  - Servidor de streaming iniciado en `/run/containerd/containerd.sock`
  - Tiempo de arranque: 0.072327s

## Conclusión
La instalación de containerd se completó exitosamente. El servicio está activo y configurado correctamente para integrarse con Kubernetes. La configuración incluye soporte para ARM64 y está optimizada para systemd. No se reportaron errores durante el proceso.

## Próximos Pasos Recomendados
1. Instalar Kubernetes (kubelet, kubeadm, kubectl)
2. Inicializar el clúster con kubeadm
3. Instalar una red de pods (ej. Calico)
4. Verificar el estado del clúster

## Notas Adicionales
- Containerd versión: 1.7.28
- Runc versión: 1.3.3
- Compatible con Kubernetes 1.30+
- No se requirió intervención manual adicional