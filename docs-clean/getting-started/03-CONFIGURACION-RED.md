# 🌐 Configuración de Red

Detalles de la configuración de red para Orange Pi y Raspberry Pi.

---

## **Esquema de Red**

```
┌─────────────────────────────┐
│   Router (192.168.1.1)      │
│   Gateway                   │
└──────────┬──────────────────┘
           │
    ┌──────┴──────────────────┬─────────────────┐
    │                         │                 │
┌───▼──────────────┐  ┌──────▼─────────────┐   │
│ Orange Pi Master │  │ Raspberry Pi Agnt  │   │ 
│ 192.168.1.254    │  │ 192.168.1.250      │   │ (otros dispositivos)
│ Armbian Ubuntu   │  │ Raspberry Pi OS    │   │
└──────────────────┘  └────────────────────┘   │
    :6443 (API)           :10250 (kubelet)     │
    :10250                :6783 (Cilium)       │
    :6783                                      │
```

---

## **IPs Estáticas**

| Dispositivo | IP | Rol | Puertos |
|---|---|---|---|
| **Orange Pi** | `192.168.1.254` | Master (control-plane) | 6443, 10250, 6783 |
| **Raspberry Pi** | `192.168.1.250` | Worker (agent) | 10250, 6783 |
| **Gateway** | `192.168.1.1` | Router | - |
| **DNS** | `8.8.8.8` `1.1.1.1` | Google, Cloudflare | - |

---

## **CIDR Networks (Kubernetes Internals)**

```
Cluster Network (Pods):
  192.168.0.0/16  ← Rango para IPs de pods

Service Network (ClusterIP):
  10.43.0.0/16    ← Rango para IPs de servicios
```

Estos se asignan automáticamente con K3s.

---

## **Configurar Master (Orange Pi)**

### Opción A: Netplan (Recomendado en Armbian)

```bash
# Ver configuración actual
cat /etc/netplan/50-cloud-init.yaml

# Editar
sudo nano /etc/netplan/50-cloud-init.yaml
```

Reemplazar todo el contenido con:

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

Aplicar:

```bash
sudo netplan apply
```

### Opción B: /etc/network/interfaces

Si netplan no funciona:

```bash
sudo nano /etc/network/interfaces
```

```
auto eth0
iface eth0 inet static
    address 192.168.1.254
    netmask 255.255.255.0
    gateway 192.168.1.1
    dns-nameservers 8.8.8.8 1.1.1.1
```

Reiniciar:

```bash
sudo systemctl restart networking
```

---

## **Configurar Worker (Raspberry Pi)**

### Opción A: dhcpcd (Recomendado en Raspberry Pi OS)

```bash
# Editar
sudo nano /etc/dhcpcd.conf
```

Agregar al final:

```
interface eth0
static ip_address=192.168.1.250/24
static routers=192.168.1.1
static domain_name_servers=8.8.8.8 1.1.1.1
```

Reiniciar:

```bash
sudo systemctl restart dhcpcd
```

### Opción B: Netplan

Si dhcpcd no funciona en Raspberry Pi OS:

```bash
sudo nano /etc/netplan/99-raspberry-pi.yaml
```

```yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: false
      addresses:
        - 192.168.1.250/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
```

Aplicar:

```bash
sudo netplan apply
```

---

## **Verificar Configuración**

### En cada dispositivo:

```bash
# Ver IP asignada
ip a show eth0

# Ver rutas
ip route show

# Ver DNS
cat /etc/resolv.conf

# Ping al gateway
ping -c 3 192.168.1.1

# Ping entre dispositivos
ping -c 3 192.168.1.250  # desde master
ping -c 3 192.168.1.254  # desde worker
```

---

## **Validar desde PC (Windows)**

```powershell
# Ping a master
ping 192.168.1.254

# Ping a worker
ping 192.168.1.250

# SSH a master
ssh root@192.168.1.254 "ip a"

# SSH a worker
ssh pi@192.168.1.250 "ip a"
```

---

## **Hostname (Opcional)**

Cambiar nombres de dispositivos:

### Master:

```bash
sudo hostnamectl set-hostname k3s-master
```

### Worker:

```bash
sudo hostnamectl set-hostname k3s-worker
```

Reiniciar o actualizar `/etc/hosts`:

```bash
sudo nano /etc/hosts

# Cambiar línea con 127.0.0.1
# De: 127.0.0.1 localhost
# A: 127.0.0.1 k3s-master
```

---

## **Troubleshooting**

### Sin conectividad

```bash
# 1. Verificar configuración
cat /etc/netplan/50-cloud-init.yaml  # master
cat /etc/dhcpcd.conf                 # worker

# 2. Ver interfaz
ip link show eth0
# Debería estar: UP

# 3. Reiniciar red
sudo systemctl restart networking      # master
sudo systemctl restart dhcpcd          # worker

# 4. Ver logs
sudo dmesg | grep -i network
journalctl -xe
```

### Dirección IP incorrecta

```bash
# Liberar DHCP
sudo dhclient -r eth0

# Obtener nueva
sudo dhclient eth0

# O forzar estática
sudo ip addr add 192.168.1.254/24 dev eth0
sudo ip route add default via 192.168.1.1
```

### DNS no funciona

```bash
# Probar DNS directamente
dig @8.8.8.8 google.com

# Ver configuración
cat /etc/resolv.conf

# Actualizar manualmente
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf
```

---

## 📖 Siguiente

Lee: `../getting-started/02-INSTALACION-PASO-A-PASO.md` para instalar K3s.

