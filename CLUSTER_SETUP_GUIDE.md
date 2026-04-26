# Guía de Configuración Cluster Híbrido Netboot - Forjanova Labs

Esta guía documenta el proceso de creación de un cluster ARM64 (Orange Pi 6 Plus, Orange Pi 5 y Raspberry Pi 4) utilizando arranque por red (Netboot) sin depender de discos locales en los nodos trabajadores.

## 1. Arquitectura del Cluster
*   **Master Node:** Orange Pi 6 Plus (IP: 192.168.1.210)
    *   Servicios: DHCP Proxy, TFTP, NFS Server.
    *   Almacenamiento: SSD externo de 1TB montado en `/mnt/ssd`.
*   **Workers:**
    *   **Worker 1:** Orange Pi 5 (IP: 192.168.1.211) - MAC: `76:86:c1:88:66:d7`
    *   **Worker 2:** Orange Pi 5 (IP: 192.168.1.212) - MAC: `18:47:3d:fc:0f:d9`
    *   **Worker 3:** Raspberry Pi 4 (IP: 192.168.1.213) - MAC: `dc:a6:32:e9:2a:be`

---

## 2. Configuración del Master (OPi 6 Plus)

### 2.1 Preparación del Almacenamiento
Los sistemas de los trabajadores residen en el SSD del Maestro:
*   TFTP (Arranque): `/mnt/ssd/netboot/tftp/`
*   NFS (Sistema): `/mnt/ssd/netboot/nfs/`

### 2.2 Instalación de Servicios
```bash
sudo apt update && sudo apt install dnsmasq nfs-kernel-server rsync
```

### 2.3 Configuración de NFS
Editar `/etc/exports` para compartir las carpetas de los trabajadores:
```text
/mnt/ssd/netboot/nfs/worker1 192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
/mnt/ssd/netboot/nfs/worker2 192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
/mnt/ssd/netboot/nfs/worker3 192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
```
Aplicar cambios: `sudo exportfs -ra`

### 2.4 Configuración de Dnsmasq (Netboot)
Archivo `/etc/dnsmasq.conf`:
```text
interface=eth0
port=0
dhcp-range=192.168.1.200,proxy
log-dhcp

# Reservas de IP y Etiquetas
dhcp-host=76:86:c1:88:66:d7,set:worker1,192.168.1.211,worker1
dhcp-host=18:47:3d:fc:0f:d9,set:worker2,192.168.1.212,worker2
dhcp-host=dc:a6:32:e9:2a:be,set:worker3,192.168.1.213,worker3

# Opciones de arranque
dhcp-option=tag:worker1,option:bootfile-name,worker1/boot.scr
dhcp-option=tag:worker2,option:bootfile-name,worker2/boot.scr
dhcp-option=tag:worker3,option:bootfile-name,bootcode.bin

enable-tftp
tftp-root=/mnt/ssd/netboot/tftp
```

---

## 3. Preparación de los Workers

### 3.1 Orange Pi 5 (Boot Bridge)
Debido a que la OPi 5 no tiene un PXE nativo robusto, usamos una Micro-SD de 256MB como puente:
1.  **Flashear SPL/U-Boot:** `sudo dd if=armbian_image.img of=/dev/sdX bs=1M count=16`
2.  **Crear partición FAT32:** A partir del sector 32768.
3.  **Generar boot.scr:** Apuntando a la carpeta NFS correspondiente.

### 3.2 Raspberry Pi 4 (Native PXE)
1.  **Actualizar EEPROM:** Usar imagen "Network Boot" de RPi Imager.
2.  **Archivos TFTP:** Copiar firmware y Kernel a la raíz de TFTP.
3.  **Configuración:** `kernel=kernel8.img` en `config.txt`.

---

## 4. Mantenimiento y Parcheo
Para que el sistema arranque correctamente, se debe comentar el montaje del disco local en el `fstab` de cada worker:
```bash
# En /mnt/ssd/netboot/nfs/workerX/etc/fstab
# UUID=... / ext4 (Comentar esta línea)
192.168.1.210:/mnt/ssd/netboot/nfs/workerX / nfs defaults,v3,tcp 0 0
```
