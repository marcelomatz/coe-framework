# coe_hud — API Reference

> Generated from `coe_hud/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

All exports are client-side.

## Exports

### `SetHidden(reason, hidden)`

Hides or shows the HUD based on reason tokens. Use your resource name as the reason; the HUD remains hidden until all active suppressions are cleared. Also available via local event `coe_hud:setHidden`.

| Parameter | Type | Description |
|---|---|---|
| `reason` | `string` | Suppression reason key (e.g. `GetCurrentResourceName()`) |
| `hidden` | `boolean` | Whether to suppress the HUD |

**Returns**

- `boolean` `ok` — `false` for empty or non-string reason

### `IsHidden()`

Returns whether the HUD is currently suppressed by any active reason.

**Returns**

- `boolean` `hidden`

### `SetLogoVisible(visible)`

Shows or hides the server brand logo (persisted player preference).

| Parameter | Type | Description |
|---|---|---|
| `visible` | `boolean` | Target visibility state |

**Returns**

- `boolean` `visible` — Resulting visibility state

### `IsLogoVisible()`

Returns whether the server logo is currently visible per player preference.

**Returns**

- `boolean` `visible`

### `ToggleLogo()`

Toggles the server logo visibility (same effect as the `/logo` command).

**Returns**

- `boolean` `visible` — Visibility state after toggle
