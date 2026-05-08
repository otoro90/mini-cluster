# ZITADEL + Headscale en Mini-Cluster

## Objetivo

Desplegar un IdP self-hosted (ZITADEL) y un control-plane VPN self-hosted (Headscale) en K3s ARM, con enfoque de seguridad y operacion estable para entorno lab/productivo pequeno.

## Estado actual (Mayo 2026)

- ZITADEL v4.13.1 desplegado y operativo — `https://auth.forjanova.com`
- Headscale v0.27.0 desplegado y operativo — `https://vpn.forjanova.com`
- OIDC ZITADEL → Headscale **CONFIGURADO Y OPERATIVO**
  - Issuer: `https://auth.forjanova.com`
  - client_id: `371944937371009137`
  - Allowlist activa: `allowed_domains: [forjanova.com]`, `allowed_users: [admin@forjanova.com]`
- Usuario humano ZITADEL admin creado: `admin@forjanova.com`
- Mac node `mac-oscar-forjanova` conectado a Headscale (100.64.0.1)
- VPN landing page en `http://headscale.192.168.1.210.nip.io`
- STUN Headscale: `192.168.1.210:30478/udp`

> ⚠️ `scripts/setup-zitadel-oidc-headscale.sh` está roto (HTTP 500 en token exchange).
> Usar `iam-admin-pat` directamente para llamadas API ZITADEL.

## Diseño aplicado

1. ZITADEL en namespace dedicado (`zitadel`) con PostgreSQL dedicado en el cluster.
2. Headscale en namespace dedicado (`headscale`) con SQLite sobre PVC local.
3. Ambos pods fijados a `orangepi6plus` por estabilidad (SSD NVMe, sin restricciones overlayfs).
4. Ingress via Traefik en hostnames nip.io de LAN y Cloudflare Tunnel para URLs públicas.
5. DERP embebido habilitado en Headscale y STUN publicado por `NodePort` UDP 30478.
6. `vpn.forjanova.com` apunta **directamente al service `headscale`** (no al portal Nginx) — necesario para que TS2021 WebSocket funcione a través de Cloudflare.
7. Portal VPN landing page en `headscale.192.168.1.210.nip.io` (solo LAN).

## Archivos

- `zitadel-postgres.yaml`: PostgreSQL dedicado + secretos de conexion de ZITADEL.
- `zitadel-values.yaml`: valores Helm endurecidos para ZITADEL en K3s + Traefik.
- `headscale.yaml`: despliegue completo de Headscale (DERP, STUN, Ingress).
- `scripts/deploy/deploy-zitadel-headscale.sh`: script de despliegue remoto al maestro.

## Despliegue

Desde tu laptop en este repo:

```bash
chmod +x scripts/deploy/deploy-zitadel-headscale.sh
./scripts/deploy/deploy-zitadel-headscale.sh
```

## Endpoints esperados

- ZITADEL: `http://zitadel.192.168.1.210.nip.io`
- Headscale: `http://headscale.192.168.1.210.nip.io`
- STUN Headscale (LAN): `192.168.1.210:30478/udp`

## Endpoints públicos (Cloudflare Tunnel)

- Login/Consola IdP: `https://auth.forjanova.com`
- VPN control URL: `https://vpn.forjanova.com`

`vpn.forjanova.com` ahora expone una página amigable en `/` y hace reverse proxy a Headscale para el resto de rutas.

## OIDC Headscale ↔ ZITADEL

### Config activa (runtime en cluster)

La configuración vive en:
- **ConfigMap** `headscale-config` (namespace `headscale`) — clave `config.yaml`, sección `oidc:`
- **Secret** `headscale-oidc-credentials` (namespace `headscale`) — clave `client_secret`

```yaml
oidc:
  only_start_if_oidc_is_available: true
  issuer: https://auth.forjanova.com       # HTTPS obligatorio — debe coincidir con discovery
  client_id: 371944937371009137
  client_secret: <en secret headscale-oidc-credentials>
  scope: [openid, profile, email]
  allowed_domains: [forjanova.com]
  allowed_groups: []
  allowed_users: [admin@forjanova.com]     # whitelist explícita
```

> ⚠️ El manifest `headscale.yaml` tiene el bloque OIDC **comentado**.
> Si se re-aplica el manifest, se perderá la config OIDC del runtime.
> Restaurar ejecutando el script de allowlist o aplicando el ConfigMap manualmente.

### Gestión del allowlist OIDC

```bash
# Reemplaza la lista completa (idempotente)
./scripts/deploy/set-headscale-oidc-allowlist.sh admin@forjanova.com user2@forjanova.com

# El script edita headscale-config y hace rollout del deployment headscale
```

### Notas críticas Headscale v0.27.0

