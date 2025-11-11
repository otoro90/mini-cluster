# 📚 Índice de Documentación - Instalación Limpia K3s

## 🚀 COMIENZA AQUÍ

**`INICIO-AQUI.md`** ← Lee esto primero
- Resumen de pasos rápidos (30 minutos total)
- Checklist de instalación
- Guía de solución de problemas

---

## 📋 Guías Principales

### **1. Instalación Paso-a-Paso**

**`INSTALACION-K3S-LIMPIA.md`** - Guía detallada
- Paso 1: Configurar red (netplan en master, dhcpcd en worker)
- Paso 2: Configurar SSH keys
- Paso 3: Instalar K3s server en master
- Paso 4: Instalar K3s agent en worker
- Paso 5: Validar cluster
- Troubleshooting para cada paso

### **2. Información Técnica**

**`docs/K3S-VS-KUBEADM.md`** - Comparativa arquitectónica
- Diferencias entre K3s y Kubeadm
- Arquitectura de K3s
- Tokens y autenticación
- Puertos importantes
- Debugging común

### **3. Referencia General**

**`README.md`** - Información general del proyecto
- Estructura del proyecto
- Arquitectura del cluster
- Despliegues disponibles
- URLs de acceso
- Comandos útiles

---

## 🔧 Scripts de Instalación

### **Instalación Limpia (Recomendado)**

```
scripts/install/INSTALL-K3S-MASTER-CLEAN.sh
  ↓ Ejecutar en Orange Pi
  - Actualiza sistema
  - Instala K3s server
  - Genera token para worker
  - Valida que funciona

scripts/install/INSTALL-K3S-WORKER-CLEAN.sh
  ↓ Ejecutar en Raspberry Pi
  - Actualiza sistema
  - Instala K3s agent
  - Se conecta al master
  - Valida conexión

scripts/install/VALIDATE-K3S-CLUSTER.sh
  ↓ Ejecutar en Master (después de instalar ambos)
  - Verifica nodos Ready
  - Valida componentes del sistema
  - Verifica API, kubelet, CNI
  - Genera reporte completo
```

---

## 📁 Estructura del Proyecto

```
mini-cluster/
├── INICIO-AQUI.md ........................ ⭐ Lee esto primero
├── INSTALACION-K3S-LIMPIA.md ............ Guía detallada paso-a-paso
├── README.md ............................ Información general
│
├── scripts/
│   ├── install/
│   │   ├── INSTALL-K3S-MASTER-CLEAN.sh .. Instalar master
│   │   ├── INSTALL-K3S-WORKER-CLEAN.sh .. Instalar worker
│   │   └── VALIDATE-K3S-CLUSTER.sh ...... Validar cluster
│   │
│   ├── deploy/
│   │   └── [Scripts para Cilium, Longhorn, Prometheus]
│   │
│   └── recovery/
│       └── [Scripts de recuperación]
│
├── docs/
│   ├── K3S-VS-KUBEADM.md
│   ├── MIGRATION_STEP_BY_STEP.md (OBSOLETO - para referencia)
│   └── [Otras guías]
│
└── manifests/
    ├── keycloak/
    ├── postgres/
    └── [Otros YAML]
```

---

## 🎯 Flujo de Trabajo

```
1. INICIO-AQUI.md
   ↓
2. INSTALACION-K3S-LIMPIA.md → Paso 1-5
   ↓
3. Ejecutar scripts:
   - INSTALL-K3S-MASTER-CLEAN.sh
   - INSTALL-K3S-WORKER-CLEAN.sh
   - VALIDATE-K3S-CLUSTER.sh
   ↓
4. Cluster K3s Funcionando ✓
```

---

## 📊 Configuración Final

**Master (Orange Pi - 192.168.1.254)**
- K3s v1.33.5+k3s1 (server)
- IP estática
- Puerto 6443 (API)

**Worker (Raspberry Pi - 192.168.1.250)**
- K3s v1.33.5+k3s1 (agent)
- IP estática
- Conectado al master

**Red Cluster**
- Cluster CIDR: 192.168.0.0/16
- Service CIDR: 10.43.0.0/16
- CNI: Flannel (default)

---

## ✅ Checklist de Instalación

- [ ] Leer INICIO-AQUI.md
- [ ] Configurar red en master (IP 192.168.1.254)
- [ ] Configurar red en worker (IP 192.168.1.250)
- [ ] Configurar SSH keys
- [ ] Ejecutar INSTALL-K3S-MASTER-CLEAN.sh
- [ ] Obtener token del master
- [ ] Ejecutar INSTALL-K3S-WORKER-CLEAN.sh
- [ ] Ejecutar VALIDATE-K3S-CLUSTER.sh
- [ ] Verificar ambos nodos Ready: `kubectl get nodes`
- [ ] Cluster listo ✓

---

## 🔍 Verificación Rápida

```bash
# Ver estado de nodos
kubectl get nodes

# Ver pods del sistema
kubectl get pods -A

# Ver servicios
kubectl get svc -A

# Ver recursos
kubectl top nodes
kubectl top pods -A
```

---

## 📞 Troubleshooting

### Si worker no se conecta
```bash
# Ver logs del worker
sudo journalctl -u k3s-agent.service -f

# Verificar token
sudo cat /var/lib/rancher/k3s/server/node-token

# Reiniciar agent
sudo systemctl restart k3s-agent.service
```

### Si master no responde
```bash
# Ver logs del master
sudo journalctl -u k3s.service -f

# Verificar puerto 6443
sudo ss -tlnp | grep 6443

# Reiniciar k3s
sudo systemctl restart k3s.service
```

### Si no hay conectividad de red
```bash
# Verificar configuración
ip a
ip route
cat /etc/netplan/50-cloud-init.yaml  # master
cat /etc/dhcpcd.conf                 # worker

# Reiniciar networking
sudo systemctl restart systemd-networkd  # master
sudo systemctl restart dhcpcd            # worker
```

---

## 🚀 Próximos Pasos (Después de K3s)

1. **Desplegar CNI Cilium**
   - Reemplaza Flannel
   - eBPF para mejor performance

2. **Instalar Longhorn**
   - Storage distribuido HA
   - Para PostgreSQL

3. **Instalar Prometheus + Grafana**
   - Monitoreo completo

4. **Desplegar PostgreSQL + Keycloak**
   - Aplicaciones principales

---

## 📖 Documentación de Referencia

### Oficial
- [K3s Docs](https://docs.k3s.io/)
- [Kubernetes Docs](https://kubernetes.io/docs/)
- [Orange Pi Wiki](https://orangepi.org/)
- [Raspberry Pi Docs](https://www.raspberrypi.com/documentation/)

### Conceptos
- [Kubernetes Concepts](https://kubernetes.io/docs/concepts/)
- [K3s Architecture](https://docs.k3s.io/architecture/)

---

## 🎓 Estado del Proyecto

**Versión:** 2.0 - Instalación Limpia K3s  
**Estado:** 🟢 Listo para usar  
**Creado:** 10 Nov 2025  

**Cambios desde v1.0:**
- ✅ Documentación actualizada para instalación limpia
- ✅ Scripts sin cleanup (solo instalación)
- ✅ Guías paso-a-paso simplificadas
- ✅ Removed migraciones complicadas
- ✅ Added validación de cluster

---

**¿Listo para instalar? Lee: `INICIO-AQUI.md`** 🚀