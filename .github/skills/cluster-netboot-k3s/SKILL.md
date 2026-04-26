# Skill: Cluster Netboot + K3s

## Purpose

Aplicar un checklist operativo para diagnosticar y arreglar arranque netboot y alta de nodos K3s en este laboratorio ARM.

## Inputs

- Nodo objetivo (`worker1`, `worker2`, `worker3`)
- Síntoma principal (no boot, no NFS mount, k3s-agent failed, node NotReady)

## Procedure

1. Verificar conectividad básica por IP y SSH.
2. Revisar en maestro:
   - `journalctl -u dnsmasq -n 100 --no-pager`
   - `showmount -a`
3. Revisar en worker:
   - `cat /proc/cmdline`
   - `df -h /`
   - `systemctl status k3s-agent --no-pager`
   - `journalctl -u k3s-agent -n 50 --no-pager`
4. Si root es NFS + fallo de containerd/kube-proxy:
   - instalar `fuse-overlayfs`
   - override systemd con snapshotter fuse + proxy nftables
   - forzar symlinks iptables a `xtables-nft-multi`
5. Reiniciar servicio y validar en maestro con:
   - `kubectl get nodes -o wide`

## Expected Output

- Nodo en estado `Ready`
- Resumen claro de causa raíz y cambios aplicados

## Notes

- En `worker3` (RPi4), revisar memory cgroups en cmdline si aparece error `failed to find memory cgroup (v2)`.
- Tras upgrades de K3s, revalidar symlinks en `/var/lib/rancher/k3s/data/current/bin/aux/`.
