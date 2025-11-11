# 📑 Tabla de Contenidos Global - Mini-Cluster K3s

**Referencia rápida para encontrar cualquier información en el proyecto.**

---

## 🚀 INSTALACIÓN

### Para Comenzar
- **[INICIO-AQUI.md](../INICIO-AQUI.md)** - Punto de entrada (5 pasos, 32 min)
- **[NAVEGACION.md](../NAVEGACION.md)** - Guía de navegación por el proyecto
- **[LISTO-PARA-INSTALAR.md](../LISTO-PARA-INSTALAR.md)** - Checklist de requisitos

### Guías Detalladas
- **[INSTALACION-K3S-LIMPIA.md](../INSTALACION-K3S-LIMPIA.md)** - Guía completa de instalación
- **[docs-clean/getting-started/01-INICIO.md](../docs-clean/getting-started/01-INICIO.md)** - 5 pasos iniciales
- **[docs-clean/getting-started/02-INSTALACION-PASO-A-PASO.md](../docs-clean/getting-started/02-INSTALACION-PASO-A-PASO.md)** - Instalación paso a paso

### Configuración
- **[docs-clean/getting-started/03-CONFIGURACION-RED.md](../docs-clean/getting-started/03-CONFIGURACION-RED.md)** - Red estática
- **[docs-clean/getting-started/04-SSH-KEYS.md](../docs-clean/getting-started/04-SSH-KEYS.md)** - SSH sin contraseña

### Scripts de Instalación
- `scripts/install/INSTALL-K3S-MASTER-CLEAN.sh` - Instalar en master
- `scripts/install/INSTALL-K3S-WORKER-CLEAN.sh` - Instalar en worker
- `scripts/install/VALIDATE-K3S-CLUSTER.sh` - Validar clúster

---

## 📚 REFERENCIA TÉCNICA

### Arquitectura y Diseño
- **[docs-clean/technical/K3S-ARCHITECTURE.md](../docs-clean/technical/K3S-ARCHITECTURE.md)** - Arquitectura de K3s
- **[docs-clean/technical/K3S-VS-KUBEADM.md](../docs-clean/technical/K3S-VS-KUBEADM.md)** - Por qué K3s

### Componentes del Clúster
- **[docs-clean/technical/NETWORKING.md](../docs-clean/technical/NETWORKING.md)** - Networking de pods
- **[docs-clean/technical/STORAGE.md](../docs-clean/technical/STORAGE.md)** - Volúmenes persistentes
- **[docs-clean/technical/SECURITY.md](../docs-clean/technical/SECURITY.md)** - Seguridad en K3s

---

## 🆘 TROUBLESHOOTING

### Por Problema
- **[docs-clean/troubleshooting/NETWORK-ISSUES.md](../docs-clean/troubleshooting/NETWORK-ISSUES.md)** - Problemas de conectividad
- **[docs-clean/troubleshooting/K3S-ISSUES.md](../docs-clean/troubleshooting/K3S-ISSUES.md)** - Problemas de K3s
- **[docs-clean/troubleshooting/SSH-ISSUES.md](../docs-clean/troubleshooting/SSH-ISSUES.md)** - Problemas de SSH
- **[docs-clean/troubleshooting/CLUSTER-ISSUES.md](../docs-clean/troubleshooting/CLUSTER-ISSUES.md)** - Problemas del clúster

---

## ⚙️ COMPONENTES OPCIONALES

### Después de Instalar K3s
- **[docs-clean/deployment/CILIUM-CNI.md](../docs-clean/deployment/CILIUM-CNI.md)** - CNI avanzado con eBPF
- **[docs-clean/deployment/LONGHORN-STORAGE.md](../docs-clean/deployment/LONGHORN-STORAGE.md)** - Storage distribuido
- **[docs-clean/deployment/PROMETHEUS-GRAFANA.md](../docs-clean/deployment/PROMETHEUS-GRAFANA.md)** - Monitoreo
- **[docs-clean/deployment/POSTGRESQL-KEYCLOAK.md](../docs-clean/deployment/POSTGRESQL-KEYCLOAK.md)** - Base de datos + OAuth2

---

## 📊 INFORMACIÓN DEL PROYECTO

### Visiones Generales
- **[README.md](../README.md)** - Visión general del proyecto
- **[DOCUMENTACION-COMPLETA.md](../DOCUMENTACION-COMPLETA.md)** - Resumen ejecutivo
- **[docs-clean/INDEX.md](../docs-clean/INDEX.md)** - Índice de documentación limpia

### Reportes Internos (en agents/)
- **[agents/README.md](README.md)** - Descripción de la carpeta
- **[agents/INDEX.md](INDEX.md)** - Índice de reportes
- **[agents/RESUMEN-ESTADO-FINAL.md](RESUMEN-ESTADO-FINAL.md)** - Estado final del proyecto
- **[agents/VERIFICACION-LIMPIEZA.md](VERIFICACION-LIMPIEZA.md)** - Verificación de limpieza

---

## 🔍 BÚSQUEDA RÁPIDA

### Si Necesitas Saber...

**...cómo instalar K3s**
→ [INICIO-AQUI.md](../INICIO-AQUI.md)

