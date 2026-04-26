---
applyTo: "scripts/install/**,scripts/deploy/**,manifests/**,docs-clean/deployment/**"
---

# K3s on NFS Workers Instructions

Al generar o modificar contenido de K3s para este cluster:

- Considera siempre que los workers arrancan desde NFS root.
- Incluye en recomendaciones de agent:
  - `--snapshotter=fuse-overlayfs`
  - `--kube-proxy-arg=proxy-mode=nftables`
- Asume que en OPi5 y RPi4 puede faltar `ip_tables.ko`; prioriza nftables.
- Cuando sea relevante, documenta ajuste de symlinks en:
  - `/var/lib/rancher/k3s/data/current/bin/aux/iptables*`
  - objetivo: `xtables-nft-multi`
- En RPi4, recordar requisito de memory cgroup (`cgroup_memory=1 cgroup_enable=memory`).

Validaciones mínimas esperadas:

- `systemctl status k3s-agent`
- `journalctl -u k3s-agent -n 30 --no-pager`
- `kubectl get nodes -o wide` desde el maestro
