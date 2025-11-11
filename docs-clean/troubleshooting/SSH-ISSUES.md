# 🔐 Problemas de SSH

Diagnóstico y resolución de problemas de conectividad SSH.

---

## **Problema: "Connection refused"**

```bash
# Intentar conectar
ssh root@192.168.1.254

# Error: Connection refused
```

### Verificación

```bash
# ¿SSH está activo?
sudo systemctl status ssh

# ¿Puerto 22 activo?
sudo ss -tlnp | grep 22

# ¿Firewall bloqueando?
sudo ufw status
```

### Solución

```bash
# Iniciar SSH
sudo systemctl start ssh
sudo systemctl enable ssh

# Verificar config SSH
sudo cat /etc/ssh/sshd_config | grep -E "^Port|^PasswordAuthentication|^PermitRootLogin"

# Debería tener:
# Port 22
# PasswordAuthentication yes
# PermitRootLogin yes

# Reiniciar SSH
sudo systemctl restart ssh
```

---

## **Problema: "Permission denied (publickey)"**

SSH keys no funcionan.

```bash
# Intenta con key
ssh -i ~/.ssh/id_rsa root@192.168.1.254

# Error: Permission denied (publickey)
```

### Verificación

1. **¿Exists la key?**
   ```bash
   ls -la ~/.ssh/id_rsa*
   ```

2. **¿Permisos correctos?**
   ```bash
   # En tu PC
   ls -la ~/.ssh/
   # Debería ser:
   # ~/.ssh       → 700
   # id_rsa       → 600
   # id_rsa.pub   → 644
   
   # En servidor
   ssh root@192.168.1.254 "ls -la ~/.ssh/"
   # Debería ser:
   # ~/.ssh           → 700
   # authorized_keys  → 600
   ```

3. **¿Public key en servidor?**
   ```bash
   ssh root@192.168.1.254 "cat ~/.ssh/authorized_keys"
   
   # Debería mostrar tu public key (ssh-rsa ...)
   ```

### Solución

```bash
# Fijar permisos en PC
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub

# Copiar key al servidor (si no está)
cat ~/.ssh/id_rsa.pub | ssh root@192.168.1.254 \
  "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

# Probar
ssh -i ~/.ssh/id_rsa -v root@192.168.1.254
# Debería conectar sin pedir contraseña
```

---

## **Problema: "Host key verification failed"**

```
Host key verification failed
```

Primera conexión a dispositivo nuevo.

### Solución

```bash
# Primera vez, aceptar la key
ssh -o StrictHostKeyChecking=no root@192.168.1.254 "echo OK"

# O aceptar interactivamente
ssh root@192.168.1.254
# Escribe: yes
# Luego contraseña
```

---

## **Problema: "No matching host key type found"**

Old SSH key format.

```bash
# Regenerar keys con formato moderno
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""

# Copiar al servidor
cat ~/.ssh/id_rsa.pub | ssh root@192.168.1.254 \
  "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

---

## **Problema: "Connection timeout"**

```bash
# Intenta
ssh -v root@192.168.1.254

# Logs muestran: timeout
```

### Verificación

```bash
# ¿Conectividad de red?
ping 192.168.1.254

# ¿Puerto 22 activo?
telnet 192.168.1.254 22

# ¿Firewall?
ssh -p 2222 root@192.168.1.254  # Probar otro puerto
```

### Solución

```bash
# Si está en otra red/red inalámbrica
ping 192.168.1.1  # Gateway

# Si no responde, reconectar a la red

# Si está detrás de NAT
ssh -p <puerto-externo> user@<ip-publica>

# Ver si K3s está usando puertos
sudo ss -tlnp
```

---

## **Problema: "Bad owner or permissions on home"**

```
Bad owner or permissions on /home/user
```

Permisos del home incorrectos.

```bash
# Fijar
sudo chmod 755 /home/user
sudo chmod 755 /home/user/.ssh

# O desde servidor
ssh root@192.168.1.254 "chmod 755 /root; chmod 755 /root/.ssh"
```

---

## **Problema: "Too many authentication failures"**

```bash
# Intentas conectar
ssh root@192.168.1.254

# Error: Too many authentication failures
```

SSH cansado de intentos.

### Solución

```bash
# Especificar solo tu key
ssh -i ~/.ssh/id_rsa root@192.168.1.254

