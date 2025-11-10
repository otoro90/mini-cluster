#!/bin/bash

# Script de diagnóstico para acceso WAN
# Fecha: 6 de noviembre de 2025

echo "🔍 Diagnóstico de acceso WAN..."
echo "================================="

# IP local
echo "📍 IP local del servidor: $(hostname -I | awk '{print $1}')"

# Puertos locales abiertos
echo ""
echo "🔌 Puertos locales abiertos:"
echo "- 8080 (Keycloak): $(ss -tlnp | grep :8080 >/dev/null && echo '✅ ABIERTO' || echo '❌ CERRADO')"
echo "- 5432 (PostgreSQL): $(ss -tlnp | grep :5432 >/dev/null && echo '✅ ABIERTO' || echo '❌ CERRADO')"
echo "- 30126 (Ingress): $(ss -tlnp | grep :30126 >/dev/null && echo '✅ ABIERTO' || echo '❌ CERRADO')"

# Servicios funcionando
echo ""
echo "🌐 Servicios locales:"
echo "- Keycloak: $(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080 && echo '✅ OK' || echo '❌ FAIL')"
echo "- PostgreSQL: $(timeout 2 bash -c "</dev/tcp/localhost/5432" && echo '✅ OK' || echo '❌ FAIL')"

# Configuración del router necesaria
echo ""
echo "🔧 Configuración necesaria en el router:"
echo "Puerto externo → Puerto interno → IP interna ($(hostname -I | awk '{print $1}'))"
echo "8080 → 8080 → $(hostname -I | awk '{print $1}')"
echo "5432 → 5432 → $(hostname -I | awk '{print $1}')"
echo "30126 → 30126 → $(hostname -I | awk '{print $1}') (opcional)"

echo ""
echo "🌐 Posibles problemas:"
echo "1. ❌ Port forwarding NO configurado en router"
echo "2. ❌ IP WAN diferente a la que muestra cual-es-mi-ip.net"
echo "3. ❌ ISP bloqueando puertos (común: 8080, 5432)"
echo "4. ❌ Firewall del router bloqueando conexiones"
echo "5. ❌ Doble NAT (router ISP + router local)"

echo ""
echo "🧪 Pruebas desde otro dispositivo en la misma red:"
echo "curl http://$(hostname -I | awk '{print $1}'):8080"
echo "telnet $(hostname -I | awk '{print $1}') 8080"

echo ""
echo "📞 Para soporte, verifica:"
echo "1. Configuración del router"
echo "2. IP WAN real (puede diferir de cual-es-mi-ip.net)"
echo "3. Firewall del router"