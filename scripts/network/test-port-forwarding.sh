#!/bin/bash

# Script rápido para probar port forwarding
# Ejecutar en Orange Pi después de configurar el router

echo "🧪 PRUEBA RÁPIDA DE PORT FORWARDING"
echo "===================================="

# Verificar IP WAN
echo "🌐 Tu IP WAN actual:"
curl -s https://api.ipify.org
echo ""

# Verificar DNS
echo "🔍 Resolución DNS de tu dominio:"
nslookup otoro.ddnsfree.com | grep "Address:" | tail -1
echo ""

# Probar Keycloak desde el exterior
echo "🔗 Probando acceso a Keycloak desde WAN..."
echo "URL: http://otoro.ddnsfree.com:8080"
echo ""

timeout 10 curl -I http://otoro.ddnsfree.com:8080 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ ¡EXITO! Port forwarding configurado correctamente"
    echo "🎉 Puedes acceder a Keycloak en: http://otoro.ddnsfree.com:8080"
else
    echo "❌ FALLÓ: Port forwarding no configurado o puerto bloqueado"
    echo ""
    echo "Posibles soluciones:"
    echo "1. Verifica configuración en router (192.168.1.1)"
    echo "2. Asegúrate de que puerto 8080 esté abierto"
    echo "3. Prueba desde un dispositivo FUERA de tu red local"
    echo "4. Ejecuta: /root/setup-claro-router.sh"
fi

echo ""
echo "🔍 Para diagnóstico completo: /root/diagnose-wan.sh"