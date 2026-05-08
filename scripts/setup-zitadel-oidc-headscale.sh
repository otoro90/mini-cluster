#!/usr/bin/env bash
# =============================================================================
# Fase 2: Configurar OIDC de Headscale contra ZITADEL
# =============================================================================
set -euo pipefail

MASTER_IP="${MASTER_IP:-192.168.1.210}"
MASTER_USER="${MASTER_USER:-root}"
MASTER_PASS="${MASTER_PASS:-123456}"
ZITADEL_URL="${ZITADEL_URL:-https://auth.forjanova.com}"
ZITADEL_API_URL="${ZITADEL_API_URL:-http://zitadel.192.168.1.210.nip.io}"
HEADSCALE_URL="${HEADSCALE_URL:-https://vpn.forjanova.com}"

run_remote() {
  sshpass -p "$MASTER_PASS" ssh -o StrictHostKeyChecking=no "$MASTER_USER@$MASTER_IP" "$@"
}

echo "================================================================="
echo "Fase 2: OIDC Headscale → ZITADEL"
echo "ZITADEL URL : $ZITADEL_URL"
echo "ZITADEL API : $ZITADEL_API_URL"
echo "Headscale URL: $HEADSCALE_URL"
echo "================================================================="
echo "Nota: si reaplicas manifests/security/zitadel-headscale/headscale.yaml,"
echo "      vuelve a ejecutar este script para restaurar el bloque OIDC runtime."

# 1. Dependencias Python
echo ""
echo "[1/7] Verificando dependencias Python en maestro..."
run_remote "python3 -c 'import jwt, cryptography' 2>/dev/null || apt-get install -y -qq python3-jwt python3-cryptography >/dev/null 2>&1"
echo "  OK"

# 2. Clave IAM Admin
echo ""
echo "[2/7] Extrayendo clave IAM Admin de ZITADEL..."
IAM_KEY_B64=$(run_remote \
  "KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n zitadel get secret iam-admin \
   -o jsonpath='{.data.iam-admin\.json}' 2>/dev/null || echo ''")

if [[ -z "$IAM_KEY_B64" ]]; then
  echo "  ERROR: Secret iam-admin no encontrado. Verifica que zitadel-setup completó."
  exit 1
fi
echo "  OK"

# 3. Crear app OIDC en ZITADEL via Management API v1
echo ""
echo "[3/7] Autenticando y creando app OIDC en ZITADEL..."

PYTHON_SCRIPT='
import sys, json, time, base64, urllib.request, urllib.parse, urllib.error

iam_key_b64 = sys.argv[1]
zitadel_public_url = sys.argv[2].rstrip("/")
zitadel_api_url = sys.argv[3].rstrip("/")
headscale_url = sys.argv[4].rstrip("/")

iam_key = json.loads(base64.b64decode(iam_key_b64).decode())
user_id = iam_key["userId"]
key_id  = iam_key["keyId"]
private_key_pem = iam_key["key"]

import jwt  # python3-jwt (PyJWT)

now = int(time.time())
payload = {
    "iss": user_id,
    "sub": user_id,
    "aud": zitadel_api_url,
    "iat": now,
    "exp": now + 3600,
}
assertion = jwt.encode(payload, private_key_pem, algorithm="RS256", headers={"kid": key_id})

# Get access token
token_data = urllib.parse.urlencode({
    "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
    "scope": "openid urn:zitadel:iam:org:project:id:zitadel:aud",
    "assertion": assertion,
}).encode()
tok_req = urllib.request.Request(
    f"{zitadel_api_url}/oauth/v2/token",
    data=token_data,
    headers={"Content-Type": "application/x-www-form-urlencoded"},
    method="POST"
)
try:
    tok_resp = json.loads(urllib.request.urlopen(tok_req, timeout=30).read())
except urllib.error.HTTPError as e:
    raise RuntimeError(f"Token error {e.code}: {e.read().decode()}")

access_token = tok_resp["access_token"]

def api(method, path, body=None):
    url = f"{zitadel_api_url}{path}"
    headers = {"Content-Type": "application/json", "Authorization": f"Bearer {access_token}"}
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        resp = urllib.request.urlopen(req, timeout=30)
        return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"HTTP {e.code} on {path}: {e.read().decode()}")

# Create project via Management API v1
try:
    proj = api("POST", "/management/v1/projects", {
        "name": "Headscale VPN",
        "projectRoleAssertion": True,
    })
    project_id = proj["id"]
except RuntimeError as e:
    err = str(e)
    if "already exists" in err.lower() or "AlreadyExists" in err or "6," in err:
        # Try to find existing project
        search = api("POST", "/management/v1/projects/_search", {
            "query": {"name": {"name": "Headscale VPN", "method": "TEXT_QUERY_METHOD_EQUALS"}}
        })
        results = search.get("result", [])
        if not results:
            raise RuntimeError("Project already exists but cannot find it: " + err)
        project_id = results[0]["id"]
    else:
        raise

