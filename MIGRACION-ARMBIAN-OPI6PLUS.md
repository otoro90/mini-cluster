# Migración OrangePi 6+ → Armbian Ubuntu Noble 24.04

> **✅ COMPLETADO — Abril 2026**
>
> El maestro `orangepi6plus` corre **Armbian Ubuntu 24.04 Noble 26.2.1**, kernel `6.18.8-current-arm64`, en WD Black 512 GB NVMe. K3s v1.35.4+k3s1 operativo con 4/4 nodos Ready. La app Tramites (dev + prod) está desplegada y accesible vía traefik.

---

## Estado migración (Abril 2026)

| Ítem | Estado anterior | Estado actual ✅ |
|------|----------------|-----------------|
| OS maestro | Debian 12, kernel `6.1.44-cix` (vendor BSP) | Armbian Ubuntu 24.04 Noble 26.2.1, kernel `6.18.8-current-arm64` |
| SSD de boot | Predator SSD GM3500 1 TB (NVMe M.2) | **WD Black 512 GB (NVMe M.2)** |
| Workers | Sin cambios (Armbian Noble en NFS root) | Sin cambios ✓ |
| Kernel uniformidad | Maestro 6.1.44 ≠ workers 6.18.8 | **Todos en 6.18.8/6.18.9** ✓ |
| ingress controller | ingress-nginx (Pending — conflicto hostPorts) | **traefik** (bundled K3s, funcionando) |
| K3s version | v1.34.x | **v1.35.4+k3s1** (maestro) / v1.34.6+k3s1 (workers) |

---

## Contexto original (plan de migración)

---

## Inventario de datos a migrar

| Datos | Tamaño | Ruta actual |
|-------|--------|-------------|
| Worker1 NFS root | 2.3 GB | `/mnt/ssd/netboot/nfs/worker1/` |
| Worker2 NFS root | 2.8 GB | `/mnt/ssd/netboot/nfs/worker2/` |
| Worker3 NFS root | 2.6 GB | `/mnt/ssd/netboot/nfs/worker3/` |
| TFTP (kernels+dtb) | 573 MB | `/mnt/ssd/netboot/tftp/` |
| K8s PVC data (PostgreSQL) | 48 MB | `/mnt/ssd/k8s-volumes/` |
| K3s server data | 20 MB | `/var/lib/rancher/k3s/server/` |
| **Total mínimo** | **~8.4 GB** | — |

**Servicios a reinstalar:** `dnsmasq`, `nfs-kernel-server`, `k3s` (server), `worker-nat`, `helm`, `docker`

---

## Prerrequisitos

### Hardware necesario
- [ ] WD Black 512 GB M.2 NVMe (nuevo, sin usar)
- [ ] **Enclosure USB-to-NVMe** (imprescindible: el OPi6+ tiene UN solo slot M.2 ocupado por el Predator)
- [ ] Cable/adaptador USB 3.0 Type-A libre en el OPi6+
- [ ] Mac con Balena Etcher o acceso a `dd`

### Imagen Armbian
```bash
# Descargar en el Mac
# URL directa Armbian Ubuntu 24.04 Noble CLI (kernel 6.18.8, ~862 MB, Estable)
curl -L -o armbian-orangepi6plus-noble.img.xz \
  "https://dl.armbian.com/orangepi6-plus/Noble_current_minimal"

# Verificar checksum (obtener SHA256 desde la página de descarga)
# https://www.armbian.com/boards/orangepi6-plus/
```

---

## Fase 0 — Backup completo (maestro corriendo, sin apagar nada)

> ⚠️ **Esta fase se hace con el cluster OPERATIVO.** No se toca nada del cluster aún.

### 0.1 Crear directorio de backup en Mac

```bash
# En el Mac — crear directorio de backup local
mkdir -p ~/opi6plus-backup/{k3s,config,k8s}
cd ~/opi6plus-backup
```

### 0.2 Backup K3s server (token + certs + DB — datos críticos)

