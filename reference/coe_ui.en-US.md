# coe_ui — API Reference

> Generated from `coe_ui/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

## Exports

### `GetTheme()`

Retrieves the active theme. Server-side: server default theme; client-side: theme synchronized from server (`nil` prior to initial sync).

**Returns**

- `string|nil` `name`

### `GetThemes()`

Returns the list of available framework themes and the currently active theme. Server-side.

**Returns**

- `{ current: string, options: CoeThemeOption[] }`

### `SetTheme(name)`

Configures the server-wide default theme and broadcasts the change to all connected clients. Server-side; restricted to callers authorized in `UiConfig.Caller`.

| Parameter | Type | Description |
|---|---|---|
| `name` | `string` | Theme identifier name |

**Returns**

- `true|string` `result` — `true` or error code: `forbidden`, `invalid_theme`

### `GetAccent()`

Returns the accent palette selected by the player (`theme` = follow server default palette). Client-side.

**Returns**

- `CoeAccent`

### `SetAccent(name)`

Configures the player's personal accent color, persists to local KVP storage, and triggers `coe_ui:accentChanged`. Client-side.

| Parameter | Type | Description |
|---|---|---|
| `name` | `CoeAccent` | Accent color key |

## Types

```lua
---@alias CoeAccent 'theme'|'lime'|'cyan'|'amber'|'rose'|'violet'

---@class CoeThemeOption
---@field name string Identifier key (e.g., 'moss', 'ocean', 'amber', 'rose', 'violet')
---@field label string Human-readable display label
```
