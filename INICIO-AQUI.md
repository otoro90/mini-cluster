# 🚀 COMIENZA AQUÍ - Instalación Limpia K3s

## ✅ Estado Actual

- **Orange Pi (Master)**: Formateado - Sistema limpio
- **Raspberry Pi (Worker)**: Formateado - Sistema limpio
- **Siguiente**: Instalar K3s desde cero

---

## 📋 Pasos Rápidos

### **Paso 1: Red (5 minutos)**
Configura IPs estáticas en ambos dispositivos:
- Master: `192.168.1.200`
- Worker: `192.168.1.100`

**Lee**: `INSTALACION-K3S-LIMPIA.md` → Paso 1

### **Paso 2: SSH Keys (2 minutos)**
Configura acceso sin password desde tu PC:

```powershell
ssh-keygen -t rsa -b 4096 -f $env:USERPROFILE\.ssh\id_rsa -N '""'
cat $env:USERPROFILE\.ssh\id_rsa.pub | ssh root@192.168.1.200 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
cat $env:USERPROFILE\.ssh\id_rsa.pub | ssh pi@192.168.1.100 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

**Lee**: `INSTALACION-K3S-LIMPIA.md` → Paso 2

### **Paso 3: Instalar K3s Master (10 minutos)**
En el master (Orange Pi):

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --cluster-cidr=192.168.0.0/16 \
  --service-cidr=10.43.0.0/16 \
  --disable=traefik \
  --disable=servicelb \
  --disable=local-storage" sh -

# Obtener token
sudo cat /var/lib/rancher/k3s/server/node-token
```

**Lee**: `INSTALACION-K3S-LIMPIA.md` → Paso 3

### **Paso 4: Instalar K3s Worker (10 minutos)**
En el worker (Raspberry Pi):

```bash
export K3S_URL="https://192.168.1.200:6443"
export K3S_TOKEN="[Pega el token del paso anterior]"

curl -sfL https://get.k3s.io | K3S_URL=$K3S_URL K3S_TOKEN=$K3S_TOKEN sh -
```

**Lee**: `INSTALACION-K3S-LIMPIA.md` → Paso 4

### **Paso 5: Validar (5 minutos)**
Desde tu PC, verifica que funciona:

```powershell
ssh root@192.168.1.200 "kubectl get nodes"

# Debería mostrar AMBOS nodos como Ready
```

**Lee**: `INSTALACION-K3S-LIMPIA.md` → Paso 5

---

## 🎯 Tiempo Total Estimado

| Paso | Tiempo | Estado |
|------|--------|--------|
| Red | 5 min | ⏳ Pendiente |
| SSH | 2 min | ⏳ Pendiente |
| Master K3s | 10 min | ⏳ Pendiente |
| Worker K3s | 10 min | ⏳ Pendiente |
| Validación | 5 min | ⏳ Pendiente |
| **TOTAL** | **32 min** | **🚀 Listo** |

---

## 📚 Documentación Principal

- **`INSTALACION-K3S-LIMPIA.md`** ← Guía detallada paso-a-paso
- **`README.md`** ← Información general del proyecto
- **`docs/K3S-VS-KUBEADM.md`** ← Explicación de K3s vs Kubeadm

---

## ⚠️ Notas Importantes

1. **Red**: Configura IPs estáticas, no DHCP
2. **Token**: Guarda el token del master, lo necesitarás en el worker
3. **Firewall**: Si hay problemas, desactiva temporalmente `sudo ufw disable`
4. **Logs**: Si algo falla: `sudo journalctl -u k3s.service -f`

---

## 🔄 Si Algo Falla

**Worker no conecta:**
```bash
ssh root@192.168.1.200 "kubectl get nodes"  # Ver estado
sudo journalctl -u k3s-agent.service -f      # Ver errores en worker
```

**Master no responde:**
```bash
sudo systemctl restart k3s.service           # Reiniciar
sudo ss -tlnp | grep 6443                    # Verificar puerto
```

**Sin conectividad de red:**
```bash
ping -c 3 192.168.1.1                        # Verificar gateway
cat /etc/netplan/50-cloud-init.yaml          # Verificar config (master)
cat /etc/dhcpcd.conf                         # Verificar config (worker)
```

---

## ✨ Después de Instalar K3s

Una vez que ambos nodos estén **Ready**, podemos:

1. **Desplegar Cilium** (CNI avanzado)
2. **Instalar Longhorn** (Storage distribuido)
3. **Instalar Prometheus + Grafana** (Monitoreo)
4. **Desplegar PostgreSQL + Keycloak** (Aplicaciones)

---

## 🚀 ¡Vamos!

**Lee ahora**: `INSTALACION-K3S-LIMPIA.md` → Paso 1

Cuando termines cada paso, vuelve aquí y marca como ✅

---

**Estado:** 🟢 Listo para instalar K3s
**Creado:** 10 Nov 2025
**Versión:** 1.0