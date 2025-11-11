# ⚠️ Problemas de K3s

Diagnosticar y resolver problemas específicos de K3s.

---

## **Problema: K3s no inicia**

```bash
# Verificar estado
sudo systemctl status k3s        # Master
sudo systemctl status k3s-agent  # Worker

# Ver logs
sudo journalctl -u k3s.service -f         # Master
sudo journalctl -u k3s-agent.service -f   # Worker
```

### Causas Comunes

1. **Puerto 6443 en uso (Master)**
   ```bash
   sudo ss -tlnp | grep 6443
   # Si algo lo usa, liberarlo o cambiar puerto
   ```

2. **Permisos de archivo**
   ```bash
   # K3s necesita permisos a /var/lib/rancher/k3s/
   ls -la /var/lib/rancher/k3s/
   
   # Debe ser propiedad de root
   sudo chown -R root:root /var/lib/rancher/k3s/
   sudo chmod -R 755 /var/lib/rancher/k3s/
   ```

3. **Espacio en disco**
   ```bash
   df -h
   # Si < 1GB libre, limpiar:
   sudo apt clean
   sudo apt autoclean
   ```

4. **RAM insuficiente**
   ```bash
   free -h
   # K3s mínimo 256MB, recomendado 512MB
   ```

---

## **Problema: Worker no se conecta al Master**

```bash
# Ver estado
kubectl get nodes

# Worker mostrará "NotReady" o no aparecerá
```

### Verificación

```bash
# En worker
sudo systemctl status k3s-agent.service
sudo journalctl -u k3s-agent.service -f

# Buscar errores tipo:
# "unable to connect to master"
# "x509: certificate signed by unknown authority"
```

### Causas

1. **Token incorrecto**
   ```bash
   # En master, generar nuevo token
   sudo cat /var/lib/rancher/k3s/server/node-token
   
   # En worker, actualizar
   sudo nano /etc/systemd/system/multi-user.target.wants/k3s-agent.service
   # O: sudo nano /etc/rancher/k3s/config.yaml
   
   # Buscar: K3S_TOKEN=...
   # Reemplazar con el token correcto
   
   # Reiniciar
   sudo systemctl restart k3s-agent.service
   ```

2. **URL del master incorrecta**
   ```bash
   # En worker, verificar
   cat /etc/rancher/k3s/config.yaml
   # Debería tener: server: https://192.168.1.200:6443
   ```

3. **Master no responde**
   ```bash
   # Verificar conectividad
   ssh root@192.168.1.200 "systemctl status k3s"
   
   # Verificar puerto
   ssh root@192.168.1.200 "ss -tlnp | grep 6443"
   ```

---

## **Problema: Nodo en estado NotReady**

```bash
# Ver estado
kubectl get nodes

# Ver detalles
kubectl describe node <node-name>

# Ver condiciones
kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[3].status
```

### Causas

1. **Kubelet no corriendo**
   ```bash
   sudo systemctl status k3s         # Master
   sudo systemctl status k3s-agent   # Worker
   
   # Reiniciar
   sudo systemctl restart k3s
   sudo systemctl restart k3s-agent
   ```

2. **Sin espacio en disco**
   ```bash
   df -h
   kubectl describe node | grep DiskPressure
   
   # Limpiar
   sudo docker image prune -a
   sudo docker system prune
   ```

3. **Sin memoria**
   ```bash
   free -h
   kubectl describe node | grep MemoryPressure
   
   # Ver qué consume
   kubectl top pods -A
   ```

4. **Network plugin (CNI) no listo**
   ```bash
   kubectl logs -n kube-system -l app=flannel
   ```

---

## **Problema: Pods en Pending**

```bash
# Ver pod
kubectl describe pod <pod-name>

# Ver eventos
kubectl get events -A --sort-by='.lastTimestamp'
```

### Causas

1. **Sin nodos disponibles**
   ```bash
   kubectl get nodes
   # Debería haber al menos 1 Ready
   
   # Si hay Taints, pod no se asigna
   kubectl describe node | grep Taints
   ```

2. **Recursos insuficientes**
   ```bash
   # Si pod pide más de lo disponible
   kubectl top nodes
   
   # Ver requests del pod
   kubectl describe pod <pod-name> | grep -A 5 "Limits"
   ```

3. **PersistentVolume no disponible**
   ```bash
   kubectl get pvc
   kubectl get pv
   
   # Si PVC está Pending
   kubectl describe pvc <pvc-name>
   ```

---

## **Problema: Pods en ImagePullBackOff**

Imagen del contenedor no se puede descargar.

```bash
# Ver error
kubectl describe pod <pod-name>

# Causas:
# 1. Imagen no existe
# 2. Registry no accesible
# 3. Credenciales incorrectas
```

