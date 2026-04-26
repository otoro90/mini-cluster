# Mini-Cluster Forjanova Labs — Guía Completa de Netboot

## Arquitectura

```
┌─────────────────────────────────────────────────────────┐
│  Router Casa (192.168.1.1) — DHCP general de la red     │
└───────────────────────┬─────────────────────────────────┘
                        │
         ┌──────────────▼──────────────┐
         │  MAESTRO: Orange Pi 5 Plus  │
         │  IP: 192.168.1.210 (fija)   │
         │  SSD 1TB via USB            │
         │  Servicios:                 │
         │   - dnsmasq (DHCP+TFTP)     │
         │   - NFS Server              │
         └──────┬──────────────────────┘
                │ Red Local 192.168.1.0/24
      ┌─────────┼─────────────┐
      ▼         ▼             ▼
  Worker 1   Worker 2     Worker 3
  OPi 5 4GB  OPi 5 8GB    RPi 4
  .211        .212          .213
  (Netboot)  (Netboot)   (Netboot)
```

**Principio clave**: Los workers NO tienen OS en disco. Arrancan por red (Netboot).
La OPi 5 necesita una micro-SD de 256MB como "boot bridge" para saltar a la red.
La RPi 4 tiene PXE nativo, no necesita SD.

---

## Resumen de MACs y IPs

| Nodo | Hostname | IP | MAC | RAM |
|---|---|---|---|---|
| Maestro | orangepi6plus | 192.168.1.210 | — | 8GB |
| Worker 1 | worker1 | 192.168.1.211 | 76:86:c1:88:66:d7 | 4GB |
| Worker 2 | worker2 | 192.168.1.212 | 9e:67:0e:af:20:e1 | 8GB |
| Worker 3 | worker3 | 192.168.1.213 | dc:a6:32:e9:2a:be | — |

---

## Estructura de directorios en el Maestro

```
/mnt/ssd/netboot/
├── tftp/                           ← Raíz TFTP
│   ├── pxelinux.cfg/               ← Para fase PXEClient
│   │   ├── 01-76-86-c1-88-66-d7   ← Worker 1
│   │   └── 01-9e-67-0e-af-20-e1   ← Worker 2
│   ├── worker1/
│   │   ├── vmlinuz
│   │   ├── initrd.img
│   │   ├── dtb/rockchip/rk3588s-orangepi-5.dtb
│   │   ├── boot.scr               ← Script U-Boot compilado
│   │   ├── boot.cmd               ← Script U-Boot fuente
│   │   └── pxelinux.cfg/          ← Para fase U-Boot (paths sin worker1/)
│   │       └── 01-76-86-c1-88-66-d7
│   └── worker2/                   ← Igual estructura
└── nfs/
    ├── worker1/                   ← OS completo (raíz del sistema)
    ├── worker2/
    └── worker3/
```

---

## Paso 1: Instalar paquetes en el Maestro

```bash
sudo apt update
sudo apt install -y dnsmasq nfs-kernel-server u-boot-tools
```

---

## Paso 2: Configurar dnsmasq

**`/etc/dnsmasq.conf`**:
```
interface=eth0
port=0
log-dhcp

dhcp-range=192.168.1.210,192.168.1.240,12h

# CLAVE: detectar la fase de arranque por vendor class
dhcp-vendorclass=set:uboot,U-Boot
dhcp-vendorclass=set:pxeclient,PXEClient

# Worker 1
dhcp-host=76:86:c1:88:66:d7,set:worker1,192.168.1.211,worker1
dhcp-option=tag:worker1,tag:uboot,option:bootfile-name,worker1/boot.scr
dhcp-option=tag:worker1,tag:pxeclient,option:bootfile-name,pxelinux.cfg/01-76-86-c1-88-66-d7
dhcp-option=tag:worker1,17,192.168.1.210:/mnt/ssd/netboot/nfs/worker1

# Worker 2
dhcp-host=18:47:3d:fc:0f:d9,set:worker2,192.168.1.212,worker2
dhcp-option=tag:worker2,tag:uboot,option:bootfile-name,worker2/boot.scr
dhcp-option=tag:worker2,tag:pxeclient,option:bootfile-name,pxelinux.cfg/01-18-47-3d-fc-0f-d9
dhcp-option=tag:worker2,17,192.168.1.210:/mnt/ssd/netboot/nfs/worker2

# Worker 3 — RPi 4
dhcp-host=dc:a6:32:e9:2a:be,set:worker3,192.168.1.213,worker3
dhcp-option=tag:worker3,option:bootfile-name,bootcode.bin

enable-tftp
tftp-root=/mnt/ssd/netboot/tftp
```

```bash
sudo systemctl restart dnsmasq && sudo systemctl enable dnsmasq
```

