# ZITADEL + Headscale en Mini-Cluster

## Objetivo

Desplegar un IdP self-hosted (ZITADEL) y un control-plane VPN self-hosted (Headscale) en K3s ARM, con enfoque de seguridad y operacion estable para entorno lab/productivo pequeno.

## Diseno aplicado

1. ZITADEL en namespace dedicado (`zitadel`) con PostgreSQL dedicado en el cluster.
2. Headscale en namespace dedicado (`headscale`) con SQLite sobre PVC local.
3. Ambos pods fijados a `orangepi6plus` por estabilidad mientras workers estan `NotReady`.
4. Ingress via Traefik en hostnames nip.io de LAN.
5. DERP embebido habilitado en Headscale y STUN publicado por `NodePort` UDP 30478.

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

## Integracion OIDC (fase 2 recomendada)

Para habilitar login OIDC de Headscale con ZITADEL de forma robusta, se recomienda:

1. Exponer ZITADEL por HTTPS con certificado valido (Cloudflare Tunnel o cert-manager).
2. Crear aplicacion OIDC para Headscale en ZITADEL con redirect URI:
   - `https://headscale.<dominio>/oidc/callback`
3. Actualizar `config.yaml` de Headscale con:
   - `oidc.issuer`
   - `oidc.client_id`
   - `oidc.client_secret` (en secret, no en ConfigMap)
   - `oidc.scope: ["openid", "profile", "email"]`
4. Reiniciar deployment `headscale`.

## Notas de seguridad

- Cambiar passwords por defecto de `zitadel-postgres-auth` y `zitadel-db-credentials`.
- Mantener `zitadel-masterkey` fuera de Git y respaldada de forma segura.
- No exponer paneles admin a internet sin control de acceso adicional.
