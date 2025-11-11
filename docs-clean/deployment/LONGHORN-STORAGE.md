# 💾 Longhorn Storage

Almacenamiento distribuido y replicado.

---

## **¿Qué es Longhorn?**

Sistema de storage cloud-native:

- ✅ Replicación automática entre nodos
- ✅ Snapshots y backups
- ✅ Web UI para gestión
- ✅ Discos virtuales distribuidos
- ✅ Failover automático (si un nodo falla)

### Vs local-path (K3s default)

| Feature | local-path | Longhorn |
|---|---|---|
| **Ubicación** | Un nodo solo | Replicado en múltiples |
| **Failover** | ❌ Si nodo falla, datos perdidos | ✅ Automático |
| **Snapshots** | ❌ NO | ✅ SÍ |
| **Backups** | ❌ NO | ✅ SÍ |
| **UI** | ❌ NO | ✅ SÍ |
| **Complejidad** | ✅ Mínima | ⏳ Media |

---

## **Prerequisitos**

1. **K3s corriendo con 2+ nodos** ✅
2. **Cilium CNI** (opcional pero recomendado) ✅
3. **iSCSI en nodos**:
   ```bash
   # En master
   ssh root@192.168.1.254 "sudo apt install -y open-iscsi"
   
   # En worker
   ssh pi@192.168.1.250 "sudo apt install -y open-iscsi"
   ```

4. **Espacio en disco disponible**:
   ```bash
   # Mínimo 20GB recomendado
   ssh root@192.168.1.254 "df -h"
   ssh pi@192.168.1.250 "df -h"
   ```

---

## **Instalación**

### 1. Agregar repo de Longhorn

```bash
helm repo add longhorn https://charts.longhorn.io
helm repo update
```

### 2. Crear namespace

```bash
kubectl create namespace longhorn-system
```

### 3. Instalar Longhorn

```bash
helm install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --set persistence.defaultClass=true \
  --set persistence.defaultClassReplicaCount=2 \
  --set persistence.recurringJobSelector.enable=true \
  --set preUpgradeChecker.jobActive=false \
  --set defaultSettings.backupTarget="" \
  --set defaultSettings.allowRecurringJobWhileVolumeDetached=true
```

### 4. Verificar instalación

```bash
# Ver pods
kubectl get pods -n longhorn-system

# Esperar a que todos sean Running
kubectl rollout status deployment/longhorn-manager -n longhorn-system

# Debería tomar 2-3 minutos

# Verificar StorageClass
kubectl get storageclass

# Debería mostrar: longhorn (default)
```

---

## **Web UI de Longhorn**

### Acceder

```bash
# Port-forward
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80

# En navegador
# http://localhost:8080
```

Verás:
- Nodos disponibles
- Volúmenes creados
- Réplicas
- Snapshots
- Backups
- Health del sistema

---

## **Usar Longhorn**

### Crear volumen

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-volume
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 5Gi
```

```bash
kubectl apply -f pvc.yaml

# Verificar
kubectl get pvc
# Debería mostrar: my-volume BOUND
```

### Usar en Deployment

```yaml
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
          claimName: my-volume
```

---

## **Snapshots (Backups Automáticos)**

### Crear snapshot manual

```bash
# Desde UI
# 1. Ir a Volumes
# 2. Seleccionar volumen
# 3. Click "Create Snapshot"

# O desde CLI
kubectl exec -n longhorn-system -it pod/longhorn-manager-XXXXX -- \
  longhornctl create snapshot my-volume
```

### Snapshots automáticos

En la instalación anterior, ya habilitamos `recurringJobSelector`.

Para scheduling:

```yaml
apiVersion: longhorn.io/v1beta1
kind: RecurringJob
metadata:
  name: backup-daily
  namespace: longhorn-system
spec:
  cron: "0 2 * * *"  # Cada día a las 2 AM
  task: backup
  groups:
  - default
```

---

## **Replicación**

### Configurar número de réplicas

```bash
# En UI:
# Volumes → Seleccionar volumen → Edit → Number of Replicas

# O en YAML:
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: critical-data
  annotations:
    longhorn.io/numberOfReplicas: "3"  # 3 copias
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 10Gi
```

### Failover

Si un nodo falla:

```
Node A (falla)
├── Réplica 1 (perdida)
└── (Volume inaccesible temporalmente)

