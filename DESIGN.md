# Design

## Theme

Restrained operations UI for a Flutter mobile/tablet product. The interface should feel closer to a compact business terminal than a landing page.

## Color

- Background: near-white cool slate in light mode, near-black neutral in dark mode.
- Surface: white or deep neutral panels with visible one-pixel borders.
- Primary: teal/green for scan, receive, and selected states.
- Secondary: blue for analysis and system intelligence.
- Semantic: green success, red danger, amber warning.
- Avoid decorative gradients except for rare summary surfaces where the gradient conveys emphasis.

## Typography

Use the platform sans stack. Keep product UI type fixed and compact:

- Page title: 20-22, weight 800-900.
- Section title: 13-14, weight 750-800.
- Body: 12-14.
- Metadata: 10-11.
- Numeric metrics: tabular-looking, bold, scale down with `FittedBox` when needed.

## Components

- Cards: 10-12 radius, border-first, minimal or no shadow.
- Buttons: one primary shape, one outlined/ghost shape, no emoji prefixes.
- Navigation: vector Material icons only, selected state uses filled/tinted background.
- Lists: compact rows with stable icon containers and one-line metadata.
- Empty states: useful next action, not just large decorative symbols.

## Layout

- 4/8dp spacing rhythm.
- First viewport prioritizes GMV, gross profit, margin, orders, stock status, stale stock, and pending work.
- Tablet layout may use side navigation; phone layout uses bottom navigation.
- Avoid nested cards and oversized repeated metrics.

## Motion

150-250ms state transitions only. Pressed feedback should be immediate. No decorative page-load choreography.
