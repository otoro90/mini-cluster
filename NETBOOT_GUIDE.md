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
  OPi 5 4GB  OPi 5 8GB    RPi 4b model 8GB
  .211        .212          .213
  (Netboot)  (Netboot)   (Netboot)
```

**Principio clave**: Los workers NO tienen OS en disco. Arrancan por red (Netboot).
La OPi 5 inicialmente necesitaban una micro-SD de 256MB como "boot bridge" para saltar a la red. Pero se configuro la SPI, para que bootearan a la red sin estas.
La RPi 4 tiene PXE nativo, no necesita SD.

---

## Resumen de MACs y IPs

| Nodo | Hostname | IP | MAC | RAM |
|---|---|---|---|---|
| Maestro | orangepi6plus | 192.168.1.210 | — | 32GB |
| Worker 1 | worker1 | 192.168.1.211 | 76:86:c1:88:66:d7 | 4GB |
| Worker 2 | worker2 | 192.168.1.212 | 9e:67:0e:af:20:e1 | 8GB |
| Worker 3 | worker3 | 192.168.1.213 | dc:a6:32:e9:2a:be | 8GB |

> **Estado verificado (Abril 2026)**: Los 3 workers arrancan desde NFS. Workers 1 y 2 via U-Boot SPI → TFTP → NFS. Worker 3 (RPi 4) via EEPROM PXE nativo → TFTP → NFS.

---

## Estructura de directorios en el Maestro

```
/mnt/ssd/netboot/
├── tftp/                           ← Raíz TFTP
│   ├── pxelinux.cfg/               ← Para fase PXEClient
│   │   ├── 01-76-86-c1-88-66-d7   ← Worker 1
│   │   └── 01-9e-67-0e-af-20-e1   ← Worker 2
│   │   └── 01-dc-a6-32-e9-2a-be   ← Worker 3
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

**`/etc/dnsmasq.conf`** (configuración final verificada):
```
interface=enp97s0
port=0
log-dhcp

dhcp-range=192.168.1.210,192.168.1.240,12h

# CLAVE: detectar la fase de arranque por vendor class
dhcp-vendorclass=set:uboot,U-Boot
dhcp-vendorclass=set:pxeclient,PXEClient

# CLAVE RPi4: responder con option 60=PXEClient para que la RPi acepte el OFFER
dhcp-option=tag:pxeclient,60,PXEClient

# Worker 1 (OPi 5, U-Boot SPI)
dhcp-host=76:86:c1:88:66:d7,set:worker1,192.168.1.211,worker1
dhcp-option=tag:worker1,tag:uboot,option:bootfile-name,worker1/boot.scr
dhcp-option=tag:worker1,tag:pxeclient,option:bootfile-name,pxelinux.cfg/01-76-86-c1-88-66-d7
dhcp-option=tag:worker1,17,192.168.1.210:/mnt/ssd/netboot/nfs/worker1

# Worker 2 (OPi 5, U-Boot SPI)
dhcp-host=9e:67:0e:af:20:e1,set:worker2,192.168.1.212,worker2
dhcp-option=tag:worker2,tag:uboot,option:bootfile-name,worker2/boot.scr
dhcp-option=tag:worker2,tag:pxeclient,option:bootfile-name,pxelinux.cfg/01-9e-67-0e-af-20-e1
dhcp-option=tag:worker2,17,192.168.1.210:/mnt/ssd/netboot/nfs/worker2

# Worker 3 (RPi 4) — EEPROM PXE nativo
# dhcp-boot: fija siaddr (campo DHCP next-server) + bootfile + IP TFTP
# option 66: TFTP server explícito (la RPi lo solicita y lo necesita)
# Usar la IP canónica del cluster (.210) para siaddr y option 66
dhcp-host=dc:a6:32:e9:2a:be,set:worker3,192.168.1.213,worker3
dhcp-boot=tag:worker3,bootcode.bin,,192.168.1.210
dhcp-option=tag:worker3,66,192.168.1.210
dhcp-option=tag:worker3,17,192.168.1.210:/mnt/ssd/netboot/nfs/worker3

enable-tftp
tftp-root=/mnt/ssd/netboot/tftp
```

