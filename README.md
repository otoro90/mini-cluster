# Mini-Cluster Kubernetes ARM64 - K3s Limpio

Proyecto para configurar un clúster Kubernetes de alta disponibilidad en dispositivos ARM64 con **K3s** v1.33.5+k3s1 limpio, documentado y sin conflictos de información.

**ESTADO**: ✅ Documentación completamente reorganizada, proyecto limpio y ordenado, listo para instalación.

> � **¡COMIENZA AQUÍ!** 
> 1. Lee [NAVEGACION.md](NAVEGACION.md) para orientarte (2 min)
> 2. Abre [INICIO-AQUI.md](INICIO-AQUI.md) para instalar (5 pasos, 32 min)
> 3. ¡Tu clúster K3s estará funcionando en 50 minutos!

## 🎯 ¿Qué es Este Proyecto?

Este es un conjunto completo y bien documentado para desplegar K3s en una Orange Pi (master) y Raspberry Pi (worker). Todo está organizado en una estructura limpia sin documentación obsoleta que pueda causar confusión.

- **Antes**: Documentación fragmentada, información sobre migraciones fallidas, conflictos de instrucciones
- **Ahora**: Una única fuente de verdad con documentación clara para K3s limpio

## Estructura del Proyecto

```
mini-cluster/
├── docs-clean/                        # ✅ NUEVA documentación limpia (18 archivos)
│   ├── getting-started/               # Inicio rápido (4 docs)
│   │   ├── 01-INICIO.md              # 5 pasos, 32 minutos
│   │   ├── 02-INSTALACION-PASO-A-PASO.md
│   │   ├── 03-CONFIGURACION-RED.md
│   │   └── 04-SSH-KEYS.md
│   ├── technical/                     # Referencia técnica (5 docs)
│   │   ├── K3S-ARCHITECTURE.md
│   │   ├── K3S-VS-KUBEADM.md
│   │   ├── NETWORKING.md
│   │   ├── STORAGE.md
│   │   └── SECURITY.md
│   ├── troubleshooting/               # Problemas y soluciones (4 docs)
│   │   ├── NETWORK-ISSUES.md
│   │   ├── K3S-ISSUES.md
│   │   ├── SSH-ISSUES.md
│   │   └── CLUSTER-ISSUES.md
│   ├── deployment/                    # Componentes opcionales (4 docs)
│   │   ├── CILIUM-CNI.md
│   │   ├── LONGHORN-STORAGE.md
│   │   ├── PROMETHEUS-GRAFANA.md
│   │   └── POSTGRESQL-KEYCLOAK.md
│   └── INDEX.md                       # Índice de navegación
├── scripts/install/                   # ✅ 3 scripts limpios (sin migraciones)
│   ├── INSTALL-K3S-MASTER-CLEAN.sh   # Instalar en Orange Pi
│   ├── INSTALL-K3S-WORKER-CLEAN.sh   # Instalar en Raspberry Pi
│   └── VALIDATE-K3S-CLUSTER.sh       # Validar clúster
├── manifests/                         # Archivos YAML opcionales
│   ├── keycloak-deployment.yaml
│   ├── postgres-statefulset.yaml
│   └── ...otros manifests
├── agents/                            # 📊 Reportes e instrucciones internas
│   ├── README.md                      # Índice de contenido
│   ├── RESUMEN-ESTADO-FINAL.md       # Estado final del proyecto
│   ├── VERIFICACION-LIMPIEZA.md      # Checklist de verificación
│   └── ...otros reportes
├── INICIO-AQUI.md                     # 📍 EMPIEZA AQUÍ
├── LISTO-PARA-INSTALAR.md            # Checklist de requisitos
├── INSTALACION-K3S-LIMPIA.md         # Guía principal
├── DOCUMENTACION-COMPLETA.md         # Resumen ejecutivo
├── README.md                          # Esta documentación
└── [sin archivos obsoletos de kubeadm/migraciones]
```

**IMPORTANTE**: 
- ✅ Toda documentación antigua ha sido ELIMINADA
- ✅ Solo existe UN conjunto de instrucciones (docs-clean/)
- ✅ Ningún contenido conflictivo
- ✅ Los LLMs no tendrán información desactualizada

## Fecha
6 de noviembre de 2025 (Reorganización completa y limpieza)

## Arquitectura del Clúster

- **Master (Control Plane)**: Orange Pi (192.168.1.254)
- **Worker**: Raspberry Pi (192.168.1.250)
- **Kubernetes**: K3s v1.33.5+k3s1 (optimizado para ARM64)
- **CNI**: Flannel (por defecto, opcional: Cilium)
- **Storage**: local-path (por defecto, opcional: Longhorn)
- **Ingress**: Traefik (incluido en K3s)

## 🚀 Instalación Rápida (32 minutos)

### Paso 1: Lee la Documentación Inicial
```bash
# Abre INICIO-AQUI.md en tu editor favorito
# Te dirá todo lo que necesitas hacer en 5 pasos
```

### Paso 2: Configura Red (Ambos Nodos)

**Orange Pi (master)** - Edita `/etc/netplan/50-cloud-init.yaml`:
```yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: false
      addresses:
        - 192.168.1.254/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
```

