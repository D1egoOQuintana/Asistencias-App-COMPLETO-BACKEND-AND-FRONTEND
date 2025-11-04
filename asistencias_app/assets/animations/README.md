# 🎨 Animaciones Rive para Login

## 📁 Archivos necesarios

Coloca aquí los archivos `.riv` exportados desde Rive Editor:

- `bubbles_cool.riv` - Modo Docente (tonos fríos: azul, violeta, celeste, rosado)
- `bubbles_warm.riv` - Modo Admin (tonos grises: plomo y gris)

## 🚀 Cómo crear las animaciones en Rive

### 1️⃣ Accede a Rive Editor
- Ve a [rive.app](https://rive.app)
- Crea una cuenta gratuita
- Crea un **New File**

### 2️⃣ Configuración del artboard
- Tamaño: **375 x 812** (o 360 x 800)
- Fondo: Transparente (el gradiente lo maneja Flutter)

### 3️⃣ Crear burbujas para Modo Docente

**Burbuja 1 - Azul:**
- Herramienta **Ellipse** (círculo perfecto)
- Tamaño: ~120-180px
- Fill: **Radial Gradient**
  - Centro: `#2196F3` (azul vibrante) - Opacity 40%
  - Exterior: `#64B5F6` (azul claro) - Opacity 10%
- Inner Shadow: Blur 30px, Color blanco 10% opacity

**Burbuja 2 - Violeta:**
- Fill: Radial Gradient
  - Centro: `#9C27B0` - Opacity 40%
  - Exterior: `#BA68C8` - Opacity 10%

**Burbuja 3 - Celeste:**
- Fill: Radial Gradient
  - Centro: `#00BCD4` - Opacity 40%
  - Exterior: `#4DD0E1` - Opacity 10%

**Burbuja 4 - Rosado:**
- Fill: Radial Gradient
  - Centro: `#E91E63` - Opacity 40%
  - Exterior: `#F06292` - Opacity 10%

**Duplica y varía:** Crea 8 burbujas en total con tamaños variados (60-180px)

### 4️⃣ Animar las burbujas

**State Machine:**
- Crea nueva **State Machine** llamada `"bubbles_animation"`
- Añade **Entry → Any State → Loop**

**Para cada burbuja:**
1. Crea **Timeline Animation** (duración 8-12 segundos)
2. Anima **Transform → Position**:
   - Keyframe 0s: Posición inicial (distribúyelas por todo el canvas)
   - Keyframe 4s: Mover en X (-50 a +50) y Y (-30 a +30)
   - Keyframe 8s: Volver cerca de origen (pero no igual)
3. Anima **Transform → Scale**:
   - Keyframe 0s: Scale 1.0
   - Keyframe 4s: Scale 0.85 o 1.15 (varía entre burbujas)
   - Keyframe 8s: Scale 1.0
4. Selecciona todos los keyframes → **Ease In-Out**
5. Marca la animación como **Loop**

**Variación entre burbujas:**
- Diferentes duraciones (8s, 10s, 12s)
- Diferentes direcciones de movimiento
- Diferentes escalas máximas (0.85-1.15)
- Diferentes opacidades (30-50%)

### 5️⃣ Exportar Modo Docente
- File → Export → **Runtime (.riv)**
- Nombre: `bubbles_cool.riv`
- Guarda en esta carpeta

### 6️⃣ Crear Modo Admin (gris)

**Duplica el archivo** y cambia los colores:

**Burbuja 1 - Gris azulado:**
- Centro: `#607D8B` - Opacity 40%
- Exterior: `#78909C` - Opacity 10%

**Burbuja 2 - Gris medio:**
- Centro: `#546E7A` - Opacity 40%
- Exterior: `#78909C` - Opacity 10%

**Burbuja 3 - Gris oscuro:**
- Centro: `#455A64` - Opacity 40%
- Exterior: `#607D8B` - Opacity 10%

**Burbuja 4 - Gris profundo:**
- Centro: `#37474F` - Opacity 40%
- Exterior: `#546E7A` - Opacity 10%

### 7️⃣ Exportar Modo Admin
- File → Export → **Runtime (.riv)**
- Nombre: `bubbles_warm.riv`
- Guarda en esta carpeta

---

## 💡 Tips para mejor resultado

1. **Posicionamiento inicial:** Distribuye burbujas por todo el canvas (esquinas, centro, bordes)
2. **Movimiento natural:** Usa trayectorias curvas, no lineales
3. **Variación:** Cada burbuja debe tener timing diferente para evitar sincronización
4. **Blur sutil:** No exageres con blur, máximo 30-40px radius
5. **Opacidad baja:** Mantén 30-50% para que no tape el contenido

## 🧪 Probar animación

En Rive Editor:
- Presiona **Play** en el panel Animation
- Verifica que el loop funcione infinitamente
- Asegúrate que las burbujas no salgan del canvas

## ✅ Verificar en Flutter

Una vez exportados ambos archivos `.riv`, la app automáticamente los usará:
- Al abrir login → verás burbujas animadas
- Al cambiar de "Docente" a "Admin" → cambiarán los colores con transición suave

---

## 🎯 Alternativa: Usar animación nativa de Flutter

Si no quieres usar Rive, **ya tienes una implementación nativa** en:
- `lib/widgets/animated_background.dart`

Esta implementación **no requiere archivos .riv** y funciona idéntico, solo usa Flutter puro.
Para activarla, simplemente no agregues los archivos .riv y el código seguirá usando la versión Flutter nativa.

---

**Creado el:** 28 de octubre de 2025
