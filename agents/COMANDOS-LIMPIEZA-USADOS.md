# 🗑️ COMANDOS EXACTOS DE LIMPIEZA USADOS

Aquí están los comandos PowerShell exactos que se ejecutaron para limpiar la documentación vieja:

---

## PASO 1: Eliminar archivos de raíz

```powershell
cd "D:\Repository\Personales\mini-cluster"

Remove-Item -Path "DIAGNOSE-K3S-ISSUES.sh", "MIGRATION-SUMMARY.md", "prepare-migration-simple.ps1", "prepare-migration.ps1", "prepare-migration.sh", "RUN-MIGRATION.sh" -Force -ErrorAction SilentlyContinue

Write-Host "✅ Archivos raiz eliminados" -ForegroundColor Green
```

---

## PASO 2: Eliminar carpeta docs/ (vieja)

```powershell
cd "D:\Repository\Personales\mini-cluster"

Remove-Item -Path "docs" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "✅ Carpeta docs/ eliminada" -ForegroundColor Green
```

---

## PASO 3: Eliminar scripts antiguos en scripts/install/

```powershell
cd "D:\Repository\Personales\mini-cluster\scripts\install"

Remove-Item -Path "01-cleanup-kubeadm-master.sh", "02-cleanup-kubeadm-worker.sh" -Force -ErrorAction SilentlyContinue

Write-Host "✅ Scripts antiguos en scripts/install/ eliminados" -ForegroundColor Green
```

---

## PASO 4: Eliminar carpetas de recovery/maintenance/network

```powershell
cd "D:\Repository\Personales\mini-cluster\scripts"

Remove-Item -Path "recovery", "maintenance", "network" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "✅ Carpetas recovery/maintenance/network eliminadas" -ForegroundColor Green
```

---

## PASO 5: Eliminar scripts viejos restantes en scripts/install/

```powershell
cd "D:\Repository\Personales\mini-cluster\scripts\install"

Remove-Item -Path "03-install-k3s-master.sh", "04-install-k3s-agent.sh", "install-k3s.sh", "migrate-to-k3s-master.sh", "migrate-to-k3s.sh" -Force -ErrorAction SilentlyContinue

Write-Host "✅ Scripts viejos eliminados" -ForegroundColor Green

Get-ChildItem -File | ForEach-Object { Write-Host "  ✓ $($_.Name)" -ForegroundColor Yellow }
```

---

## ALTERNATIVA: Un Comando para Todo

```powershell
# Copiar y pegar TODO esto en PowerShell de una vez:

cd "D:\Repository\Personales\mini-cluster"

# Eliminar archivos raíz
Remove-Item -Path "DIAGNOSE-K3S-ISSUES.sh", "MIGRATION-SUMMARY.md", "prepare-migration-simple.ps1", "prepare-migration.ps1", "prepare-migration.sh", "RUN-MIGRATION.sh" -Force -ErrorAction SilentlyContinue

# Eliminar carpeta docs/
Remove-Item -Path "docs" -Recurse -Force -ErrorAction SilentlyContinue

# Eliminar scripts antiguos en install/
Remove-Item -Path "scripts/install/01-cleanup-kubeadm-master.sh", "scripts/install/02-cleanup-kubeadm-worker.sh", "scripts/install/03-install-k3s-master.sh", "scripts/install/04-install-k3s-agent.sh", "scripts/install/install-k3s.sh", "scripts/install/migrate-to-k3s-master.sh", "scripts/install/migrate-to-k3s.sh" -Force -ErrorAction SilentlyContinue

# Eliminar carpetas
Remove-Item -Path "scripts/recovery", "scripts/maintenance", "scripts/network" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "✅ LIMPIEZA COMPLETADA" -ForegroundColor Green
```

---

## Archivos Exactos Eliminados

### Raíz del Proyecto (6 archivos)
- DIAGNOSE-K3S-ISSUES.sh
- MIGRATION-SUMMARY.md
- prepare-migration-simple.ps1
- prepare-migration.ps1
- prepare-migration.sh
- RUN-MIGRATION.sh

### Carpetas Completas (4)
- docs/ (toda la carpeta)
- scripts/recovery/
- scripts/maintenance/
- scripts/network/

### Scripts en scripts/install/ (7 archivos)
- 01-cleanup-kubeadm-master.sh
- 02-cleanup-kubeadm-worker.sh
- 03-install-k3s-master.sh
- 04-install-k3s-agent.sh
- install-k3s.sh
- migrate-to-k3s-master.sh
- migrate-to-k3s.sh

**Total**: ~20 archivos/carpetas eliminados

---

## Resultado Final

✅ **3 scripts limpios en scripts/install/**
- INSTALL-K3S-MASTER-CLEAN.sh
- INSTALL-K3S-WORKER-CLEAN.sh
- VALIDATE-K3S-CLUSTER.sh

✅ **18 documentos limpios en docs-clean/**
- 4 en getting-started/
- 5 en technical/
- 4 en troubleshooting/
- 4 en deployment/
- INDEX.md

✅ **Cero información desactualizada**
- Sin riesgo de alucinaciones de LLMs
- Un único punto de verdad
- Proyecto 100% limpio

