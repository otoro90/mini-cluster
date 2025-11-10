#!/bin/bash

# Script para instalar y configurar Dynu DDNS en Orange Pi
# Dynu es un servicio gratuito de DNS dinámico

echo "=== INSTALACIÓN DE DYNU DDNS ==="
echo ""

# Instalar dependencias
echo "Instalando dependencias..."
apt update
apt install -y curl wget jq ddclient

# Configurar ddclient para Dynu (alternativa más compatible con ARM64)
echo "Configurando ddclient para Dynu..."

# Crear configuración básica para ddclient
cat > /etc/ddclient.conf << EOF
# Configuration file for ddclient
#
# /etc/ddclient.conf

# Dynu DDNS configuration
protocol=dyndns2
use=web
server=api.dynu.com
login=TU_USERNAME
password=TU_PASSWORD
TU_HOSTNAME.dynu.net
EOF

echo "Configuración de ddclient creada en /etc/ddclient.conf"
echo "Edita el archivo con tus credenciales reales:"
echo "nano /etc/ddclient.conf"
echo ""
echo "Reemplaza:"
echo "  TU_USERNAME → tu email de Dynu"
echo "  TU_PASSWORD → tu contraseña de Dynu"
echo "  TU_HOSTNAME → tu hostname (ej: mini-cluster-arm)"

# Verificar que ddclient esté disponible
echo "Verificando ddclient..."
ddclient --version

echo ""
echo "=== CONFIGURACIÓN DE DYNU ==="
echo ""
echo "PASO 1: Crear cuenta en Dynu"
echo "=============================="
echo "1. Ve a: https://www.dynu.com/"
echo "2. Haz clic en 'Sign Up' (registro gratuito)"
echo "3. Completa el formulario con tu email"
echo "4. Verifica tu email"
echo "5. Inicia sesión en tu cuenta"
echo ""

echo "PASO 2: Crear hostname"
echo "======================="
echo "1. En tu panel de Dynu, ve a 'DDNS Services'"
echo "2. Haz clic en 'Add' para crear un nuevo hostname"
echo "3. Elige un nombre único (ej: tu-nombre-mini-cluster.dynu.net)"
echo "4. Selecciona el tipo 'Host with IP address'"
echo "5. Deja la IP en blanco (se actualizará automáticamente)"
echo "6. Haz clic en 'Save'"
echo ""

echo "PASO 3: Obtener credenciales"
echo "============================="
echo "1. Ve a 'Account' > 'API Credentials'"
echo "2. Copia tu 'Username' y 'Password' (o genera una API Key)"
echo ""

echo "PASO 4: Configurar cliente Dynu (usando ddclient)"
echo "================================================"
echo "El archivo de configuración se creó en /etc/ddclient.conf"
echo "Edítalo con tus credenciales:"
echo ""
echo "nano /etc/ddclient.conf"
echo ""
echo "Reemplaza:"
echo "  TU_USERNAME → tu email de Dynu"
echo "  TU_PASSWORD → tu contraseña de Dynu"
echo "  TU_HOSTNAME → tu hostname (ej: mini-cluster-arm)"
echo ""

echo "PASO 5: Probar configuración"
echo "============================"
echo "1. Edita la configuración: nano /etc/ddclient.conf"
echo "2. Prueba manualmente: ddclient -daemon=0 -debug -verbose -noquiet"
echo "3. Verifica que tu hostname se actualice en https://www.dynu.com/"
echo ""

echo "PASO 6: Configurar actualización automática"
echo "==========================================="
echo "ddclient ya se ejecuta como servicio systemd."
echo "Para verificar: systemctl status ddclient"
echo ""
echo "Para forzar actualización: ddclient -daemon=0"
echo ""

echo "PASO 7: Configuración avanzada (opcional)"
echo "=========================================="
echo "Si quieres más control, puedes:"
echo "- Editar /etc/default/ddclient para cambiar intervalos"
echo "- Usar múltiples hostnames agregando líneas al final del archivo"
echo ""

echo "=== EJEMPLO DE USO ==="
echo ""
echo "Una vez configurado, podrás acceder a tus servicios usando:"
echo "• Keycloak: http://tu-hostname.dynu.net:8080"
echo "• PostgreSQL: tu-hostname.dynu.net:5432"
echo ""
echo "En lugar de usar la IP que cambia: http://181.51.34.83:8080"
echo ""
echo "Comandos útiles:"
echo "• Verificar estado: systemctl status ddclient"
echo "• Actualizar manualmente: ddclient -daemon=0"
echo "• Ver logs: journalctl -u ddclient -f"
echo ""

echo "=== LIMPIEZA ==="
echo "rm dynu-linux-arm64.deb"
echo ""

echo "=== INSTALACIÓN COMPLETADA ==="
echo "Ejecuta los pasos 1-6 manualmente para completar la configuración."