> **Por qué RPi 4 necesita `dhcp-boot` + `option 66`**: La RPi 4 hace DHCPDISCOVER
> solicitando explícitamente option 66 (TFTP server). Si el OFFER no incluye option 66,
> la RPi ignora el OFFER y repite el DISCOVER indefinidamente. El campo `siaddr` (next-server)
> del paquete DHCP no es suficiente — la opción 66 debe estar presente.
> `dhcp-option=bootfile-name` solo no funciona para RPi 4 porque no rellena el campo `siaddr`.

```bash
sudo systemctl restart dnsmasq && sudo systemctl enable dnsmasq
```

---

## Paso 3: Configurar NFS

---

## Paso 2b: Preparar archivos TFTP para RPi 4 (Worker 3)

```bash
# La RPi 4 busca archivos en el TFTP root (no en un subdirectorio)
mkdir -p /mnt/ssd/netboot/tftp/overlays

# Copiar desde Raspberry Pi OS image o rootfs NFS:
# bootcode.bin, start4.elf, fixup4.dat — firmware de 1ra etapa
# kernel8.img (o vmlinuz) — kernel ARM64 para RPi4
# initrd.img — initramfs
# bcm2711-rpi-4-b.dtb — Device Tree para RPi 4 Model B
# config.txt — configuración del firmware
# cmdline.txt — parámetros del kernel
# overlays/ — overlays del Device Tree

# config.txt para netboot NFS:
cat > /mnt/ssd/netboot/tftp/config.txt << 'EOF'
[all]
kernel=kernel8.img
initramfs initrd.img followkernel
arm_64bit=1
auto_initramfs=1
disable_overscan=1
EOF

# Crear symlink kernel8.img -> vmlinuz (si vmlinuz es el kernel)
ln -sf vmlinuz /mnt/ssd/netboot/tftp/kernel8.img

# cmdline.txt para NFS root:
cat > /mnt/ssd/netboot/tftp/cmdline.txt << 'EOF'
console=serial0,115200 console=tty1 root=/dev/nfs nfsroot=192.168.1.210:/mnt/ssd/netboot/nfs/worker3,v3,tcp rw ip=dhcp rootwait dwc_otg.lpm_enable=0 cgroup_memory=1 cgroup_enable=memory
EOF
```

> **Importante para K3s en RPi4**: si en `/proc/cmdline` aparece `cgroup_disable=memory`,
> K3s agent falla con `failed to find memory cgroup (v2)`. Debes arrancar con
> `cgroup_memory=1 cgroup_enable=memory`.

> **NOTA**: La RPi 4 primero busca `<serial_number>/start4.elf` (directorio con su serial).
> Si no lo encuentra, cae back al directorio raíz del TFTP. Esto es normal — dnsmasq
> logueará errores `file not found for 192.168.1.213` para el directorio de serial,
> seguidos de transferencias exitosas desde el root. También verás mensajes
> `failed sending kernel8.img` seguidos de `sent kernel8.img` — son reintentos normales
> de la negociación de opciones TFTP.

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

## Paso 5: Preparar arranque de RPi 4 (Worker 3)

La RPi 4 tiene PXE nativo en su EEPROM — **no necesita micro-SD**.

### 5.1 Habilitar netboot en la EEPROM

```bash
# Desde el sistema operativo corriendo en la RPi 4:
sudo raspi-config
# → Advanced Options → Boot Order → Network Boot
# O directamente:
rpi-eeprom-config --edit
# Añadir: BOOT_ORDER=0x21  (SD primero, luego red)
```

### 5.2 Preparar rootfs NFS

