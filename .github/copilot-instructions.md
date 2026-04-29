# Mini-Cluster Forjanova Labs — Instrucciones de Copilot

## Descripción del proyecto

Cluster Kubernetes K3s de 3 nodos ARM en red local. Los 3 workers arrancan por red (Netboot/PXE) desde el nodo maestro vía NFS — **ningún worker tiene OS en disco**.

## Arquitectura del cluster

| Nodo | Rol | IP | Hardware | RAM | OS / Kernel |
|------|-----|----|----------|-----|-------------|
| `orangepi6plus` | control-plane K3s | 192.168.1.210 | Orange Pi 6+ | 32 GB | Armbian Noble 26.2.1 / 6.18.8-current-arm64 |
| `worker1` | agent K3s | 192.168.1.211 | Orange Pi 5 | 4 GB | Armbian Noble / 6.18.8-current-rockchip64 |
| `worker2` | agent K3s | 192.168.1.212 | Orange Pi 5 | 8 GB | Armbian Noble / 6.18.8-current-rockchip64 |
| `worker3` | agent K3s | 192.168.1.213 | Raspberry Pi 4B | 8 GB | Armbian Noble / 6.18.9-current-bcm2711 |

**Credenciales SSH:**
- Maestro (Armbian): `root@192.168.1.210` contraseña `123456` — acceso directo, kubectl sin sudo
- Workers: `root@192.168.1.21x` contraseña `123456`

> La IP `192.168.1.210` es la IP canónica del cluster (estática, añadida por `add-cluster-ip.service`). La `enp97s0` también tiene `.129` DHCP pero no se usa en comandos.

**K3s token:** `K10dd8855fe8c3ed719655efdf5310fc9c868c28802825dc239ddd110feb80adfec::server:dc42591fa3eeee232aca82dd70c2e542`

**K3s versión maestro:** `v1.35.4+k3s1` | **Workers:** `v1.34.6+k3s1`

## Restricciones críticas del hardware/kernel

### Workers Orange Pi 5 (`rockchip64`)
- **SIN ip_tables**: El kernel solo tiene `nf_tables.ko`. NO tiene `ip_tables`. Usar siempre nftables.
- **SIN overlayfs nativo sobre NFS**: El root (`/`) es NFS → overlayfs falla. Se usa `fuse-overlayfs`.
- K3s debe iniciarse con: `--snapshotter=fuse-overlayfs --kube-proxy-arg='proxy-mode=nftables'`
- Iptables bundled de K3s apunta a `xtables-nft-multi`: `/var/lib/rancher/k3s/data/current/bin/aux/iptables → xtables-nft-multi`

### Worker Raspberry Pi 4B (`bcm2711`)
- Mismas restricciones que OPi5: sin ip_tables, NFS root, requiere fuse-overlayfs
- **PXE nativo** en EEPROM: no necesita micro-SD ni SPI flash
- Interfaz de red: `end0` (no `eth0`)

### Maestro (Orange Pi 6+ — Armbian Noble 26.2.1)
- Root en WD Black 512 GB NVMe — sin restricciones de overlayfs
- K3s v1.35.4+k3s1, `KUBECONFIG=/etc/rancher/k3s/k3s.yaml` (como root, sin sudo)
- **Una NIC física**: `enp97s0` — IP canónica `192.168.1.210/24` (añadida por `add-cluster-ip.service`, estática)
- K3s iniciado con `--bind-address=192.168.1.210 --advertise-address=192.168.1.210 --node-ip=192.168.1.210 --flannel-iface=enp97s0`

## Configuración Netboot

- DHCP+TFTP: dnsmasq en el maestro
- NFS roots: `/mnt/ssd/netboot/nfs/{worker1,worker2,worker3}`
- TFTP root: `/mnt/ssd/netboot/tftp/`
- Workers OPi5: botan SPI Flash → U-Boot → TFTP → NFS
- Worker RPi4: EEPROM PXE nativo → TFTP → NFS (requiere DHCP option 66 + dhcp-boot para siaddr)

**Tiempos de boot (Abril 2026):**
- Workers OPi5 (worker1/2): **~2 min** (antes 3-4 min)
- Worker RPi4 (worker3): **~1 min 10 seg**
- Maestro OPi6+ Armbian: **~10-15 seg** (sin servicios desktop, Armbian minimal)

