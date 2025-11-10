# Mini-Cluster Kubernetes

# Mini-Cluster Kubernetes ARM64

Proyecto para configurar un clúster Kubernetes optimizado en dispositivos ARM64 (Orange Pi + Raspberry Pi) con PostgreSQL, Keycloak y acceso WAN.

## Estructura del Proyecto

```
mini-cluster/
├── manifests/                 # Archivos YAML de Kubernetes
│   ├── ingress-traefik.yaml   # Ingress para Traefik (K3s)
│   ├── keycloak-deployment.yaml
│   ├── keycloak-secret.yaml
│   ├── keycloak-service.yaml
│   ├── postgres-secret.yaml
│   ├── postgres-service.yaml
│   └── postgres-statefulset.yaml
├── scripts/                   # Scripts de automatización organizados por función
│   ├── install/               # Scripts de instalación
│   │   ├── install-k3s.sh
│   │   └── migrate-to-k3s.sh
│   ├── deploy/                # Scripts de despliegue
│   │   ├── deploy-k3s-optimized.sh
│   │   └── deploy.sh
│   ├── maintenance/           # Scripts de mantenimiento
│   │   ├── check-status.sh
│   │   ├── cleanup.sh
│   │   ├── redistribute-pods.sh
│   │   └── setup-master-worker.sh
│   └── network/               # Scripts de configuración de red/WAN
│       ├── create-dynu-account.sh
│       ├── diagnose-wan.sh
│       ├── setup-claro-router.sh
│       ├── setup-dynu-ddns.sh
│       ├── setup-router-wan.sh
│       ├── setup-wan-access.sh
│       └── test-port-forwarding.sh
├── README.md                  # Esta documentación
└── [archivos de documentación adicionales]
```

## Fecha
6 de noviembre de 2025

## Arquitectura del Clúster
- **Master (Control Plane)**: Orange Pi (192.168.1.200)
- **Worker**: Raspberry Pi (192.168.1.100)
- **Kubernetes**: K3s v1.30+ (optimizado para ARM64)
- **CNI**: Cilium (eBPF para mejor seguridad y performance)
- **CRI**: containerd
- **Storage**: Longhorn (distribuido y HA)
- **Ingress**: Traefik (incluido en K3s)
- **Monitoreo**: Prometheus + Grafana

## Instalación Inicial

### Orange Pi (Master)
Sigue los pasos en `resumen_instalacion_kubernetes.md` o `guia_kubernetes_continuacion.md`.

Comandos clave:
```bash
# Preparar sistema
sudo apt update && sudo apt upgrade -y
# ... (ver archivos de documentación)

# Inicializar clúster
sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --cri-socket=unix:///var/run/containerd/containerd.sock

# Instalar Calico
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

### Raspberry Pi (Worker)
Similar a Orange Pi, pero usa el comando de join del master.

## Configuración Multi-Nodo
Después de inicializar el master, obtén el token de join:
```bash
kubeadm token create --print-join-command
```

En el worker:
```bash
sudo kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash <hash>
```

## Despliegues

Los manifests están en la carpeta `manifests/`.

### Scripts Disponibles
- `scripts/install/install-k3s.sh`: Instala K3s en ARM64
- `scripts/install/migrate-to-k3s.sh`: Migra de kubeadm a K3s (¡cuidado, resetea cluster!)
- `scripts/deploy/deploy-k3s-optimized.sh`: Despliegue completo optimizado con K3s + Cilium + Longhorn + Prometheus
- `scripts/deploy/deploy.sh`: Despliegue legacy con kubeadm (para referencia)
- `scripts/maintenance/check-status.sh`: Verificación del estado
- `scripts/maintenance/cleanup.sh`: Limpieza de recursos no utilizados
- `scripts/maintenance/setup-master-worker.sh`: Configura el master como worker de emergencia
- `scripts/maintenance/redistribute-pods.sh`: Fuerza redistribución de pods para alta disponibilidad
- `scripts/network/setup-wan-access.sh`: Guía para configurar acceso desde internet
- `scripts/network/diagnose-wan.sh`: Diagnóstico completo de problemas de acceso WAN
- `scripts/network/setup-router-wan.sh`: Instrucciones detalladas para configuración del router
- `scripts/network/setup-dynu-ddns.sh`: Instala y configura cliente Dynu DDNS
- `scripts/network/create-dynu-account.sh`: Guía completa para crear cuenta en Dynu
- `scripts/network/setup-claro-router.sh`: Instrucciones específicas para router Claro
- `scripts/network/test-port-forwarding.sh`: Prueba rápida de port forwarding

### PostgreSQL
- `postgres-secret.yaml`: Credenciales
- `postgres-service.yaml`: Servicio
- `postgres-statefulset.yaml`: StatefulSet con PVC para persistencia

### Keycloak
- `keycloak-secret.yaml`: Credenciales de admin y DB
- `keycloak-deployment.yaml`: Deployment con probes de readiness/liveness
- `keycloak-service.yaml`: Servicio

## Despliegue Automático

### Opción 1: Setup Optimizado con K3s (Recomendado)
```bash
# 1. Instalar K3s (nuevo cluster)
scp scripts/install/install-k3s.sh root@192.168.1.200:/root/
ssh root@192.168.1.200 "/root/install-k3s.sh"

