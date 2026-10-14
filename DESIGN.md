# Design

## Theme

Telemetry cockpit for a Flutter mobile/tablet product. The interface uses a dark orbital field, a silver/lilac mechanical launch visual, and a controlled Mars-red data state. It should feel like an instrument panel for a resale operation, not a generic dark dashboard.

## Color

- Background: near-black neutral with graphite orbital grid lines.
- Surface: deep graphite panels with four-corner HUD frames and one-pixel violet borders.
- Primary: silver/lilac for selection, navigation, and live telemetry.
- Mars state: muted red/rose for dense analytics and history, never for normal actions.
- Semantic: mint success, orange attention, rose danger.
- Gradients are reserved for the launch visual and Mars data surface where they communicate depth.

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
- Navigation: vector Material icons only, selected state uses a framed violet instrument cell.
- Lists: compact rows with stable icon containers and one-line metadata.
- Empty states: useful next action, not just large decorative symbols.

## Layout

- 4/8dp spacing rhythm.
- First viewport prioritizes GMV, gross profit, margin, orders, stock status, stale stock, and pending work.
- Tablet layout may use side navigation; phone layout uses bottom navigation.
- Avoid nested cards and oversized repeated metrics.

## Motion

150-250ms state transitions only. Pressed feedback should be immediate. No decorative page-load choreography.