### Solución

```bash
# Verificar nombre imagen
kubectl get pod <pod-name> -o yaml | grep image

# Probar descargar en worker
ssh pi@192.168.1.100 "crictl pull myimage:latest"

# O manualmente
docker pull myimage:latest

# Si falla, usar imagen local que exista
kubectl set image deployment/app app=busybox:latest
```

---

## **Problema: Pods en CrashLoopBackOff**

Pod inicia pero se apaga inmediatamente.

```bash
# Ver logs
kubectl logs <pod-name> --tail=50

# Logs anteriores (si se reinicia)
kubectl logs <pod-name> --previous

# Detalles
kubectl describe pod <pod-name>
```

### Causas Comunes

1. **Error en la aplicación**
   ```bash
   # Ver qué dice el error
   kubectl logs <pod-name>
   
   # Arreglarlo y redeploy
   ```

2. **Configuración incorrecta**
   ```bash
   # Si usa ConfigMap/Secret, verificar existen
   kubectl get cm
   kubectl get secret
   ```

3. **Entrypoint incorrecto**
   ```bash
   # Ver comando
   kubectl get pod <pod-name> -o yaml | grep -A 5 "command"
   
   # Ejecutar comando manualmente
   docker run -it myimage:latest /bin/sh
   ```

---

## **Problema: Error de certificados**

```
x509: certificate signed by unknown authority
```

Problema típico al conectar worker.

```bash
# En worker, verificar certificados
ls -la /var/lib/rancher/k3s/

# Verificar token
cat /var/lib/rancher/k3s/agent/node-token

# Comparar con token del master
ssh root@192.168.1.200 "cat /var/lib/rancher/k3s/server/node-token"

# Si son diferentes, actualizar worker
```

### Solución

```bash
# En master, generar nuevo token
sudo cat /var/lib/rancher/k3s/server/node-token

# En worker
export K3S_TOKEN=<token-nuevo>
export K3S_URL=https://192.168.1.200:6443

# Reinstalar agent
curl -sfL https://get.k3s.io | sh -

# Verificar
kubectl get nodes
```

---

## **Problema: API Server no responde**

```bash
# Probar conectar
curl -k https://192.168.1.200:6443

# O con kubectl
kubectl get nodes
# Error: Unable to connect...
```

### Verificación

```bash
# En master
sudo systemctl status k3s
sudo journalctl -u k3s.service -f

# Ver puerto
sudo ss -tlnp | grep 6443

# Si no aparece, reiniciar
sudo systemctl restart k3s
```

---

## **Problema: etcd corruption**

Raro, pero puede pasar si apagamos bruscamente.

```bash
# Ver si etcd está sano
kubectl get endpoints kube-apiserver -n kube-system

# Si ves errores de etcd
sudo journalctl -u k3s.service | grep -i etcd
```

### Solución

```bash
# En master
# 1. Parar K3s
sudo systemctl stop k3s

# 2. Backup
sudo cp -r /var/lib/rancher/k3s/server/db /var/lib/rancher/k3s/server/db.backup

# 3. Iniciar
sudo systemctl start k3s

# 4. Verificar
kubectl get nodes
```

---

## **Problema: Versiones incompatibles**

Master y worker con versiones diferentes de K3s.

```bash
# Ver versiones
kubectl version
kubectl get nodes -o wide

# Debería mostrar misma versión en todos
```

### Solución

```bash
# Actualizar todos a misma versión
# En master
curl -sfL https://get.k3s.io | K3S_VERSION=v1.33.5+k3s1 sh -

# En worker
curl -sfL https://get.k3s.io | K3S_VERSION=v1.33.5+k3s1 K3S_URL=https://192.168.1.200:6443 K3S_TOKEN=<token> sh -

# Verificar
kubectl get nodes -o wide
```

---

## **Checklist de Troubleshooting K3s**

1. ✅ K3s corriendo: `systemctl status k3s`
2. ✅ Puerto 6443 activo: `ss -tlnp | grep 6443`
3. ✅ Nodos Ready: `kubectl get nodes`
4. ✅ No hay Taints de restricción: `kubectl describe node`
5. ✅ Espacio en disco: `df -h`
6. ✅ RAM disponible: `free -h`
7. ✅ Token correcto: `cat /var/lib/rancher/k3s/server/node-token`
8. ✅ Versiones iguales: `kubectl get nodes -o wide`
9. ✅ API responde: `kubectl get nodes`
10. ✅ Sin errores: `journalctl -u k3s.service -n 50`

---

## 📖 Siguiente

Lee: `../troubleshooting/SSH-ISSUES.md` para problemas de SSH.