**Optimizaciones aplicadas (permanentes en disco/NFS root):**
- `tftpblocksize 65464` + `tftpwindowsize 8` en `boot.cmd` de OPi5 (mayor impacto)
- NFS mount con `rsize=131072,wsize=131072` en `boot.cmd`
- `RPCNFSDCOUNT=16` en maestro
- Masked en workers: `bluetooth-hciattach`, `wpa_supplicant`, `avahi-daemon`
- Masked en maestro: `chrony-wait`, `rtkit-daemon`, `accounts-daemon`, `power-profiles-daemon`, `loadcpufreq`, `cpufrequtils`, `systemd-udev-settle`

> ✅ **Armbian en OPi6+ COMPLETADO (Abril 2026)**: Imagen Armbian Ubuntu 24.04 Noble 26.2.1, kernel `6.18.8-current-arm64`, instalado en WD Black 512 GB NVMe. Ver [MIGRACION-ARMBIAN-OPI6PLUS.md](../MIGRACION-ARMBIAN-OPI6PLUS.md) para detalle.

## Conectividad internet de los workers

Los workers usan `192.168.1.210` como gateway. El maestro tiene NAT masquerade que SNAT el tráfico saliente:

- **Servicio**: `worker-nat.service` (systemd, enabled + running en maestro)
- **Regla**: `iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -o enp97s0 -j MASQUERADE`
- **DNS IPv4**: `/etc/gai.conf` con `precedence ::ffff:0:0/96  100` en cada worker (NFS root persistido)
- **Verificar**: `systemctl status worker-nat.service` en maestro

> Sin estos dos ajustes los workers NO tienen conectividad TCP a internet.

## Stack CI/CD instalado (Abril 2026)

| Componente | URL / Acceso | Credenciales | Notas |
|-----------|--------------|--------------|-------|
| Argo CD v3.3.8 | `http://argocd.local` (añadir a `/etc/hosts`) | admin / `ipb4EnoshkInEr4g` | Helm `argo/argo-cd`, todos los pods en orangepi6plus |
| Docker Registry v2 | `http://registry.192.168.1.210.nip.io` | admin / Registry12345 | Solo LAN — ARM64-native (`registry:2`) |
| **traefik** | `192.168.1.210:80/443` | — | Bundled K3s, DaemonSet svclb-traefik en todos los nodos. `ingressClassName: traefik` |
| local-path-provisioner | StorageClass `local-path` (default) | — | PVCs en `/mnt/ssd/k8s-volumes` en orangepi6plus |

> ⚠️ NO usar ingress-nginx: hostPorts 80/443 los ocupa svclb-traefik en todos los nodos → ingress-nginx queda Pending.

**Imágenes CI/CD** (GitHub Container Registry — ARM64, alcanzable desde workers vía internet):
- Backend API: `ghcr.io/otoro90/tramites-api`
- Frontend: `ghcr.io/otoro90/tramites-frontend`

> ⚠️ NO usar Harbor (imágenes oficiales son amd64-only, no hay ARM64 para Harbor).  
> ⚠️ NO usar un registry LAN para CI desde GitHub Actions (IP privada no alcanzable).

## Stack de aplicación Tramites en cluster (Abril 2026)

| Recurso | Namespace dev | Notas |
|---------|--------------|-------|
| PostgreSQL StatefulSet | `tramites-dev` / `tramites-prod` | `postgres:16-alpine`, PVC `local-path` 5Gi dev / 20Gi prod, **solo en orangepi6plus** |
| Backend API (.NET 8) | `tramites-dev` / `tramites-prod` | `ghcr.io/otoro90/tramites-api`, puerto 8080, EF Core migrations al arrancar |
| Frontend Angular 19 | `tramites-dev` / `tramites-prod` | `ghcr.io/otoro90/tramites-frontend`, nginx con `env.json` desde ConfigMap |
| tramites-secrets | `tramites-dev` / `tramites-prod` | Generado por Kustomize secretGenerator (`disableNameSuffixHash: true`) |
| postgres-credentials | `tramites-dev` / `tramites-prod` | Generado por Kustomize secretGenerator |

