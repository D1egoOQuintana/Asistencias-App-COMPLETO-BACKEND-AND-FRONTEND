# 🧹 Script de Limpieza para GitHub
# Elimina archivos temporales y generados antes de subir a GitHub

param(
    [switch]$WhatIf,  # Mostrar qué se eliminará sin hacerlo
    [switch]$KeepPlatforms  # Mantener todas las plataformas Flutter
)

$ErrorActionPreference = "Continue"
Write-Host "🧹 Iniciando limpieza del proyecto..." -ForegroundColor Cyan
Write-Host ""

# Contadores
$deletedFiles = 0
$deletedDirs = 0
$savedSpace = 0

function Remove-SafeItem {
    param(
        [string]$Path,
        [string]$Description
    )
    
    if (Test-Path $Path) {
        $size = 0
        if (Test-Path $Path -PathType Container) {
            $size = (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | 
                     Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        } else {
            $size = (Get-Item $Path -Force -ErrorAction SilentlyContinue).Length
        }
        
        $sizeMB = [math]::Round($size / 1MB, 2)
        
        if ($WhatIf) {
            Write-Host "  [SIMULACIÓN] Eliminaría: $Description ($sizeMB MB)" -ForegroundColor Yellow
        } else {
            Write-Host "  ❌ Eliminando: $Description ($sizeMB MB)" -ForegroundColor Red
            Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
            
            if (Test-Path $Path -PathType Container) {
                $script:deletedDirs++
            } else {
                $script:deletedFiles++
            }
            $script:savedSpace += $size
        }
    }
}

Write-Host "📱 Limpiando Flutter App (asistencias_app)..." -ForegroundColor Green
Write-Host ""

# Flutter - Archivos generados
Remove-SafeItem "asistencias_app\.dart_tool" "Dart Tool Cache"
Remove-SafeItem "asistencias_app\build" "Build Output"
Remove-SafeItem "asistencias_app\.flutter-plugins-dependencies" "Flutter Plugins Dependencies"

# Flutter - Archivos temporales
Remove-SafeItem "asistencias_app\temp_classroom.dart" "Archivo temporal de prueba"

# Flutter - IDE
if (-not $KeepPlatforms) {
    Write-Host ""
    Write-Host "  ⚠️  Eliminando configuración de IDE..." -ForegroundColor Yellow
    Remove-SafeItem "asistencias_app\.idea" "IntelliJ IDEA Config"
}

# Flutter - Plataformas no usadas (si no se especifica -KeepPlatforms)
if (-not $KeepPlatforms) {
    Write-Host ""
    Write-Host "  ⚠️  Eliminando plataformas no usadas..." -ForegroundColor Yellow
    Write-Host "     (Usa -KeepPlatforms para mantenerlas)" -ForegroundColor Gray
    
    Remove-SafeItem "asistencias_app\linux" "Plataforma Linux"
    Remove-SafeItem "asistencias_app\macos" "Plataforma macOS"
    Remove-SafeItem "asistencias_app\web" "Plataforma Web"
    Remove-SafeItem "asistencias_app\windows" "Plataforma Windows"
}

Write-Host ""
Write-Host "🔧 Limpiando Backend (functions)..." -ForegroundColor Green
Write-Host ""

# Backend - Archivos generados
Remove-SafeItem "functions\node_modules" "Node Modules (npm install los regenera)"
Remove-SafeItem "functions\lib" "JavaScript compilado (npm run build lo regenera)"

# Backend - IDE
Remove-SafeItem "functions\.vscode" "VS Code Config"

Write-Host ""
Write-Host "📂 Limpiando Root..." -ForegroundColor Green
Write-Host ""

# Root - Backups y temporales
Remove-SafeItem "backup-archivos-eliminados" "Backup de archivos eliminados"

# Root - Documentación a consolidar
Write-Host "  ℹ️  Documentos por consolidar en README.md:" -ForegroundColor Cyan
Write-Host "     - ESTRUCTURA_MODULAR.md" -ForegroundColor Gray
Write-Host "     - FIREBASE_AUTH_GUIDE.md" -ForegroundColor Gray
Write-Host "     - SALONES_API_DOCS.md" -ForegroundColor Gray
Write-Host "     - TEST_CHANGES.md" -ForegroundColor Gray

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan

if ($WhatIf) {
    Write-Host ""
    Write-Host "✅ Simulación completada." -ForegroundColor Green
    Write-Host "   Ejecuta sin -WhatIf para aplicar los cambios." -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "✅ Limpieza completada!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 Resumen:" -ForegroundColor Cyan
    Write-Host "   Directorios eliminados: $deletedDirs" -ForegroundColor White
    Write-Host "   Archivos eliminados: $deletedFiles" -ForegroundColor White
    Write-Host "   Espacio liberado: $([math]::Round($savedSpace / 1MB, 2)) MB" -ForegroundColor White
    
    Write-Host ""
    Write-Host "🔄 Próximos pasos:" -ForegroundColor Cyan
    Write-Host "   1. cd functions && npm install && npm run build" -ForegroundColor Gray
    Write-Host "   2. cd asistencias_app && flutter pub get" -ForegroundColor Gray
    Write-Host "   3. Revisar y consolidar documentación .md en README.md" -ForegroundColor Gray
    Write-Host "   4. Verificar .gitignore actualizado" -ForegroundColor Gray
    Write-Host "   5. git add . && git commit -m 'Limpieza del proyecto'" -ForegroundColor Gray
}

Write-Host ""
