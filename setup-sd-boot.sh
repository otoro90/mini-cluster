#!/bin/bash
set -e

WORKER_NAME=$1
if [ -z "$WORKER_NAME" ]; then
    echo "Usage: $0 <worker-name>"
    exit 1
fi

echo "Setting up SD card boot bridge for $WORKER_NAME..."

# Ensure mmcblk0 exists
if ! lsblk | grep -q mmcblk0; then
    echo "ERROR: /dev/mmcblk0 not found! Is the MicroSD card inserted?"
    exit 1
fi

echo "Wiping partition table on /dev/mmcblk0..."
dd if=/dev/zero of=/dev/mmcblk0 bs=1M count=10
sync

echo "Flashing U-Boot to SD card first..."
# Orange Pi 5 U-Boot is written at sector 64 (32KB offset)
dd if=/usr/lib/linux-u-boot-current-orangepi5/u-boot-rockchip.bin of=/dev/mmcblk0 bs=32k seek=1 conv=notrunc
sync

echo "Creating new ext4 partition..."
# We start at 16MiB to ensure we don't overwrite U-Boot which is ~9.6MB.
parted -s /dev/mmcblk0 mklabel msdos
parted -s /dev/mmcblk0 mkpart primary ext4 16MiB 100%
partprobe /dev/mmcblk0 || true
sync
sleep 2

echo "Formatting partition as ext4..."
mkfs.ext4 -F /dev/mmcblk0p1

echo "Mounting SD card..."
mkdir -p /mnt/sd
mount /dev/mmcblk0p1 /mnt/sd

echo "Copying /boot contents to SD card..."
cp -a /boot/* /mnt/sd/

echo "Configuring armbianEnv.txt for NFS root..."
cat <<EOF > /mnt/sd/armbianEnv.txt
verbosity=1
bootlogo=false
console=both
rootdev=/dev/nfs
rootfstype=ext4
extraargs=cma=256M nfsroot=192.168.1.210:/mnt/ssd/netboot/nfs/${WORKER_NAME},v3,tcp,nolock,rsize=1048576,wsize=1048576,timeo=600 rw ip=dhcp
overlay_prefix=rockchip-rk3588
fdtfile=rockchip/rk3588s-orangepi-5.dtb
EOF

echo "Unmounting..."
umount /mnt/sd
echo "Done! The SD card is now ready to boot the kernel locally and mount NFS."