**URLs en dev (añadir a `/etc/hosts → 192.168.1.210`):**
- Frontend: `http://tramites-dev.local`
- API: `http://tramites-api-dev.local`

**URLs en prod (añadir a `/etc/hosts → 192.168.1.210`):**
- Frontend: `http://tramites.forjanova.local`
- API: `http://tramites-api.forjanova.local`

**PostgreSQL en cluster** (ya NO usa Render.com):
- Connection string: `Host=postgres;Port=5432;Database=tramitesdb;Username=tramites;Password=<overlay>;SSL Mode=Disable`
- El pod postgres corre **solo en `orangepi6plus`** (`nodeSelector: kubernetes.io/hostname: orangepi6plus`) para aprovechar el SSD
- `PGDATA=/var/lib/postgresql/data/pgdata` (subdirectorio para evitar conflictos con el mountpoint)

**Configuración runtime del frontend** (sin rebuild por env):
- Angular carga `/assets/env.json` en `main.ts` → `window.__env`
- `AppConfigService` fusiona `environment.ts` (build-time fallback) con `window.__env` (runtime override)
- En K8s: ConfigMap `tramites-frontend-env` montado con `subPath: env.json` → `/usr/share/nginx/html/assets/env.json`

## GitHub Actions CI/CD — Tramites (actualizado Abril 2026)

- **Workflow**: `Tramites/.github/workflows/ci-main.yml` — monorepo, path filter en `Govco.Tramites/**`
- **Jobs**: `test` → `build-and-push` (API) + `build-frontend` (paralelo) → `update-gitops`
- **Secrets configurados en repo Tramites**: `GITOPS_PAT` (PAT con `repo` write para push al mismo monorepo)
- **Secret Argo CD en cluster**: `argocd-repo-tramites` en namespace `argocd` con label `argocd.argoproj.io/secret-type=repository`
- **imagePullSecret en cluster**: `ghcr-pull-secret` en namespaces `tramites-dev`, `tramites-prod`, `argocd`
- **Aplicaciones Argo CD**: `tramites-dev` (auto-sync) + `tramites-prod` (manual) — aplicadas con `kubectl apply -f manifests/tramites/argocd-apps.yaml`

### Script update-digest.sh (nueva firma)

```bash
# Un componente
./scripts/update-digest.sh prod api:sha256:abc...

# Ambos en una sola pasada (un solo clone + push)
./scripts/update-digest.sh prod api:sha256:abc... frontend:sha256:def...
```

### Gotchas ARM64 en CI (runners amd64 con imagen linux/arm64-only)

| Herramienta | Problema | Solución |
|-------------|----------|----------|
| `aquasecurity/trivy-action` | No tiene input `platform:` — lo ignora | Usar `env: TRIVY_PLATFORM: linux/arm64` |
| `anchore/sbom-action@v0` | No soporta `--platform` | Usar `syft scan --platform linux/arm64` directo en `run:` |
| `sed` con `\|` como delimitador | `\|` de alternancia regex se confunde con delimitador | Usar `#` como delimitador: `s#patron(a\|b)#reemplazo#` |
| `update-gitops` job | NO usa `repository_dispatch` — hace checkout directo del monorepo | El script `scripts/update-digest.sh` se llama directamente con `GITOPS_PAT` |
| `Dockerfile.frontend` stage Angular | `node:22-alpine` no es ARM64 nativo en CI | Usar `FROM --platform=$BUILDPLATFORM node:22-alpine` — archivos estáticos son arch-agnósticos |
| `update-digest.sh` múltiples imágenes | `sed` remplazaría ambos `digest:` | Usar `awk` con context-matching por nombre de imagen |

## Kustomize — Reglas críticas (lecciones aprendidas Abril 2026)

> **Verificado con documentación oficial Kustomize y context7.**

### NUNCA usar `commonLabels` si ya existen Deployments/StatefulSets

`commonLabels` es equivalente a `labels` con `includeSelectors: true`. Agrega labels a `spec.selector.matchLabels` de Deployments y StatefulSets — campo **inmutable** en Kubernetes. Si el recurso ya existe, K8s rechazará el update con error de inmutabilidad.

