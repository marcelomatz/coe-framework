# coe_loadscreen

Coe loading screen (NUI), using the same visual style as character selection (`coe_characters`) and the creator (`coe_appearance`):

- **Background scene** with a slow-moving camera (approach and drift, like the cinematic camera during selection): the Los Santos sunset seen from the Observatory, drawn directly in HTML (sky, sun, Vinewood hills, buildings with flickering windows and warning lights), or your own photos in `html/backgrounds/` shown in sequence with a smooth transition. A light film grain overlays the scene.
- **Same grid, typography, cards, and vignettes** as character selection (`coe_characters`) and the creator (`coe_appearance`): brand at the top left (`COE · LOS SANTOS`), badge at the top right, steps at the bottom left (`40x40` cards with individual progress bars, live status, `translateX(8px)` offset, and an accent side bar on the active step), and the current step highlighted in a large panel on the right with its active fun message, chips, and glowing progress bar.
- **Stylesheet order (Themes)**: just like `coe_characters` and `coe_appearance`, it strictly follows the cascade:
  1. **Default theme** (`:root` and `:root[data-coe-theme="..."]`)
  2. **User-defined theme** (`:root[data-coe-user-theme="..."]`)
  If the user has not selected a theme, the default theme is used; if selected, the user's theme is always applied (delivered upon connection via `deferrals.handover` by `coe_ui` and persisted in `localStorage`/KVP).
- **Live, synchronized steps (no tips box to keep the appearance clean)**: Connecting → Preparing the map → Supplying the city → Lighting up Los Santos → Entering the city. Steps advance both through native FiveM events (`loadProgress`, `startInitFunctionOrder`, `initFunctionInvoking`, `startDataFileEntries`, `onDataFileEntry`, `performMapLoadFunction`, `endDataFileEntries`) and progress bar thresholds (`floor`), with rotating fun messages (such as *"Calibrating lockpicks and crowbars…"*, *"Hiding illegal workbenches in the alleys…"*). Clicking the steps or the highlighted panel's subtitle immediately picks another activity.
- Respects `prefers-reduced-motion` (no camera, glow, or flicker).

## Customization

Everything is at the top of `html/app.js`:

| Key | Purpose |
|---|---|
| `CONFIG.eyebrow`, `title`, `subtitle`, `tag` | Brand and badge text. |
| `CONFIG.backgrounds` | Photo names in `html/backgrounds/` (empty: drawn sunset). `backgroundSeconds`: interval between photos. |
| `CONFIG.activitySeconds` | Automatic interval for changing each step's fun messages. |
| `STEPS` | Steps, text, `activities` (rotating fun phrases), and the minimum progress bar value (`floor`) for each. |

## Limits

- Declares `loadscreen 'html/index.html'` with `loadscreen_manual_shutdown 'yes'`: the screen remains until character selection (`coe_characters`) has the 3D scene ready, then calls `ShutdownLoadingScreenNui`. This prevents the raw game or an interface without a scene from appearing between loading and selection.
- `client.lua` is only a safety net: if `coe_characters` is not started, it closes the screen 5 seconds after the player becomes active; if selection hangs, it closes after 60 seconds. Test: `lua test\client_test.lua`.
- Loads `nui://coe_ui/html/tokens.css`, `components.css`, and `surfaces.css`, and keeps the default and user theme tokens in `style.css` in the same order so it works immediately from the first connection frame.
- The loading screen has no game scene behind it, so the scene is drawn (or comes from photos), not the character selection's 3D scene.

## Usage

`ensure [coelho]` already starts the resource. Keep **only one** resource with `loadscreen` on the server; any other one (for example, the template default) must be left out of `server.cfg`. If the old loading screen still appears when connecting, another loadscreen resource may be running, or it may be the client cache (clear the FiveM cache).
