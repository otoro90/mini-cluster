#!/bin/bash

# Script para configurar acceso WAN
# Fecha: 6 de noviembre de 2025

echo "🌐 Configurando acceso WAN..."

# Configurar IP estática (ejemplo)
echo "💡 Para IP estática, edita /etc/netplan/50-cloud-init.yaml:"
echo "network:"
echo "  version: 2"
echo "  ethernets:"
echo "    eth0:"
echo "      dhcp4: false"
echo "      addresses:"
echo "        - 192.168.1.200/24"
echo "      routes:"
echo "        - to: default"
echo "          via: 192.168.1.1"
echo "      nameservers:"
echo "        addresses: [8.8.8.8, 1.1.1.1]"
echo ""

# Mostrar configuración actual
echo "📊 Puertos disponibles:"
echo "- Keycloak directo: $(hostname -I | awk '{print $1}'):8080"
echo "- PostgreSQL directo: $(hostname -I | awk '{print $1}'):5432"
echo "- Ingress HTTP: $(hostname -I | awk '{print $1}'):30126"
echo "- Keycloak via Ingress: http://$(hostname -I | awk '{print $1}'):30126/keycloak"
echo ""

echo "🔧 Configuración del router necesaria:"
echo "Puerto externo → Puerto interno → IP interna"
echo "8080 → 8080 → $(hostname -I | awk '{print $1}')"
echo "5432 → 5432 → $(hostname -I | awk '{print $1}')"
echo "30126 → 30126 → $(hostname -I | awk '{print $1}') (opcional para ingress)"
echo ""

echo "✅ Configuración de acceso WAN completada!"
echo "📝 Recuerda configurar port forwarding en tu router."