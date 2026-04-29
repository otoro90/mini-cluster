# K3s en Workers Netboot (OPi5 + RPi4)

Guía específica para este mini-cluster: Orange Pi 6+ como control-plane y 3 workers que arrancan por red (NFS root).

## 1. Alcance y contexto

Esta guía asume que el netboot ya funciona correctamente:

- `worker1` (`192.168.1.211`) arranca por SPI U-Boot -> TFTP -> NFS
- `worker2` (`192.168.1.212`) arranca por SPI U-Boot -> TFTP -> NFS
- `worker3` (`192.168.1.213`) arranca por EEPROM PXE nativo -> TFTP -> NFS

Control-plane:

- `orangepi6plus` (`192.168.1.210`)

## 2. Restricciones críticas de este hardware

En estos kernels ARM (Armbian Noble actual):

- No existe `ip_tables.ko`; sí existe `nf_tables.ko`
- El root en NFS puede romper overlayfs de kernel para containerd
- En RPi4, K3s puede fallar si memory cgroups no están habilitados en cmdline

Implicaciones para K3s agent:

- Usar `--snapshotter=fuse-overlayfs`
- Usar `--kube-proxy-arg=proxy-mode=nftables`
- Cambiar iptables bundled de K3s a `xtables-nft-multi`

## 3. Instalar K3s server en el maestro

En `orangepi6plus`:

```bash
curl -sfL https://get.k3s.io | sh -
```

Validar:

```bash
echo 'M1gu3l.1990*' | sudo -S kubectl get nodes -o wide
```

Token del cluster:

```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```

## 4. Instalar K3s agent en un worker netboot

Ejemplo con cualquier worker (`worker1`, `worker2`, `worker3`):

```bash
# 1) Instalar agent
curl -sfL https://get.k3s.io | \
  K3S_URL='https://192.168.1.210:6443' \
  K3S_TOKEN='K10dd8855fe8c3ed719655efdf5310fc9c868c28802825dc239ddd110feb80adfec::server:dc42591fa3eeee232aca82dd70c2e542' \
  sh -s - agent

# 2) Instalar snapshotter compatible con root NFS
apt-get update && apt-get install -y fuse-overlayfs

# 3) Override systemd para snapshotter + nftables
mkdir -p /etc/systemd/system/k3s-agent.service.d
cat > /etc/systemd/system/k3s-agent.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=/usr/local/bin/k3s agent --snapshotter=fuse-overlayfs --kube-proxy-arg=proxy-mode=nftables
EOF

# 4) Forzar iptables bundled a nft
cd /var/lib/rancher/k3s/data/current/bin/aux
for i in iptables iptables-save iptables-restore ip6tables ip6tables-save ip6tables-restore; do
  ln -sf xtables-nft-multi "$i"
done

# 5) Reiniciar agente
systemctl daemon-reload
systemctl restart k3s-agent
systemctl status k3s-agent --no-pager
```

## 5. Requisito adicional para `worker3` (RPi4)

Si el journal muestra:

- `failed to find memory cgroup (v2)`

Debes revisar cmdline del kernel:

```bash
cat /proc/cmdline
```

Debe incluir:

- `cgroup_memory=1 cgroup_enable=memory`

Y no debe bloquear memory cgroup con:

- `cgroup_disable=memory`

En este cluster, se sirve desde TFTP en:

- `/mnt/ssd/netboot/tftp/cmdline.txt`
- `/mnt/ssd/netboot/tftp/worker3/cmdline.txt`

Tras cambiar cmdline, reiniciar `worker3`.

## 6. Verificación del cluster

Desde el maestro:

```bash
echo 'M1gu3l.1990*' | sudo -S kubectl get nodes -o wide
```

Estado esperado:

- `orangepi6plus` Ready (control-plane)
- `worker1` Ready
- `worker2` Ready
- `worker3` Ready

Verificación rápida de salud en worker:

```bash
journalctl -u k3s-agent -n 30 --no-pager
```

## 7. Mantenimiento y persistencia

Como los workers arrancan por NFS root:

- Cambios en `/etc` y `/var/lib/rancher/k3s` persisten en el rootfs NFS
- Tras actualización de K3s, revisar symlinks de iptables en:
  - `/var/lib/rancher/k3s/data/current/bin/aux/`

Comando de validación:

```bash
readlink -f /var/lib/rancher/k3s/data/current/bin/aux/iptables
```

Debe resolver a `xtables-nft-multi`.

## 8. Puertos mínimos a permitir (referencia K3s)

- `TCP 6443` (agents -> server)
- `UDP 8472` (Flannel VXLAN entre nodos)
- `TCP 10250` (kubelet API/metrics entre nodos)

Si usas otro CNI, ajusta según corresponda.

---

## 9. Optimización de tiempos de boot (verificado Abril 2026)

### Tiempos medidos antes/después

| Worker | Antes | Después |
|---|---|---|
| worker1/2 (OPi5 RK3588) | ~3-4 min | **~2 min** |
| worker3 (RPi4 BCM2711) | ~2-3 min | **~1 min 10 seg** |
| maestro (OPi6+ CIX P1) | ~23 seg | **~5-6 seg** (próx. reboot) |

### Maestro — servicios masked (efecto en próximo reboot)

```bash
# Elimina 17+ segundos de espera al boot
sudo systemctl mask \
  chrony-wait.service \
  rtkit-daemon.service \
  accounts-daemon.service \
  power-profiles-daemon.service \
  loadcpufreq.service \
  cpufrequtils.service \
  systemd-udev-settle.service
```

> **⚠️ Armbian en OPi6+**: NO recomendado. El SoC es **CIX P1 CD8160** — chip propietario
> sin soporte en Armbian. El kernel `6.1.44-cix` es el único BSP existente.

### Workers OPi5 — boot.cmd optimizado

El cambio de mayor impacto es `tftpblocksize`: pasa de 512 bytes (defecto) a 65464 bytes,
reduciendo los round-trips para transferir 58MB de ~120,000 a ~600 paquetes UDP.

```bash
# /mnt/ssd/netboot/tftp/workerX/boot.cmd
setenv tftpblocksize 65464
setenv tftpwindowsize 8
setenv bootargs "root=/dev/nfs nfsroot=192.168.1.210:/mnt/ssd/netboot/nfs/workerX,v3,tcp,nolock,rsize=131072,wsize=131072,timeo=600 rw ip=dhcp rootwait quiet console=ttyS2,1500000"
tftp ${kernel_addr_r} workerX/vmlinuz
tftp ${fdt_addr_r} workerX/dtb/rockchip/rk3588s-orangepi-5.dtb
tftp ${ramdisk_addr_r} workerX/initrd.img
booti ${kernel_addr_r} ${ramdisk_addr_r}:${filesize} ${fdt_addr_r}
```

Regenerando boot.scr tras editar boot.cmd:

```bash
mkimage -C none -A arm64 -T script -d /mnt/ssd/netboot/tftp/workerX/boot.cmd \
        /mnt/ssd/netboot/tftp/workerX/boot.scr
```

### Workers OPi5 — servicios masked en NFS root

```bash
# Ejecutar en el maestro (modifica el NFS root del worker)
for w in worker1 worker2; do
  NFSROOT="/mnt/ssd/netboot/nfs/${w}/etc/systemd/system"
  sudo ln -sf /dev/null "${NFSROOT}/bluetooth-hciattach.service"
  sudo ln -sf /dev/null "${NFSROOT}/wpa_supplicant.service"
  sudo ln -sf /dev/null "${NFSROOT}/ModemManager.service"
  sudo ln -sf /dev/null "${NFSROOT}/avahi-daemon.service"
  sudo ln -sf /dev/null "${NFSROOT}/avahi-daemon.socket"
done
```

### NFS server — más threads para boot simultáneo de 3 workers

```bash
# /etc/default/nfs-kernel-server
RPCNFSDCOUNT=16   # default: 8
sudo systemctl restart nfs-kernel-server
```