---

## Paso 3: Configurar NFS

**`/etc/exports`**:
```
/mnt/ssd/netboot/nfs/worker1  192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
/mnt/ssd/netboot/nfs/worker2  192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
/mnt/ssd/netboot/nfs/worker3  192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
```

```bash
sudo exportfs -arv
sudo systemctl enable nfs-kernel-server
```

---

## Paso 4: Preparar OS base para workers OPi 5

### 4.1 Descargar imagen Armbian
```bash
wget https://dl.armbian.com/orangepi5/archive/Armbian_24.x_Orangepi5_bookworm_current_6.x.img.xz
xz -d Armbian_24.x_*.img.xz
```

### 4.2 Extraer rootfs a NFS
```bash
sudo mkdir -p /mnt/tmp_img /mnt/ssd/netboot/nfs/worker1

# Encontrar offset de la particion del OS
OFFSET=$(fdisk -l Armbian_24.x_*.img | grep "Linux filesystem" | awk '{print $2 * 512}')
sudo mount -o loop,offset=$OFFSET Armbian_24.x_*.img /mnt/tmp_img

sudo rsync -axHAWX --numeric-ids /mnt/tmp_img/ /mnt/ssd/netboot/nfs/worker1/
sudo umount /mnt/tmp_img
```

### 4.3 Extraer kernel, initrd y DTB
```bash
sudo mkdir -p /mnt/ssd/netboot/tftp/worker1/dtb/rockchip
sudo mkdir -p /mnt/ssd/netboot/tftp/worker1/pxelinux.cfg

# Kernel e initrd (los nombres exactos varían, ajustar)
sudo cp /mnt/ssd/netboot/nfs/worker1/boot/vmlinuz-* \
        /mnt/ssd/netboot/tftp/worker1/vmlinuz
sudo cp /mnt/ssd/netboot/nfs/worker1/boot/initrd.img-* \
        /mnt/ssd/netboot/tftp/worker1/initrd.img
sudo cp /mnt/ssd/netboot/nfs/worker1/boot/dtb/rockchip/rk3588s-orangepi-5.dtb \
        /mnt/ssd/netboot/tftp/worker1/dtb/rockchip/
```

### 4.4 Crear archivos PXE config

> **IMPORTANTE**: Se necesitan DOS archivos con el mismo nombre en dos ubicaciones distintas.
> Uno para la fase U-Boot (busca bajo `worker1/pxelinux.cfg/`) y otro para PXEClient (busca bajo `pxelinux.cfg/`).

**Fase U-Boot** — `/mnt/ssd/netboot/tftp/worker1/pxelinux.cfg/01-76-86-c1-88-66-d7`:
```
DEFAULT w1boot
LABEL w1boot
    KERNEL vmlinuz
    FDT dtb/rockchip/rk3588s-orangepi-5.dtb
    INITRD initrd.img
    APPEND root=/dev/nfs nfsroot=192.168.1.210:/mnt/ssd/netboot/nfs/worker1,v3,tcp,nolock rw ip=dhcp rootwait console=ttyS2,1500000 console=tty1
```

**Fase PXEClient** — `/mnt/ssd/netboot/tftp/pxelinux.cfg/01-76-86-c1-88-66-d7`:
```
DEFAULT w1boot
LABEL w1boot
    KERNEL worker1/vmlinuz
    FDT worker1/dtb/rockchip/rk3588s-orangepi-5.dtb
    INITRD worker1/initrd.img
    APPEND root=/dev/nfs nfsroot=192.168.1.210:/mnt/ssd/netboot/nfs/worker1,v3,tcp,nolock rw ip=dhcp rootwait console=ttyS2,1500000 console=tty1
```

### 4.5 Crear boot.scr
```bash
cat > /mnt/ssd/netboot/tftp/worker1/boot.cmd << 'EOF'
setenv bootargs "root=/dev/nfs nfsroot=192.168.1.210:/mnt/ssd/netboot/nfs/worker1,v3,tcp,nolock rw ip=dhcp rootwait console=ttyS2,1500000 console=tty1"
tftp ${kernel_addr_r} worker1/vmlinuz
tftp ${fdt_addr_r} worker1/dtb/rockchip/rk3588s-orangepi-5.dtb
tftp ${ramdisk_addr_r} worker1/initrd.img
booti ${kernel_addr_r} ${ramdisk_addr_r}:${filesize} ${fdt_addr_r}
EOF
sudo mkimage -C none -A arm64 -T script \
    -d /mnt/ssd/netboot/tftp/worker1/boot.cmd \
       /mnt/ssd/netboot/tftp/worker1/boot.scr
```

