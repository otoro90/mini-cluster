# 💾 Storage (Almacenamiento)

Cómo gestionar datos persistentes en K3s.

---

## **Problema: Datos en Pods**

Contenedores son **efímeros** (temporales):

```bash
# Si eliminas un pod
kubectl delete pod my-pod

# Su disco desaparece
# ¿Y tus datos?
```

**Solución**: **PersistentVolumes** (discos persistentes)

---

## **Tipos de Almacenamiento**

### 1. EmptyDir (Temporal)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: temp
      mountPath: /tmp/data
  volumes:
  - name: temp
    emptyDir: {}
```

- Vive solo mientras el pod existe
- Compartido entre contenedores del mismo pod
- Se elimina con el pod

---

### 2. hostPath (En el Nodo)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: host-data
      mountPath: /data
  volumes:
  - name: host-data
    hostPath:
      path: /var/app-data
      type: Directory
```

- Almacena datos en el nodo físico
- Persiste cuando pod muere
- Problema: Si el nodo falla, datos perdidos

---

### 3. PersistentVolume (PV) + PersistentVolumeClaim (PVC)

Sistema profesional de almacenamiento.

```yaml
---
# 1. Define espacio disponible
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-data
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  local:
    path: /var/lib/rancher/k3s/storage
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - orangepi5

---
# 2. Pod solicita ese espacio
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 5Gi

---
# 3. Pod usa el PVC
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: app
        image: myapp:latest
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: my-pvc
```

**StorageClass** define cómo crear PVs automáticamente.

---

## **K3s Storage por Defecto**

K3s incluye `local-path`:

```bash
# Ver storage classes
kubectl get storageclass

# Debería mostrar:
# NAME         PROVISIONER             
# local-path   rancher.io/local-path
```

Crea PVs automáticamente en: `/var/lib/rancher/k3s/storage/`

---

## **Usar StorageClass Automático**

Sin definir PV explícitamente:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-data
spec:
  storageClassName: local-path
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15
        env:
        - name: POSTGRES_PASSWORD
          value: secretpass
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: my-data
```

---

## **Problemas con local-path**

1. **No tolerante a fallos**: Si el nodo físico falla, datos perdidos
2. **Un nodo solo**: Los datos están en el nodo específico
3. **No redundancia**: Copia única

---

## **Solución: Longhorn**

**Longhorn** es almacenamiento distribuido:

- ✅ Replicación automática entre nodos
- ✅ Backups
- ✅ Snapshots
- ✅ Web UI para gestión

Veremos instalación en: `../deployment/LONGHORN-STORAGE.md`

---

## **Access Modes (Modos de Acceso)**

| Modo | Símbolo | Significado |
|---|---|---|
| ReadWriteOnce | RWO | Un pod puede leer/escribir (un nodo) |
| ReadOnlyMany | ROX | Múltiples pods leen (un nodo) |
| ReadWriteMany | RWX | Múltiples pods leen/escriben (múltiples nodos) |

K3s local-path solo soporta: **RWO**

---

## **Ver Volúmenes**

```bash
# Ver PVs
kubectl get pv

# Ver PVCs
kubectl get pvc

# Detalles
kubectl describe pvc my-data
kubectl describe pv pvc-xxxxx

# Logs
kubectl logs -f deployment/my-app

# Conectar al pod y ver archivos
kubectl exec -it <pod-name> -- bash
ls -la /data
```

---

## **Montar Archivos en Pods: ConfigMaps y Secrets**

### ConfigMap (Configuración)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  config.txt: |
    DEBUG=true
    LOG_LEVEL=info
  nginx.conf: |
    server {
      listen 80;
      ...
    }

---
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: app
    image: myapp
    volumeMounts:
    - name: config
      mountPath: /etc/config
  volumes:
  - name: config
    configMap:
      name: app-config
```

Dentro del pod: `/etc/config/config.txt` y `/etc/config/nginx.conf`

### Secret (Credenciales)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
stringData:
  username: postgres
  password: secretpass123

---
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: app
    image: myapp
    env:
    - name: DB_USER
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: username
    - name: DB_PASS
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: password
```

O en archivos:

```yaml
volumeMounts:
- name: secrets
  mountPath: /etc/secrets
  readOnly: true
volumes:
- name: secrets
  secret:
    secretName: db-credentials
```

---

## **Backups**

### Backup manual

```bash
# Copiar datos desde pod
kubectl cp <namespace>/<pod-name>:/data ./backup-local

# Copiar datos hacia pod
kubectl cp ./data <namespace>/<pod-name>:/data
```

### Backup automático (con Longhorn)

Longhorn permite snapshots automáticos (veremos después)

---

## 📖 Siguiente

Lee: `../deployment/LONGHORN-STORAGE.md` para Longhorn.