# O resetear SSH
sudo systemctl restart ssh
```

---

## **Problema: SSH muy lento**

```bash
# Conectar toma mucho tiempo
ssh -v root@192.168.1.254
# Ves demoras en DNS o en authentication
```

### Verificación

```bash
# ¿DNS lento?
ssh -o GSSAPIAuthentication=no root@192.168.1.254

# ¿DNS servidor apunta mal?
cat /etc/resolv.conf

# Cambiar a DNS rápido
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
```

---

## **Problema: "Channel open failure"**

```bash
# Conecta pero no puede ejecutar comandos
ssh root@192.168.1.254 "ls"

# Error: Channel open failure
```

### Verificación

```bash
# ¿Shell del usuario está correcto?
ssh root@192.168.1.254 "echo $SHELL"

# ¿Hay scripts en .bashrc que cierren sesión?
ssh root@192.168.1.254 "cat ~/.bashrc"
```

### Solución

```bash
# Revisar /root/.bashrc y /root/.bash_profile
ssh root@192.168.1.254 "nano ~/.bashrc"

# Comentar líneas que causen problemas
# Ejemplo: exit al final del archivo

# Reintentar
ssh root@192.168.1.254 "ls"
```

---

## **Problema: SCP/SFTP no funciona**

```bash
# Copiar archivo
scp myfile.txt root@192.168.1.254:/tmp/

# Error: command not found: scp
```

### Solución

```bash
# Instalar OpenSSH server completo
ssh root@192.168.1.254 "sudo apt install -y openssh-server openssh-client"

# Reiniciar SSH
ssh root@192.168.1.254 "sudo systemctl restart ssh"

# Probar
scp myfile.txt root@192.168.1.254:/tmp/
```

---

## **Problema: "Agent admitted failure"**

SSH agent issues.

```bash
# Solución
eval $(ssh-agent -s)
ssh-add ~/.ssh/id_rsa

# Probar
ssh root@192.168.1.254 "hostname"
```

---

## **SSH Config Avanzado (Opcional)**

Crear alias para conectar más fácil.

```bash
# En tu PC, crear/editar ~/.ssh/config
cat > ~/.ssh/config << 'EOF'
Host master
  HostName 192.168.1.254
  User root
  IdentityFile ~/.ssh/id_rsa
  StrictHostKeyChecking no

Host worker
  HostName 192.168.1.250
  User pi
  IdentityFile ~/.ssh/id_rsa
  StrictHostKeyChecking no

Host *
  ServerAliveInterval 60
  ServerAliveCountMax 5
EOF

# Permisos
chmod 600 ~/.ssh/config

# Usar alias
ssh master          # En lugar de ssh root@192.168.1.254
ssh worker          # En lugar de ssh pi@192.168.1.250
scp myfile master:/tmp/  # Copiar archivos
```

---

## **Ver Logs de SSH**

```bash
# En servidor
sudo journalctl -u ssh.service -f

# O
tail -f /var/log/auth.log

# En cliente (con -v para verbose)
ssh -v root@192.168.1.254
ssh -vv root@192.168.1.254  # Más detalle
ssh -vvv root@192.168.1.254  # Muy detallado
```

---

## **Checklist de Troubleshooting SSH**

1. ✅ SSH servicio corriendo: `systemctl status ssh`
2. ✅ Puerto 22 activo: `ss -tlnp | grep 22`
3. ✅ Conectividad de red: `ping 192.168.1.254`
4. ✅ Credenciales correctas: `ssh -i ~/.ssh/id_rsa`
5. ✅ Permisos de key: `ls -la ~/.ssh/id_rsa*` (600)
6. ✅ Permisos de authorized_keys: `chmod 600 ~/.ssh/authorized_keys`
7. ✅ Public key en servidor: `cat ~/.ssh/authorized_keys`
8. ✅ Resolver DNS: `nslookup 192.168.1.254`
9. ✅ Firewall permitiendo puerto 22
10. ✅ Logs sin errores: `journalctl -u ssh.service -n 50`

---

## 📖 Siguiente

Lee: `../troubleshooting/CLUSTER-ISSUES.md` para problemas generales del cluster.