### 4.6 Configurar fstab y hostname del worker
```bash
sudo tee /mnt/ssd/netboot/nfs/worker1/etc/fstab << 'EOF'
192.168.1.210:/mnt/ssd/netboot/nfs/worker1  /  nfs  defaults,v3,tcp,nolock  0  0
none  /tmp  tmpfs  defaults  0  0
EOF

echo "worker1" | sudo tee /mnt/ssd/netboot/nfs/worker1/etc/hostname
sudo sed -i 's/orangepi/worker1/g' /mnt/ssd/netboot/nfs/worker1/etc/hosts
```

### 4.7 Clonar para Worker 2
```bash
sudo rsync -axHAWX /mnt/ssd/netboot/nfs/worker1/ /mnt/ssd/netboot/nfs/worker2/
echo "worker2" | sudo tee /mnt/ssd/netboot/nfs/worker2/etc/hostname
sudo sed -i 's/worker1/worker2/g' /mnt/ssd/netboot/nfs/worker2/etc/hosts
sudo sed -i 's/worker1/worker2/g' /mnt/ssd/netboot/nfs/worker2/etc/fstab

# Copiar archivos TFTP y crear configs PXE para worker2 (igual pero con MAC de worker2)
```

---

## Paso 5: Preparar micro-SD Boot Bridge (OPi 5)

```bash
# Flashear solo los primeros 16MB de la imagen (U-Boot)
sudo dd if=Armbian_24.x_*.img of=/dev/sdX bs=1M count=16 status=progress
sync

# Si la SD tiene GPT que causa problemas, recrear tabla MBR
# (U-Boot vive en sectores bajos, no en la tabla de particiones)
sudo parted /dev/sdX mklabel msdos
sync
```

---

## Paso 6: Verificar el cluster

```bash
# Ping a todos
fping 192.168.1.211 192.168.1.212 192.168.1.213

# SSH (Armbian default: root / 1234)
ssh root@192.168.1.211
ssh root@192.168.1.212
ssh root@192.168.1.213

# Verificar que el OS corre desde NFS
ssh root@192.168.1.211 "df -h / && free -h"
# Filesystem correcto: 192.168.1.210:/mnt/ssd/netboot/nfs/worker1
```

---

## Backup y recreación rápida

```bash
# Backup de configuración (ligero, solo configs y TFTP)
sudo tar -czpf netboot_config_$(date +%Y%m%d).tar.gz \
    /etc/dnsmasq.conf /etc/exports \
    /mnt/ssd/netboot/tftp/

# Backup de rootfs de un worker (pesado ~5-10GB)
sudo tar -czpf worker1_rootfs_$(date +%Y%m%d).tar.gz \
    -C /mnt/ssd/netboot/nfs/worker1 .

# Restaurar en nuevo Maestro
sudo tar -xzpf netboot_config_XXXXXXXX.tar.gz -C /
sudo tar -xzpf worker1_rootfs_XXXXXXXX.tar.gz -C /mnt/ssd/netboot/nfs/worker1/
sudo exportfs -arv
sudo systemctl restart dnsmasq nfs-kernel-server
```

---

## Diagrama de flujo de arranque (OPi 5)

```
SD Card (256MB, solo U-Boot)
        │
        ▼
  U-Boot arranca
        │
        ▼ DHCP (vendor: U-Boot.armv8)
  dnsmasq responde:
    IP: 192.168.1.211
    bootfile: worker1/boot.scr  ← U-Boot usa worker1/ como prefijo
    root-path: .../nfs/worker1
        │
        ▼ TFTP: worker1/pxelinux.cfg/01-MAC  ← encontrado!
        │
        ▼ TFTP descarga (desde worker1/):
    vmlinuz + initrd.img + dtb
        │
        ▼
  Kernel Linux arranca
        │
        ▼ DHCP (vendor: Linux/sin vendor)
  IP confirmada: 192.168.1.211
        │
        ▼ NFS mount:
  192.168.1.210:/nfs/worker1 → /
        │
        ▼
  ¡Sistema operativo corriendo!
  SSH: root@192.168.1.211 / 1234
```

---

## Resolución de problemas frecuentes

| Síntoma | Causa | Solución |
|---|---|---|
| No aparece en dnsmasq log | Sin conexión ethernet | Verificar cable |
| Busca `pxelinux.cfg/pxelinux.cfg/...` | Doble prefijo por bootfile con directorio | Usar vendor class en dnsmasq |
| Descarga kernel pero se reinicia | NFS no monta | Verificar fstab y exportfs |
| `abandoning lease` en log | Normal — el kernel tomó el relevo de U-Boot | Señal positiva |
| SSH: Permission denied | Contraseña incorrecta | Armbian: root/1234 |
| SD no arranca U-Boot | GPT corrupta | `parted /dev/sdX mklabel msdos` |