Longhorn automáticamente:
1. Detecta que Node A está down
2. Promueve Réplica 2 (en Node B) a primaria
3. Crea nueva Réplica 3 en Node C
4. Volume vuelve a estar online
```

Todo automático. El pod/deployment sigue funcionando.

---

## **Migración de volúmenes**

### De local-path a Longhorn

```bash
# 1. Crear volumen Longhorn
kubectl apply -f - << EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: migrated-data
spec:
  storageClassName: longhorn
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
EOF

# 2. Copiar datos (si tenía datos en local-path)
# Manualmente con kubectl cp o equivalente

# 3. Actualizar Deployment
kubectl patch deployment <name> -p \
  '{"spec":{"template":{"spec":{"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"migrated-data"}}]}}}}'

# 4. Rollout
kubectl rollout restart deployment/<name>
```

---

## **Troubleshooting**

### Volumen en "Attached Unknown"

```bash
# Reintentar
kubectl describe pvc <pvc-name>

# Esperar 1-2 minutos, a veces se recupera

# Si persiste
kubectl rollout restart deployment/<deployment>
```

### Bajo espacio en disco

```bash
# Ver espacio usado
kubectl exec -n longhorn-system pod/longhorn-manager-XXXXX -- \
  longhornctl volume list

# O en UI: Nodes

# Soluciones:
# 1. Agregar más disco al nodo
# 2. Reducir tamaño de volúmenes
# 3. Eliminar snapshots antiguos
```

### Manager pod no inicia

```bash
# Ver logs
kubectl logs -n longhorn-system -l app=longhorn-manager

# Típicamente:
# - iSCSI no instalado
# - Permisos incorrectos
# - Kernel muy viejo

# Soluciones
# Ver sección de Prerequisites
```

### Alta latencia

```bash
# Longhorn replica datos entre nodos = latencia natural
# Especialmente en redes lentas

# Mitigar:
# - Usar fiber/ethernet directo entre nodos
# - Reducir número de réplicas si no es crítico
# - Usar SSD en lugar de HDD
```

---

## **Backup a Backup Target**

Guardar backups en S3/NFS (opcional).

### S3 (Amazon, Minio, etc)

```yaml
apiVersion: longhorn.io/v1beta1
kind: Setting
metadata:
  name: backup-target
  namespace: longhorn-system
value: "s3://my-bucket@us-east-1/longhorn"
---
apiVersion: longhorn.io/v1beta1
kind: Setting
metadata:
  name: backup-target-credential-secret
  namespace: longhorn-system
value: "minio-secret"  # Secret con AWS_ACCESS_KEY_ID, etc
```

### NFS

```yaml
apiVersion: longhorn.io/v1beta1
kind: Setting
metadata:
  name: backup-target
  namespace: longhorn-system
value: "nfs://192.168.1.50:/backups"
```

---

## **Performance Tuning**

### Tamaño de réplica para recursos limitados

```yaml
# Para Raspberry Pi / Orange Pi (recursos limitados)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data
  annotations:
    longhorn.io/numberOfReplicas: "1"  # Solo 1 copia
    longhorn.io/staleReplicaTimeout: "30"  # Reconstruir rápido
spec:
  storageClassName: longhorn
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
```

### Deshabilitar replicación para datos no críticos

```yaml
metadata:
  annotations:
    longhorn.io/numberOfReplicas: "0"  # ⚠️ NO REPLICADO
```

---

## **Comparación con Alternativas**

| Storage | Simplicidad | Replicación | UI | Costo |
|---|---|---|---|---|
| **local-path** | ✅✅ | ❌ | ❌ | Gratis |
| **Longhorn** | ✅ | ✅✅ | ✅✅ | Gratis |
| **NFS** | ✅ | ❌ (manual) | ❌ | NAS necesaria |
| **Ceph** | ❌ | ✅✅ | ✅ | Gratis (complejo) |

**Para nuestro caso (2 nodos ARM)**: Longhorn es perfecto.

---

## **Próximos Pasos**

1. ✅ Longhorn instalado
2. ⏳ Usar Longhorn para PostgreSQL (veremos después)
3. ⏳ Configurar backups automáticos

Lee: `../deployment/PROMETHEUS-GRAFANA.md`

