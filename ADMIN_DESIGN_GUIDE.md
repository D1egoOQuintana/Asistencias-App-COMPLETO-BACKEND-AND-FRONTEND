# ADMIN DESIGN GUIDE — Sistema Inteligente de Asistencia QR

> Guía visual fija para el **Admin Web Panel**. Toda fase futura (Sonnet u otro) debe
> respetar este documento. No rediseñar fuera de estas reglas sin actualizar la guía.

---

## 0. Regla principal (no negociable)

| Rol | Esqueleto | Naturaleza |
|---|---|---|
| **Docente** | Mono-columna táctil | App móvil (NO TOCAR) |
| **Admin** | Multi-columna web con **sidebar + topbar** | Panel institucional web |

> Comparten **piel** (color primario, tipografía manrope, radios, sombras suaves).
> NO comparten **esqueleto**. El admin nunca debe verse como una app móvil estirada.

**Prohibido en admin (es lenguaje móvil):** BottomNav como navegación principal en
desktop, botón QR circular gigante, layout de una sola columna centrada, header con
gradiente a pantalla completa, scroll vertical único como patrón base.

---

## 1. Dirección visual — "Institutional Light Workspace"

- **Sidebar** = ancla oscura navy `#0D1B2A`.
- **Lienzo de trabajo** = claro `#F4F6FA`.
- **Superficies** = cards blancas, sombra suave, radius 16.
- **Acento azul** = solo en datos accionables (selección, links, valores clave).
- **Densidad media-alta**: aprovechar el ancho con grids y tablas. Nada de gradientes
  en cards de datos.

---

## 2. Layout responsive

### Desktop (≥1200px)
```
┌────────────┬───────────────────────────────────────────────┐
│            │  TOPBAR (64px): título + subtítulo · 🔍 · 🔔 · 👤│
│  SIDEBAR   ├───────────────────────────────────────────────┤
│  240px     │  CONTENT (padding 32)                          │
│  navy      │  ┌────┬────┬────┬────┐  KPIs x4                │
│            │  └────┴────┴────┴────┘                         │
│  [perfil]  │  ┌──────────────┬──────────┐ tabla 60 / feed 40│
│  [logout]  │  └──────────────┴──────────┘                   │
└────────────┴───────────────────────────────────────────────┘
```

### Tablet (600–1199px)
```
┌──────┬──────────────────────────────────────┐
│ RAIL │  TOPBAR (56px): título · 🔔 · 👤      │
│ 72px ├──────────────────────────────────────┤
│ navy │  KPI 2x2 · tabla full · feed full     │
│ icons│  (rail custom navy, NO Material rail) │
└──────┴──────────────────────────────────────┘
```

### Mobile (<600px)
```
┌──────────────────────────────┐
│ APPBAR navy · título · 👤     │
│  KPI 2x2 · chips · feed       │
│  aulas → cards (no tabla)     │
│  BottomNav (5 ítems)          │
└──────────────────────────────┘
```

---

## 3. Espaciado (múltiplos de 8)

| Contexto | Valor |
|---|---|
| Padding contenido desktop / tablet / mobile | `32 / 24 / 16` |
| Gap entre KPIs | `16` |
| Gap entre secciones | `24` |
| Padding interno card | `20–24` |
| Topbar alto desktop / tablet | `64 / 56` |
| Sidebar expandido / rail compacto | `240 / 72` |

Ritmo vertical en múltiplos de 8. Migrar valores sueltos (11/14/18 → 12/16/20/24).

---

## 4. Tipografía (manrope)

| Rol | Size / Weight | Uso |
|---|---|---|
| Display | 28 / w800 | Saludo / títulos grandes |
| Title section | 18 / w700 | "Aulas registradas" |
| KPI value | 30 / w800 | El número |
| KPI label | 13 / w500 secondary | "Docentes" |
| Body | 14 / w500 | Filas de tabla |
| Caption | 12 / w500 secondary | Metadatos, horas |
| Overline | 11 / w600 / ls 0.8 | Etiquetas de estado / secciones nav |

Máximo **2 pesos por pantalla**. Texto: `#212121` primario / `#757575` secundario.

---

## 5. Paleta (Material 3 + institucional)

```
SIDEBAR / ANCLA
  navy surface        #0D1B2A
  navy hover          blanco @ 4–6% alpha (hover suave)
  navy text           #B0BEC5
  navy text active    #FFFFFF
  navy section label  #6B7A8D

PRIMARIO
  primary             #1976D2
  primary light       #42A5F5   (barra de selección sobre navy)
  primary container   #E3F0FC   (fills suaves)
  primary dark        #0D47A1

LIENZO / SUPERFICIES
  canvas              #F4F6FA
  surface card        #FFFFFF
  border / divider    #E6EAF0

SEMÁNTICOS
  success  #2E7D32 / cont #E6F4EA
  warning  #F57C00 / cont #FFF3E0
  error    #C62828 / cont #FDECEA
  info     #1565C0 / cont #E3F0FC
```

