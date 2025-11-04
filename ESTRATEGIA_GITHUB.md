# 🏗️ Estrategia de Repositorios GitHub

## 🎯 Recomendación: 2 Repositorios Separados

### Por qué separar:
1. ✅ Versionado independiente (Backend v1.2.0, App v2.3.1)
2. ✅ CI/CD más eficiente (no compila Flutter en cada cambio de backend)
3. ✅ Permisos granulares (frontend público, backend privado)
4. ✅ Clones más rápidos
5. ✅ Facilita Open Source (puedes hacer público solo el frontend)

---

## 📦 Repo 1: Backend (asistencias-backend)

### Contenido:
```
asistencias-backend/
├── functions/                 # Firebase Functions
│   ├── src/
│   ├── package.json
│   └── tsconfig.json
├── firestore.rules           # Reglas de seguridad
├── firestore.indexes.json    # Índices
├── firebase.json             # Config Firebase
├── .firebaserc               # Proyectos Firebase
├── .gitignore
└── README.md
```

### README.md debe incluir:
- 🔧 Configuración de Firebase Functions
- 📡 Documentación de API endpoints
- 🔐 Guía de autenticación y roles
- 🚀 Instrucciones de deploy
- 🔗 Link al repo de la app móvil

### Comandos para crear:
```bash
cd C:\Users\Luis\asistencias-backend

# Inicializar Git
git init
git add .
git commit -m "Initial commit: Firebase backend"

# Crear repo en GitHub y conectar
git remote add origin https://github.com/tu-usuario/asistencias-backend.git
git branch -M main
git push -u origin main
```

---

## 📱 Repo 2: App Flutter (asistencias-app)

### Contenido:
```
asistencias-app/
├── lib/                      # Código fuente
│   ├── models/
│   ├── providers/
│   ├── screens/
│   ├── services/
│   └── widgets/
├── assets/                   # Recursos
├── android/                  # Config Android
├── ios/                      # Config iOS
├── pubspec.yaml              # Dependencias
├── .gitignore
└── README.md
```

### README.md debe incluir:
- 📱 Setup de Flutter
- 🔥 Configuración de Firebase
- 📸 Screenshots de la app
- 🚀 Cómo compilar y ejecutar
- 🔗 Link al repo del backend

### Comandos para crear:
```bash
cd C:\Users\Luis\asistencias-backend\asistencias_app

# Inicializar Git (nuevo repo)
git init
git add .
git commit -m "Initial commit: Flutter app"

# Crear repo en GitHub y conectar
git remote add origin https://github.com/tu-usuario/asistencias-app.git
git branch -M main
git push -u origin main
```

---

## 🔗 Vincular los Repos

### En backend README.md:
```markdown
## 📱 App Móvil
La aplicación móvil está en: [asistencias-app](https://github.com/tu-usuario/asistencias-app)
```

### En app README.md:
```markdown
## 🔧 Backend
El backend con Firebase Functions está en: [asistencias-backend](https://github.com/tu-usuario/asistencias-backend)
```

---

## 📋 Checklist para Backend

Antes de hacer push:

- [ ] Ejecutar `.\limpiar-github.ps1`
- [ ] Verificar que no haya archivos de la app (`asistencias_app/` debe estar fuera)
- [ ] Verificar `.gitignore`:
  ```gitignore
  # Functions
  functions/node_modules/
  functions/lib/
  functions/.env
  functions/.env.local
  functions/.env.production
  
  # Logs
  *.log
  
  # IDE
  .vscode/
  .idea/
  ```
- [ ] README.md actualizado
- [ ] Sin credenciales sensibles

### Estructura final del backend:
```
asistencias-backend/
├── functions/
├── firestore.rules
├── firestore.indexes.json
├── firebase.json
├── .firebaserc
├── .gitignore
├── README.md
└── (documentación .md si es necesaria)
```

---

## 📋 Checklist para App

Antes de hacer push:

- [ ] Ejecutar `flutter clean`
- [ ] Eliminar `.dart_tool/` y `build/`
- [ ] Verificar `.gitignore`:
  ```gitignore
  # Flutter
  .dart_tool/
  .flutter-plugins
  .flutter-plugins-dependencies
  .packages
  build/
  
  # Android
  **/android/**/gradle-wrapper.jar
  **/android/.gradle
  **/android/captures/
  **/android/local.properties
  **/android/**/GeneratedPluginRegistrant.java
  **/android/key.properties
  *.jks
  
  # iOS
  **/ios/**/*.mode1v3
  **/ios/**/*.mode2v3
  **/ios/**/*.moved-aside
  **/ios/**/*.pbxuser
  **/ios/**/*.perspectivev3
  **/ios/Pods/
  **/ios/.symlinks/
  **/ios/Flutter/App.framework
  **/ios/Flutter/Flutter.framework
  **/ios/Flutter/Flutter.podspec
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
  
  # IDE
  .vscode/
  .idea/
  *.iml
  ```
- [ ] README.md con screenshots
- [ ] Sin `google-services.json` ni `GoogleService-Info.plist`

---

## 🎨 Nombres Sugeridos para los Repos

### Opción 1: Descriptiva
- `asistencias-backend` / `asistencias-app`
- `school-attendance-backend` / `school-attendance-app`

### Opción 2: Organizada
- `asistencias-api` / `asistencias-mobile`
- `attendance-api` / `attendance-mobile`

### Opción 3: Corta
- `asistencias-server` / `asistencias-client`

---

## 🚀 Pasos Finales

### 1. Preparar Backend
```powershell
cd C:\Users\Luis\asistencias-backend
.\limpiar-github.ps1
# Mover asistencias_app FUERA de este directorio
Move-Item asistencias_app C:\Users\Luis\asistencias-app
```

### 2. Crear Repo Backend
```bash
cd C:\Users\Luis\asistencias-backend
git init
git add .
git commit -m "Initial commit: Backend con Firebase Functions"
# Crear repo en GitHub primero
git remote add origin https://github.com/tu-usuario/asistencias-backend.git
git push -u origin main
```

### 3. Crear Repo App
```bash
cd C:\Users\Luis\asistencias-app
flutter clean
git init
git add .
git commit -m "Initial commit: App Flutter"
# Crear repo en GitHub primero
git remote add origin https://github.com/tu-usuario/asistencias-app.git
git push -u origin main
```

---

## ✅ Resultado Final

```
GitHub.com/tu-usuario/
├── 📦 asistencias-backend (~100MB)
│   └── Firebase Functions, Firestore rules, API docs
│
└── 📱 asistencias-app (~500MB)
    └── Flutter app, screens, widgets, assets
```

**Ventajas:**
- ✅ Repositorios limpios y enfocados
- ✅ Fácil de mantener y contribuir
- ✅ CI/CD optimizado
- ✅ Permisos flexibles

---

**¿Necesitas ayuda para configurar alguno de los repos?** 🚀