```bash
# Desde el Mac — tar del directorio K3s server completo
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S tar czf /tmp/k3s-server-backup.tar.gz \
    /var/lib/rancher/k3s/server/"

# Descargar al Mac
sshpass -p 'M1gu3l.1990*' scp \
  orangepi@192.168.1.210:/tmp/k3s-server-backup.tar.gz \
  ~/opi6plus-backup/k3s/

# Verificar contenido
tar tzf ~/opi6plus-backup/k3s/k3s-server-backup.tar.gz | head -20
```

> **¿Por qué es crítico?** El token K3s cifra el bootstrap del datastore SQLite. Sin el mismo token, los workers no se pueden reconectar y las snapshots son inútiles.

### 0.3 Backup de configuraciones del sistema

```bash
# dnsmasq
sshpass -p 'M1gu3l.1990*' scp \
  orangepi@192.168.1.210:/etc/dnsmasq.conf \
  ~/opi6plus-backup/config/

# NFS exports
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S cat /etc/exports" \
  > ~/opi6plus-backup/config/exports

# worker-nat service
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S cat /etc/systemd/system/worker-nat.service" \
  > ~/opi6plus-backup/config/worker-nat.service

# kubeconfig
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S cat /etc/rancher/k3s/k3s.yaml" \
  > ~/opi6plus-backup/k3s/k3s.yaml.bak
```

### 0.4 Anotar el token K3s (doble verificación)

```bash
TOKEN=$(sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S cat /var/lib/rancher/k3s/server/token")
echo "TOKEN: $TOKEN"
# Guardar también en archivo local
echo "$TOKEN" > ~/opi6plus-backup/k3s/node-token.txt
```

Token actual conocido:
```
K10dd8855fe8c3ed719655efdf5310fc9c868c28802825dc239ddd110feb80adfec::server:dc42591fa3eeee232aca82dd70c2e542
```

### 0.5 Backup K8s PVC data (PostgreSQL)

```bash
# Los PVCs solo son 48 MB — rsync rápido al Mac
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S tar czf /tmp/k8s-volumes-backup.tar.gz \
    /mnt/ssd/k8s-volumes/"

sshpass -p 'M1gu3l.1990*' scp \
  orangepi@192.168.1.210:/tmp/k8s-volumes-backup.tar.gz \
  ~/opi6plus-backup/k8s/
```

### 0.6 Verificar backup

```bash
ls -lh ~/opi6plus-backup/k3s/ ~/opi6plus-backup/config/ ~/opi6plus-backup/k8s/
# Esperado: k3s-server-backup.tar.gz, node-token.txt, k3s.yaml.bak
#           dnsmasq.conf, exports, worker-nat.service
#           k8s-volumes-backup.tar.gz
```

---

## Fase 1 — Preparar WD Black con Armbian (desde el Mac)

### 1.1 Flash de la imagen

```bash
# Descomprimir y flashear (ajustar /dev/diskN al WD Black)
# PRIMERO identificar el disco correcto:
diskutil list  # buscar el WD Black por tamaño (≈512 GB)

# Flash con dd (ajustar disk2 al disco correcto — VERIFICAR antes de ejecutar)
xz -dc armbian-orangepi6plus-noble.img.xz | \
  sudo dd of=/dev/rdisk2 bs=4m status=progress
```

> ⚠️ Verificar **dos veces** el device antes de `dd`. Usar `diskutil list` para confirmar cuál es el WD Black.

### 1.2 Expulsar y preparar

```bash
diskutil eject /dev/disk2
```

---

## Fase 2 — Primera conexión: WD Black vía USB al OPi6+

> **El Predator sigue en M.2. El WD Black se conecta en USB (enclosure).** El cluster sigue funcionando en esta etapa.

### 2.1 Conectar WD Black vía enclosure USB al OPi6+

```bash
# Verificar que el maestro detecta el nuevo disco
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S bash -c 'lsblk -o NAME,SIZE,MODEL,TRAN'"
# Debería aparecer sda (USB) con ~476G (WD Black)
```

