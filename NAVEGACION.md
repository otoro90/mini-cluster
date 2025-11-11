# 🗺️ Guía de Navegación - Mini-Cluster K3s

**¿Por dónde empiezo?** → Depende de lo que necesites:

---

## 🚀 Si Quieres INSTALAR el Clúster

### Paso 1: Lee
📖 **[INICIO-AQUI.md](INICIO-AQUI.md)** - Comienza aquí (5 minutos)

### Paso 2: Lee
📖 **[docs-clean/getting-started/02-INSTALACION-PASO-A-PASO.md](docs-clean/getting-started/02-INSTALACION-PASO-A-PASO.md)** - Guía detallada (20 minutos)

### Paso 3: Ejecuta
🔧 Configurar red + SSH + Scripts (32 minutos)

---

## 📚 Si Quieres ENTENDER la Instalación

**Lectura rápida (5-10 min):**
- 📘 [README.md](README.md) - Visión general
- 📘 [LISTO-PARA-INSTALAR.md](LISTO-PARA-INSTALAR.md) - Checklist de requisitos

**Lectura completa (30-45 min):**
- 📗 [INSTALACION-K3S-LIMPIA.md](INSTALACION-K3S-LIMPIA.md) - Guía completa
- 📗 [DOCUMENTACION-COMPLETA.md](DOCUMENTACION-COMPLETA.md) - Resumen ejecutivo
- 📗 [docs-clean/technical/](docs-clean/technical/) - Referencias técnicas (5 docs)

---

## 🆘 Si Tienes PROBLEMAS

**Busca en troubleshooting:**
- 🔴 Problemas de red → [docs-clean/troubleshooting/NETWORK-ISSUES.md](docs-clean/troubleshooting/NETWORK-ISSUES.md)
- 🔴 Problemas de K3s → [docs-clean/troubleshooting/K3S-ISSUES.md](docs-clean/troubleshooting/K3S-ISSUES.md)
- 🔴 Problemas de SSH → [docs-clean/troubleshooting/SSH-ISSUES.md](docs-clean/troubleshooting/SSH-ISSUES.md)
- 🔴 Problemas del clúster → [docs-clean/troubleshooting/CLUSTER-ISSUES.md](docs-clean/troubleshooting/CLUSTER-ISSUES.md)

---

## ⚙️ Si Quieres AGREGAR COMPONENTES

Después de que K3s esté corriendo:

- **Cilium CNI** → [docs-clean/deployment/CILIUM-CNI.md](docs-clean/deployment/CILIUM-CNI.md)
- **Longhorn Storage** → [docs-clean/deployment/LONGHORN-STORAGE.md](docs-clean/deployment/LONGHORN-STORAGE.md)
- **Prometheus + Grafana** → [docs-clean/deployment/PROMETHEUS-GRAFANA.md](docs-clean/deployment/PROMETHEUS-GRAFANA.md)
- **PostgreSQL + Keycloak** → [docs-clean/deployment/POSTGRESQL-KEYCLOAK.md](docs-clean/deployment/POSTGRESQL-KEYCLOAK.md)

---

## 📋 Estructura del Proyecto

```
mini-cluster/
├── 📘 INICIO-AQUI.md              ← COMIENZA AQUÍ
├── 📘 README.md                   ← Visión general
├── 📘 LISTO-PARA-INSTALAR.md     ← Checklist
├── 📘 INSTALACION-K3S-LIMPIA.md  ← Guía completa
├── 📘 DOCUMENTACION-COMPLETA.md  ← Resumen ejecutivo
│
├── 📁 docs-clean/
│   ├── getting-started/           ← 4 guías de inicio
│   ├── technical/                 ← 5 referencias técnicas
│   ├── troubleshooting/           ← 4 guías de problemas
│   ├── deployment/                ← 4 componentes opcionales
│   └── INDEX.md
│
├── 📁 scripts/install/
│   ├── INSTALL-K3S-MASTER-CLEAN.sh
│   ├── INSTALL-K3S-WORKER-CLEAN.sh
│   └── VALIDATE-K3S-CLUSTER.sh
│
├── 📁 manifests/                  ← Archivos YAML
│
└── 📁 agents/                     ← Reportes internos
    ├── README.md
    ├── RESUMEN-ESTADO-FINAL.md
    ├── VERIFICACION-LIMPIEZA.md
    └── ...otros reportes
```

---

## ⏱️ Tiempo Estimado

| Tarea | Tiempo |
|-------|--------|
| Leer INICIO-AQUI.md | 5 min |
| Leer guía de instalación | 20 min |
| Configurar red | 5 min |
| Configurar SSH | 5 min |
| Ejecutar scripts | 10 min |
| **TOTAL** | **45 min** |

---

## 🎯 Flujo Recomendado

```
┌─────────────────────┐
│  INICIO-AQUI.md     │  ← Comienza aquí
└──────────┬──────────┘
           ↓
┌─────────────────────────────────────┐
│  02-INSTALACION-PASO-A-PASO.md      │  ← Lee esto
└──────────┬──────────────────────────┘
           ↓
┌─────────────────────┐
│  Configura Red      │
│  Configura SSH      │
└──────────┬──────────┘
           ↓
┌──────────────────────────────────┐
│  Ejecuta 3 scripts:              │
│  1. INSTALL-K3S-MASTER-CLEAN    │
│  2. INSTALL-K3S-WORKER-CLEAN    │
│  3. VALIDATE-K3S-CLUSTER        │
└──────────┬───────────────────────┘
           ↓
┌──────────────────────┐
│  ✅ K3s Funcionando  │
│  Clúster Listo       │
└──────────────────────┘
```

---

## 🔍 Información Sobre el Proyecto

**¿Por qué todo está tan limpio?**  
Eliminamos toda documentación antigua de kubeadm para evitar confusiones y alucinaciones de LLMs. Una única fuente de verdad: **K3s limpio**.

**¿Dónde están los reportes internos?**  
En la carpeta `agents/` - No necesitas leerlos para instalar, son para referencia histórica.

**¿Cuánto tiempo toma?**  
32-50 minutos desde cero hasta tener un clúster K3s funcional.

---

## 💡 Tips Útiles

✅ Todo está documentado en **docs-clean/**  
✅ Los scripts están probados y funcionan  
✅ Puedes ejecutarlos tantas veces como necesites  
✅ No hay riesgo de alucinaciones de LLM (documentación única)  
✅ Componentes opcionales disponibles después de la instalación  

---

**¿Listo? Abre [INICIO-AQUI.md](INICIO-AQUI.md) y comienza.** 🚀
