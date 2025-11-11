# 🔑 Configuración de SSH Keys

Guía para configurar acceso seguro sin contraseña.

---

## **Generar Keys en tu PC (Windows)**

Usa PowerShell como Administrator:

```powershell
# Crear directorio si no existe
if (!(Test-Path "$env:USERPROFILE\.ssh")) {
    New-Item -ItemType Directory -Path "$env:USERPROFILE\.ssh" -Force
}

# Generar par de keys
ssh-keygen -t rsa -b 4096 -f "$env:USERPROFILE\.ssh\id_rsa" -N '""'

# Resultado:
# Your public key has been saved in C:\Users\..\.ssh\id_rsa.pub
# Your private key has been saved in C:\Users\..\.ssh\id_rsa

# Verificar
dir $env:USERPROFILE\.ssh\
```

---

## **Copiar Key al Master (Orange Pi)**

```powershell
# Copiar public key
Get-Content "$env:USERPROFILE\.ssh\id_rsa.pub" | ssh root@192.168.1.254 `
  "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && chmod 700 ~/.ssh"

# Si pide contraseña, escribir la del root de Orange Pi
```

---

## **Copiar Key al Worker (Raspberry Pi)**

```powershell
# Copiar public key
Get-Content "$env:USERPROFILE\.ssh\id_rsa.pub" | ssh pi@192.168.1.250 `
  "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && chmod 700 ~/.ssh"

# Si pide contraseña, escribir la del usuario 'pi'
```

---

## **Verificar Configuración**

```powershell
# Master (sin contraseña)
ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no root@192.168.1.254 "hostname"
# Debería responder: orangepi5

# Worker (sin contraseña)
ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no pi@192.168.1.250 "hostname"
# Debería responder: rpi-worker
```

---

## **Crear Alias en PowerShell (Opcional)**

Edita tu perfil PowerShell:

```powershell
# Abrir
notepad $env:USERPROFILE\Documents\PowerShell\profile.ps1

# Agregar:
function m { ssh -o StrictHostKeyChecking=no root@192.168.1.254 }
function w { ssh -o StrictHostKeyChecking=no pi@192.168.1.250 }
function k { ssh -o StrictHostKeyChecking=no root@192.168.1.254 kubectl }

# Luego usar como:
# m              → Conecta a master
# w              → Conecta a worker
# k get nodes    → Ejecuta kubectl en master
```

---

## **Si Falla**

### "Permission denied (publickey)"

```bash
# En el dispositivo (master o worker), verificar:
ls -la ~/.ssh/
cat ~/.ssh/authorized_keys

# Permisos deben ser:
# ~/.ssh     → 700
# authorized_keys → 600
```

### "Could not resolve hostname"

Verificar conectividad:

```powershell
ping 192.168.1.254  # master
ping 192.168.1.250  # worker
```

### "Connection refused"

SSH no está activo. En los dispositivos:

```bash
# Ver estado
sudo systemctl status ssh

# Iniciar
sudo systemctl start ssh
sudo systemctl enable ssh
```

---

## **Seguridad**

⚠️ **IMPORTANTE**: Tu clave privada (`id_rsa`) es como la contraseña del banco.

- ✅ Nunca la compartas
- ✅ Copia de seguridad en lugar seguro
- ✅ Permisos 600 en todos lados
- ✅ Si la comprometes, regenera

---

## 📖 Siguiente

Lee: `../getting-started/01-INICIO.md` para volver al resumen rápido.

