# Guía de Exposición a Internet para el Mini-Cluster

Esta guía describe la forma recomendada de publicar múltiples servicios a Internet para este clúster K3s.

## Arquitectura recomendada

- Mantener Traefik como el único controlador de ingress en el clúster.
- Publicar servicios usando Cloudflare Tunnel (túnel de salida desde el clúster hacia Cloudflare).
- Enrutar cada nombre de host público a un servicio interno de Kubernetes.
- Proteger los endpoints de administración con Cloudflare Access.

Por qué esta es la mejor opción aquí:

- No requiere redirección de puertos (port-forward) en el router doméstico.
- Funciona con IP residencial dinámica.
- Coincide con la configuración actual de K3s donde Traefik ya posee los puertos 80/443.
- Mantiene la superficie de ataque más pequeña que exponiendo NodePorts públicamente.

## Realidad actual del clúster (verificada antes de esta guía)

- El servicio de Traefik está saludable en `192.168.1.210`.
- Los Ingress existentes están funcionando con `ingressClassName: traefik`.
- Los nodos trabajadores (workers) están actualmente en estado `NotReady`; desplegar cloudflared fijado a `orangepi6plus` hasta que los workers se recuperen.

## Requisitos previos

- Un dominio en Cloudflare (ejemplo: `forjanova.com`).
- Acceso al panel de Cloudflare Zero Trust.
- Acceso SSH al nodo maestro `root@192.168.1.210`.
- Acceso a `kubectl` desde el maestro (`KUBECONFIG=/etc/rancher/k3s/k3s.yaml`).

## Paso 1: Crear el túnel en el panel de Cloudflare

En Zero Trust:

1. Ve a Networks > Tunnels.
2. Crea un túnel (tipo de conector: Cloudflared).
3. Copia el token del túnel.

No crees entradas DNS locales todavía; mapearemos los nombres de host en el Paso 4.

## Paso 2: Desplegar cloudflared en K3s

Aplica el manifiesto:

```bash
sshpass -p '123456' ssh -o StrictHostKeyChecking=no root@192.168.1.210 \
  "cat > /tmp/cloudflared.yaml" < manifests/cloudflare-tunnel/cloudflared.yaml

sshpass -p '123456' ssh -o StrictHostKeyChecking=no root@192.168.1.210 \
  "KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl apply -f /tmp/cloudflared.yaml"
```

Parchea el secreto del token (recomendado después de la primera aplicación):

```bash
sshpass -p '123456' ssh -o StrictHostKeyChecking=no root@192.168.1.210 \
  "kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml -n cloudflare-tunnel create secret generic cloudflared-tunnel-token \
  --from-literal=token='TU_TOKEN_DE_TUNEL' --dry-run=client -o yaml | \
  kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml apply -f -"
```

Validar:

```bash
sshpass -p '123456' ssh -o StrictHostKeyChecking=no root@192.168.1.210 \
  "kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml -n cloudflare-tunnel get pods -o wide"

sshpass -p '123456' ssh -o StrictHostKeyChecking=no root@192.168.1.210 \
  "kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml -n cloudflare-tunnel logs deploy/cloudflared --tail=80"
```

## Paso 3: Mantener el Ingress de Kubernetes interno como está

Ya tienes estos nombres de host internos:

- `tramites-dev.local`
- `tramites-api-dev.local`
- `argocd.local`
- `registry.192.168.1.210.nip.io`

No es necesario reemplazar Traefik. Cloudflare Tunnel apuntará los nombres de host públicos a esas rutas/servicios internos.

## Paso 4: Agregar nombres de host públicos en Cloudflare Tunnel

Para cada servicio, crea un "Public Hostname" en el túnel:

- `tramites-dev.tudominio.com` -> `http://tramites-frontend.tramites-dev.svc.cluster.local:80`
- `api-dev.tudominio.com` -> `http://tramites-api.tramites-dev.svc.cluster.local:80`
- `argocd.tudominio.com` -> `http://argocd-server.argocd.svc.cluster.local:80`
- `registry.tudominio.com` -> `http://registry.registry.svc.cluster.local:5000`

Notas:

- Prefiere los nombres de servicio DNS de Kubernetes sobre las IPs de los nodos.
- Mantén el protocolo `http` entre el túnel y el servicio dentro del clúster, a menos que ya termines TLS internamente.
- Para el Docker Registry, aumenta los límites de subida/cuerpo en la ruta de Traefik si es necesario.

## Paso 5: Asegurar las superficies de administración

Endurecimiento mínimo:

- Coloca `argocd.tudominio.com` bajo una política de Cloudflare Access.
- Coloca `registry.tudominio.com` bajo Access o una lista de permitidos por IP.
- Mantén el servidor API de K3s y el acceso SSH cerrados al Internet público.

Política de Access recomendada:

- Permitir solo correos electrónicos/grupos específicos.
- Forzar MFA (Autenticación de múltiples factores).
- Agregar un TTL de sesión corto para las aplicaciones de administración.

## Paso 6: Estrategia TLS opcional dentro del clúster

Tienes dos modelos válidos:

- Modelo A (más simple): TLS termina en el borde de Cloudflare; túnel hacia HTTP interno.
- Modelo B (estricto de extremo a extremo): TLS en el borde de Cloudflare + TLS interno con cert-manager DNS-01.

Para este laboratorio doméstico, el Modelo A suele ser suficiente. Usa el Modelo B solo si requieres cumplimiento de TLS interno.

## Paso 7: Lista de verificación de validación

Ejecuta desde tu laptop:

```bash
curl -I https://tramites-dev.tudominio.com
curl -I https://api-dev.tudominio.com/health
curl -I https://argocd.tudominio.com
```

Ejecuta desde el maestro:

```bash
kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml get ingress -A
kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml -n cloudflare-tunnel get pods
kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml -n cloudflare-tunnel logs deploy/cloudflared --tail=100
```

## Mapa rápido de resolución de problemas

- El nombre de host público agota el tiempo de espera (timeout):
  - Verifica los logs del pod de cloudflared y el estado del túnel en Cloudflare.
- Error 502/504 de Cloudflare:
  - Verifica que el objetivo de origen en el túnel apunte al `*.svc.cluster.local` y puerto correctos.
- ArgoCD/Registry inalcanzables solo externamente:
  - Valida que la política de Access no esté bloqueando la identidad esperada.
- Nodos trabajadores caídos:
  - Mantén cloudflared fijado al maestro y recupera los trabajadores por separado (k3s-agent, fuse-overlayfs, argumentos de nftables).

## Notas específicas para este clúster

- No instales ingress-nginx; Traefik ya ocupa el 80/443 en el ServiceLB de K3s.
- Para la recuperación de los trabajadores, mantén los flags de K3s específicos para NFS (`fuse-overlayfs`, `proxy-mode=nftables`) en los agentes.
- Mantén el servicio NAT activo en el maestro para que los trabajadores mantengan internet de salida para las descargas de imágenes.
