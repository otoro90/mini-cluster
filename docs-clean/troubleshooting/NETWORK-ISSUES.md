# 🚨 Problemas de Red

Diagnosticar y resolver problemas de conectividad.

---

## **Diagnóstico Rápido**

```bash
# 1. ¿Puedo alcanzar el nodo?
ping 192.168.1.200        # Master
ping 192.168.1.100        # Worker

# 2. ¿DNS funciona?
nslookup google.com

# 3. ¿SSH funciona?
ssh root@192.168.1.200 "hostname"

# 4. ¿K3s está corriendo?
ssh root@192.168.1.200 "systemctl status k3s"

# 5. ¿Puedo hablar con API?
kubectl get nodes
```

---

## **Problema: "Unable to connect to 192.168.1.200"**

### Verificación

```bash
# En tu PC (Windows PowerShell)
ping 192.168.1.200

# Si no responde:
# 1. ¿IP correcta?
# 2. ¿Dispositivo encendido?
# 3. ¿En la misma red?
# 4. ¿Firewall del router bloqueando?
```

### En el dispositivo (Master)

```bash
# Ver IP asignada
ip addr show eth0

# Debería mostrar: inet 192.168.1.200/24

# Si NO está:
ip route show
cat /etc/netplan/50-cloud-init.yaml  # master
cat /etc/dhcpcd.conf                 # worker

# Reiniciar red
sudo systemctl restart networking      # master
sudo systemctl restart dhcpcd          # worker
```

### Solución

```bash
# Master - Reconfigurar netplan
sudo nano /etc/netplan/50-cloud-init.yaml

# Cambiar a:
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
sudo netplan try  # Revisar configuración

# Verificar
ip a
ping 192.168.1.1
```

---

## **Problema: Pods sin IP**

```bash
# Ver pods
kubectl get pods

# STATUS: Pending, no IP

# Causas: CNI no iniciado
```

### Verificación

```bash
# ¿Flannel está corriendo?
kubectl get daemonset -n kube-system -o wide

# Debería mostrar: flannel-xxxxx con STATUS Running

# Ver logs de Flannel
kubectl logs -n kube-system -l app=flannel | head -50
```

### Solución

```bash
# 1. Esperar (Flannel toma 30-60 segundos)
kubectl get pods --watch

# 2. Si sigue en Pending, ver qué pasó
kubectl describe pod <pod-name>

# 3. Ver eventos del cluster
kubectl get events -A --sort-by='.lastTimestamp'

# 4. Reinstalar Flannel si está broken
kubectl delete daemonset -n kube-system flannel
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

---

## **Problema: Pods en CrashLoopBackOff**

```bash
# Ver estado
kubectl describe pod <pod-name>

# Ver logs
kubectl logs <pod-name> --tail=50

# Ver logs anteriores si se está reciclando
kubectl logs <pod-name> --previous
```

### Causas Comunes

1. **Imagen no existe**
   ```bash
   kubectl describe pod | grep Image
   # Si dice "ImagePullBackOff", la imagen no está
   ```

2. **Puerto ya en uso**
   ```bash
   # Ver puertos del nodo
   sudo ss -tlnp
   ```

3. **Memoria insuficiente**
   ```bash
   kubectl top nodes
   kubectl top pods -A
   ```

4. **Aplicación no inicia**
   ```bash
   # Ver logs de la app
   kubectl logs <pod-name>
   # Buscar errores
   ```

---

## **Problema: Service no accesible**

```bash
# Crear servicio
kubectl expose deployment nginx --port=80 --type=ClusterIP

# Ver servicio
kubectl get svc

# Probar acceso interno
kubectl run -it --rm debug --image=busybox --restart=Never -- wget -O- http://nginx:80

# Si falla, verificar:
# 1. Service existe
# 2. Pods detrás de service están Running
# 3. Selector del service coincide con labels de pods
```

### Verificación

```bash
# Ver endpoints del service
kubectl get endpoints

# Si está vacío, el service no tiene pods

# Verificar labels
kubectl get pods --show-labels

# Labels deben coincidir con selector del service
kubectl get svc nginx -o yaml | grep selector
```

---

## **Problema: "Connection refused" entre nodos**

Pods no pueden comunicarse entre master y worker.

```bash
# En un pod del master
kubectl exec -it <pod> -- bash
ping 192.168.0.20  # IP de pod en worker

# Si falla, ver rutas
ip route
```

### Verificación en Nodos

```bash
# Master
ip route
ip link show

# Worker
ip route
ip link show

# Debería haber: vxlan0 (Flannel VXLAN)
```

### Solución

```bash
# Verificar Flannel en ambos nodos
kubectl logs -n kube-system -l app=flannel

# Reiniciar Flannel
kubectl rollout restart daemonset/flannel -n kube-system

# Esperar
kubectl rollout status daemonset/flannel -n kube-system
```

---

## **Problema: DNS no funciona dentro de pods**

```bash
# Desde pod
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup google.com

# Si falla:
# Buscar errores de coredns
kubectl logs -n kube-system -l k8s-app=kube-dns

# Reiniciar coredns
kubectl rollout restart deployment/coredns -n kube-system
```

---

## **Problema: Gateway no alcanzable**

```bash
# Desde pod
kubectl run -it --rm debug --image=busybox --restart=Never -- ping 192.168.1.1

# Si falla
# Verificar en el nodo
ping 192.168.1.1

# Ver configuración de red
cat /etc/netplan/50-cloud-init.yaml  # master
cat /etc/dhcpcd.conf                 # worker

# Verificar DNS resolvers
cat /etc/resolv.conf

# Actualizar manualmente
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
```

---

## **Problema: "No route to host"**

```bash
# Verificar rutas
ip route
ip route show

# Debería haber entrada para cluster CIDR
# 192.168.0.0/16 via ... dev ...

# Agregar manualmente si falta
sudo ip route add 192.168.0.0/16 via 192.168.1.100 dev eth0  # desde master
sudo ip route add 192.168.0.0/16 via 192.168.1.200 dev eth0  # desde worker

# Hacer permanente en netplan
sudo nano /etc/netplan/50-cloud-init.yaml
# Agregar bajo routes:
# - to: 192.168.0.0/16
#   via: 192.168.1.100
sudo netplan apply
```

---

## **Checklist de Troubleshooting**

1. ✅ Ping a gateway: `ping 192.168.1.1`
2. ✅ Ping entre nodos: `ping 192.168.1.100` (desde master)
3. ✅ SSH a nodos: `ssh root@192.168.1.200`
4. ✅ K3s corriendo: `systemctl status k3s`
5. ✅ Nodos Ready: `kubectl get nodes`
6. ✅ Flannel corriendo: `kubectl get daemonset -n kube-system`
7. ✅ CoreDNS corriendo: `kubectl get pods -n kube-system -l k8s-app=kube-dns`
8. ✅ Pods con IP: `kubectl get pods -A` (no Pending)
9. ✅ Services activos: `kubectl get svc`
10. ✅ Endpoints: `kubectl get endpoints`

---

## **Ver Logs Completos**

```bash
# Master
sudo journalctl -u k3s.service -f

# Worker
sudo journalctl -u k3s-agent.service -f

# Kernel network issues
sudo dmesg | grep -i network

# Etcd
sudo journalctl -u etcd.service -f
```

---

## 📖 Siguiente

Lee: `../troubleshooting/K3S-ISSUES.md` para problemas específicos de K3s.

