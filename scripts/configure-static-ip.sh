# Script para configurar IP estática en Raspberry Pi con Armbian Ubuntu Noble
# Ejecutar como root o con sudo

# Paso 1: Verificar la interfaz de red actual
echo "Interfaz de red actual:"
ip addr show

# Paso 2: Ver conexiones de NetworkManager
echo "Conexiones de NetworkManager:"
nmcli connection show

# Paso 3: Configurar IP estática usando NetworkManager (asumiendo 'Wired connection 1' como nombre de conexión)
# Nota: Ajusta el nombre de la conexión si es diferente
CONNECTION_NAME="Wired connection 1"
nmcli connection modify "$CONNECTION_NAME" ipv4.method manual
nmcli connection modify "$CONNECTION_NAME" ipv4.addresses 192.168.1.254/24
nmcli connection modify "$CONNECTION_NAME" ipv4.gateway 192.168.1.1
nmcli connection modify "$CONNECTION_NAME" ipv4.dns "8.8.8.8 8.8.4.4"

# Paso 4: Aplicar la configuración (reiniciar la conexión)
nmcli connection down "$CONNECTION_NAME"
nmcli connection up "$CONNECTION_NAME"

# Paso 5: Verificar la nueva IP
echo "Nueva configuración de IP:"
ip addr show end0

echo "Configuración completada. Si no funciona, reinicia el dispositivo."