**...dónde está cada archivo**
→ [NAVEGACION.md](../NAVEGACION.md)

**...cómo funciona K3s**
→ [docs-clean/technical/K3S-ARCHITECTURE.md](../docs-clean/technical/K3S-ARCHITECTURE.md)

**...cuál es el requisito mínimo**
→ [LISTO-PARA-INSTALAR.md](../LISTO-PARA-INSTALAR.md)

**...cómo solucionar problemas**
→ [docs-clean/troubleshooting/](../docs-clean/troubleshooting/)

**...qué fue eliminado**
→ [VERIFICACION-LIMPIEZA.md](VERIFICACION-LIMPIEZA.md)

**...cómo se hizo la limpieza**
→ [COMANDOS-LIMPIEZA-USADOS.md](COMANDOS-LIMPIEZA-USADOS.md)

**...qué componentes instalar después**
→ [docs-clean/deployment/](../docs-clean/deployment/)

---

## 📁 ESTRUCTURA COMPLETA

```
mini-cluster/
├── 📘 INICIO-AQUI.md                    [Instalación]
├── 🗺️  NAVEGACION.md                    [Orientación]
├── 📘 README.md                         [General]
├── 📘 LISTO-PARA-INSTALAR.md           [Requisitos]
├── 📘 INSTALACION-K3S-LIMPIA.md        [Detallado]
├── 📘 DOCUMENTACION-COMPLETA.md        [Resumen]
│
├── 📁 docs-clean/
│   ├── 01-INICIO.md                    [Quick start]
│   ├── 02-INSTALACION-PASO-A-PASO.md   [Detallado]
│   ├── 03-CONFIGURACION-RED.md         [Red]
│   ├── 04-SSH-KEYS.md                  [SSH]
│   ├── K3S-ARCHITECTURE.md             [Técnico]
│   ├── K3S-VS-KUBEADM.md              [Comparativo]
│   ├── NETWORKING.md                   [Técnico]
│   ├── STORAGE.md                      [Técnico]
│   ├── SECURITY.md                     [Técnico]
│   ├── NETWORK-ISSUES.md              [Troubleshooting]
│   ├── K3S-ISSUES.md                  [Troubleshooting]
│   ├── SSH-ISSUES.md                  [Troubleshooting]
│   ├── CLUSTER-ISSUES.md              [Troubleshooting]
│   ├── CILIUM-CNI.md                  [Deployment]
│   ├── LONGHORN-STORAGE.md            [Deployment]
│   ├── PROMETHEUS-GRAFANA.md          [Deployment]
│   ├── POSTGRESQL-KEYCLOAK.md         [Deployment]
│   └── INDEX.md                        [Navegación]
│
├── 📁 scripts/
│   └── install/
│       ├── INSTALL-K3S-MASTER-CLEAN.sh
│       ├── INSTALL-K3S-WORKER-CLEAN.sh
│       └── VALIDATE-K3S-CLUSTER.sh
│
├── 📁 manifests/
│   └── [YAML files]
│
└── 📁 agents/
    ├── README.md                       [Descripción]
    ├── INDEX.md                        [Índice]
    ├── RESUMEN-ESTADO-FINAL.md        [Reporte]
    ├── VERIFICACION-LIMPIEZA.md       [Reporte]
    ├── COMANDOS-LIMPIEZA-USADOS.md    [Reporte]
    └── [Otros reportes]
```

---

## ⏱️ LECTURA ESTIMADA

| Documento | Tiempo |
|-----------|--------|
| INICIO-AQUI.md | 5 min |
| 02-INSTALACION-PASO-A-PASO.md | 20 min |
| K3S-ARCHITECTURE.md | 10 min |
| NETWORKING.md | 10 min |
| **Total introducción** | **~45 min** |

---

## 🎯 RUTA RECOMENDADA

### Ruta Rápida (45 min - Solo instalación)
1. [INICIO-AQUI.md](../INICIO-AQUI.md) - 5 min
2. [02-INSTALACION-PASO-A-PASO.md](../docs-clean/getting-started/02-INSTALACION-PASO-A-PASO.md) - 20 min
3. Ejecutar scripts - 20 min
4. Validar - 5 min

### Ruta Completa (2-3 horas - Todo detallado)
1. [NAVEGACION.md](../NAVEGACION.md) - 5 min
2. [README.md](../README.md) - 10 min
3. [02-INSTALACION-PASO-A-PASO.md](../docs-clean/getting-started/02-INSTALACION-PASO-A-PASO.md) - 20 min
4. [K3S-ARCHITECTURE.md](../docs-clean/technical/K3S-ARCHITECTURE.md) - 15 min
5. [NETWORKING.md](../docs-clean/technical/NETWORKING.md) - 15 min
6. [STORAGE.md](../docs-clean/technical/STORAGE.md) - 10 min
7. Ejecutar scripts - 20 min
8. [docs-clean/deployment/](../docs-clean/deployment/) - 30 min

---

**¿Listo? Comienza por [INICIO-AQUI.md](../INICIO-AQUI.md)**

Creado: 10 de noviembre de 2025