# Create OIDC app via Management API v1
redirect_uri = f"{headscale_url}/oidc/callback"
try:
    app = api("POST", f"/management/v1/projects/{project_id}/apps/oidc", {
        "name": "Headscale",
        "redirectUris": [redirect_uri],
        "responseTypes": ["OIDC_RESPONSE_TYPE_CODE"],
        "grantTypes": ["OIDC_GRANT_TYPE_AUTHORIZATION_CODE"],
        "appType": "OIDC_APP_TYPE_WEB",
        "authMethodType": "OIDC_AUTH_METHOD_TYPE_BASIC",
        "postLogoutRedirectUris": [headscale_url],
        "devMode": True,
    })
except RuntimeError as e:
    raise RuntimeError(f"Failed to create OIDC app: {e}")

client_id     = app.get("clientId", "")
client_secret = app.get("clientSecret", "")
app_id        = app.get("appId", "")

if not client_secret and app_id:
    sec = api("PUT", f"/management/v1/projects/{project_id}/apps/{app_id}/oidc/reset_client_secret", {})
    client_secret = sec.get("clientSecret", "")

print(json.dumps({
    "client_id": client_id,
    "client_secret": client_secret,
    "issuer": zitadel_public_url,
    "project_id": project_id,
    "app_id": app_id,
}))
'

OIDC_JSON=$(run_remote "python3 -c '$PYTHON_SCRIPT' '$IAM_KEY_B64' '$ZITADEL_URL' '$ZITADEL_API_URL' '$HEADSCALE_URL'")

CLIENT_ID=$(echo "$OIDC_JSON"     | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['client_id'])")
CLIENT_SECRET=$(echo "$OIDC_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['client_secret'])")
ISSUER=$(echo "$OIDC_JSON"        | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['issuer'])")

echo "  OK — App OIDC creada."
echo "  issuer     : $ISSUER"
echo "  client_id  : $CLIENT_ID"
echo "  secret     : ${CLIENT_SECRET:0:8}..."

# 4. Secret K8s
echo ""
echo "[4/7] Guardando en K8s secret headscale-oidc-credentials..."
run_remote "KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n headscale delete secret headscale-oidc-credentials --ignore-not-found=true"
run_remote "KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n headscale create secret generic headscale-oidc-credentials \
  --from-literal=issuer='$ISSUER' \
  --from-literal=client_id='$CLIENT_ID' \
  --from-literal=client_secret='$CLIENT_SECRET'"
echo "  OK"

# 5-6. ConfigMap con OIDC
echo ""
echo "[5/7] Generando ConfigMap de Headscale con OIDC..."

CONFIGMAP_YAML="apiVersion: v1
kind: ConfigMap
metadata:
  name: headscale-config
  namespace: headscale
data:
  config.yaml: |
    server_url: ${HEADSCALE_URL}
    listen_addr: 0.0.0.0:8080
    metrics_listen_addr: 0.0.0.0:9090
    grpc_listen_addr: 0.0.0.0:50443
    grpc_allow_insecure: true
    noise:
      private_key_path: /var/lib/headscale/noise_private.key
    prefixes:
      v4: 100.64.0.0/10
      v6: fd7a:115c:a1e0::/48
      allocation: sequential
    database:
      type: sqlite
      sqlite:
        path: /var/lib/headscale/db.sqlite
        write_ahead_log: true
    dns:
      magic_dns: true
      base_domain: tailnet.forjanova.local
      override_local_dns: false
      nameservers:
        global:
          - 1.1.1.1
          - 8.8.8.8
    derp:
      server:
        enabled: true
        region_id: 999
        region_code: forjanova
        region_name: Forjanova Embedded DERP
        stun_listen_addr: 0.0.0.0:3478
        private_key_path: /var/lib/headscale/derp_server_private.key
        automatically_add_embedded_derp_region: true
        verify_clients: true
        ipv4: 192.168.1.210
      urls:
        - https://controlplane.tailscale.com/derpmap/default
      auto_update_enabled: true
      update_frequency: 24h
    policy:
      mode: database
    oidc:
      only_start_if_oidc_is_available: true
      issuer: ${ISSUER}
      client_id: ${CLIENT_ID}
      client_secret: ${CLIENT_SECRET}
      scope:
        - openid
        - profile
        - email
      extra_params: {}
      allowed_domains: []
      allowed_groups: []
      allowed_users: []
    log:
      format: text
      level: info"

echo ""
echo "[6/7] Aplicando ConfigMap al cluster..."
sshpass -p "$MASTER_PASS" ssh -o StrictHostKeyChecking=no "$MASTER_USER@$MASTER_IP" \
  "cat > /tmp/headscale-config-oidc.yaml" <<< "$CONFIGMAP_YAML"
run_remote "KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl apply -f /tmp/headscale-config-oidc.yaml"
echo "  OK"

# 7. Restart
echo ""
echo "[7/7] Reiniciando Headscale..."
run_remote "KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n headscale rollout restart deployment/headscale"
run_remote "KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n headscale rollout status deployment/headscale --timeout=3m"

echo ""
echo "================================================================="
echo "OIDC configurado"
echo "  Issuer     : $ISSUER"
echo "  Client ID  : $CLIENT_ID"
echo "  Redirect   : ${HEADSCALE_URL}/oidc/callback"
echo "  Secret K8s : headscale-oidc-credentials (ns: headscale)"
echo ""
echo "  Conectar cliente Tailscale:"
echo "    tailscale up --login-server=$HEADSCALE_URL"
echo "  Consola ZITADEL: $ZITADEL_URL/ui/console"
echo "================================================================="
