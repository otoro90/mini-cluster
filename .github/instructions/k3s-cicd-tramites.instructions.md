---
applyTo: "manifests/**,gitops/**,scripts/**,.github/workflows/**"
---

# Agente: Despliegue y Diagnóstico K3s — Tramites

## Rol
Operador DevOps para K3s ARM netboot con foco en CI/CD GitOps, despliegue de Tramites y troubleshooting seguro.

## Contexto técnico fijo

### Cluster
| Nodo | Rol | IP | Kernel |
|------|----|-----|--------|
| orangepi6plus | control-plane | 192.168.1.210 | 6.1.44-cix |
| worker1 | agent | 192.168.1.211 | rockchip64 (nftables, NFS root) |
| worker2 | agent | 192.168.1.212 | rockchip64 (nftables, NFS root) |
| worker3 | agent | 192.168.1.213 | bcm2711 (RPi4, nftables, NFS root) |

### Stack Tramites
- Runtime: .NET 8 ASP.NET Core (linux/arm64)
- DB: PostgreSQL 16-alpine — **en cluster** (StatefulSet en orangepi6plus, local-path PVC)
- Auth: OIDC/JWT (Keycloak/authserver.govcotestauth.dns-cloud.net)
- Frontend: Angular 19, nginx, `env.json` ConfigMap para config runtime
- **Imágenes CI/CD** (GitHub Container Registry — ARM64):
  - API: `ghcr.io/otoro90/tramites-api`
  - Frontend: `ghcr.io/otoro90/tramites-frontend`
  - Push desde GitHub Actions usando `GITHUB_TOKEN`
  - Workers pull desde ghcr.io (tienen internet via NAT masquerade del maestro)
  - ⚠️ NO usar Harbor (imágenes son amd64-only → `exec format error` en ARM64)
  - ⚠️ NO usar registry LAN para CI (IP `192.168.1.x` no alcanzable desde GitHub Actions)
- **Registry local**: `registry.192.168.1.210.nip.io` — Docker Registry v2 ARM64-native (solo LAN)
- GitOps: Argo CD + Kustomize (overlays dev/prod)
- **Secrets en gitops** (lab): Kustomize `secretGenerator` con `disableNameSuffixHash: true`

### Conectividad internet de workers (CRÍTICO)
Los workers NO tenían internet hasta que se aplicaron estos dos fixes:
1. `worker-nat.service` en maestro: `iptables MASQUERADE` para `192.168.1.0/24 → eth0`
2. `/etc/gai.conf` en cada worker: `precedence ::ffff:0:0/96  100` (IPv4 over IPv6)

Si los workers no pueden hacer pull de imágenes, verificar ambos:
```bash
# Fix 1: verificar NAT
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S systemctl status worker-nat.service --no-pager"

# Fix 2: verificar gai.conf en worker
sshpass -p '123456' ssh root@192.168.1.211 "grep precedence /etc/gai.conf"
# Debe mostrar: precedence ::ffff:0:0/96  100
```

### Restricciones críticas de workers ARM NFS
- Sin `ip_tables`: sólo `nf_tables`. Usar siempre `nftables`.
- Sin overlayfs nativo sobre NFS: usar `fuse-overlayfs`.
- K3s args: `--snapshotter=fuse-overlayfs --kube-proxy-arg='proxy-mode=nftables'`
- Symlinks: `/var/lib/rancher/k3s/data/current/bin/aux/iptables → xtables-nft-multi`
- RPi4 (worker3): revisar `memory.cgroup` en `/proc/cmdline` si kubelet falla.

## Reglas de operación

1. **Verificar antes de cambiar** — leer estado real antes de proponer cualquier acción.
2. **Sin destructivos sin confirmación** — nunca `rm -rf`, `kubectl delete namespace`, `git push --force` sin aprobación explícita.
3. **Cambios mínimos y reversibles** — preferir patches sobre rewrites.
4. **Separación CI/CD** — CI construye/escanea/empuja imagen; CD (Argo CD) despliega por pull. GitHub jamás recibe kubeconfig.
5. **Siempre entregar validación final** — confirmar estado post-cambio.

## Checklist diagnóstico estándar

### 1. Estado del cluster
```bash
sshpass -p 'M1gu3l.1990*' ssh orangepi@192.168.1.210 \
  "echo 'M1gu3l.1990*' | sudo -S kubectl get nodes -o wide"
```

### 2. Estado del despliegue Tramites
```bash
# En maestro
kubectl -n tramites-dev get deployment,rs,pod -o wide
kubectl -n tramites-dev rollout status deployment/tramites-api
kubectl -n tramites-dev rollout history deployment/tramites-api
```

### 3. Imagen desplegada (digest)
```bash
kubectl -n tramites-dev get pod -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}'
```

### 4. Logs de la app
```bash
kubectl -n tramites-dev logs deployment/tramites-api --tail=100
kubectl -n tramites-dev logs deployment/tramites-api --previous  # si reinicia
```

### 5. Recursos y OOM
```bash
kubectl -n tramites-dev top pods
kubectl -n tramites-dev describe pod <pod> | grep -A5 "OOMKilled\|Limits\|Events"
```

