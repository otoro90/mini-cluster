# 🔗 Problemas del Cluster

Diagnosticar problemas generales del cluster K3s.

---

## **Problema: Cluster degradado**

Algunos servicios no funcionan.

```bash
# Ver estado general
kubectl get nodes
kubectl get pods -A

# Si algo está rojo: Pending, CrashLoopBackOff, etc
```

### Verificación

```bash
# Ver qué está mal
kubectl get all -A

# Events del cluster
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# Describe problematic pod
kubectl describe pod <pod-name> -n <namespace>
```

---

## **Problema: No hay nodos disponibles**

```bash
# Ver nodos
kubectl get nodes

# Si ves: 0 (zero) nodos, o solo master

# Causas posibles:
# 1. Worker no se conectó
# 2. Master sola no es válida (a veces)
```

### Verificación

```bash
# ¿Worker conectado?
ssh pi@192.168.1.100 "systemctl status k3s-agent"

# ¿Master responde?
ssh root@192.168.1.200 "systemctl status k3s"

# ¿Se ven mutuamente?
ssh root@192.168.1.200 "ping -c 3 192.168.1.100"
ssh pi@192.168.1.100 "ping -c 3 192.168.1.200"
```

### Solución

Ver `../troubleshooting/K3S-ISSUES.md` - "Worker no se conecta al Master"

---

## **Problema: Pods no se crean**

```bash
kubectl create deployment nginx --image=nginx

# Ver
kubectl get pods

# Si queda en Pending o no aparece
```

### Verificación

```bash
# ¿Hay nodos disponibles?
kubectl get nodes

# ¿Hay taints?
kubectl describe nodes

# Ver qué dice deployment
kubectl describe deployment nginx

# Ver eventos
kubectl get events -A --sort-by='.lastTimestamp'
```

### Solución

1. **Esperar**: Primero pod toma 10-30 segundos
2. **Ver logs**: `kubectl logs deployment/nginx`
3. **Describir**: `kubectl describe pod <pod-name>`

---

## **Problema: Storage no funciona**

```bash
kubectl apply -f - << EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 1Gi
EOF

# Ver estado
kubectl get pvc

# Si está "Pending"
```

### Verificación

```bash
# ¿StorageClass existe?
kubectl get storageclass

# Debería mostrar: local-path

# ¿Hay espacio en disco?
ssh root@192.168.1.200 "df -h"
ssh pi@192.168.1.100 "df -h"

# Mínimo 10% libre
```

### Solución

```bash
# Si local-path no existe
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

# Esperar a que provisioner esté Ready
kubectl get pods -n local-path-storage

# Reintentar PVC
kubectl delete pvc test-pvc
kubectl apply -f ...
```

---

## **Problema: "kubelet_cgroup_manager_duration_seconds" timeout**

Kubelet se vuelve lento.

```bash
# Ver logs
ssh root@192.168.1.200 "sudo journalctl -u k3s.service | grep -i cgroup"

# Típicamente:
# - OOM (sin memoria)
# - Disco lleno
# - CPU saturada
```

### Solución

```bash
# Ver recursos
kubectl top nodes
kubectl top pods -a

# Liberar espacio
ssh root@192.168.1.200 "sudo apt clean && sudo apt autoclean"
ssh pi@192.168.1.100 "sudo apt clean && sudo apt autoclean"

# Si sigue, reiniciar
sudo systemctl restart k3s
```

---

## **Problema: Deployments no se actualizan**

```bash
kubectl set image deployment/app app=myimage:v2

# Pero pods siguen con v1
```

### Verificación

```bash
# Ver deployment
kubectl get deployment app -o yaml | grep image

# Ver pods
kubectl get pods -o wide
```

### Solución

```bash
# Forzar rolling restart
kubectl rollout restart deployment/app

# Esperar
kubectl rollout status deployment/app

# Verificar versión
kubectl get pods -o jsonpath='{.items[0].spec.containers[0].image}'
```

---

## **Problema: "Insufficient resources"**

```bash
# Ver error
kubectl describe pod <pod>

# Dice: Insufficient cpu/memory
```

### Verificación

```bash
# Ver recursos del cluster
kubectl describe nodes

# Ver disponible
kubectl top nodes

# Ver usado
kubectl top pods -a
```

### Solución

```bash
# Reducir replicas
kubectl scale deployment <name> --replicas=1

# O reducir requests del pod
kubectl edit deployment <name>
# Buscar: resources: y reducir

# O:
kubectl set resources deployment <name> \
  --limits=cpu=500m,memory=128Mi \
  --requests=cpu=250m,memory=64Mi
```

---

## **Problema: Etcd desincronizado**

Master y worker con datos inconsistentes.

```bash
# Ver status de etcd
kubectl exec -n kube-system etcd-master -- \
  etcdctl --endpoints=127.0.0.1:2379 member list

# Si solo ves 1 miembro, worker no registrada
```