- **NO** incluir `oidc.strip_email_domain` — fue removida, rompe startup con `FATAL`.
- El issuer DEBE ser `https://auth.forjanova.com` (HTTPS). ZITADEL retorna HTTPS en el
  discovery endpoint y Headscale valida coincidencia exacta. Si difiere → `FTL` crash.

## Conectar cliente Tailscale/Headscale

```bash
# ❌ NO funciona: defaults write io.tailscale.ipn.macos ControlURL ...
# (no afecta al daemon en ejecución)

# ✅ Opción 1: via preauth key (bootstrap sin OIDC)
HEADSCALE_POD=$(kubectl -n headscale get pod -l app=headscale -o jsonpath='{.items[0].metadata.name}')
kubectl -n headscale exec $HEADSCALE_POD -- headscale users create oscar
kubectl -n headscale exec $HEADSCALE_POD -- headscale preauthkeys create --user oscar --expiration 1h
# En el cliente Mac:
tailscale up --reset --login-server=https://vpn.forjanova.com --auth-key=<key>

# ✅ Opción 2: via OIDC (flujo browser)
tailscale up --reset --login-server=https://vpn.forjanova.com --force-reauth
# Browser abre → https://auth.forjanova.com/ui/login → login con admin@forjanova.com
```

> `vpn.forjanova.com` en raíz devuelve 404 — esto es normal (Headscale no tiene root handler).
> El portal LAN está en `http://headscale.192.168.1.210.nip.io`.

## Acceso a ZITADEL

### Usuario humano admin (creado Mayo 2026)

| Campo | Valor |
|-------|-------|
| Login UI | `https://auth.forjanova.com/ui/login` |
| Console | `https://auth.forjanova.com/ui/console` |
| Usuario | `admin@forjanova.com` |
| Contraseña inicial | `ForjaNovaAdmin!2026` ← **cambiar en primer login** |
| Rol | ORG_OWNER |

### Credenciales bootstrap K8s (para automatización API)

```bash
# PAT admin (para llamadas API ZITADEL)
sshpass -p '123456' ssh root@192.168.1.210 \
   "KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n zitadel get secret iam-admin-pat -o jsonpath='{.data.pat}' | base64 -d"

# Ejemplo: crear usuario humano via API
PAT=$(sshpass -p '123456' ssh root@192.168.1.210 \
  "KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n zitadel get secret iam-admin-pat -o jsonpath='{.data.pat}' | base64 -d")
curl -s -H "Authorization: Bearer $PAT" \
     -H "Content-Type: application/json" \
     -d '{"profile":{"firstName":"Nombre","lastName":"Apellido"},"email":{"email":"user@forjanova.com","isEmailVerified":true},"password":{"password":"Pass!2026","changeRequired":true}}' \
     https://auth.forjanova.com/v2/users/human | jq .
```

> ZITADEL no usa usuario/clave por defecto fija. El chart crea secrets bootstrap:
> - `iam-admin-pat` (PAT admin) — en namespace `zitadel`
> - `login-client-pat` (PAT login) — en namespace `zitadel`

## Probar VPN (cliente Tailscale)

Ver sección "Conectar cliente Tailscale/Headscale" arriba.

Verificar nodos conectados en el cluster:
```bash
HEADSCALE_POD=$(sshpass -p '123456' ssh root@192.168.1.210 \
  "KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n headscale get pod -l app=headscale -o jsonpath='{.items[0].metadata.name}'")
sshpass -p '123456' ssh root@192.168.1.210 \
  "KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n headscale exec $HEADSCALE_POD -- headscale nodes list"
```

## Notas de seguridad

- Cambiar password del usuario `admin@forjanova.com` en primer login.
- Mantener `zitadel-masterkey` fuera de Git y respaldada en Bitwarden.
- Guardar `client_secret` OIDC solo en secret `headscale-oidc-credentials` (no en ConfigMap).
- `allowed_users` y `allowed_domains` deben estar explícitamente configurados — no dejar vacíos.
- No exponer paneles admin a internet sin control de acceso adicional.
- Deshabilitar "Allow public registration" en ZITADEL Console → Organization Settings.

## Lecciones aprendidas (Mayo 2026)

| Problema | Causa | Solución |
|---------|-------|----------|
| Headscale crash `FTL OIDC issuer mismatch` | Issuer en config era `http://` pero ZITADEL retorna `https://` | Usar `https://auth.forjanova.com` como issuer |
| Tailscale va a `login.tailscale.com` en vez del propio server | `defaults write` no afecta daemon en ejecución | Usar `tailscale up --reset --login-server=<url>` |
| TS2021 falla con "No Upgrade header" | `vpn.forjanova.com` pasaba por Nginx portal (doble proxy) | Ingress de `vpn.forjanova.com` apunta directamente al service `headscale` |
| Cualquier usuario puede hacer login OIDC | `allowed_users/domains/groups` vacíos en config | Configurar allowlist explícita con `set-headscale-oidc-allowlist.sh` |
