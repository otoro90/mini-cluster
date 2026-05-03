# Internet Exposure Guide for Mini-Cluster

This guide describes the recommended way to publish multiple services to the Internet for this K3s cluster.

## Recommended architecture

- Keep Traefik as the only ingress controller in the cluster.
- Publish services using Cloudflare Tunnel (outbound tunnel from cluster to Cloudflare).
- Route each public hostname to an internal Kubernetes service.
- Protect admin endpoints with Cloudflare Access.

Why this is the best fit here:

- No inbound port-forward on home router.
- Works with dynamic residential IP.
- Matches current K3s setup where Traefik already owns ports 80/443.
- Keeps attack surface smaller than exposing NodePorts publicly.

## Current cluster reality checked before this guide

- Traefik service is healthy on `192.168.1.210`.
- Existing Ingresses are running with `ingressClassName: traefik`.
- Workers are currently `NotReady`; deploy cloudflared pinned to `orangepi6plus` until workers recover.

## Prerequisites

- A domain in Cloudflare (example: `forjanova.com`).
- Access to Cloudflare Zero Trust dashboard.
- SSH access to master node `root@192.168.1.210`.
- `kubectl` access from master (`KUBECONFIG=/etc/rancher/k3s/k3s.yaml`).

## Step 1: Create tunnel in Cloudflare dashboard

In Zero Trust:

1. Go to Networks > Tunnels.
2. Create a tunnel (connector type: Cloudflared).
3. Copy the tunnel token.

Do not create local DNS entries yet; we will map hostnames in Step 4.

## Step 2: Deploy cloudflared in K3s

Apply the manifest:

```bash
sshpass -p '123456' ssh -o StrictHostKeyChecking=no root@192.168.1.210 \
  "cat > /tmp/cloudflared.yaml" < manifests/cloudflare-tunnel/cloudflared.yaml

sshpass -p '123456' ssh -o StrictHostKeyChecking=no root@192.168.1.210 \
  "KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl apply -f /tmp/cloudflared.yaml"
```

Patch the token secret (recommended after first apply):

```bash
sshpass -p '123456' ssh -o StrictHostKeyChecking=no root@192.168.1.210 \
  "kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml -n cloudflare-tunnel create secret generic cloudflared-tunnel-token \
  --from-literal=token='YOUR_TUNNEL_TOKEN' --dry-run=client -o yaml | \
  kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml apply -f -"
```

Validate:

```bash
sshpass -p '123456' ssh -o StrictHostKeyChecking=no root@192.168.1.210 \
  "kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml -n cloudflare-tunnel get pods -o wide"

sshpass -p '123456' ssh -o StrictHostKeyChecking=no root@192.168.1.210 \
  "kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml -n cloudflare-tunnel logs deploy/cloudflared --tail=80"
```

## Step 3: Keep Kubernetes Ingress internal as-is

You already have these internal hostnames:

- `tramites-dev.local`
- `tramites-api-dev.local`
- `argocd.local`
- `registry.192.168.1.210.nip.io`

No need to replace Traefik. Cloudflare Tunnel will point public hostnames to those internal routes/services.

## Step 4: Add public hostnames in Cloudflare Tunnel

For each service, create a Public Hostname in the tunnel:

- `tramites-dev.tudominio.com` -> `http://tramites-frontend.tramites-dev.svc.cluster.local:80`
- `api-dev.tudominio.com` -> `http://tramites-api.tramites-dev.svc.cluster.local:80`
- `argocd.tudominio.com` -> `http://argocd-server.argocd.svc.cluster.local:80`
- `registry.tudominio.com` -> `http://registry.registry.svc.cluster.local:5000`

Notes:

- Prefer Kubernetes DNS service names over node IPs.
- Keep protocol `http` between tunnel and service inside cluster unless you already terminate TLS internally.
- For Docker Registry, raise upload/body limits in Traefik route if needed.

## Step 5: Secure admin surfaces

Minimum hardening:

- Put `argocd.tudominio.com` behind Cloudflare Access policy.
- Put `registry.tudominio.com` behind Access or IP allowlist.
- Keep K3s API server and SSH closed to public Internet.

Recommended Access policy:

- Allow only specific emails/groups.
- Enforce MFA.
- Add short session TTL for admin apps.

## Step 6: Optional TLS strategy inside cluster

You have two valid models:

- Model A (simpler): TLS terminates at Cloudflare edge; tunnel to internal HTTP.
- Model B (strict end-to-end): Cloudflare edge TLS + internal TLS with cert-manager DNS-01.

For this homelab, Model A is usually enough. Use Model B only if you require internal TLS compliance.

## Step 7: Validation checklist

Run from your laptop:

```bash
curl -I https://tramites-dev.tudominio.com
curl -I https://api-dev.tudominio.com/health
curl -I https://argocd.tudominio.com
```

Run from master:

```bash
kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml get ingress -A
kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml -n cloudflare-tunnel get pods
kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml -n cloudflare-tunnel logs deploy/cloudflared --tail=100
```

## Troubleshooting quick map

- Public hostname times out:
  - Check cloudflared pod logs and tunnel status in Cloudflare.
- 502/504 from Cloudflare:
  - Verify origin target in tunnel points to correct `*.svc.cluster.local` and port.
- ArgoCD/Registry unreachable only externally:
  - Validate Access policy is not blocking expected identity.
- Worker nodes down:
  - Keep cloudflared pinned to master and recover workers separately (k3s-agent, fuse-overlayfs, nftables args).

## Notes specific to this cluster

- Do not install ingress-nginx; Traefik already occupies 80/443 in K3s ServiceLB.
- For worker recovery, keep NFS-specific K3s flags (`fuse-overlayfs`, `proxy-mode=nftables`) on agents.
- Keep NAT service active on master so workers maintain outbound internet for image pulls.
