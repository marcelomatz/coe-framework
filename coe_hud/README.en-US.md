# coe_hud

Player HUD with perspective panels (`coe_ui/html/perspective.css`).

- Health and armor in the bottom corner; vehicle panel (speed, RPM, gear, fuel, engine) when the player is driving. Motorcycles, boats, and aircraft are identified (`kind`); boats/aircraft do not show a gear.
- `/hud` opens **edit mode** (see below); the *Preferences* button on the bar opens color, style (glass/solid/minimal), icons (round/square/hexagon), side, unit (km/h or mph), size, and visibility. Everything is saved per player in local KVP and validated in `prefs.lua`.
- Performance: one loop (250 ms on foot, 100 ms while driving) that sends a message to NUI only when a value changes; CSS without `backdrop-filter`, large shadows, or continuous animation.
- Fuel uses `GetVehicleFuelLevel`; integrate a fuel resource through a state bag/native if needed.

- Hunger, thirst, and stress come from `coe_needs` (local event `coe_needs:changed`) and can be hidden in `/hud`.
- Vehicle: keys registered with `RegisterKeyMapping` (change under Settings > Key Bindings > FiveM): `B` seat belt (prevents windshield ejection and blocks exiting the car), `H` headlights (off → low → high; native headlights are blocked), `←`/`→` turn signals. State resets when switching vehicles or exiting.
- Health, armor, hunger, thirst, and stress use icons that fill according to the value, without a background panel. In `/hud`: color (accent), icon colors (by status or one color; when a color is chosen, it applies to all icons, and only *Theme* mode uses the server default and per-status colors), shape (round, square, hexagon), and *Show percentage*.
- Minimap: the HUD calculates the minimap's actual position (safezone and screen aspect ratio, reevaluated every 0.5 s) and anchors panels beside it, with a corner frame. Native minimap health and armor are hidden (the bars are from the HUD). In `/hud` > *Location and compass*, the panel above the minimap shows compass, street, region, and time, and native street, region, and vehicle text are hidden.
- Upcoming streets (/hud > *Upcoming streets*): up to 3 streets ahead, with side (← left, → right, ↑ ahead) and distance. `route.lua` samples points along the heading and to the sides and reads the street name at each one; range increases with speed (180 to 600 m) and the reading is refreshed every 1 s.

Tests: `lua test\client_hud_test.lua`, `lua test\prefs_test.lua`, `lua test\route_test.lua` and, in `coe_hud`, `npm ci; npm test` (DOM with jsdom: `speedo.test.js` and `editor.test.js`, also run in CI).

## Minimap and on-foot compass

In `/hud` > Preferences, **Minimap** and **Compass and location** have `Always` (default) or `In vehicle only` (`minimapMode`, `locationMode`). In vehicle mode, they appear for driver and passenger and disappear when exiting; the existing HUD loop detects the change (no new loop) and calls `DisplayRadar` only when the state changes. Health and needs stay beside the minimap space without jumping when entering and exiting. In edit mode, both appear on foot too so they can be positioned.

## Hide the HUD

Other resources hide the HUD and minimap for a reason, using the resource name: `TriggerEvent('coe_hud:setHidden', GetCurrentResourceName(), true)` (or `exports.coe_hud:SetHidden(reason, true)`). The HUD returns only when no reasons remain; if the resource that hid it stops, its reason is cleared. `exports.coe_hud:IsHidden()` reports the state. Used by character selection (`coe_characters`) and the creator (`coe_appearance`).

The server logo follows the player's preference: `exports.coe_hud:SetLogoVisible(true|false)`, `IsLogoVisible()`, and `ToggleLogo()` (same effect as `/logo`) return the final state. Full contract in [`types.lua`](types.lua) and the [API reference](../reference/coe_hud.md).

## Speedometers

In `/hud` > *Speedometer*, the player chooses the appearance of the vehicle panel; the choice is saved per player (`speedo` in `prefs.lua`).

| Option | Appearance |
|---|---|
| `panel` | Perspective panel (default, previous behavior) |
| `modern` | Speed ring with gear, and engine and fuel rings |
| `modernpro` | Display with speed arcs (left) and RPM arcs (right) and tick scale |
| `bold` | Large speed with dimmed zeros, speed bar, and fuel and engine bars |
| `retro` | Large speed, gear, engine and fuel chips, and segmented RPM bar |
| `minimal` | Compact pill with gear, speed, fuel, and engine |
| `analog` | RPM and speed gauges with needles, and a fuel gauge |

The indicator strip (turn signals, engine, low/high beams, seat belt, low fuel) is its own component, used with all styles: by default it is directly above the speedometer and can be moved in edit mode. The scale tops out at 240 km/h or 160 mph; boats and aircraft hide the gear. Implementation is in `html/speedo.js` (static SVG/HTML templates, updates only what changed) and `html/speedo.css`.

## Edit mode (`/hud`)

`/hud` opens the editor over the HUD (with mouse focus); `/hud` again discards changes. Components: **health and needs** (`status`), **location** (`location`), **minimap** (`minimap`), **speedometer** (`speedo`, panel or styles), and **indicators** (`indicators`). Outside a vehicle, the editor shows an example state so everything can be positioned on foot.

- Drag the box to move it; the corner handle resizes it (50% to 200%, relative to global *Size*); the eye icon hides/shows it (uses `showHealth`, `showLocation`, `showMinimap`, `showVehicle`, `showIndicators`).
- Bar: **Grid** (20 px snapping and 5% size increments), **Safe zone** (GTA safezone frame), **Anchor zones** (default position for each component; dropping with half or more over the zone re-anchors it), **Hidden** (shows hidden components dimmed for positioning). Options are saved (`editor`).
- **Undo/Redo** (also `Ctrl+Z` / `Ctrl+Y`), **Restore default** (layout and visibility; color and style remain), **Discard** (`Esc`), and **Done** (saves). Preferences opened through the editor are part of the same draft.
- While editing, the client only previews (`hudPreview`, does not save KVP); `hudDone` saves and `hudDiscard` reverts to the saved settings.
- Saved format: `layout[component] = { x, y, size }`. `x`/`y` are the top-left corner as a screen fraction (0–1, 4 decimal places), so the layout works at any resolution; without `x`/`y`, the component is anchored in its default position. `prefs.lua` limits size and coordinates, requires `x` and `y` together, and discards unknown components.
- Minimap: `minimap.lua` converts the selected rectangle into `SetMinimapComponentPosition` (minimap, mask, and blur, offset and scaled from the default corner) and toggles bigmap once so the radar rereads the positions. Anchored health/needs and location continue following the moved minimap, including the expanded `coe_map` view (which opens from the minimap corner). When the resource stops, the radar returns to the GTA default position.
- No new per-frame loops: radar repositioning is a one-time bigmap toggle.

## Ultrawide and 4K

In `/hud` *Preferences*:

- **HUD area**: `Full screen` (default), `16:9`, or `21:9`. On screens wider than the selected aspect ratio, the HUD is placed in a centered area: the native minimap (`minimap.lua`, `MinimapLayout.Area`/`AreaBase`) and components anchored to it are placed in the area, right-side panels respect its margin, and the area appears as a frame in the editor and limits dragging. Layout `x` becomes relative to the area, so the same layout works in 16:9 and 21:9. On screens narrower than the selected ratio, the full screen is used.
- **Automatic resolution scaling** (`autoScale`, enabled by default): the HUD scales with screen height using 1080p as 100% (1440p ≈ 133%, 4K = 200%, limits 50% to 300%); *Size* remains a fine adjustment on top. Reevaluated when the window is resized.
