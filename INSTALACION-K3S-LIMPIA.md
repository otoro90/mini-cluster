# 🚀 Instalación Limpia: K3s en ARM64

## Estado Actual

✅ **Dispositivos Formateados**
- Orange Pi (Master): Sistema limpio - Ubuntu/Armbian
- Raspberry Pi (Worker): Sistema limpio - Raspberry Pi OS Lite 64-bit

⏳ **Próximos Pasos**
1. Configurar red en ambos
2. Instalar K3s
3. Desplegar stack completo

---

## 📋 Paso 1: Configurar Red

### Orange Pi (Master)

Conectate físicamente o vía SSH y ejecuta:

```bash
# Configurar IP estática
sudo nano /etc/netplan/50-cloud-init.yaml

# Reemplaza contenido con:
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

# Aplicar
sudo netplan apply

# Verificar
ip a
ip route
ping -c 3 8.8.8.8
```

### Raspberry Pi (Worker)

```bash
# Configurar hostname
sudo hostnamectl set-hostname rpi-worker

# Configurar IP estática
sudo nano /etc/dhcpcd.conf

# Agregar al final:
interface eth0
static ip_address=192.168.1.250/24
static routers=192.168.1.1
static domain_name_servers=8.8.8.8 1.1.1.1

# Reiniciar
sudo systemctl restart dhcpcd

# Verificar
ip a
ip route
ping -c 3 8.8.8.8
```

---

## 🔑 Paso 2: Configurar SSH Keys (Desde tu PC)

```powershell
# Generar keys si no tienes
ssh-keygen -t rsa -b 4096 -f $env:USERPROFILE\.ssh\id_rsa -N '""'

# Copiar a master
cat $env:USERPROFILE\.ssh\id_rsa.pub | ssh root@192.168.1.254 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

# Copiar a worker
cat $env:USERPROFILE\.ssh\id_rsa.pub | ssh pi@192.168.1.250 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

# Verificar acceso sin password
ssh root@192.168.1.254 "echo 'Master OK'"
ssh pi@192.168.1.250 "echo 'Worker OK'"
```

---

## 🐳 Paso 3: Instalar K3s en Master

En el master (Orange Pi), ejecuta:

```bash
# Actualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar dependencias
sudo apt install -y curl wget net-tools

# Instalar K3s con configuración correcta
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --cluster-cidr=192.168.0.0/16 \
  --service-cidr=10.43.0.0/16 \
  --disable=traefik \
  --disable=servicelb \
  --disable=local-storage" sh -

# Esperar a que inicie (30-60 segundos)
sudo systemctl status k3s.service --no-pager

# Verificar que kubectl funciona
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes

# Obtener token para worker
sudo cat /var/lib/rancher/k3s/server/node-token
# Copia el token, lo necesitarás en el siguiente paso
```

---

## 🐳 Paso 4: Instalar K3s Agent en Worker

En el worker (Raspberry Pi), ejecuta (reemplaza TOKEN y MASTER_IP):

```bash
# Variables
export K3S_URL="https://192.168.1.254:6443"
export K3S_TOKEN="K1xxxxxxxxxxxx::server:yyyyyyyyyy"  # Reemplaza con el token del master

# Actualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar dependencias
sudo apt install -y curl wget net-tools

# Instalar K3s agent
curl -sfL https://get.k3s.io | K3S_URL=$K3S_URL K3S_TOKEN=$K3S_TOKEN sh -

# Esperar a que inicie (30-60 segundos)
sudo systemctl status k3s-agent.service --no-pager

# Ver logs
sudo journalctl -u k3s-agent.service -n 50 --no-pager
```

---

## ✅ Paso 5: Validar Cluster

Desde tu PC Windows, ejecuta:

```powershell
# Ver nodos
ssh root@192.168.1.254 "kubectl get nodes"

# Debería mostrar:
# NAME            STATUS   ROLES                  AGE   VERSION
# orangepi5       Ready    control-plane,master   2m    v1.33.5+k3s1
# rpi-worker      Ready    <none>                 1m    v1.33.5+k3s1

# Ver pods del sistema
ssh root@192.168.1.254 "kubectl get pods -A"

# Ver servicios
ssh root@192.168.1.254 "kubectl get svc -A"
```

Si ambos nodos están `Ready`, ¡K3s está funcionando correctamente!

---

## 🔧 Si Algo Falla

### Worker no se conecta al master

```bash
# En worker, ver logs
sudo journalctl -u k3s-agent.service -f

# Errores comunes y soluciones:

# "Connection refused"
# → Master puede no estar listo. Espera 2 minutos y reinicia worker

# "TLS handshake timeout"  
# → IP incorrecta o firewall bloqueando puerto 6443

# "token CA hash does not match"
# → Token incorrecto. Verifica con: sudo cat /var/lib/rancher/k3s/server/node-token
```

### Master no responde

```bash
# En master, ver logs
sudo journalctl -u k3s.service -f

# Reiniciar k3s
sudo systemctl restart k3s.service

# Verificar puerto 6443
sudo ss -tlnp | grep 6443
```

### No hay conectividad de red

```bash
# En cualquier nodo:

# Verificar IP
ip a

# Verificar gateway
ip route

# Probar ping
ping -c 3 192.168.1.1

# Ver DNS
cat /etc/resolv.conf
```

---

## 📊 Configuración Final

**Master (Orange Pi - 192.168.1.254)**
- K3s Server: ✅ Instalado
- IP: 192.168.1.254/24
- Puertos: 6443 (API), 10250 (Kubelet)

**Worker (Raspberry Pi - 192.168.1.250)**
- K3s Agent: ✅ Instalado
- IP: 192.168.1.250/24
- Conectado al master: ✅

**Red Cluster**
- Cluster CIDR: 192.168.0.0/16
- Service CIDR: 10.43.0.0/16
- CNI: Flannel (default, se reemplazará con Cilium)

---

## 🎯 Próximos Pasos

Una vez que ambos nodos estén `Ready`, podemos:

1. **Desplegar CNI Cilium** (reemplaza Flannel)
2. **Instalar Longhorn** (storage distribuido)
3. **Instalar Prometheus + Grafana** (monitoreo)
4. **Desplegar PostgreSQL + Keycloak** (aplicaciones)

¿Necesitas ayuda con algún paso?

---

**Creado:** 10 Nov 2025
**Versión:** 1.0 - Instalación Limpia K3s