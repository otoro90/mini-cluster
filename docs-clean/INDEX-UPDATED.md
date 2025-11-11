# 📚 Documentación Completa K3s

Índice de toda la documentación del proyecto mini-cluster.

---

## **🚀 Inicio Rápido**

Para empezar YA, lee:
1. `01-INICIO.md` - 5 pasos, 32 minutos
2. `02-INSTALACION-PASO-A-PASO.md` - Detalles de cada paso

---

## **📂 Estructura de Documentación**

### 🎯 Getting Started (Comienza aquí)

Guías paso-a-paso para instalar y configurar.

| Documento | Contenido | Estado |
|---|---|---|
| 01-INICIO.md | Resumen rápido de 5 pasos ⏱️ 32 min | ✅ |
| 02-INSTALACION-PASO-A-PASO.md | Instalación detallada (5 pasos con sub-pasos) | ✅ |
| 03-CONFIGURACION-RED.md | Red estática, IPs, netplan, dhcpcd | ✅ |
| 04-SSH-KEYS.md | Acceso seguro sin contraseña | ✅ |

### 🔧 Technical (Entender el sistema)

Documentación técnica profunda.

| Documento | Contenido | Estado |
|---|---|---|
| K3S-ARCHITECTURE.md | Cómo funciona K3s, componentes, flujos | ✅ |
| K3S-VS-KUBEADM.md | Comparación y por qué K3s | ✅ |
| NETWORKING.md | Redes, pods, servicios, Flannel, DNS | ✅ |
| STORAGE.md | PersistentVolumes, StorageClass, ConfigMaps | ✅ |
| SECURITY.md | RBAC, Secrets, certificados, Pod Security | ✅ |

### 🆘 Troubleshooting (Problemas)

Soluciones a problemas comunes.

| Documento | Contenido | Estado |
|---|---|---|
| NETWORK-ISSUES.md | Red no funciona, pods sin IP, DNS | ✅ |
| K3S-ISSUES.md | K3s no inicia, nodos offline, certificados | ✅ |
| SSH-ISSUES.md | No puedo conectar SSH, keys, permisos | ✅ |
| CLUSTER-ISSUES.md | Cluster degradado, pods en error, RBAC | ✅ |

### 🚀 Deployment (Instalar componentes)

Guías para componentes opcionales del stack.

| Documento | Contenido | Estado |
|---|---|---|
| CILIUM-CNI.md | CNI mejorado, Network Policies, eBPF | ✅ |
| LONGHORN-STORAGE.md | Storage distribuido, replicación, backups | ✅ |
| PROMETHEUS-GRAFANA.md | Monitoring, dashboards, alertas | ✅ |
| POSTGRESQL-KEYCLOAK.md | Base de datos + Autenticación OAuth2 | ✅ |

---

## **🗂️ Archivos Root**

En la raíz del proyecto:

- `INICIO-AQUI.md` - Punto de entrada principal
- `INSTALACION-K3S-LIMPIA.md` - Instalación completa paso a paso
- `DOCUMENTACION.md` - Índice de documentación
- `LISTO-PARA-INSTALAR.md` - Verificación de requisitos

---

## **Recomendación de Lectura**

```
USUARIO NUEVO → INICIO-AQUI.md (5 min)
        ↓
      01-INICIO.md (5 min)
        ↓
      02-INSTALACION-PASO-A-PASO.md (27 min)
        ↓
      ✅ K3s corriendo
        ↓
      ¿Necesitas entender cómo funciona?
        ↓
      technical/* (30 min cada uno)
        ↓
      ¿Algo no funciona?
        ↓
      troubleshooting/* (según problema)
        ↓
      ¿Quieres agregar componentes?
        ↓
      deployment/* (según componente)
```

---

## **Búsqueda Rápida**

| Necesito... | Lee... |
|---|---|
| Instalar K3s | `01-INICIO.md` o `02-INSTALACION-PASO-A-PASO.md` |
| Solucionar error de red | `NETWORK-ISSUES.md` |
| Solucionar K3s no inicia | `K3S-ISSUES.md` |
| Solucionar problema SSH | `SSH-ISSUES.md` |
| Entender la arquitectura | `K3S-ARCHITECTURE.md` |
| Saber por qué K3s vs Kubeadm | `K3S-VS-KUBEADM.md` |
| Entender redes K3s | `NETWORKING.md` |
| Almacenamiento distribuido | `LONGHORN-STORAGE.md` |
| Monitoreo y dashboards | `PROMETHEUS-GRAFANA.md` |
| Seguridad avanzada | `SECURITY.md` y `CILIUM-CNI.md` |
| BD + Autenticación | `POSTGRESQL-KEYCLOAK.md` |

---

## **Estadísticas**

- 📄 Total documentos: 18
- ✅ Creados: 18 (100%)
- ⏳ Por crear: 0
- 📈 Cobertura: 100% ✅
- ⏱️ Lectura total: ~3 horas

---

## **Stack Completo**

```
┌─────────────────────────────────────────┐
│       Aplicaciones                      │
│  PostgreSQL | Keycloak | Tu App        │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│     Componentes Opcionales              │
│  Cilium | Longhorn | Prometheus+Grafana│
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│          K3s Cluster                    │
│  Master (Orange Pi) + Worker (RPi)     │
│  Flannel CNI | local-path Storage      │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│       Network & Hosts                   │
│  192.168.1.200 | 192.168.1.100        │
│  Gateway 192.168.1.1                   │
└─────────────────────────────────────────┘
```

---

**¿Dónde empezar?**  
→ Lee: `getting-started/01-INICIO.md`
