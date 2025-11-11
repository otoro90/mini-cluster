# 🚀 COMIENZA AQUÍ - Instalación K3s

## ✅ Estado Actual

- **Orange Pi (Master)**: Formateado - Sistema limpio
- **Raspberry Pi (Worker)**: Formateado - Sistema limpio
- **Siguiente**: Instalar K3s en 32 minutos

---

## 🎯 5 Pasos Rápidos

### **Paso 1: Configurar Red (5 min)**
IPs estáticas en ambos dispositivos:
- Master: `192.168.1.254`
- Worker: `192.168.1.250`

Lee: `03-CONFIGURACION-RED.md`

### **Paso 2: SSH Keys (2 min)**
Acceso sin password desde tu PC.

Lee: `04-SSH-KEYS.md`

### **Paso 3: Instalar K3s Master (10 min)**
Ejecuta en Orange Pi:
```bash
bash scripts/install/INSTALL-K3S-MASTER-CLEAN.sh
```

### **Paso 4: Instalar K3s Worker (10 min)**
Ejecuta en Raspberry Pi:
```bash
bash scripts/install/INSTALL-K3S-WORKER-CLEAN.sh
```

### **Paso 5: Validar (5 min)**
Desde tu PC:
```bash
ssh root@192.168.1.254 "kubectl get nodes"
```

Ambos nodos deberían estar **Ready**.

---

## ⏱️ Tiempo Total: 32 minutos

| Paso | Tiempo | Link |
|------|--------|------|
| Red | 5 min | `03-CONFIGURACION-RED.md` |
| SSH | 2 min | `04-SSH-KEYS.md` |
| Master | 10 min | Script |
| Worker | 10 min | Script |
| Validación | 5 min | Script |
| **TOTAL** | **32 min** | ✅ Listo |

---

## 📖 Documentación Relacionada

- **Instalación Detallada**: `02-INSTALACION-PASO-A-PASO.md`
- **Referencia Técnica**: `../technical/K3S-ARCHITECTURE.md`
- **Problemas**: `../troubleshooting/NETWORK-ISSUES.md`

---

## ¿Listo?

→ **Continúa con**: `02-INSTALACION-PASO-A-PASO.md`