Cada KPI usa su color **solo en ícono y valor**; fondo siempre blanco.

---

## 6. Sidebar

- Fondo navy `#0D1B2A`. Ancho 240 (expandido) / 72 (compacto).
- **Selección:** pill suave (`primary @ 16% alpha`) + **barra lateral izquierda 3px**
  en `#42A5F5`. Texto blanco. NO fill sólido duro.
- **Hover:** blanco @ 4–6% alpha (suave).
- Ítem: ícono 20 + label 13.5 (w600 activo / w500 inactivo).
- **Agrupación por secciones** con micro-encabezados overline:
  - **PRINCIPAL** → Dashboard
  - **GESTIÓN** → Docentes · Estudiantes · Aulas
  - **OPERACIÓN** → Sesiones · Reportes · Incidencias
  - **SISTEMA** → Configuración
- En compacto: secciones separadas por divisor fino, no por texto.
- **Footer:** bloque de perfil (avatar + nombre + rol) arriba de un divisor, y debajo
  el botón **Cerrar sesión** (rojo, siempre visible).
- Módulos no implementados muestran badge **"Pronto"**.

---

## 7. Topbar (desktop / tablet)

- Fondo blanco, borde inferior `#E6EAF0`. Alto 64 (desktop) / 56 (tablet).
- **Izquierda:** título de la sección actual (18 w700) + subtítulo corto (12 secondary).
- **Centro/derecha:** caja de búsqueda visual (fondo `#F4F6FA`, radius full, ícono
  search + hint "Buscar…"). En tablet puede colapsar a ícono.
- **Derecha:** ícono de notificaciones con punto rojo + avatar de perfil con iniciales.
- El contenido scrollea bajo el topbar; el topbar permanece fijo.

---

## 8. Cards KPI

```
┌─────────────────────────┐
│ [ícono 40, fill color12] │
│  248            ▲ +12%   │ ← valor 30/w800 + delta semántico
│  Docentes activos        │ ← label 13 secondary
└─────────────────────────┘
  blanco · radius 16 · shadow SM · border #E6EAF0
```
- Incluir **delta/contexto** (▲▼ % o "hoy"). Nunca el número solo.
- Hover desktop: sombra SM→MD.

---

## 9. Tablas

```
NOMBRE              GRADO/SEC   DOCENTE       CAPACIDAD   ESTADO
[A] Aula Innovación   3° A      M. Quispe       30/32     ● Activa
```
- Header: fondo `#F4F6FA`, overline 11 w600 secondary uppercase.
- Filas: alto 56, divisor `#E6EAF0`, hover `#F9FAFC`.
- Primera celda con avatar/inicial cuadrado radius 10. Estado = chip con punto.
- Acción al final de fila (`›` o `⋯`).
- **Mobile:** la tabla colapsa a cards verticales.

---

## 10. Alertas / Incidencias

```
┌─ borde-izq 4px (error/warning/info) ────────┐
│ ⚠  Inasistencia reiterada                    │
│    Juan Pérez · 3°A · 5 faltas consecutivas  │
│    hace 2h                       [Revisar ›]  │
└───────────────────────────────────────────────┘
  fondo container semántico · radius 12
```
- Severidad por color de borde izquierdo. Ícono + título w700 + descripción + timestamp + acción.

---

## 11. Placeholders (módulos en preparación)

No dejar vacíos. Deben incluir:
- Ícono en círculo (`color @ 10%`).
- Título + descripción.
- Badge **"Pronto"** / "Módulo en desarrollo".
- **Lista de 3 bullets** "Qué podrás hacer aquí" (checks atenuados).
- Alineación superior-centro, profesional, dentro del marco con topbar.

---

## 12. Estados y microinteracciones

- Carga: preferir **skeletons** sobre spinners centrados.
- Hover/transición 150ms en filas, cards y nav.
- Bordes globales suaves `#E6EAF0`.

---

## 13. Roadmap visual por fases

- **Fase 2 (estructura del shell)** ✅ topbar, canvas claro, rail custom, selección pill+barra, secciones, perfil footer, placeholders con bullets.
- **Fase 3 (dashboard):** quitar header gradiente, KPIs con delta, tabla real de aulas, bloque de incidencias.
- **Fase 4 (sistema/pulido):** normalizar espaciado a 8, skeletons, microinteracciones, placeholders nivel-2 con wireframe.
