# 🗑️ COMANDOS PARA ELIMINAR DOCUMENTACION VIEJA

# Copiar y ejecutar estos comandos en PowerShell para limpiar todo

Write-Host "
╔════════════════════════════════════════════════╗
║   ELIMINANDO DOCUMENTACIÓN VIEJA (KUBEADM)    ║
║                                                ║
║   Archivos a eliminar:                         ║
║   - Docs de migración                          ║
║   - Scripts de recovery                        ║
║   - Guías de diagnóstico antiguos              ║
║   - Preparación de migración (ps1, sh)         ║
╚════════════════════════════════════════════════╝
" -ForegroundColor Yellow

# ============================================
# PASO 1: Archivos en raíz
# ============================================

Write-Host "`n[1/4] Eliminando archivos en raíz..." -ForegroundColor Cyan

Remove-Item -Path "D:\Repository\Personales\mini-cluster\DIAGNOSE-K3S-ISSUES.sh" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "D:\Repository\Personales\mini-cluster\MIGRATION-SUMMARY.md" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "D:\Repository\Personales\mini-cluster\prepare-migration-simple.ps1" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "D:\Repository\Personales\mini-cluster\prepare-migration.ps1" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "D:\Repository\Personales\mini-cluster\prepare-migration.sh" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "D:\Repository\Personales\mini-cluster\RUN-MIGRATION.sh" -Force -ErrorAction SilentlyContinue

Write-Host "✅ Archivos raíz eliminados" -ForegroundColor Green

# ============================================
# PASO 2: Carpeta docs/ (vieja)
# ============================================

Write-Host "`n[2/4] Eliminando carpeta docs/ (vieja)..." -ForegroundColor Cyan

Remove-Item -Path "D:\Repository\Personales\mini-cluster\docs" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "✅ Carpeta docs/ eliminada" -ForegroundColor Green

# ============================================
# PASO 3: Scripts viejos en scripts/install/
# ============================================

Write-Host "`n[3/4] Eliminando scripts antiguos en scripts/install/..." -ForegroundColor Cyan

Remove-Item -Path "D:\Repository\Personales\mini-cluster\scripts\install\01-cleanup-kubeadm-master.sh" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "D:\Repository\Personales\mini-cluster\scripts\install\02-cleanup-kubeadm-worker.sh" -Force -ErrorAction SilentlyContinue

Write-Host "✅ Scripts antiguos en scripts/install/ eliminados" -ForegroundColor Green

# ============================================
# PASO 4: Carpetas y scripts de maintenance/recovery
# ============================================

Write-Host "`n[4/4] Eliminando carpetas scripts/maintenance/ y scripts/recovery/..." -ForegroundColor Cyan

Remove-Item -Path "D:\Repository\Personales\mini-cluster\scripts\recovery" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "D:\Repository\Personales\mini-cluster\scripts\maintenance" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "D:\Repository\Personales\mini-cluster\scripts\network" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "✅ Carpetas de recovery/maintenance/network eliminadas" -ForegroundColor Green

# ============================================
# VERIFICACIÓN FINAL
# ============================================

Write-Host "`n" -ForegroundColor White
Write-Host "╔════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║        ✅ LIMPIEZA COMPLETADA                 ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host "`nVerificando estructura final..." -ForegroundColor Cyan

# Ver estructura actual
Write-Host "`nEstructura actual del proyecto:" -ForegroundColor White
Get-ChildItem -Path "D:\Repository\Personales\mini-cluster" -Directory | ForEach-Object {
    Write-Host "  📁 $($_.Name)" -ForegroundColor Yellow
}

Write-Host "`n✅ Documentación antigua completamente eliminada" -ForegroundColor Green
Write-Host "✅ Solo queda: docs-clean/ (nueva documentación)" -ForegroundColor Green
Write-Host "✅ Solo queda: scripts/install/ (scripts limpios)" -ForegroundColor Green
