# 🔐 PostgreSQL + Keycloak

Base de datos y autenticación para aplicaciones.

---

## **¿Qué es?**

- **PostgreSQL**: Base de datos SQL
- **Keycloak**: Servidor de identidad (login, OAuth2, OIDC)

### Arquitectura

```
┌──────────────────────────────┐
│      Aplicación (App)        │
└──────────────────────────────┘
         ↓           ↓
    ┌────────┐   ┌──────────┐
    │  PG    │   │ Keycloak │
    │Database│   │  (Auth)  │
    └────────┘   └──────────┘
         ↓               ↓
    Datos internos   User login
```

---

## **Instalación de PostgreSQL**

### 1. Crear ConfigMap para init

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-init
data:
  init.sql: |
    CREATE DATABASE keycloak;
    CREATE USER keycloak WITH PASSWORD 'keycloak-password';
    GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;
    ALTER USER keycloak CREATEDB;
```

```bash
kubectl apply -f configmap.yaml
```

### 2. Deployment de PostgreSQL

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
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
        image: postgres:15-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_PASSWORD
          value: "root-password"
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
        - name: init-scripts
          mountPath: /docker-entrypoint-initdb.d
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U postgres
          initialDelaySeconds: 30
          periodSeconds: 10
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: postgres-pvc
      - name: init-scripts
        configMap:
          name: postgres-init
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
spec:
  storageClassName: longhorn
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
  type: ClusterIP
```

```bash
kubectl apply -f postgres.yaml

# Verificar
kubectl get pods -l app=postgres
kubectl get svc postgres
```

---

## **Instalación de Keycloak**

### 1. Secret para acceso a DB

```bash
kubectl create secret generic keycloak-db \
  --from-literal=DB_USER=keycloak \
  --from-literal=DB_PASSWORD=keycloak-password
```

### 2. Deployment de Keycloak

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: keycloak
spec:
  replicas: 1
  selector:
    matchLabels:
      app: keycloak
  template:
    metadata:
      labels:
        app: keycloak
    spec:
      containers:
      - name: keycloak
        image: quay.io/keycloak/keycloak:latest
        ports:
        - containerPort: 8080
        env:
        - name: KEYCLOAK_ADMIN
          value: "admin"
        - name: KEYCLOAK_ADMIN_PASSWORD
          value: "admin-password"
        - name: KC_DB
          value: "postgres"
        - name: KC_DB_URL
          value: "jdbc:postgresql://postgres:5432/keycloak"
        - name: KC_DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: keycloak-db
              key: DB_USER
        - name: KC_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: keycloak-db
              key: DB_PASSWORD
        - name: KC_HOSTNAME
          value: "keycloak.local"
        - name: KC_PROXY
          value: "edge"
        args:
          - "start"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 5
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
      volumes:
      - name: keycloak-data
        persistentVolumeClaim:
          claimName: keycloak-pvc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: keycloak-pvc
spec:
  storageClassName: longhorn
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
---
apiVersion: v1
kind: Service
metadata:
  name: keycloak
spec:
  selector:
    app: keycloak
  ports:
  - port: 8080
    targetPort: 8080
  type: ClusterIP
```

```bash
kubectl apply -f keycloak.yaml

# Verificar
kubectl get pods -l app=keycloak
kubectl get svc keycloak
```

---

## **Acceder a Keycloak**

### Port-forward

```bash
kubectl port-forward svc/keycloak 8080:8080

# http://localhost:8080

# Admin console
# http://localhost:8080/admin

# Login: admin / admin-password
```

### O vía Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: keycloak-ingress
spec:
  rules:
  - host: keycloak.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: keycloak
            port:
              number: 8080
```

```bash
# En tu /etc/hosts
192.168.1.200 keycloak.local

# Ir a http://keycloak.local/admin
```

---

## **Configurar Keycloak**

### 1. Crear Realm

```
Admin Console → Click "Master" (arriba izq) → Create Realm

Name: myrealm
Display name: My Application
Save
```

### 2. Crear Usuario

```
Manage → Users → Create user

Username: testuser
Email: test@example.com
First Name: Test
Last Name: User

Save

Tab "Credentials"
Set password: testpass123
Temporary: OFF
Save password
```

### 3. Crear Cliente (para tu app)

```
Clients → Create

Client ID: my-app
Client Type: Web application

Next

Capability config:
✓ Client authentication: ON
✓ Authorization: ON

Save

Tab "Credentials"
Copy: Client ID + Client Secret (para tu app)
```