```bash
# Desde el maestro, copiar rootfs de Raspberry Pi OS a NFS:
DEBIAN_IMG="raspios_lite_arm64_FECHA.img"
OFFSET=$(fdisk -l $DEBIAN_IMG | grep Linux | awk '{print $2 * 512}')
mkdir -p /mnt/tmp_rpi
sudo mount -o loop,offset=$OFFSET $DEBIAN_IMG /mnt/tmp_rpi
sudo rsync -axHAWX --numeric-ids /mnt/tmp_rpi/ /mnt/ssd/netboot/nfs/worker3/
sudo umount /mnt/tmp_rpi

# Modificar fstab para NFS root:
sudo tee /mnt/ssd/netboot/nfs/worker3/etc/fstab << 'EOF'
# UUID originales comentados (no aplican en netboot)
tmpfs /tmp tmpfs defaults,nosuid 0 0
192.168.1.210:/mnt/ssd/netboot/nfs/worker3 / nfs defaults,v3,tcp 0 0
EOF

echo "worker3" | sudo tee /mnt/ssd/netboot/nfs/worker3/etc/hostname

# Copiar kernel y firmware al TFTP root:
sudo cp /mnt/ssd/netboot/nfs/worker3/boot/firmware/start4.elf /mnt/ssd/netboot/tftp/
sudo cp /mnt/ssd/netboot/nfs/worker3/boot/firmware/fixup4.dat /mnt/ssd/netboot/tftp/
sudo cp /mnt/ssd/netboot/nfs/worker3/boot/firmware/*.dtb /mnt/ssd/netboot/tftp/
sudo cp /mnt/ssd/netboot/nfs/worker3/boot/firmware/overlays/ /mnt/ssd/netboot/tftp/overlays/ -r
sudo cp /mnt/ssd/netboot/nfs/worker3/boot/vmlinuz-* /mnt/ssd/netboot/tftp/vmlinuz
sudo cp /mnt/ssd/netboot/nfs/worker3/boot/initrd.img-* /mnt/ssd/netboot/tftp/initrd.img
sudo ln -sf vmlinuz /mnt/ssd/netboot/tftp/kernel8.img
```

### 5.3 Verificar boot

```bash
# Monitorear logs dnsmasq en tiempo real:
sudo journalctl -u dnsmasq -f | grep -E 'dc:a6:32:e9:2a:be|213|TFTP'

# Secuencia esperada:
# DHCPDISCOVER → DHCPOFFER (con next server: 192.168.1.210)
# DHCPREQUEST → DHCPACK ← LA CLAVE: ahora acepta el OFFER
# TFTP: bootcode.bin / start4.elf / kernel8.img...
# Segundo DHCP cycle (kernel Linux ya corriendo)
# rpc.mountd: authenticated mount for /mnt/ssd/netboot/nfs/worker3

# SSH al worker3:
ssh root@192.168.1.213
# Interfaz de red: end0 (no eth0) en sistemas con naming persistente
```

---

## Paso 6: Preparar arranque de OPi 5 (dos métodos)

### Método A — SPI Flash (recomendado, sin micro-SD) ✅ VERIFICADO

Si el worker ya arranca con Armbian (por SD o NFS), se puede grabar U-Boot directamente
en la memoria SPI interna de la placa. Así arranca sin micro-SD y hace DHCP→TFTP directo.

```bash
# Desde dentro del worker (por SSH):
dd if=/usr/lib/linux-u-boot-current-orangepi5/u-boot-rockchip-spi.bin \
   of=/dev/mtdblock0 conv=notrunc
sync
# Salida esperada: ~1.7 MB copiados en ~20s
```

Después del reboot la placa arranca SPI → DHCP (vendor: U-Boot) → dnsmasq le da
`worker1/boot.scr` por TFTP → kernel + initrd + dtb por TFTP → NFS root.
**No necesita micro-SD.**

> **Verificado en Worker 1 (76:86:c1:88:66:d7)** — Abril 2026

### Método B — micro-SD Boot Bridge (fallback)

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

## Paso 7: Verificar el cluster

```bash
# Ping a todos
fping 192.168.1.211 192.168.1.212 192.168.1.213

# SSH a workers OPi 5 (Armbian default: root / 1234 o root / 123456)
ssh root@192.168.1.211
ssh root@192.168.1.212

# SSH a worker3 (RPi 4 — password configurado durante setup)
ssh root@192.168.1.213

# Verificar que el OS corre desde NFS
ssh root@192.168.1.211 "df -h / && free -h"
# Filesystem correcto: 192.168.1.210:/mnt/ssd/netboot/nfs/worker1

ssh root@192.168.1.213 "uname -a && df -h / && cat /proc/cpuinfo | grep Model"
# Esperado:
# Linux worker3 6.x.x-current-bcm2711 ... aarch64 GNU/Linux
# 192.168.1.210:/mnt/ssd/netboot/nfs/worker3  886G ...
# Model: Raspberry Pi 4 Model B Rev 1.4

# Ver todos los mounts NFS activos en el maestro:
sudo showmount -a
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
SPI Flash (U-Boot, sin micro-SD) ← Método A recomendado
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
  SSH: root@192.168.1.211
```

## Diagrama de flujo de arranque (RPi 4)