# 2. Desplegar todo optimizado
scp scripts/deploy/deploy-k3s-optimized.sh root@192.168.1.200:/root/
ssh root@192.168.1.200 "/root/deploy-k3s-optimized.sh"
```

### Opción 2: Migrar de kubeadm a K3s
```bash
# ⚠️ CUIDADO: Resetea el cluster actual
scp scripts/install/migrate-to-k3s.sh root@192.168.1.200:/root/
ssh root@192.168.1.200 "/root/migrate-to-k3s.sh"
```

### Opción 3: Setup Legacy con kubeadm
```bash
# Copiar archivos al servidor
scp manifests/* scripts/deploy/deploy.sh scripts/maintenance/check-status.sh root@192.168.1.200:/root/

# Ejecutar despliegue
ssh root@192.168.1.200 "chmod +x /root/deploy.sh && /root/deploy.sh"
```

## Acceso WAN (Internet)

### Configuración de IP Estática
Para acceso desde internet, configura IP estática en el Orange Pi (master):

```bash
# Editar configuración de red
sudo nano /etc/netplan/50-cloud-init.yaml

# Agregar configuración:
network:
  version: 2
  ethernets:
    eth0:  # Cambia por tu interfaz de red
      dhcp4: false
      addresses:
        - 192.168.1.200/24  # Tu IP actual
      routes:
        - to: default
          via: 192.168.1.1  # Gateway de tu router
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]

# Aplicar cambios
sudo netplan apply
```

### Port Forwarding en Router
Configura tu router para redirigir puertos externos. **Este es el paso más importante y probablemente faltante.**

**Ejemplo de configuración (varía por router):**
```
Puerto externo: 8080 → IP interna: 192.168.1.200 → Puerto interno: 8080
Puerto externo: 5432 → IP interna: 192.168.1.200 → Puerto interno: 5432
```

**Comandos para verificar:**
```bash
# Diagnóstico completo
/root/diagnose-wan.sh

# Verificar IP WAN real
curl -s https://api.ipify.org
```

### Problemas Comunes
- **IP WAN diferente**: La IP que muestra cual-es-mi-ip.net puede ser diferente a la real
- **ISP bloquea puertos**: Algunos proveedores bloquean 8080, 5432. Prueba con puertos alternos (8081, 5433)
- **Doble NAT**: Si tienes router del ISP + router local, configura port forwarding en ambos
- **Firewall**: Desactiva temporalmente firewall del router para testing

### Testing Paso a Paso
1. **Desde otro dispositivo en tu red local:**
   ```bash
   curl http://192.168.1.200:8080
   ```

2. **Desde internet (usando IP WAN real):**
   ```bash
   curl http://TU-IP-WAN:8080
   ```

3. **Si no funciona:** Ejecuta `/root/diagnose-wan.sh` para diagnóstico detallado

### Seguridad Recomendada
- **PostgreSQL**: Usa túnel SSH o VPN en lugar de exponer puerto directamente
- **Keycloak**: Considera SSL con Let's Encrypt si tienes dominio

## DNS Dinámico (DDNS) con Dynu

Para evitar problemas con IPs dinámicas que cambian, configura DNS dinámico con Dynu (gratuito).

### ¿Por qué DDNS?
- **IP dinámica**: Tu proveedor de internet cambia tu IP periódicamente
- **Acceso fácil**: URLs fijas como `http://tu-nombre.dynu.net:8080` en lugar de `http://181.51.34.83:8080`
- **Gratuito**: Dynu ofrece servicio gratuito con actualizaciones automáticas
- **Compatible ARM64**: Usamos ddclient que funciona perfectamente en ARM64

### Instalación y Configuración

```bash
# Copiar scripts al servidor
scp scripts/network/setup-dynu-ddns.sh scripts/network/create-dynu-account.sh root@192.168.1.200:/root/

# Ejecutar guía de creación de cuenta
ssh root@192.168.1.200 "/root/create-dynu-account.sh"

# Instalar ddclient para Dynu
ssh root@192.168.1.200 "/root/setup-dynu-ddns.sh"
```

### Configuración del Cliente

Después de crear tu cuenta en Dynu, configura ddclient:

```bash
# En el Orange Pi, edita la configuración
sudo nano /etc/ddclient.conf

# Reemplaza con tus datos:
protocol=dyndns2
use=web
server=api.dynu.com
login=TU_EMAIL
password=TU_PASSWORD
TU_HOSTNAME.dynu.net
```

### Actualización Automática

ddclient se ejecuta como servicio systemd y actualiza automáticamente:

```bash
# Verificar estado del servicio
sudo systemctl status ddclient

# Forzar actualización manual
sudo ddclient -daemon=0

# Ver logs
sudo journalctl -u ddclient -f
```

### URLs con DDNS

Una vez configurado, accede usando tu dominio Dynu:
- **Keycloak**: `http://tu-nombre.dynu.net:8080`
- **PostgreSQL**: `tu-nombre.dynu.net:5432`
- **Nginx**: `http://tu-nombre.dynu.net:30126/`

### Verificación

```bash
# Probar actualización manual con debug
sudo ddclient -daemon=0 -debug -verbose -noquiet

# Verificar que el hostname se actualizó en Dynu
curl -s https://api.ipify.org  # Tu IP actual
nslookup tu-nombre.dynu.net    # Debe resolver a tu IP
```

### NGINX Ingress Controller
El script `deploy.sh` instala automáticamente NGINX Ingress Controller para routing avanzado.

**URLs de acceso:**
- **Keycloak**: `http://TU-IP-PUBLICA:8080` o `http://TU-IP-PUBLICA:30126/keycloak`
- **PostgreSQL**: `TU-IP-PUBLICA:5432` (desde DBeaver, etc.)
- **Nginx (test)**: `http://TU-IP-PUBLICA:30126/`

### Servicios Disponibles
- **Ingress Controller**: Puerto 30126 (HTTP), 32024 (HTTPS)
- **Keycloak**: Puerto 8080 directo
- **PostgreSQL**: Puerto 5432 directo

## Alta Disponibilidad

### Distribución de Réplicas
Las aplicaciones están distribuidas en ambos nodos para maximizar la resiliencia:

- **Nginx**: 2 réplicas (1 en master, 1 en worker)
- **PostgreSQL**: 1 réplica principal + 1 StatefulSet (con persistencia)
- **Keycloak**: 1 réplica (con probes de health)

### Recuperación Automática
Si un nodo falla:
1. Las réplicas sobrevivientes mantienen el servicio
2. Kubernetes reprograma automáticamente los pods perdidos
3. El master puede asumir carga adicional si es necesario

### Redistribución Manual
```bash
# Forzar redistribución de pods
kubectl delete pods -l app=<app-name>

# O usar el script automatizado
/root/redistribute-pods.sh
```

## Copiar Manifests a Servidores

Desde tu máquina local (Windows):

```powershell
# A Orange Pi
scp manifests/* root@192.168.1.200:/root/

# A Raspberry Pi
scp manifests/* root@192.168.1.100:/root/
```

Luego, en cada servidor:
```bash
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl apply -f /root/*.yaml
```

## Estado Actual
- ✅ **K3s optimizado**: Cluster corriendo en K3s para mejor performance ARM64
- ✅ **Cilium CNI**: Networking avanzado con eBPF para seguridad
- ✅ **Longhorn Storage**: Storage distribuido y HA para PostgreSQL
- ✅ **Traefik Ingress**: Routing moderno incluido en K3s
- ✅ **Prometheus + Grafana**: Monitoreo completo del cluster
- ✅ Master configurado como worker de emergencia (puede ejecutar pods de usuario)
- ✅ Alta disponibilidad: Réplicas distribuidas en ambos nodos
- ✅ PostgreSQL desplegado y accesible con persistencia
- ✅ Keycloak desplegado y corriendo con probes de health
- ✅ Documentación completa (este README)
- ✅ Scripts de automatización funcionales
- ✅ Pruebas de integración Keycloak-PostgreSQL (accesible en http://192.168.1.200:8080)
- ✅ Port-forwards persistentes configurados
- ✅ **DDNS funcionando: otoro.ddnsfree.com → 181.51.34.83**
- ⏳ **PENDIENTE**: Configurar port forwarding en router para acceso WAN

## Próximos Pasos
1. ✅ Completar despliegue de Keycloak
2. ✅ Probar integración con PostgreSQL
3. ✅ Automatizar despliegue completo
4. Agregar más aplicaciones (ej. nginx con ingress)
5. Configurar monitoring (Prometheus + Grafana)
6. Implementar CI/CD básico
7. Documentar backup/restore procedures

## Troubleshooting

### Port-forwards no persisten
Los port-forwards requieren `nohup` para ejecutarse en background. Usa el script `deploy.sh` que los configura automáticamente.

### Port forwarding no funciona
Si después de configurar el router no puedes acceder desde WAN:
```bash
# Prueba rápida
/root/test-port-forwarding.sh

# Diagnóstico completo
/root/diagnose-wan.sh
```

**Para router Claro:**
```bash
# Instrucciones específicas
/root/setup-claro-router.sh
```

### PVCs en Pending
Si los PVCs quedan en Pending, verifica que haya un StorageClass disponible:
```bash
kubectl get storageclass
```

### Keycloak no inicia
Verifica la conectividad con PostgreSQL:
```bash
kubectl exec -it <keycloak-pod> -- curl postgres-svc:5432
```

### DDNS no actualiza
Si usas ddclient, verifica la configuración:
```bash
# Ver estado
sudo systemctl status ddclient

# Ver logs
sudo journalctl -u ddclient -f

# Actualizar manualmente
sudo ddclient -daemon=0
```

### Acceso desde WAN
Tu dominio DDNS `otoro.ddnsfree.com` ya está funcionando. Solo necesitas configurar port forwarding en el router (192.168.1.1).

## Mejoras Implementadas

### En Manifests
- ✅ Probes de readiness/liveness en Keycloak para mejor estabilidad
- ✅ Sintaxis YAML corregida en postgres-statefulset
- ✅ StorageClass y PV para persistencia de PostgreSQL
- ✅ Secrets separados para mejor organización y seguridad

### En Scripts
- ✅ `deploy.sh`: Automatización completa del despliegue
- ✅ `check-status.sh`: Verificación del estado del clúster
- ✅ Port-forwards persistentes con logging y PIDs
- ✅ Validación de readiness antes de continuar
- ✅ Manejo inteligente de StatefulSets (no espera por storage provisioning)

### Problemas Resueltos Automáticamente
- ❌ Port-forwards que fallaban → ✅ Persistentes con `nohup`
- ❌ Esperas manuales → ✅ `kubectl wait` automático  
- ❌ Health checks faltantes → ✅ Probes configuradas
- ❌ Sintaxis YAML errónea → ✅ Validada y corregida
- ❌ Storage no provisionado → ✅ StorageClass + PV local

## Resumen del Proyecto

Este mini-cluster Kubernetes ARM64 incluye:

- **Infraestructura**: Clúster de 2 nodos (Orange Pi master + Raspberry Pi worker)
- **Master como Worker**: El master puede ejecutar pods de usuario en caso de emergencia
- **Alta Disponibilidad**: Réplicas distribuidas en ambos nodos para resiliencia
- **Base de datos**: PostgreSQL con persistencia local
- **Identity Management**: Keycloak integrado con PostgreSQL
- **Ingress Controller**: NGINX para routing y acceso WAN
- **Automatización**: Scripts completos para despliegue, verificación, limpieza y configuración
- **Acceso externo**: Port-forwards persistentes y ingress para desarrollo

**URLs de acceso:**
- Keycloak Admin: http://192.168.1.200:8080 (admin/admin)
- Keycloak via Traefik: http://192.168.1.200/keycloak
- PostgreSQL: 192.168.1.200:5432 (postgres/password)
- **Prometheus**: http://192.168.1.200:9090
- **Grafana**: http://192.168.1.200:3000 (admin/admin)
- **Longhorn UI**: Accede vía kubectl port-forward o ingress
- **WAN Access (después de configurar router)**: http://otoro.ddnsfree.com:8080

**Comandos útiles:**
```bash
# Desplegar todo
/root/deploy.sh

# Verificar estado
/root/check-status.sh

# Limpiar recursos
/root/cleanup.sh

# Configurar master como worker
/root/setup-master-worker.sh

# Redistribuir pods
/root/redistribute-pods.sh

# Configurar acceso WAN
/root/setup-wan-access.sh
```