---

## **PostgreSQL desde tu Aplicación**

### Python (psycopg2)

```python
import psycopg2

conn = psycopg2.connect(
    host="postgres",
    database="mydb",
    user="keycloak",
    password="keycloak-password"
)
cursor = conn.cursor()
cursor.execute("SELECT * FROM users")
```

### JavaScript (node-postgres)

```javascript
const { Client } = require('pg')
const client = new Client({
  host: 'postgres',
  port: 5432,
  user: 'keycloak',
  password: 'keycloak-password',
  database: 'mydb'
})
await client.connect()
```

### Desde dentro de pods

```bash
# Pod se conecta a "postgres:5432" (nombre del service)
# Network K3s lo resuelve automáticamente
```

---

## **Keycloak OAuth2 en tu App**

### Configuration

```javascript
// Express.js example
const express = require('express');
const session = require('express-session');
const axios = require('axios');

const app = express();

app.use(session({
  secret: 'your-secret',
  resave: false,
  saveUninitialized: true
}));

// Login endpoint
app.get('/login', (req, res) => {
  const keycloakUrl = 'http://keycloak:8080/realms/myrealm/protocol/openid-connect/auth';
  const redirectUri = encodeURIComponent('http://localhost:3000/callback');
  const clientId = 'my-app';
  
  res.redirect(
    `${keycloakUrl}?client_id=${clientId}&redirect_uri=${redirectUri}&response_type=code`
  );
});

// Callback después del login
app.get('/callback', async (req, res) => {
  const code = req.query.code;
  
  // Intercambiar code por token
  const token = await axios.post(
    'http://keycloak:8080/realms/myrealm/protocol/openid-connect/token',
    {
      grant_type: 'authorization_code',
      code: code,
      client_id: 'my-app',
      client_secret: 'YOUR_CLIENT_SECRET',
      redirect_uri: 'http://localhost:3000/callback'
    }
  );
  
  req.session.token = token.data.access_token;
  res.redirect('/');
});

// Logout
app.get('/logout', (req, res) => {
  delete req.session.token;
  res.redirect(
    'http://keycloak:8080/realms/myrealm/protocol/openid-connect/logout'
  );
});
```

---

## **Troubleshooting**

### Keycloak no inicia

```bash
# Ver logs
kubectl logs -f deployment/keycloak

# Buscar:
# - DB connection errors
# - Memory issues
```

### PostgreSQL no responde

```bash
# Conectar
kubectl exec -it deployment/postgres -- \
  psql -U postgres -d keycloak

# Si no funciona
kubectl describe pod <postgres-pod>
kubectl logs <postgres-pod>
```

### "Connection refused"

```bash
# Verificar que servicios existen
kubectl get svc

# Ambos deben aparecer: postgres, keycloak

# Desde pod, probar conectividad
kubectl run -it --rm debug --image=busybox -- \
  wget -O- http://keycloak:8080/health
```

### Alto consumo de RAM (Keycloak)

```bash
# Keycloak (Java) necesita ~1GB mínimo
# En nuestro Orange Pi/RPi, puede ser lento

# Reducir:
# 1. Aumentar swap
# 2. Reducir réplicas
# 3. Usar Keycloak X (más ligero)
```

---

## **Backup y Restore**

### Backup de PostgreSQL

```bash
# Desde dentro del pod
kubectl exec deployment/postgres -- \
  pg_dump -U postgres keycloak > backup.sql

# O vía Longhorn (snapshots automáticos)
```

### Restore

```bash
kubectl exec -i deployment/postgres -- \
  psql -U postgres keycloak < backup.sql
```

---

## **Producción - Checklist**

- ✅ PostgreSQL con múltiples réplicas (Longhorn)
- ✅ Keycloak con session store distribuido
- ✅ Secrets cifrados en K3s
- ✅ HTTPS/TLS (Ingress con cert)
- ✅ Backups automáticos
- ✅ Monitoring (Prometheus)
- ✅ Network Policies (Cilium)
- ⏳ Rate limiting
- ⏳ DDoS protection

---

## **Próximos Pasos**

1. ✅ PostgreSQL corriendo
2. ✅ Keycloak configurado
3. ⏳ Tus aplicaciones conectadas a DB
4. ⏳ OAuth2 integrado en tus apps

Lee: `../getting-started/01-INICIO.md` para volver a start.