```
EEPROM PXE nativo (sin SD, sin SPI flash)
        │
        ▼ DHCPDISCOVER (vendor: PXEClient:Arch:00000:UNDI:002001)
  dnsmasq responde (DHCPOFFER):
    IP: 192.168.1.213
    next-server: 192.168.1.210  ← siaddr via dhcp-boot (IP canónica cluster)
    option 66: 192.168.1.210   ← TFTP server (OBLIGATORIO para RPi4)
    option 67: bootcode.bin
    option 60: PXEClient       ← echo para validación
        │
        ▼ DHCPREQUEST → DHCPACK ← RPi acepta el OFFER
        │
        ▼ TFTP busca <serial>/start4.elf → no encontrado (normal)
        │  cae back al root TFTP:
        ▼ TFTP descarga:
    start4.elf + fixup4.dat + config.txt
    kernel8.img (= vmlinuz, kernel bcm2711)
    initrd.img + bcm2711-rpi-4-b.dtb
    overlays/ + cmdline.txt
        │  (reintentos TFTP son normales — Early terminate luego éxito)
        ▼
  Kernel Linux arranca
        │
        ▼ DHCP (kernel ip=dhcp, vendor: sin PXEClient)
  IP confirmada: 192.168.1.213
        │
        ▼ NFS mount:
  192.168.1.210:/nfs/worker3 → /
        │
        ▼
  ¡Sistema operativo corriendo!
  SSH: root@192.168.1.213  (interfaz de red: end0, no eth0)
```

---

## Resolución de problemas frecuentes

| Síntoma | Causa | Solución |
|---|---|---|
| No aparece en dnsmasq log | Sin conexión ethernet | Verificar cable |
| Busca `pxelinux.cfg/pxelinux.cfg/...` | Doble prefijo por bootfile con directorio | Usar vendor class en dnsmasq |
| Descarga kernel pero se reinicia | NFS no monta | Verificar fstab y exportfs |
| `abandoning lease` en log | Normal — el kernel tomó el relevo de U-Boot/EEPROM | Señal positiva |
| SSH: Permission denied | Contraseña incorrecta | Armbian: root/1234 o root/123456 |
| SD no arranca U-Boot | GPT corrupta | `parted /dev/sdX mklabel msdos` |
| **RPi 4**: Loop DISCOVER→OFFER sin REQUEST | Falta option 66 en DHCP OFFER | Añadir `dhcp-option=tag:worker3,66,192.168.1.210` |
| **RPi 4**: No intenta TFTP | `dhcp-option bootfile-name` no rellena siaddr | Usar `dhcp-boot=tag:worker3,bootcode.bin,,192.168.1.210` |
| **RPi 4**: dnsmasq sigue enviando IP vieja tras cambio de config | `systemctl reload` (SIGHUP) **no recarga** `dhcp-boot` ni `dhcp-option` en runtime | Usar siempre `systemctl restart dnsmasq` al cambiar opciones DHCP de siaddr/option 66 |
| **RPi 4**: `failed sending kernel8.img` | Reintentos de negociación TFTP | Normal — buscar `sent kernel8.img` a continuación |
| **RPi 4**: Error `file not found` para `e4834e0c/start4.elf` | RPi busca en dir de serial primero | Normal — cae al root TFTP automáticamente |
| **RPi 4**: Interfaz de red es `end0` no `eth0` | Naming persistente de Debian/Ubuntu | Usar `end0` en comandos de red |

---

## Netboot + K3s en ARM (restricciones validadas)

Para este cluster (OPi5 `rockchip64` y RPi4 `bcm2711`) se validaron estos requisitos
adicionales para que K3s funcione sobre root NFS:

1. **Sin `ip_tables` en kernel**: usar nftables (`nf_tables`) y forzar binarios iptables de K3s a nft.
2. **Root sobre NFS**: overlayfs de kernel puede fallar; usar `fuse-overlayfs` como snapshotter.
3. **RPi4**: habilitar memory cgroups en cmdline para que K3s arranque.

Comandos aplicados en cada worker:

```bash
# 1) Instalar snapshotter compatible con root NFS
apt-get install -y fuse-overlayfs

# 2) Forzar k3s-agent a usar fuse-overlayfs + kube-proxy nftables
mkdir -p /etc/systemd/system/k3s-agent.service.d
cat > /etc/systemd/system/k3s-agent.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=/usr/local/bin/k3s agent --snapshotter=fuse-overlayfs --kube-proxy-arg=proxy-mode=nftables
EOF

# 3) Cambiar iptables bundled de K3s a xtables-nft-multi
cd /var/lib/rancher/k3s/data/current/bin/aux
for i in iptables iptables-save iptables-restore ip6tables ip6tables-save ip6tables-restore; do
    ln -sf xtables-nft-multi "$i"
done

systemctl daemon-reload
systemctl restart k3s-agent
```

