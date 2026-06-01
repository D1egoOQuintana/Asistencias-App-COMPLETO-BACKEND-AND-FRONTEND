---
name: Core Scholar Design System
colors:
  surface: '#f7f9fd'
  surface-dim: '#d8dade'
  surface-bright: '#f7f9fd'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f4f8'
  surface-container: '#eceef2'
  surface-container-high: '#e6e8ec'
  surface-container-highest: '#e0e3e6'
  on-surface: '#191c1f'
  on-surface-variant: '#414752'
  inverse-surface: '#2d3134'
  inverse-on-surface: '#eff1f5'
  outline: '#717783'
  outline-variant: '#c1c6d4'
  surface-tint: '#005faf'
  primary: '#005dac'
  on-primary: '#ffffff'
  primary-container: '#1976d2'
  on-primary-container: '#fffdff'
  inverse-primary: '#a5c8ff'
  secondary: '#525f71'
  on-secondary: '#ffffff'
  secondary-container: '#d3e1f6'
  on-secondary-container: '#566475'
  tertiary: '#196b22'
  on-tertiary: '#ffffff'
  tertiary-container: '#368539'
  on-tertiary-container: '#fcfff6'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d4e3ff'
  primary-fixed-dim: '#a5c8ff'
  on-primary-fixed: '#001c3a'
  on-primary-fixed-variant: '#004786'
  secondary-fixed: '#d6e4f9'
  secondary-fixed-dim: '#bac8dc'
  on-secondary-fixed: '#0f1c2c'
  on-secondary-fixed-variant: '#3a4859'
  tertiary-fixed: '#a3f69c'
  tertiary-fixed-dim: '#88d982'
  on-tertiary-fixed: '#002204'
  on-tertiary-fixed-variant: '#005312'
  background: '#f7f9fd'
  on-background: '#191c1f'
  surface-variant: '#e0e3e6'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  display-lg-mobile:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  title-sm:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
  label-caps:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '700'
    lineHeight: 16px
    letterSpacing: 0.05em
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  unit: 8px
  container-margin: 24px
  gutter: 16px
  sidebar-width: 260px
  compact-padding: 12px
---

## Brand & Style

The design system is engineered for high-stakes educational administration, where clarity, efficiency, and reliability are paramount. It follows a **Soft Enterprise** aesthetic—a refined evolution of traditional corporate UI that balances professional rigor with approachable, modern interfaces.

The visual language communicates authority through a structured grid and a disciplined color palette, while maintaining a high signal-to-noise ratio suitable for data-heavy SaaS environments. The emotional response is one of organized calm, ensuring school administrators can process attendance records and student data without cognitive fatigue. Key pillars include:

*   **Precision:** High-density layouts that maximize information visibility.
*   **Trust:** Institutional blues and substantial typography that feel established.
*   **Modernity:** Subtle roundedness and soft borders that move away from "legacy" enterprise software.

## Colors

The palette is anchored by **Institutional Blue**, providing a professional and recognizable primary action color. 

*   **Surface Hierarchy:** The primary background uses a very light grey (#F4F6FA) to reduce glare, while white (#FFFFFF) is reserved for cards and content containers to create a clear "layering" effect.
*   **Navigation:** A Dark Navy (#0D1B2A) is dedicated to the sidebar, creating a strong vertical anchor and clearly separating navigation from the workspace.
*   **Semantics:** Success states use a deep "Sobey Green," warnings utilize a "Soft Amber," and critical errors use a "Professional Red." These are calibrated for legibility against both white and light-grey backgrounds.
*   **Borders:** Soft Grey (#E6EAF0) is used exclusively for structural definition, ensuring UI elements are bounded without creating visual clutter.

## Typography

This design system utilizes **Inter** for its exceptional legibility in technical interfaces. The scale is optimized for a high-density SaaS environment.

*   **Hierarchy:** High-contrast weights are used to differentiate data labels from user input. Bold caps are utilized for table headers to provide a clear structural anchor for data columns.
*   **Readability:** Body text is set at 14px for standard interaction, with a 13px variant for secondary data or dense tables.
*   **Responsive Scaling:** Large display titles scale down on mobile to maintain vertical space for lists and forms.

## Layout & Spacing

The system follows a strict **8px spacing grid** to maintain professional alignment and density.

*   **Grid Model:** A 12-column fluid grid is used for the main content area. In desktop view, the layout is anchored by a fixed 260px sidebar.
*   **Density:** Elements utilize "Compact Padding" (12px) for table rows and list items, allowing for more data points per screen.
*   **Breakpoints:**
    *   **Desktop (1280px+):** Full 12-column grid, persistent sidebar.
    *   **Tablet (768px - 1279px):** Collapsed sidebar (icon only), 8-column grid, 16px margins.
    *   **Mobile (below 768px):** Single column, 16px margins, bottom navigation or "hamburger" overlay.

## Elevation & Depth

To maintain a "Soft Enterprise" feel, the system avoids heavy drop shadows in favor of **Tonal Layers** and **Low-Contrast Outlines**.

*   **Base (Level 0):** The #F4F6FA background.
*   **Surface (Level 1):** White cards (#FFFFFF) with a 1px border (#E6EAF0). No shadow.
*   **Overlay (Level 2):** Modals and dropdowns. These use a very soft, highly diffused shadow: `0px 4px 20px rgba(13, 27, 42, 0.08)`.
*   **Interactive:** Hover states on buttons or clickable list items use a subtle background tint change rather than an elevation increase.

## Shapes

The design system uses **Soft (Level 1)** roundedness. 

*   **Standard Elements:** Buttons, input fields, and chips use a 4px (0.25rem) radius to maintain a crisp, professional look.
*   **Containers:** Large cards and modals use a 8px (0.5rem) radius to soften the overall appearance of the workspace.
*   **Status Indicators:** Chips may use a fully rounded (pill) style for distinct visual separation from actionable buttons.

## Components

*   **Buttons:** 
    *   *Primary:* Solid #1976D2 with white text. 
    *   *Secondary:* White background with #E6EAF0 border and #1976D2 text.
    *   *Tertiary/Ghost:* No border, just text, used for less frequent actions.
*   **Chips (Status):** Small height (24px), semi-bold text. Success chips use a 10% opacity green background with 100% opacity green text for high readability.
*   **Input Fields:** White background, 1px #E6EAF0 border. On focus, the border transitions to #1976D2 with a 2px outer "glow" of 10% opacity blue.
*   **Lists/Tables:** High-density. Rows are 48px high. Zebra striping is not used; instead, 1px horizontal dividers separate entries.
*   **Sidebar Items:** Active states use a subtle left-border accent in Primary Blue and a slight background highlight (#FFFFFF10) against the Dark Navy.
*   **QR Area:** QR codes should be framed in a white card with a subtle border to ensure maximum contrast for scanners.