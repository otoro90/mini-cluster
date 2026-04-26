# Guía Maestra Cluster Netboot - Forjanova Labs

Este documento detalla la configuración de un cluster ARM64 donde los nodos trabajadores arrancan 100% desde la red (NFS/TFTP) gestionados por un nodo Maestro.

## 1. Identificación del Hardware (Inventario)
*   **Master (OPi 6 Plus):** 192.168.1.210
*   **Worker 1 (OPi 5):** 192.168.1.211 | MAC: `76:86:c1:88:66:d7`
*   **Worker 2 (OPi 5):** 192.168.1.212 | MAC: `18:47:3d:fc:0f:d9`
*   **Worker 3 (RPi 4):** 192.168.1.213 | MAC: `dc:a6:32:e9:2a:be` (Ping: 192.168.1.231 temporal)

---

## 2. Configuración del Servidor Maestro
El Maestro centraliza el arranque mediante `dnsmasq` (DHCP Proxy + TFTP) y sirve los sistemas de archivos mediante `nfs-kernel-server`.

### Estructura en SSD:
*   `/mnt/ssd/netboot/tftp/`: Archivos de arranque (boot.scr, kernel, dtb).
*   `/mnt/ssd/netboot/nfs/`: Raíz del sistema (rootfs) para cada worker.

---

## 3. Estrategias de Arranque (Netboot)

### 3.1 Nodos Orange Pi 5 (Lógica "Boot Bridge")
Las OPi 5 requieren una Micro-SD pequeña para iniciar el proceso:
1.  **U-Boot:** Se graban los primeros 16MB de una imagen Armbian oficial para obtener el cargador de arranque.
2.  **Limpieza de Tabla:** Se aplica una tabla `msdos` (MBR) nueva para ignorar la tabla gigante de la imagen original.
3.  **Partición de Salto:** Una partición FAT32 con un archivo `boot.scr` que redirige el arranque hacia la IP del Maestro.
    *   *Comando de creación:* `mkimage -C none -A arm64 -T script -d boot.cmd boot.scr`

### 3.2 Nodo Raspberry Pi 4 (PXE Nativo)
La RPi 4 puede arrancar sin SD si se ha actualizado su EEPROM:
1.  Busca archivos en la raíz del TFTP del Maestro.
2.  Requiere `start4.elf`, `fixup4.dat`, `config.txt` y `cmdline.txt` en el servidor TFTP.
3.  `cmdline.txt` debe configurarse con: `root=/dev/nfs nfsroot=192.168.1.210:/path/to/worker3`.

---

## 4. Parcheo del Sistema de Archivos (FSTAB)
Para que un sistema clonado de una SD funcione por NFS, es **OBLIGATORIO** modificar su `/etc/fstab` interno:
```bash
# Comentar el montaje por UUID (disco local)
# UUID=... / ext4 defaults 0 1

# Añadir el montaje por red
192.168.1.210:/mnt/ssd/netboot/nfs/workerX / nfs defaults,v3,tcp 0 0
```

---

## 5. Troubleshooting (Comandos Útiles)
*   **Ver logs de arranque:** `sudo journalctl -u dnsmasq -f`
*   **Ver montajes NFS activos:** `showmount -e 192.168.1.210`
*   **Reiniciar servicios:** `sudo systemctl restart dnsmasq nfs-kernel-server`
