# 🔄 Script para Separar Backend y App en Repos Independientes
# Separa asistencias_app del directorio backend de forma segura

param(
    [string]$AppDestination = "C:\Users\Luis\asistencias-app",
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
Write-Host "🔄 Iniciando separación de proyectos..." -ForegroundColor Cyan
Write-Host ""

# Verificar que estamos en el directorio correcto
$currentDir = Get-Location
if ($currentDir.Path -notlike "*asistencias-backend*") {
    Write-Host "❌ Error: Debes ejecutar este script desde asistencias-backend" -ForegroundColor Red
    exit 1
}

# Verificar que existe el directorio de la app
$appSource = Join-Path $currentDir "asistencias_app"
if (-not (Test-Path $appSource)) {
    Write-Host "❌ Error: No se encontró el directorio asistencias_app" -ForegroundColor Red
    exit 1
}

Write-Host "📂 Configuración:" -ForegroundColor Yellow
Write-Host "   Origen: $appSource" -ForegroundColor Gray
Write-Host "   Destino: $AppDestination" -ForegroundColor Gray
Write-Host ""

# Verificar si el destino ya existe
if (Test-Path $AppDestination) {
    Write-Host "⚠️  El directorio destino ya existe: $AppDestination" -ForegroundColor Yellow
    $response = Read-Host "¿Deseas sobrescribirlo? (s/n)"
    if ($response -ne "s" -and $response -ne "S") {
        Write-Host "❌ Operación cancelada" -ForegroundColor Red
        exit 0
    }
    if (-not $WhatIf) {
        Remove-Item $AppDestination -Recurse -Force
    }
}

if ($WhatIf) {
    Write-Host "🔍 MODO SIMULACIÓN - No se harán cambios reales" -ForegroundColor Yellow
    Write-Host ""
}

# Paso 1: Limpiar la app antes de mover
Write-Host "📱 Paso 1: Limpiando Flutter App..." -ForegroundColor Green
if (-not $WhatIf) {
    Push-Location $appSource
    
    Write-Host "   Ejecutando flutter clean..." -ForegroundColor Gray
    flutter clean 2>&1 | Out-Null
    
    Write-Host "   Eliminando archivos temporales..." -ForegroundColor Gray
    if (Test-Path ".dart_tool") { Remove-Item ".dart_tool" -Recurse -Force -ErrorAction SilentlyContinue }
    if (Test-Path "build") { Remove-Item "build" -Recurse -Force -ErrorAction SilentlyContinue }
    if (Test-Path ".idea") { Remove-Item ".idea" -Recurse -Force -ErrorAction SilentlyContinue }
    if (Test-Path "temp_classroom.dart") { Remove-Item "temp_classroom.dart" -Force -ErrorAction SilentlyContinue }
    
    Pop-Location
    Write-Host "   ✅ Limpieza completada" -ForegroundColor Green
} else {
    Write-Host "   [SIMULACIÓN] Limpiaría flutter app" -ForegroundColor Yellow
}
Write-Host ""

# Paso 2: Copiar app al nuevo directorio
Write-Host "📦 Paso 2: Copiando App al nuevo directorio..." -ForegroundColor Green
if (-not $WhatIf) {
    Write-Host "   Copiando archivos..." -ForegroundColor Gray
    Copy-Item -Path $appSource -Destination $AppDestination -Recurse -Force
    Write-Host "   ✅ App copiada exitosamente" -ForegroundColor Green
} else {
    Write-Host "   [SIMULACIÓN] Copiaría app a: $AppDestination" -ForegroundColor Yellow
}
Write-Host ""

# Paso 3: Crear .gitignore específico para la app
Write-Host "📝 Paso 3: Creando .gitignore para Flutter App..." -ForegroundColor Green
$appGitignore = @"
# Flutter/Dart
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
.pub-cache/
.pub/
build/
.metadata

# Android
**/android/**/gradle-wrapper.jar
**/android/.gradle
**/android/captures/
**/android/gradlew
**/android/gradlew.bat
**/android/local.properties
**/android/**/GeneratedPluginRegistrant.java
**/android/key.properties
*.jks
*.keystore

# iOS
**/ios/**/*.mode1v3
**/ios/**/*.mode2v3
**/ios/**/*.moved-aside
**/ios/**/*.pbxuser
**/ios/**/*.perspectivev3
**/ios/**/*sync/
**/ios/**/.sconsign.dblite
**/ios/**/.tags*
**/ios/**/.vagrant/
**/ios/**/DerivedData/
**/ios/**/Icon?
**/ios/**/Pods/
**/ios/**/.symlinks/
**/ios/**/profile
**/ios/**/xcuserdata
**/ios/.generated/
**/ios/Flutter/App.framework
**/ios/Flutter/Flutter.framework
**/ios/Flutter/Flutter.podspec
**/ios/Flutter/Generated.xcconfig
**/ios/Flutter/ephemeral
**/ios/Flutter/app.flx
**/ios/Flutter/app.zip
**/ios/Flutter/flutter_assets/
**/ios/Flutter/flutter_export_environment.sh
**/ios/ServiceDefinitions.json
**/ios/Runner/GeneratedPluginRegistrant.*

# Firebase
google-services.json
GoogleService-Info.plist
firebase.json
.firebaserc

# Environment
.env
.env.local
.env.production

# IDE
.vscode/
.idea/
*.iml
*.iws
*.ipr
.DS_Store

# Logs
*.log

# Temporales
temp_*
*.tmp
"@

if (-not $WhatIf) {
    $appGitignore | Out-File -FilePath (Join-Path $AppDestination ".gitignore") -Encoding utf8 -Force
    Write-Host "   ✅ .gitignore creado" -ForegroundColor Green
} else {
    Write-Host "   [SIMULACIÓN] Crearía .gitignore en la app" -ForegroundColor Yellow
}
Write-Host ""

# Paso 4: Crear README.md para la app
Write-Host "📄 Paso 4: Creando README.md para la App..." -ForegroundColor Green
$appReadme = @"
# 📱 Sistema de Asistencias - App Móvil

Aplicación móvil multiplataforma desarrollada con **Flutter** para el control de asistencias escolares.

## 🚀 Características

- 📸 Escaneo de códigos QR para registro rápido
- 👥 Gestión de estudiantes por aula
- 📊 Estadísticas en tiempo real
- 🎨 Material Design 3
- 🔐 Autenticación con Firebase
- 📱 Responsive y adaptable

## 🔧 Requisitos

- Flutter SDK 3.24+
- Dart 3.5+
- Android Studio / VS Code
- Firebase CLI (para configuración)

## ⚙️ Instalación

\`\`\`bash
# Clonar el repositorio
git clone https://github.com/tu-usuario/asistencias-app.git
cd asistencias-app

# Instalar dependencias
flutter pub get

# Configurar Firebase
flutterfire configure

# Ejecutar en emulador/dispositivo
flutter run
\`\`\`

## 📦 Dependencias Principales

- **provider** - State management
- **firebase_auth** - Autenticación
- **cloud_firestore** - Base de datos
- **go_router** - Navegación
- **qr_flutter** - Generación QR
- **mobile_scanner** - Escaneo QR
- **cached_network_image** - Imágenes optimizadas

## 🏗️ Estructura del Proyecto

\`\`\`
lib/
├── models/          # Modelos de datos
├── providers/       # State management
├── screens/         # Pantallas
│   ├── admin/       # Vistas de administrador
│   ├── teacher/     # Vistas de docente
│   └── auth/        # Autenticación
├── services/        # Servicios Firebase
├── widgets/         # Componentes reutilizables
├── theme/           # Tema y estilos
└── routes/          # Configuración de rutas
\`\`\`

## 🔐 Configuración de Firebase

1. Crear proyecto en [Firebase Console](https://console.firebase.google.com)
2. Descargar \`google-services.json\` (Android) y colocar en \`android/app/\`
3. Descargar \`GoogleService-Info.plist\` (iOS) y colocar en \`ios/Runner/\`
4. Ejecutar: \`flutterfire configure\`

## 🚀 Build y Deploy

\`\`\`bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS (requiere macOS)
flutter build ios --release
\`\`\`

## 🔗 Backend

El backend con Firebase Functions está en: [asistencias-backend](https://github.com/tu-usuario/asistencias-backend)

## 📝 Licencia

[Especifica tu licencia aquí]

---

**Desarrollado con 💙 usando Flutter**
"@

if (-not $WhatIf) {
    $appReadme | Out-File -FilePath (Join-Path $AppDestination "README.md") -Encoding utf8 -Force
    Write-Host "   ✅ README.md creado" -ForegroundColor Green
} else {
    Write-Host "   [SIMULACIÓN] Crearía README.md en la app" -ForegroundColor Yellow
}
Write-Host ""

# Paso 5: Eliminar app del directorio backend (OPCIONAL)
Write-Host "🗑️  Paso 5: Eliminar app del directorio backend..." -ForegroundColor Yellow
Write-Host "   ⚠️  Esto eliminará asistencias_app/ del directorio backend" -ForegroundColor Yellow
if (-not $WhatIf) {
    $response = Read-Host "   ¿Deseas eliminar asistencias_app/ del backend? (s/n)"
    if ($response -eq "s" -or $response -eq "S") {
        Remove-Item $appSource -Recurse -Force
        Write-Host "   ✅ App eliminada del backend" -ForegroundColor Green
    } else {
        Write-Host "   ⏭️  App mantenida en backend (puedes eliminarla manualmente)" -ForegroundColor Gray
    }
} else {
    Write-Host "   [SIMULACIÓN] Preguntaría si eliminar del backend" -ForegroundColor Yellow
}
Write-Host ""

# Resumen
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
if ($WhatIf) {
    Write-Host "✅ Simulación completada" -ForegroundColor Green
    Write-Host "   Ejecuta sin -WhatIf para aplicar cambios reales" -ForegroundColor Yellow
} else {
    Write-Host "✅ Separación completada exitosamente!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 Resultado:" -ForegroundColor Cyan
    Write-Host "   Backend: $currentDir" -ForegroundColor White
    Write-Host "   App Flutter: $AppDestination" -ForegroundColor White
    Write-Host ""
    Write-Host "🔄 Próximos pasos:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   📦 Para el BACKEND:" -ForegroundColor Yellow
    Write-Host "   1. cd '$currentDir'" -ForegroundColor Gray
    Write-Host "   2. git init" -ForegroundColor Gray
    Write-Host "   3. git add ." -ForegroundColor Gray
    Write-Host "   4. git commit -m 'Initial commit: Backend'" -ForegroundColor Gray
    Write-Host "   5. Crear repo en GitHub y hacer push" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   📱 Para la APP:" -ForegroundColor Yellow
    Write-Host "   1. cd '$AppDestination'" -ForegroundColor Gray
    Write-Host "   2. flutter pub get" -ForegroundColor Gray
    Write-Host "   3. git init" -ForegroundColor Gray
    Write-Host "   4. git add ." -ForegroundColor Gray
    Write-Host "   5. git commit -m 'Initial commit: Flutter App'" -ForegroundColor Gray
    Write-Host "   6. Crear repo en GitHub y hacer push" -ForegroundColor Gray
}
Write-Host ""
