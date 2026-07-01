# Lenguaje de diseño — Portal Docente

Reglas del sistema visual del portal docente. Toda pantalla docente debe
cumplirlas. Fase 0 del plan de pulido de UI.

## 1. Color

**El azul (`primaryColor` #1976D2) es acento, no fondo emocional.**

- Usar azul SOLO para: acción primaria, selección activa, estado/indicador.
- PROHIBIDO: azul en números de datos, en todos los títulos, o como "tema".
- El 80% de la pantalla es neutro (blanco / gris muy claro / texto casi-negro).

**Color por significado (semántica de asistencia):**

| Estado | Token | Color |
|---|---|---|
| Presente | `attendancePresent` | verde |
| Tardanza | `attendanceLate` | ámbar |
| Ausente | `attendanceAbsent` | rojo |

Nunca pintar un estado de azul. El significado manda el color.

## 2. Tipografía

- Familia única: **Manrope** (ya global). No mezclar fuentes.
- Título de página: escala de herramienta (~20–22px), NO 32px de héroe.
- **Un solo estilo de número grande:** `AppDesignSystem.metricLarge`. Casi-negro
  por defecto; color solo si el número ES un estado.
- Sin ALL CAPS en cuerpo. Mayúsculas solo en labels cortos (≤4 palabras).

## 3. Superficies y tarjetas

- Tarjetas **planas**: borde 1px (`TeacherUi.border`) + sombra sutil opcional.
- **Cero gradientes.** `getCardGradient` / `getBackgroundGradient` están
  deprecados. No usarlos en pantallas docente.
- Card no es el contenedor por defecto de todo. Úsala cuando aporta agrupación.

## 4. Prohibiciones (tells de "hecho por IA")

- ❌ Marcas de agua fantasma detrás de KPIs (íconos gigantes semitransparentes).
- ❌ Texto truncado con `...` en KPIs, títulos o headers. La card crece o el
   texto envuelve.
- ❌ Título duplicado (app-bar + página diciendo lo mismo).
- ❌ Gradientes decorativos.
- ❌ Datos de prueba visibles (horarios tipo `02:00–23:55`, días desordenados
   `Martes–Lunes`). Ordenar Lun→Dom y validar rangos.

## 5. Componentes base (usar SIEMPRE, no reinventar)

`lib/screens/teacher/widgets/teacher_ui.dart`:

- **`TeacherCard`** — contenedor plano estándar (opcional `onTap` con ripple).
- **`TeacherMetric`** — KPI: icono sólido pequeño + label + número grande +
  sublabel opcional. Sin watermark.
- **`TeacherStatusPill`** — estado por color semántico. Factories:
  `.present()`, `.late()`, `.absent()`, `.active(bool)`.

## 6. Movimiento

- 150–250 ms en transiciones (`durationFast` / `durationNormal`).
- El movimiento comunica estado, no decora. Sin secuencias de carga
  orquestadas: el docente entra a una tarea.

## 7. Densidad y estados

- Evitar pantallas con una card y 60% vacío. Enriquecer la card o mostrar un
  empty-state que enseñe la interfaz.
- Toda lista/pantalla con datos define: loading (skeleton), vacío (con guía),
  error (con acción de reintento).

---

**Orden de fases:** Login → Inicio → Mis Aulas → Asistencia/QR → Horario →
Alumnos → Reportes. Una pantalla por fase, un commit por fase, sin tocar
lógica (QR/Telegram/functions/datos).
