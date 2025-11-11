# 🔒 Seguridad en K3s

Protegiendo tu cluster.

---

## **Niveles de Seguridad**

```
┌────────────────────────────────┐
│   1. API Server Security       │ ← Quién accede a kubectl
├────────────────────────────────┤
│   2. RBAC (Roles)              │ ← Qué puede hacer cada usuario
├────────────────────────────────┤
│   3. Network Policies          │ ← Qué pods pueden comunicarse
├────────────────────────────────┤
│   4. Pod Security Policies     │ ← Qué pueden hacer los pods
├────────────────────────────────┤
│   5. Secrets Encryption        │ ← Datos sensibles cifrados
├────────────────────────────────┤
│   6. Image Scanning            │ ← Imágenes verificadas
└────────────────────────────────┘
```

---

## **1. Acceso a API Server**

### kubeconfig

K3s genera `/etc/rancher/k3s/k3s.yaml` en el master:

```bash
# En master
sudo cat /etc/rancher/k3s/k3s.yaml

# Contiene:
# - Certificate Authority (CA)
# - Client Certificate
# - Client Key
# - API Server URL
```

Acceso seguro:

```bash
# Copiar desde master a tu PC
ssh root@192.168.1.254 "sudo cat /etc/rancher/k3s/k3s.yaml" > ~/.kube/config

# Asegurar permisos
chmod 600 ~/.kube/config

# Usar
kubectl get nodes
```

### Certificate-based Auth

K3s usa certificados X.509:

```bash
# Ver certificados del master
kubectl get secret -n kube-system

# Ver detalles
kubectl describe secret -n kube-system <secret-name>
```

---

## **2. RBAC (Role-Based Access Control)**

Qué usuario puede hacer qué:

### Conceptos

| Concepto | Significado |
|---|---|
| **User** | Tu usuario (devops@example.com) |
| **ServiceAccount** | Usuario para aplicaciones |
| **Role** | Conjunto de permisos (read pods, delete pods, etc) |
| **RoleBinding** | Asigna Role a User/ServiceAccount |
| **ClusterRole** | Role a nivel cluster (no solo namespace) |
| **ClusterRoleBinding** | Asigna ClusterRole globalmente |

### Ejemplo: ServiceAccount + Role

```yaml
---
# 1. ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: default

---
# 2. Role con permisos
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-role
  namespace: default
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get"]

---
# 3. RoleBinding (conecta Role con SA)
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-rolebinding
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: app-role
subjects:
- kind: ServiceAccount
  name: app-sa
  namespace: default
```

Usar en Pod:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  template:
    spec:
      serviceAccountName: app-sa  # ← Usa ServiceAccount
      containers:
      - name: app
        image: myapp:latest
```

### Permisos Comunes

| Verbo | Significado |
|---|---|
| get, list, watch | Lectura |
| create | Crear |
| edit, patch | Modificar |
| delete | Eliminar |
| deletecollection | Eliminar múltiples |

---

## **3. Network Policies**

Controlar tráfico entre pods (requiere Cilium):

```yaml
---
# Denegar TODO tráfico entrante por defecto
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress

---
# Permitir solo desde frontend
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-frontend
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: frontend
    ports:
    - protocol: TCP
      port: 3000
```

Con Flannel esto NO funciona. Espera a instalar Cilium.

---

## **4. Pod Security**

Restringir qué puede hacer un pod:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: restricted-pod
spec:
  securityContext:
    runAsNonRoot: true         # ← No ejecutar como root
    runAsUser: 1000            # ← UID específico
    fsReadOnlyRootFilesystem: true  # ← FS read-only
  containers:
  - name: app
    image: myapp:latest
    securityContext:
      allowPrivilegeEscalation: false  # ← Sin escalada
      capabilities:
        drop:
        - ALL              # ← Sin capacidades Linux
        add:
        - NET_BIND_SERVICE # ← Solo la necesaria
```

---

## **5. Secrets Encryption**

Por defecto, K3s almacena secrets sin encriptar en etcd.

Para encriptar:

```yaml
# En master, editar /etc/rancher/k3s/server/encrypt.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: key1
        secret: <base64-encoded-32-bytes>
  - identity: {}
```

(Complejo - veremos después si necesario)

---

## **6. Image Scanning**

No ejecutar imágenes untrusted:

```yaml
# Usar imagePullPolicy
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  template:
    spec:
      containers:
      - name: app
        image: myapp:latest
        imagePullPolicy: Always  # ← Verificar siempre
        # O: Never (solo local)
        # O: IfNotPresent (caché)
```

Usar registros con verificación:

```bash
# Usar Docker Hub verificado
docker pull nginx:latest

# Verificar firma
docker trust inspect docker.io/library/nginx:latest
```

---

## **Secrets en Práctica**

### Crear Secret

```bash
# Desde literal
kubectl create secret generic db-pass --from-literal=password=secretpass123

# Desde archivo
echo -n "mysecretkey" > secret.txt
kubectl create secret generic my-key --from-file=secret.txt

# Ver (codificado base64)
kubectl get secret db-pass -o yaml
```

### Usar Secret en Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: app
    image: myapp
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-pass
          key: password
```

### Problemas con Secrets

⚠️ **Los Secrets son solo base64, NO cifrados por defecto**

```bash
# Base64 es reversible
echo "secretpass123" | base64
# → c2VjcmV0cGFzczEyMw==

echo "c2VjcmV0cGFzczEyMw==" | base64 -d
# → secretpass123
```

**Solución**: Usar Cilium con cifrado, o gestor de secrets (Vault, etc)

---

## **Audit Logs**

Ver quién hizo qué:

```bash
# En master
sudo journalctl -u k3s.service | grep audit

# O ver logs de API
kubectl logs -n kube-system -l k8s-app=kube-apiserver
```

---

## **Permisos por Defecto en K3s**

```bash
# Ver usuarios del sistema
kubectl config view

# Ver contextos
kubectl config get-contexts

# Ver roles existentes
kubectl get roles -A
kubectl get clusterroles

# Tu usuario ('admin') tiene permisos totales en 'default'
```

---

## **Checklist de Seguridad**

- ✅ Cambiar contraseña de root en master/worker
- ✅ Copiar `kubeconfig` de forma segura
- ✅ Usar SSH keys (no contraseña)
- ✅ Firewall en router (bloquear puerto 6443 desde internet)
- ✅ Actualizar K3s regularmente
- ✅ Monitorear logs
- ✅ Usar Network Policies (con Cilium)
- ✅ No ejecutar pods como root
- ⏳ Implementar Pod Security Policies (opcional)
- ⏳ Encriptar Secrets en etcd (opcional)

---

## 📖 Siguiente

Lee: `../troubleshooting/NETWORK-ISSUES.md` para troubleshooting.