**Raspberry Pi (worker)** - Edita `/etc/dhcpcd.conf`:
```bash
interface eth0
static ip_address=192.168.1.250/24
static routers=192.168.1.1
static domain_name_servers=8.8.8.8 1.1.1.1
```

### Paso 3: Configura SSH (Desde tu PC Windows)

```powershell
# Generar claves
ssh-keygen -t rsa -b 4096 -f $env:USERPROFILE\.ssh\id_rsa -N '""'

# Copiar clave pública a ambos nodos
cat $env:USERPROFILE\.ssh\id_rsa.pub | ssh root@192.168.1.254 "cat >> ~/.ssh/authorized_keys"
cat $env:USERPROFILE\.ssh\id_rsa.pub | ssh root@192.168.1.250 "cat >> ~/.ssh/authorized_keys"

# Verificar
ssh -o PasswordAuthentication=no root@192.168.1.254 "echo OK"
```

### Paso 4: Instalar K3s en Master

```powershell
# Copiar script
scp scripts/install/INSTALL-K3S-MASTER-CLEAN.sh root@192.168.1.254:/root/

# Ejecutar
ssh root@192.168.1.254 "chmod +x /root/INSTALL-K3S-MASTER-CLEAN.sh && /root/INSTALL-K3S-MASTER-CLEAN.sh"
```

### Paso 5: Instalar K3s en Worker

```powershell
# Copiar script
scp scripts/install/INSTALL-K3S-WORKER-CLEAN.sh root@192.168.1.250:/root/

# Ejecutar
ssh root@192.168.1.250 "chmod +x /root/INSTALL-K3S-WORKER-CLEAN.sh && /root/INSTALL-K3S-WORKER-CLEAN.sh"
```

### Paso 6: Validar Clúster

```powershell
# Ejecutar script de validación
ssh root@192.168.1.254 "chmod +x /root/VALIDATE-K3S-CLUSTER.sh && /root/VALIDATE-K3S-CLUSTER.sh"

# Deberías ver ambos nodos en "Ready":
# NAME              STATUS   ROLES
# orangepi5         Ready    control-plane
# raspberry-worker  Ready    <none>
```

**¡Listo!** Tu clúster K3s está funcionando. ✅

## Despliegues Opcionales

Después de que el clúster esté corriendo, puedes desplegar componentes adicionales:

- **Cilium CNI**: Ver `docs-clean/deployment/CILIUM-CNI.md`
- **Longhorn Storage**: Ver `docs-clean/deployment/LONGHORN-STORAGE.md`
- **Prometheus + Grafana**: Ver `docs-clean/deployment/PROMETHEUS-GRAFANA.md`
- **PostgreSQL + Keycloak**: Ver `docs-clean/deployment/POSTGRESQL-KEYCLOAK.md`

Los manifests están en la carpeta `manifests/`.

## 📖 Documentación

### Punto de Entrada
- **INICIO-AQUI.md**: Comienza por aquí (5 pasos, 32 min)
- **LISTO-PARA-INSTALAR.md**: Checklist de requisitos
- **INSTALACION-K3S-LIMPIA.md**: Guía principal de instalación
- **DOCUMENTACION-COMPLETA.md**: Resumen ejecutivo

### Guías por Fase
**docs-clean/getting-started/** (Primeros pasos)
- 01-INICIO.md
- 02-INSTALACION-PASO-A-PASO.md
- 03-CONFIGURACION-RED.md
- 04-SSH-KEYS.md

**docs-clean/technical/** (Referencia técnica)
- K3S-ARCHITECTURE.md
- K3S-VS-KUBEADM.md
- NETWORKING.md
- STORAGE.md
- SECURITY.md

**docs-clean/troubleshooting/** (Solución de problemas)
- NETWORK-ISSUES.md
- K3S-ISSUES.md
- SSH-ISSUES.md
- CLUSTER-ISSUES.md

**docs-clean/deployment/** (Componentes opcionales)
- CILIUM-CNI.md
- LONGHORN-STORAGE.md
- PROMETHEUS-GRAFANA.md
- POSTGRESQL-KEYCLOAK.md

## 🔧 Estado Actual

✅ **Instalación base K3s**: Lista (32 minutos)
✅ **Documentación**: 18 archivos, sin conflictos
✅ **Scripts de instalación**: 3 scripts limpios
✅ **Información obsoleta**: ELIMINADA (sin LLM hallucinations)
⏳ **Componentes opcionales**: Disponibles en `docs-clean/deployment/`

## 📋 Próximos Pasos

1. Lee **INICIO-AQUI.md** (5 minutos)
2. Lee **docs-clean/getting-started/02-INSTALACION-PASO-A-PASO.md** (20 minutos)
3. Configura red en ambos nodos
4. Configura SSH keys
5. Ejecuta los 3 scripts de instalación
6. Valida el clúster
7. (Opcional) Instala componentes adicionales

## 🆘 Troubleshooting

Para problemas durante la instalación o uso, consulta:

- **NETWORK-ISSUES.md**: Problemas de conectividad
- **K3S-ISSUES.md**: Problemas de Kubernetes
- **SSH-ISSUES.md**: Problemas de SSH
- **CLUSTER-ISSUES.md**: Problemas del clúster

**Todos los archivos están en: `docs-clean/troubleshooting/`**