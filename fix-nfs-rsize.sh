#!/bin/bash
set -e

WORKER_NAME=$(hostname)

mkdir -p /mnt/sd
mount /dev/mmcblk0p1 /mnt/sd

echo "Updating armbianEnv.txt to fix syntax error..."
cat <<EOF > /mnt/sd/armbianEnv.txt
verbosity=1
bootlogo=false
console=both
rootdev=/dev/nfs
rootfstype=ext4
extraargs=cma=256M nfsroot=192.168.1.210:/mnt/ssd/netboot/nfs/${WORKER_NAME},v3,tcp,nolock,rsize=131072,wsize=131072,timeo=600 rw ip=dhcp
overlay_prefix=rockchip-rk3588
fdtfile=rockchip/rk3588s-orangepi-5.dtb
EOF

umount /mnt/sd
echo "Fixed for ${WORKER_NAME}"