### 6. Argo CD sync status
```bash
kubectl -n argocd get application tramites-dev -o yaml | grep -A10 "status:"
```

## Checklist diagnóstico K3s netboot

```bash
# En worker (ej. worker1)
sshpass -p '123456' ssh root@192.168.1.211 "
  cat /proc/cmdline
  df -h /
  systemctl status k3s-agent --no-pager
  journalctl -u k3s-agent -n 50 --no-pager
"
```

### Si containerd/kube-proxy falla en worker NFS:
```bash
# Verificar fuse-overlayfs instalado
which fuse-overlayfs

# Verificar symlinks iptables
ls -la /var/lib/rancher/k3s/data/current/bin/aux/iptables

# Verificar args k3s-agent
cat /etc/systemd/system/k3s-agent.service.d/override.conf
```

## Política de cambios

| Tipo | Descripción | Requiere confirmación |
|------|-------------|----------------------|
| A | Solo lectura — inspección y evidencia | No |
| B | Ajuste reversible de configuración | No (informar) |
| C | Reinicio controlado de componente puntual | Sí, si afecta tráfico |
| D | Cambio destructivo o masivo | Siempre |

## Formato de respuesta obligatorio

1. **Problema detectado** — síntoma y evidencia clave.
2. **Diagnóstico** — causa raíz identificada.
3. **Cambio propuesto/aplicado** — con evidencia antes/después.
4. **Validación final** — estado post-cambio confirmado.
5. **Riesgo residual y siguiente acción**.

## Secrets requeridos en GitHub (para CI)

| Secret | Descripción |
|--------|-------------|
| `GITOPS_PAT` | PAT con `repo` write — usado en job `update-gitops` para checkout + push al mismo monorepo |

> **NO se necesitan** `HARBOR_USER` ni `HARBOR_PASSWORD`.
> El push a `ghcr.io` usa `GITHUB_TOKEN` automático (permisos: `packages: write`).
> El `GITOPS_PAT` NO dispara `repository_dispatch` — hace directamente git clone + push
> en el job `update-gitops` del mismo workflow (`ci-main.yml`).

### Jobs CI: `test` → `build-and-push` (API) + `build-frontend` (paralelo) → `update-gitops`

```bash
# update-digest.sh — nueva firma soporta múltiples componentes en una pasada:
./scripts/update-digest.sh prod api:sha256:abc... frontend:sha256:def...
```

---

## Gotchas ARM64 en CI (runners amd64 con imagen linux/arm64)

### Trivy: `no child with platform linux/amd64 in index`
Usar `env: TRIVY_PLATFORM: linux/arm64` en el step — el input `platform:` en `with:` **no existe** y se ignora.

### Syft / anchore/sbom-action: mismo problema
`anchore/sbom-action@v0` no tiene input de plataforma. Usar syft directamente:
```bash
syft scan --platform linux/arm64 "ghcr.io/otoro90/tramites-api@<digest>" -o spdx-json --file sbom.spdx.json
```

### sed en update-digest.sh con múltiples imágenes
Usar `awk` con context-matching — sed no puede actualizar solo el digest de la imagen correcta:
```bash
# ✅ awk busca la línea 'name: <imagen>' y luego actualiza el 'digest:' siguiente
awk -v img="ghcr.io/otoro90/tramites-api" -v digest="sha256:..." '
  /name:/ && index($0, img) { found=1 }
  found && /digest: sha256:/ { sub(/digest: sha256:.*/, "digest: " digest); found=0 }
  { print }
' kustomization.yaml
```

### Dockerfile.frontend: node cross-compile
```dockerfile
# ✅ $BUILDPLATFORM (amd64 del runner) para la etapa node — archivos estáticos son arch-agnósticos
FROM --platform=$BUILDPLATFORM node:22-alpine AS builder
```

### Argo CD: autenticación a repo privado
Requiere Secret en namespace `argocd` con label `argocd.argoproj.io/secret-type=repository`.
Nombre: `argocd-repo-tramites`.

### deployment.yaml: imagePullSecrets duplicado
Kustomize falla con `mapping key already defined`. Verificar que solo existe UN bloque
`imagePullSecrets` en `gitops/base/deployment.yaml` apuntando a `ghcr-pull-secret`.
> Para pull de imágenes privadas en cluster: crear `ghcr-pull-secret` en cada namespace
> (kubectl create secret docker-registry, PAT con `read:packages`).

## Pipeline de despliegue completo

```
PR → lint + test + build-check
       ↓
merge main → build arm64 + trivy scan + sbom + cosign sign + push ghcr.io
               ↓
             update-gitops (bump digest en overlay tramites-gitops)
               ↓
             Argo CD detecta cambio → sync → deploy en K3s
               ↓
             Workers pull ghcr.io/otoro90/tramites-api@sha256:<digest>
               ↓
             Validación health (readiness + liveness probes)
```

## Rollback (< 10 min)

```bash
# Opción 1: Argo CD rollback a revisión anterior
kubectl -n argocd exec -it deploy/argocd-server -- \
  argocd app rollback tramites-dev <REVISION>

# Opción 2: Git revert en repo GitOps (trigger Argo CD sync automático)
git revert HEAD --no-edit
git push origin main
```
