# 📋 Instalación Paso-a-Paso

Guía detallada para instalar K3s en ambos dispositivos.

---

## **Paso 1: Configurar Red**

### Orange Pi (Master)

```bash
# Editar configuración de netplan
sudo nano /etc/netplan/50-cloud-init.yaml

# Reemplazar con:
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: false
      addresses:
        - 192.168.1.200/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]

# Aplicar
sudo netplan apply

# Verificar
ip a
ip route
```

### Raspberry Pi (Worker)

```bash
# Editar dhcpcd
sudo nano /etc/dhcpcd.conf

# Agregar al final:
interface eth0
static ip_address=192.168.1.100/24
static routers=192.168.1.1
static domain_name_servers=8.8.8.8 1.1.1.1

# Reiniciar
sudo systemctl restart dhcpcd

# Verificar
ip a
ip route
```

---

## **Paso 2: Configurar SSH Keys**

Desde tu PC Windows:

```powershell
# Generar keys
ssh-keygen -t rsa -b 4096 -f $env:USERPROFILE\.ssh\id_rsa -N '""'

# Copiar a master
cat $env:USERPROFILE\.ssh\id_rsa.pub | ssh root@192.168.1.200 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

# Copiar a worker
cat $env:USERPROFILE\.ssh\id_rsa.pub | ssh pi@192.168.1.100 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

# Verificar
ssh -o PasswordAuthentication=no root@192.168.1.200 "echo 'Master OK'"
ssh -o PasswordAuthentication=no pi@192.168.1.100 "echo 'Worker OK'"
```

---

## **Paso 3: Instalar K3s Master**

En Orange Pi:

```bash
# Actualizar
sudo apt update && sudo apt upgrade -y

# Instalar dependencias
sudo apt install -y curl wget net-tools

# Ejecutar script
bash scripts/install/INSTALL-K3S-MASTER-CLEAN.sh

# Guardar token que aparecerá al final
# (Lo necesitarás en el Paso 4)
```

---

## **Paso 4: Instalar K3s Worker**

En Raspberry Pi:

```bash
# Actualizar
sudo apt update && sudo apt upgrade -y

# Instalar dependencias
sudo apt install -y curl wget net-tools

# Ejecutar script
bash scripts/install/INSTALL-K3S-WORKER-CLEAN.sh

# Cuando pida el token, pega el del Paso 3
```

---

## **Paso 5: Validar Cluster**

Desde tu PC:

```powershell
# Ver nodos
ssh root@192.168.1.200 "kubectl get nodes"

# Debería mostrar:
# NAME            STATUS   ROLES                  AGE   VERSION
# orangepi5       Ready    control-plane,master   2m    v1.33.5+k3s1
# rpi-worker      Ready    <none>                 1m    v1.33.5+k3s1

# Ver pods
ssh root@192.168.1.200 "kubectl get pods -A"

# Ver servicios
ssh root@192.168.1.200 "kubectl get svc -A"
```

Si ambos nodos están **Ready**, ¡K3s está funcionando! ✅

---

## 🔍 Validación Completa

```bash
bash scripts/install/VALIDATE-K3S-CLUSTER.sh
```

Este script verifica 8 puntos clave del cluster.

---

## ❌ Si Algo Falla

### Worker no se conecta
```bash
# Ver logs
sudo journalctl -u k3s-agent.service -f

# Verificar token correcto
sudo cat /var/lib/rancher/k3s/server/node-token

# Reiniciar agent
sudo systemctl restart k3s-agent.service
```

### Master no responde
```bash
# Ver logs
sudo journalctl -u k3s.service -f

# Verificar puerto 6443
sudo ss -tlnp | grep 6443

# Reiniciar
sudo systemctl restart k3s.service
```

### Sin conectividad de red
```bash
# Verificar configuración
ip a
ip route
cat /etc/netplan/50-cloud-init.yaml  # master
cat /etc/dhcpcd.conf                 # worker

# Ping al gateway
ping -c 3 192.168.1.1
```

---

## 📖 Siguiente

Lee: `../technical/K3S-ARCHITECTURE.md` para entender la arquitectura.