### Solución

```bash
# Re-registrar worker
# En worker
sudo systemctl restart k3s-agent.service

# Esperar 30 segundos
sleep 30

# En master, verificar
kubectl get nodes
```

---

## **Problema: Certificados expirados**

```bash
# Ver si hay warning
kubectl get node

# Si ves warnings o errores de cert
```

### Verificación

```bash
# Ver certificados
ssh root@192.168.1.200 "sudo ls -la /var/lib/rancher/k3s/server/tls/"

# Ver fecha de expiración (si openssl disponible)
ssh root@192.168.1.200 "sudo openssl x509 -in /var/lib/rancher/k3s/server/tls/server-ca.crt -text -noout | grep -A 2 'Validity'"
```

### Solución

```bash
# K3s renueva automáticamente
# Pero para forzar:
ssh root@192.168.1.200 "sudo systemctl restart k3s"

# Esperar que se renueven
# Ver logs
ssh root@192.168.1.200 "sudo journalctl -u k3s.service | grep -i cert"
```

---

## **Problema: RBAC denegando acceso**

```bash
# Intenta hacer algo
kubectl delete pod my-pod

# Error: forbidden: User "system:serviceaccount:default:default" cannot delete resource...
```

### Verificación

```bash
# ¿Qué rol tiene el usuario?
kubectl get rolebinding -A

# ¿Qué permite el role?
kubectl describe role <role-name>
```

### Solución

```bash
# Crear role con permisos necesarios
kubectl create role pod-deleter --verb=delete --resource=pods

# Asignar a usuario/serviceaccount
kubectl create rolebinding delete-pods \
  --clusterrole=pod-deleter \
  --serviceaccount=default:default
```

---

## **Problema: Ingress no funciona**

```bash
# Crear ingress
kubectl apply -f - << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test
spec:
  rules:
  - host: test.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx
            port:
              number: 80
EOF

# Probar
curl http://test.local

# Error: Cannot resolve
```

### Verificación

```bash
# ¿Ingress controller corriendo?
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik

# K3s incluye Traefik por defecto

# ¿Service existe?
kubectl get svc nginx

# Ver estado del Ingress
kubectl describe ingress test
```

### Solución

```bash
# Si Traefik no está
kubectl apply -f https://raw.githubusercontent.com/traefik/traefik-helm-chart/master/traefik/values.yaml

# Agregar host al /etc/hosts
# En tu PC
# 192.168.1.200 test.local

# O en Linux/Mac
echo "192.168.1.200 test.local" | sudo tee -a /etc/hosts

# Probar
curl http://test.local
```

---

## **Problema: ConfigMaps/Secrets no se montan**

```bash
# Crear configmap
kubectl create configmap app-config --from-literal=key=value

# Usar en pod
kubectl run debug --image=busybox -- sleep 1000

# Montarlo
kubectl patch deployment debug --type merge -p \
  '{"spec":{"template":{"spec":{"volumes":[{"name":"cfg","configMap":{"name":"app-config"}}]}}}}'

# Verificar
kubectl exec <pod> -- cat /etc/config/key

# No existe
```

### Verificación

```bash
# ¿ConfigMap existe?
kubectl get cm

# ¿Pod la ve?
kubectl describe pod <pod>

# Ver qué se montó
kubectl exec <pod> -- ls -la /etc/config/
```

### Solución

```bash
# Actualizar deployment correctamente
kubectl edit deployment debug

# Agregar en spec.template.spec:
volumes:
- name: cfg
  configMap:
    name: app-config
containers[0].volumeMounts:
- name: cfg
  mountPath: /etc/config

# Guardar y esperar rollout
kubectl rollout status deployment/debug
```

---

## **Monitoreo General**

```bash
# Dashboard simple
kubectl get all -A --show-labels

# Más detallado
kubectl describe nodes
kubectl describe pods -A

# En tiempo real
watch -n 1 'kubectl get all -A'

# O usar metrics
kubectl top nodes --sort-by memory
kubectl top pods -A --sort-by memory
```

---

## **Checklist de Salud del Cluster**

```bash
# Estos comandos deben volver todo OK/Ready/Running

✅ kubectl get nodes                    # Todos Ready
✅ kubectl get pods -n kube-system      # Todos Running
✅ kubectl get svc -A                   # Servicios activos
✅ kubectl get storageclass             # local-path presente
✅ kubectl cluster-info                 # API respondiendo
✅ kubectl get events -A                # Sin errores recientes
✅ kubectl top nodes                    # Sin Pressure
✅ kubectl get deployment -A            # Desired = Ready
```

---

## 📖 Siguiente

Lee: `../deployment/CILIUM-CNI.md` para mejorar el cluster con Cilium.

