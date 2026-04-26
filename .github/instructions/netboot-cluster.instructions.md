---
applyTo: "cluster-config/**,NETBOOT_GUIDE.md,docs-clean/**"
---

# Netboot Cluster Instructions

Al trabajar en archivos de netboot de este repositorio:

- Preserva arquitectura real del laboratorio: maestro `192.168.1.210` + workers `.211`, `.212`, `.213`.
- No elimines la distinción de boot path:
  - OPi5: SPI U-Boot -> TFTP -> NFS
  - RPi4: EEPROM PXE nativo -> TFTP -> NFS
- En ejemplos dnsmasq, mantén lógica por vendor class (`U-Boot` vs `PXEClient`) y tags por MAC.
- Para RPi4, conserva explícitamente `dhcp-boot` + `option 66` para TFTP server.
- Mantén documentación en español para guías técnicas.
- Evita cambiar IPs/MACs sin una justificación clara en el texto.

Comprobaciones clave a mencionar cuando apliquen:

- Root NFS por worker en `/mnt/ssd/netboot/nfs/workerN`
- TFTP root en `/mnt/ssd/netboot/tftp`
- Validación con `journalctl -u dnsmasq -f` y `showmount -a`