> Nota de persistencia: en este entorno `/var/lib/rancher/k3s` vive en NFS root y
> los symlinks persisten entre reinicios. Tras actualizaciones de K3s, conviene revalidar
> que sigan apuntando a `xtables-nft-multi`.

---

## Optimización de tiempos de boot (verificado Abril 2026)

### Tiempos medidos

| Worker | Antes | Después | Mejora principal |
|---|---|---|---|
| worker1/2 (OPi5 RK3588) | ~3-4 min | **~2 min** | `tftpblocksize 65464` |
| worker3 (RPi4 BCM2711) | ~2-3 min | **~1 min 10 seg** | Boot nativo EEPROM |
| maestro (OPi6+ CIX P1) | ~23 seg | **~5-6 seg** | Mask servicios innecesarios |

### boot.cmd para workers OPi5 (U-Boot SPI → TFTP)

El cuello de botella histórico era el TFTP con tamaño de bloque 512 bytes por defecto:
58MB de vmlinuz+initrd requerían ~120,000 round-trips UDP. Con `tftpblocksize 65464`
se reducen a ~600 paquetes.

```bash
# Archivo: /mnt/ssd/netboot/tftp/workerX/boot.cmd
setenv tftpblocksize 65464
setenv tftpwindowsize 8
setenv bootargs "root=/dev/nfs nfsroot=192.168.1.210:/mnt/ssd/netboot/nfs/workerX,v3,tcp,nolock,rsize=131072,wsize=131072,timeo=600 rw ip=dhcp rootwait quiet console=ttyS2,1500000"
tftp ${kernel_addr_r} workerX/vmlinuz
tftp ${fdt_addr_r} workerX/dtb/rockchip/rk3588s-orangepi-5.dtb
tftp ${ramdisk_addr_r} workerX/initrd.img
booti ${kernel_addr_r} ${ramdisk_addr_r}:${filesize} ${fdt_addr_r}
```

Siempre regenerar `boot.scr` después de editar `boot.cmd`:

```bash
mkimage -C none -A arm64 -T script \
  -d /mnt/ssd/netboot/tftp/workerX/boot.cmd \
     /mnt/ssd/netboot/tftp/workerX/boot.scr
```

### Servicios masked en NFS root de workers OPi5

Sin WiFi ni Bluetooth físico, estos servicios solo añaden latencia:

```bash
# Ejecutar en el maestro sobre cada NFS root
for w in worker1 worker2; do
  NFSROOT="/mnt/ssd/netboot/nfs/${w}/etc/systemd/system"
  sudo ln -sf /dev/null "${NFSROOT}/bluetooth-hciattach.service"
  sudo ln -sf /dev/null "${NFSROOT}/wpa_supplicant.service"
  sudo ln -sf /dev/null "${NFSROOT}/ModemManager.service"
  sudo ln -sf /dev/null "${NFSROOT}/avahi-daemon.service"
  sudo ln -sf /dev/null "${NFSROOT}/avahi-daemon.socket"
done
```

### NFS server threads

Con 3 workers cargando a la vez, aumentar threads evita contención:

```bash
# /etc/default/nfs-kernel-server
RPCNFSDCOUNT=16   # default era 8
sudo systemctl restart nfs-kernel-server
```

### Maestro — servicios masked

```bash
sudo systemctl mask \
  chrony-wait.service \
  rtkit-daemon.service \
  accounts-daemon.service \
  power-profiles-daemon.service \
  loadcpufreq.service \
  cpufrequtils.service \
  systemd-udev-settle.service
```

> ✅ **Armbian en OPi6+ COMPLETADO (Abril 2026)**: Imagen Armbian Ubuntu 24.04 Noble 26.2.1, kernel `6.18.8-current-arm64`, instalado en WD Black 512 GB NVMe. Ahora toda la red corre Armbian Noble — maestro en kernel 6.18.8, workers en 6.18.8/6.18.9. Ver [MIGRACION-ARMBIAN-OPI6PLUS.md](MIGRACION-ARMBIAN-OPI6PLUS.md).