### 2.2 Montar partición Armbian del WD Black

```bash
# El WD Black tendrá 2 particiones: p1 (boot/EFI ~200M) y p2 (root)
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S bash -c '
    mkdir -p /mnt/wdblack
    mount /dev/sda2 /mnt/wdblack
    ls /mnt/wdblack
  '"
```

---

## Fase 3 — Migrar datos al WD Black (con cluster activo)

> Esta es la fase más larga. Los workers siguen funcionando desde el NFS del Predator.

### 3.1 Copiar NFS roots de workers (8+ GB — operación larga)

```bash
# Aprox. 30-60 minutos según velocidad USB
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S bash -c '
    mkdir -p /mnt/wdblack/mnt/ssd/netboot
    rsync -avz --progress \
      /mnt/ssd/netboot/ \
      /mnt/wdblack/mnt/ssd/netboot/
  '"
```

### 3.2 Copiar K8s PVC data

```bash
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S bash -c '
    mkdir -p /mnt/wdblack/mnt/ssd/k8s-volumes
    rsync -avz --progress \
      /mnt/ssd/k8s-volumes/ \
      /mnt/wdblack/mnt/ssd/k8s-volumes/
  '"
```

### 3.3 Copiar K3s server data

```bash
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S bash -c '
    mkdir -p /mnt/wdblack/var/lib/rancher/k3s
    rsync -avz --progress \
      /var/lib/rancher/k3s/ \
      /mnt/wdblack/var/lib/rancher/k3s/
  '"
```

### 3.4 Verificar que la copia esté completa

```bash
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S bash -c '
    echo \"=== WD Black /mnt/ssd ===\" 
    du -sh /mnt/wdblack/mnt/ssd/netboot/nfs/worker{1,2,3}
    echo \"=== K3s token en WD Black ===\"
    cat /mnt/wdblack/var/lib/rancher/k3s/server/token
  '"
```

---

## Fase 4 — Configurar Armbian en WD Black (chroot desde sistema activo)

> Instalar paquetes y configurar servicios en Armbian haciendo chroot al WD Black **sin apagar el cluster**.

### 4.1 Preparar el entorno chroot

```bash
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S bash -c '
    # Montar sistema de archivos virtuales para chroot
    mount --bind /dev  /mnt/wdblack/dev
    mount --bind /proc /mnt/wdblack/proc
    mount --bind /sys  /mnt/wdblack/sys
    mount --bind /run  /mnt/wdblack/run
  '"
```

### 4.2 Copiar configuraciones al WD Black

```bash
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S bash -c '
    # dnsmasq config
    cp /etc/dnsmasq.conf /mnt/wdblack/etc/dnsmasq.conf

    # NFS exports
    cp /etc/exports /mnt/wdblack/etc/exports

    # worker-nat service
    cp /etc/systemd/system/worker-nat.service \
       /mnt/wdblack/etc/systemd/system/worker-nat.service
  '"
```

### 4.3 Configurar red estática (IP 192.168.1.210) en Armbian

Armbian Noble usa NetworkManager. Crear la conexión estática:

```bash
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S bash -c '
    mkdir -p /mnt/wdblack/etc/NetworkManager/system-connections/

    cat > /mnt/wdblack/etc/NetworkManager/system-connections/cluster.nmconnection << EOF
[connection]
id=cluster
type=ethernet
interface-name=eth0
autoconnect=true

[ethernet]

[ipv4]
method=manual
addresses=192.168.1.210/24
gateway=192.168.1.1
dns=8.8.8.8;1.1.1.1;

[ipv6]
method=disabled
EOF

    chmod 600 /mnt/wdblack/etc/NetworkManager/system-connections/cluster.nmconnection
  '"
```

