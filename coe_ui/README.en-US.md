# coe_ui

Framework UI library: design tokens, components, and shared JS API for all NUIs. No dependencies and no build step.

## Use in another NUI

In the consumer resource's `fxmanifest.lua`:

```lua
dependencies { 'coe_ui' }
```

In HTML:

```html
<link rel="stylesheet" href="nui://coe_ui/html/tokens.css">
<link rel="stylesheet" href="nui://coe_ui/html/components.css">
<script src="nui://coe_ui/html/components.js"></script>
```

## Contents

- `tokens.css`: `--coe-*` variables (colors, spacing, typography, radius, z-index). Never use literal colors in NUIs; use the tokens.
- `components.css`: `.coe-button` (`--primary`, `--danger`), `.coe-field`, `.coe-card`, `.coe-badge`, `.coe-modal*` classes.
- `surfaces.css` (load after `tokens.css`): subtle "tech" look, without neon. `.coe-glass` (translucent panel, without `backdrop-filter`, which renders as a black background in FiveM NUI), `.coe-chamfer` (cut corners, `--coe-chamfer`), `.coe-reticle` (reticle; `is-visible` and `has-target` states), and, in `callout.css`, `.coe-callout` (actions floating in 3D perspective over the reticle, without a panel: `.coe-callout__stage` > `.coe-callout__list` > `.coe-callout__item` with `--i` for depth and staggered entry; `is-interactive` enables hover; `--rx`/`--ry` on the stage tilt with the mouse). Depth and motion tokens: `--coe-shadow-depth`, `--coe-ease`, `--coe-dur`, `--coe-dur-slow`. Respects `prefers-reduced-motion`.
- `components.js`: `CoeUI.confirm({ title, message, confirmLabel, cancelLabel, danger })` → `Promise<boolean>`. Replaces `window.confirm`: focus stays in the dialog, Esc cancels, Enter confirms, focus returns to the previous element, simultaneous requests are queued. For `danger` actions, initial focus is on Cancel.
- `prompt.css` + `prompt.js` (load after `perspective.css`): standard interaction prompt (upper-left corner), used by the clock-in point and workbenches for all businesses. Creates its own element; send `SendNUIMessage({ action = 'prompt', data = { title, subtitle, options = { { key = 'E', label = '...' } } } })` and `data = nil` to hide.

## Themes

Five color themes (`moss` default, `ocean`, `amber`, `rose`, `violet`) are defined in `tokens.css` via `:root[data-coe-theme="nome"]` and listed in `config.lua`. The active theme is global, saved in the server's KVP, and changed through the admin panel ("Appearance" tab, ACE `coe_admin.theme.manage`).

For an NUI to follow the theme:

1. Load `tokens.css` and `components.js` (the JS applies `data-coe-theme` when it receives the `coe:theme` message).
2. Add `'@coe_ui/theme_bridge.lua'` to the resource's `client_scripts`; it provides the initial theme and real-time changes.
3. Use only `var(--coe-*)` and `rgba(var(--coe-accent-rgb), .2)` (also `--coe-ink-rgb` and `--coe-panel-rgb`) for transparency.

New theme: add the block to `tokens.css` and the entry to `config.lua`.

Exports (server): `GetTheme()`, `GetThemes()`, `SetTheme(nome)` (only resources with the `coe.ui.theme` ACE, e.g., `add_ace resource.coe_admin coe.ui.theme allow`).

## Style guide

`/coeui` (client command) opens a page with all components for visual review.

## Rules

- A new component must be added here, with an example in the style guide, before being used in an NUI.
- Classes always use the `.coe-` prefix; screen-specific styling belongs in that NUI.
- A change that breaks a class or API requires a new minor/major repository version.

## Tests

DOM tests with jsdom (`confirm`: ARIA, Esc, Enter, focus, queue; theme, accent, and NUI messages), run in CI:

```
cd coe_ui
npm ci
npm test
```

## Player color

Players choose their color in /hud. `coe_ui` stores the choice in local KVP (`coe_ui:accent`) and `theme_bridge.lua` provides it to all NUIs (`coe:accent` message, handled in `components.js`). The chosen color overrides the theme highlight; *Theme* uses the server default. Exports: `GetAccent` and `SetAccent(nome)`.

## API reference

[Exports, parameters, and error codes](../reference/coe_ui.md), generated from [`types.lua`](types.lua).