**Usar siempre:**
```yaml
labels:
  - pairs:
      app.kubernetes.io/name: tramites
      app.kubernetes.io/managed-by: argocd
    includeSelectors: false   # NO tocar spec.selector
    includeTemplates: false   # NO agregar a pod templates (opcional: true si se quiere en pods)
```

### StatefulSet `volumeClaimTemplates` — ignoreDifferences obligatorio en Argo CD

Kubernetes agrega automáticamente `apiVersion: v1`, `kind: PersistentVolumeClaim` y `status: {phase: Pending}` al live state de `spec.volumeClaimTemplates`. El manifiesto deseado no los incluye → Argo CD ve diff permanente.

**Fix obligatorio en `argocd-apps.yaml`:**
```yaml
ignoreDifferences:
  - group: apps
    kind: StatefulSet
    name: postgres
    jqPathExpressions:
      - .spec.volumeClaimTemplates[]?.status
      - .spec.volumeClaimTemplates[]?.apiVersion
      - .spec.volumeClaimTemplates[]?.kind
```
Más `RespectIgnoreDifferences=true` en `syncOptions` — sin esto, Argo CD ignora el diff en la UI pero sigue intentando sincronizarlo.

### Estructura gitops tramites (verificada operacional Abril 2026)

```
Tramites/gitops/
├── base/
│   ├── kustomization.yaml          # labels(includeSelectors:false), lista recursos
│   ├── deployment.yaml             # tramites-api, selector: app=tramites-api
│   ├── service.yaml                # selector: app=tramites-api
│   ├── configmap.yaml
│   ├── ingress.yaml
│   ├── frontend/
│   │   ├── deployment.yaml         # selector: app=tramites-frontend
│   │   └── service.yaml
│   ├── frontend-env-configmap.yaml
│   ├── ingress-frontend.yaml
│   └── postgres/
│       ├── statefulset.yaml        # selector: app=postgres, nodeSelector: orangepi6plus
│       └── service.yaml
└── overlays/
    ├── dev/
    │   └── kustomization.yaml      # ns=tramites-dev, secrets, patches replicas=1
    └── prod/
        └── kustomization.yaml      # ns=tramites-prod, digest:sha256 (actualizado por CI)
```

### /etc/hosts en cliente Mac (añadido Abril 2026)
```
192.168.1.210  tramites-dev.local tramites-api-dev.local
192.168.1.210  tramites.forjanova.local tramites-api.forjanova.local
192.168.1.210  argocd.local registry.192.168.1.210.nip.io
```

## Comandos frecuentes

```bash
# Ver estado del cluster (maestro Armbian — root directo, sin sudo)
sshpass -p '123456' ssh -o StrictHostKeyChecking=no root@192.168.1.210 \
  'KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get nodes -o wide'

# Logs de un worker
sshpass -p '123456' ssh root@192.168.1.211 "journalctl -u k3s-agent -n 30 --no-pager"

# Reiniciar agente en worker
sshpass -p '123456' ssh root@192.168.1.211 "systemctl restart k3s-agent"

# Monitorear arranque netboot
sshpass -p '123456' ssh root@192.168.1.210 "journalctl -u dnsmasq -f"

# Verificar NAT workers
sshpass -p '123456' ssh root@192.168.1.210 \
  'iptables -t nat -L POSTROUTING -n -v | grep MASQUERADE'

# Ver todos los pods
sshpass -p '123456' ssh root@192.168.1.210 \
  'KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get pods -A -o wide'
```

## Helm (en maestro)

- Binario: `/usr/local/bin/helm` (v3.20.2)
- Armbian: usuario root → sin sudo. Patrón: `KUBECONFIG=/etc/rancher/k3s/k3s.yaml helm ...`
- Repos añadidos: `argo` (https://argoproj.github.io/argo-helm), `harbor` (https://helm.goharbor.io)

## Convenciones del repo

- Documentación en español (guías técnicas) e inglés (README principal)
- Guías en raíz del repo, manifests K8s en `manifests/`, scripts en `scripts/`
- Ver [NETBOOT_GUIDE.md](../NETBOOT_GUIDE.md) para netboot
- Ver [CI-CD-GUIDE.md](../CI-CD-GUIDE.md) para pipeline CI/CD GitOps completo
- Ver [K3S-NETBOOT-WORKERS.md](../K3S-NETBOOT-WORKERS.md) para workers ARM