> **Nota:** Si en Armbian la interfaz se llama diferente a `eth0` (p.ej. `enP4p1s0`), actualizar `interface-name` tras el primer boot. Ver [Fase 6, punto 6.2](#62-verificar-nombre-de-interfaz-de-red).

### 4.4 Instalar paquetes en Armbian vía chroot

```bash
# Script que se ejecutará dentro del chroot
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S chroot /mnt/wdblack /bin/bash -c '
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -q \
      dnsmasq \
      nfs-kernel-server \
      nfs-common \
      fuse-overlayfs \
      iptables \
      nftables \
      sshpass \
      curl \
      wget \
      htop \
      rsync \
      docker.io
    
    # Configurar threads NFS
    sed -i \"s/RPCNFSDCOUNT=.*/RPCNFSDCOUNT=16/\" /etc/default/nfs-kernel-server

    # Habilitar servicios
    systemctl enable dnsmasq
    systemctl enable nfs-kernel-server
    systemctl enable worker-nat
    systemctl enable docker
    
    # Deshabilitar servicios innecesarios (igual que optimizaciones actuales)
    systemctl disable bluetooth-hciattach 2>/dev/null || true
    systemctl disable wpa_supplicant 2>/dev/null || true
    systemctl disable avahi-daemon 2>/dev/null || true
    systemctl disable chrony-wait 2>/dev/null || true
    systemctl disable ModemManager 2>/dev/null || true
    
    echo \"Paquetes instalados OK\"
  '"
```

### 4.5 Configurar /etc/hosts y hostname

```bash
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S bash -c '
    echo \"orangepi6plus\" > /mnt/wdblack/etc/hostname

    cat > /mnt/wdblack/etc/hosts << EOF
127.0.0.1       localhost
127.0.1.1       orangepi6plus
192.168.1.210   orangepi6plus
192.168.1.211   worker1
192.168.1.212   worker2
192.168.1.213   worker3
EOF
  '"
```

### 4.6 Instalar K3s en chroot (pre-configurar)

```bash
TOKEN="K10dd8855fe8c3ed719655efdf5310fc9c868c28802825dc239ddd110feb80adfec::server:dc42591fa3eeee232aca82dd70c2e542"

sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S chroot /mnt/wdblack /bin/bash -c '
    # Instalar K3s con el mismo token del cluster actual
    curl -sfL https://get.k3s.io | \
      K3S_TOKEN=\"${TOKEN}\" \
      INSTALL_K3S_EXEC=\"server --bind-address=192.168.1.210 --advertise-address=192.168.1.210 --node-ip=192.168.1.210 --flannel-iface=eth0\" \
      sh -

    # Deshabilitar K3s para que no arranque antes de restaurar los datos del server
    systemctl disable k3s
    echo \"K3s instalado, servicio deshabilitado hasta restaurar datos\"
  '"
```

### 4.7 Restaurar K3s server data (token + certs + SQLite DB)

```bash
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S bash -c '
    # Los datos ya se copiaron en Fase 3.3 con rsync
    # Solo verificar que el token esté correcto
    echo \"Token en WD Black:\"
    cat /mnt/wdblack/var/lib/rancher/k3s/server/token

    echo \"SQLite DB presente:\"
    ls -lh /mnt/wdblack/var/lib/rancher/k3s/server/db/ 2>/dev/null || echo \"no hay db (se creará al arrancar)\"
  '"
```

### 4.8 Instalar Helm en WD Black

```bash
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S chroot /mnt/wdblack /bin/bash -c '
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    helm version
  '"
```

### 4.9 Limpiar chroot

```bash
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S bash -c '
    umount /mnt/wdblack/dev
    umount /mnt/wdblack/proc
    umount /mnt/wdblack/sys
    umount /mnt/wdblack/run
    sync
    umount /mnt/wdblack
    echo \"WD Black desmontado OK\"
  '"
```

---

## Fase 5 — Swap físico de SSDs y primer boot en Armbian

> ⚠️ **CLUSTER SE DETIENE EN ESTE PUNTO.** Downtime estimado: 15-30 minutos hasta que K3s esté de nuevo operativo.

### 5.1 Apagar el cluster limpiamente

```bash
# Drenar el nodo maestro primero (opcional pero recomendado)
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S bash -c 'KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl drain orangepi6plus --ignore-daemonsets --delete-emptydir-data 2>&1 | tail -5'"

# Parar K3s server
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S systemctl stop k3s"

# Apagar el maestro
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S shutdown -h now"
```

### 5.2 Swap físico

1. Esperar 10 segundos tras el apagado
2. Desconectar la alimentación del OPi6+
3. **Extraer el Predator del slot M.2** — guardarlo en lugar seguro (es el rollback)
4. **Insertar el WD Black en el slot M.2**
5. Reconectar la alimentación

### 5.3 Primer boot en Armbian

El OPi6+ debería arrancar directamente desde el WD Black en M.2. Conectar monitor/teclado o esperar ping:

```bash
# Desde Mac — esperar a que el OPi6+ responda (puede tardar 1-2 minutos)
for i in {1..30}; do
  if ping -c 1 -W 1 192.168.1.210 &>/dev/null; then
    echo "Maestro UP tras $((i*5)) segundos"
    break
  fi
  echo "Esperando... ($i/30)"
  sleep 5
done
```

---

## Fase 6 — Post-boot: configuración y validación en Armbian

### 6.1 Verificar acceso SSH

```bash
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "uname -a && hostname && ip -4 addr show | grep inet"
# Esperado: kernel 6.18.8-current-..., orangepi6plus, 192.168.1.210
```

> **Si no conecta por SSH**: Armbian en primer boot puede requerir configuración desde consola serial/monitor. La contraseña por defecto es `1234` para root, y te pedirá cambiarla. Crear usuario `orangepi` con `M1gu3l.1990*` si no existe.

### 6.2 Verificar nombre de interfaz de red

```bash
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "ip link show | grep -E '^[0-9]+:' | awk '{print \$2}'"
```

Si la interfaz NO es `eth0`, actualizar los archivos correspondientes:

```bash
IFACE="eth0"  # Cambiar si es diferente (p.ej. enP4p1s0)

# Actualizar dnsmasq
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S sed -i \"s/^interface=.*/interface=${IFACE}/\" /etc/dnsmasq.conf"

# Actualizar worker-nat
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S sed -i \"s/-o eth0/-o ${IFACE}/g\" /etc/systemd/system/worker-nat.service"
  
# Actualizar NetworkManager connection
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S sed -i \"s/interface-name=eth0/interface-name=${IFACE}/\" \
    /etc/NetworkManager/system-connections/cluster.nmconnection"
```

### 6.3 Verificar iptables disponible (worker-nat usa iptables)

```bash
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S bash -c '
    iptables -L INPUT --line-numbers 2>&1 | head -5
    echo \"iptables exit: \$?\"
    lsmod | grep -E \"ip_tables|nf_tables\" | head -5
  '"
```

**Si iptables NO está disponible** (solo nf_tables), convertir worker-nat a nftables:

```bash
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S bash -c '
    cat > /etc/systemd/system/worker-nat.service << EOF
[Unit]
Description=NAT masquerade for netboot workers (nftables)
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/nft add rule ip nat POSTROUTING ip saddr 192.168.1.0/24 oifname eth0 masquerade
ExecStartPre=/usr/sbin/nft add table ip nat 2>/dev/null; /usr/sbin/nft add chain ip nat POSTROUTING { type nat hook postrouting priority 100 \\; } 2>/dev/null; /bin/true
ExecStop=/usr/sbin/nft flush ruleset

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
  '"
```

> Ajustar `eth0` al nombre real de la interfaz de internet si es diferente.

### 6.4 Verificar y arrancar servicios base

```bash
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S bash -c '
    # IP forwarding (necesario para workers)
    sysctl -w net.ipv4.ip_forward=1
    echo \"net.ipv4.ip_forward=1\" >> /etc/sysctl.d/99-k3s.conf
    
    # Arrancar worker-nat
    systemctl enable --now worker-nat
    systemctl status worker-nat --no-pager
    
    # Arrancar dnsmasq
    systemctl enable --now dnsmasq
    systemctl status dnsmasq --no-pager | head -10
    
    # Arrancar NFS server
    systemctl enable --now nfs-kernel-server
    systemctl status nfs-kernel-server --no-pager | head -10
    
    # Exportar NFS
    exportfs -ra
    exportfs -v
  '"
```

### 6.5 Arrancar K3s server

```bash
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S bash -c '
    systemctl enable --now k3s
    sleep 10
    KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get nodes
  '"
```

> Si K3s no arranca consultar: `sudo journalctl -u k3s -n 50 --no-pager`

---

## Fase 7 — Reconectar workers al cluster

Los workers arrancan por PXE desde el maestro. Una vez que `dnsmasq` + NFS + K3s están operativos, los workers se reconectan automáticamente al reiniciar.

### 7.1 Reiniciar workers (secuencial)

```bash
# Worker 1
sshpass -p '123456' ssh root@192.168.1.211 "systemctl restart k3s-agent"

# Worker 2
sshpass -p '123456' ssh root@192.168.1.212 "systemctl restart k3s-agent"

# Worker 3
sshpass -p '123456' ssh root@192.168.1.213 "systemctl restart k3s-agent"
```

### 7.2 Verificar todos los nodos Ready

```bash
# Esperar 60 segundos para que los workers se reconecten
sleep 60
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S bash -c \
    'KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get nodes -o wide'"
# Esperado: 4 nodos en estado Ready
```

---

## Fase 8 — Restaurar stack K8s

### 8.1 Verificar pods del sistema

```bash
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S bash -c \
    'KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get pods -A'"
```

> Si los datos de K3s se copiaron correctamente (Fase 3.3), todos los pods existentes deberían reaparecer automáticamente. Los workloads como Argo CD, ingress-nginx y local-path-provisioner se restaurarán solos al leer el estado del datastore SQLite.

### 8.2 Si K3s no restaura los workloads previos (datastore vacío)

Si el SQLite no se recuperó (K3s comenzó de cero), reinstalar el stack mínimo:

```bash
# Argo CD con Helm
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S bash -c '
    KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    export KUBECONFIG

    # Argo CD
    kubectl create namespace argocd
    helm repo add argo https://argoproj.github.io/argo-helm
    helm repo update
    helm install argo-cd argo/argo-cd \
      --namespace argocd \
      --version 3.3.8 \
      --set global.nodeSelector.\"kubernetes\\.io/hostname\"=orangepi6plus

    # Ingress-nginx
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm install ingress-nginx ingress-nginx/ingress-nginx \
      --namespace ingress-nginx --create-namespace \
      --set controller.kind=DaemonSet \
      --set controller.hostNetwork=true \
      --set controller.nodeSelector.\"kubernetes\\.io/hostname\"=orangepi6plus

    # Local-path-provisioner con la ruta al SSD
    kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.30/deploy/local-path-storage.yaml
    kubectl annotate storageclass local-path \
      storageclass.kubernetes.io/is-default-class=true
  '"
```

### 8.3 Restaurar secrets de Argo CD

```bash
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S bash -c '
    KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    export KUBECONFIG

    # Secret del repositorio GitOps Tramites
    kubectl create secret generic argocd-repo-tramites \
      --namespace argocd \
      --from-literal=type=git \
      --from-literal=url=https://github.com/otoro90/tramites \
      --from-literal=password=<GITOPS_PAT_AQUI> \
      --from-literal=username=otoro90
    kubectl label secret argocd-repo-tramites \
      -n argocd argocd.argoproj.io/secret-type=repository

    # imagePullSecret para GHCR
    kubectl create secret docker-registry ghcr-pull-secret \
      --docker-server=ghcr.io \
      --docker-username=otoro90 \
      --docker-password=<GHCR_PAT_AQUI> \
      -n tramites-dev
    kubectl create secret docker-registry ghcr-pull-secret \
      --docker-server=ghcr.io \
      --docker-username=otoro90 \
      --docker-password=<GHCR_PAT_AQUI> \
      -n tramites-prod
    kubectl create secret docker-registry ghcr-pull-secret \
      --docker-server=ghcr.io \
      --docker-username=otoro90 \
      --docker-password=<GHCR_PAT_AQUI> \
      -n argocd
  '"
```

### 8.4 Re-aplicar Argo CD apps

```bash
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S bash -c '
    KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl apply -f /path/to/manifests/tramites/argocd-apps.yaml
  '"

# Desde Mac (repo local):
sshpass -p 'M1gu3l.1990*' scp \
  /Users/omigueltoro/Repo/Personal/mini-cluster/manifests/tramites/argocd-apps.yaml \
  orangepi@192.168.1.210:/tmp/
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S bash -c \
    'KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl apply -f /tmp/argocd-apps.yaml'"
```

### 8.5 Restaurar Docker Registry local

```bash
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S bash -c '
    KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl apply -f /path/to/manifests/registry/
  '"
```

---

## Fase 9 — Validación completa

### 9.1 Checklist del cluster

```bash
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S bash -c '
    echo \"=== NODOS ===\"
    KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get nodes -o wide

    echo \"=== PODS SISTEMA ===\"
    KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get pods -n kube-system

    echo \"=== PODS ARGOCD ===\"
    KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get pods -n argocd

    echo \"=== SERVICIOS MAESTRO ===\"
    systemctl is-active k3s dnsmasq nfs-kernel-server worker-nat docker

    echo \"=== NFS EXPORTS ===\"
    exportfs -v

    echo \"=== NAT RULE ===\"
    iptables -t nat -L POSTROUTING -n -v | grep MASQUERADE 2>/dev/null || \
    nft list table ip nat 2>/dev/null
  '"
```

### 9.2 Verificar conectividad workers a internet

```bash
sshpass -p '123456' ssh root@192.168.1.211 "curl -s ifconfig.me && echo ''"
sshpass -p '123456' ssh root@192.168.1.212 "curl -s ifconfig.me && echo ''"
sshpass -p '123456' ssh root@192.168.1.213 "curl -s ifconfig.me && echo ''"
```

### 9.3 Verificar Argo CD

```bash
# Desde Mac — abrir http://argocd.local (añadir 192.168.1.210 argocd.local a /etc/hosts)
# Login: admin / ipb4EnoshkInEr4g
# tramites-dev debe aparecer como Synced/Healthy
curl -s http://argocd.local/api/v1/applications | python3 -m json.tool | grep -E '"name"|"health"|"sync"'
```

### 9.4 Verificar aplicación tramites-dev

```bash
# Frontend
curl -sI http://tramites-dev.local | head -5

# API health
curl -s http://tramites-api-dev.local/health
```

---

## Procedimiento de Rollback

> Aplicar si cualquier fase falla y no hay forma de seguir adelante.

### Rollback completo (≤ 5 minutos)

1. Apagar el OPi6+:
   ```bash
   sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
     "echo 'M1gu3l.1990*' | sudo -S shutdown -h now" 2>/dev/null || true
   ```
2. Esperar 10 segundos
3. **Extraer WD Black del slot M.2**
4. **Insertar Predator en el slot M.2**
5. Encender el OPi6+
6. El sistema arrancará exactamente como antes (Debian 12, K3s operativo, workers reconectándose)

```bash
# Verificar rollback exitoso (desde Mac)
sleep 90  # esperar boot del maestro
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 "uname -a"
# Esperado: Linux orangepi6plus 6.1.44-cix ...
```

---

## Configuraciones de referencia

### dnsmasq.conf actual (a copiar tal cual)

```ini
interface=eth0
port=0
log-dhcp
log-queries

dhcp-range=192.168.1.210,192.168.1.240,12h

# Detectar vendor class
dhcp-vendorclass=set:uboot,U-Boot
dhcp-vendorclass=set:pxeclient,PXEClient

# CLAVE RPi4: devolver option 60=PXEClient
dhcp-option=tag:pxeclient,60,PXEClient

# Worker 1
dhcp-host=76:86:c1:88:66:d7,set:worker1,192.168.1.211,worker1
dhcp-option=tag:worker1,tag:uboot,option:bootfile-name,worker1/boot.scr
dhcp-option=tag:worker1,tag:pxeclient,option:bootfile-name,pxelinux.cfg/01-76-86-c1-88-66-d7
dhcp-option=tag:worker1,17,192.168.1.210:/mnt/ssd/netboot/nfs/worker1

# Worker 2
dhcp-host=9e:67:0e:af:20:e1,set:worker2,192.168.1.212,worker2
dhcp-option=tag:worker2,tag:uboot,option:bootfile-name,worker2/boot.scr
dhcp-option=tag:worker2,tag:pxeclient,option:bootfile-name,pxelinux.cfg/01-9e-67-0e-af-20-e1
dhcp-option=tag:worker2,17,192.168.1.210:/mnt/ssd/netboot/nfs/worker2

# Worker 3 (RPi 4)
dhcp-host=dc:a6:32:e9:2a:be,set:worker3,192.168.1.213,worker3
dhcp-boot=tag:worker3,bootcode.bin,,192.168.1.210
dhcp-option=tag:worker3,66,192.168.1.210
dhcp-option=tag:worker3,17,192.168.1.210:/mnt/ssd/netboot/nfs/worker3

enable-tftp
tftp-root=/mnt/ssd/netboot/tftp
```

### /etc/exports actual

```
/mnt/ssd/netboot/nfs/worker1 192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
/mnt/ssd/netboot/nfs/worker2 192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
/mnt/ssd/netboot/nfs/worker3 192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
```

### /etc/hosts del cliente Mac (sin cambios tras migración)

```
192.168.1.210  tramites-dev.local tramites-api-dev.local
192.168.1.210  tramites.forjanova.local tramites-api.forjanova.local
192.168.1.210  argocd.local registry.192.168.1.210.nip.io
```

---

## Riesgos conocidos y mitigaciones

| Riesgo | Probabilidad | Mitigación |
|--------|-------------|------------|
| Interfaz red con nombre diferente (`enP4p1s0` en vez de `eth0`) | Media | Verificar en Fase 6.2 y actualizar configs antes de arrancar servicios |
| `iptables` no disponible en kernel 6.18.8 CIX | Baja-Media | worker-nat.service alternativo con nftables ya documentado (Fase 6.3) |
| K3s no restaura SQLite (inicio vacío) | Baja | Re-instalar stack con Helm + aplicar argocd-apps.yaml (Fase 8.2) |
| Workers no se reconectan tras reiniciar K3s | Baja | Los certs en NFS root son los mismos; reiniciar `k3s-agent` en cada worker |
| TFTP/NFS no funciona en Armbian por firewall | Baja | `ufw disable` o permitir ports 69/udp, 111/tcp, 2049/tcp |
| Primer boot Armbian requiere consola (cambio de contraseña) | Alta | Tener monitor+teclado conectados para el primer boot |

---

## Checklist final pre-ejecución

- [ ] WD Black 512 GB disponible y en enclosure USB-to-NVMe
- [ ] Imagen Armbian Ubuntu Noble descargada y verificada
- [ ] Backup Fase 0 completado y verificado en Mac
- [ ] Monitor+teclado listos para primer boot
- [ ] Token K3s anotado: `K10dd8855fe8c3ed719655efdf5310fc9c868c28802825dc239ddd110feb80adfec::server:dc42591fa3eeee232aca82dd70c2e542`
- [ ] Credenciales Argo CD anotadas: `admin / ipb4EnoshkInEr4g`
- [ ] PAT de GitHub (GITOPS_PAT) disponible para re-crear secrets
- [ ] /etc/hosts del Mac actualizado con `192.168.1.210 argocd.local ...`

---

*Generado: Mayo 2026 — Forjanova Labs Mini-Cluster*
