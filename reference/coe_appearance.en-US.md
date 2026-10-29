# coe_appearance — API Reference

> Generated from `coe_appearance/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

All exports are client-side. The appearance data is a table following `shared/schema.lua` format (version `Version()`).

## Exports

### `OpenCreator(options)`

Opens the character creator. Results are dispatched via local events `coe_appearance:creatorSubmit` and `coe_appearance:creatorCancelled`.

| Parameter | Type | Description |
|---|---|---|
| `options` | `CoeAppearanceCreatorOptions` | Creator initialization parameters |

**Returns**

- `boolean` `opened` — `false` if already open, missing options, or during thumbnail generation

### `CloseCreator()`

Closes the creator interface leaving the screen dark: caller prepares the next scene and triggers the fade in.

### `CreatorError(message)`

Displays an error prompt on the creator UI (e.g. server persistence failure).

| Parameter | Type | Description |
|---|---|---|
| `message` | `string\|nil` | Error description message |

### `IsCreatorOpen()`

Returns whether the character creator is currently active.

**Returns**

- `boolean` `open`

### `Apply(ped, appearance)`

Applies the appearance payload to a ped that matches the target model (does not swap ped model).

| Parameter | Type | Description |
|---|---|---|
| `ped` | `integer` | Target ped entity handle |
| `appearance` | `table` | Appearance schema table |

**Returns**

- `boolean` `ok`

### `ApplyToPlayer(appearance)`

Swaps the local player ped model and applies the full appearance dataset.

| Parameter | Type | Description |
|---|---|---|
| `appearance` | `table` | Appearance schema table |

**Returns**

- `boolean` `ok`

### `CreatePed(appearance, x, y, z, heading, gender)`

Creates a local (non-networked) ped for cinematic scenes, with custom appearance or default gender clothing. Caller must delete entity when done.

| Parameter | Type | Description |
|---|---|---|
| `appearance` | `table\|nil` | Appearance schema table |
| `x` | `number` | World coordinate X |
| `y` | `number` | World coordinate Y |
| `z` | `number` | World coordinate Z |
| `heading` | `number\|nil` | Heading orientation |
| `gender` | `'male'\|'female'\|nil` | Used when `appearance` is nil |

**Returns**

- `integer|nil` `ped` — Entity handle or `nil` on failure

### `Normalize(raw)`

Validates and normalizes an incoming appearance table (database or foreign resource). Returns `nil` when invalid.

| Parameter | Type | Description |
|---|---|---|
| `raw` | `any` | Raw input data |

**Returns**

- `table|nil` `appearance`

### `Default(gender)`

Returns initial default appearance for the given gender.

| Parameter | Type | Description |
|---|---|---|
| `gender` | `'male'\|'female'` | Target gender |

**Returns**

- `table` `appearance`

### `Version()`

Format schema version of appearance payload (`AppearanceSchema.Version`).

**Returns**

- `integer` `version`

## Types

```lua
---@class CoeAppearanceCreatorOptions
---@field mode 'create'|'appearance'|nil `create` (new character, default) or `appearance` (edit existing)
---@field characterId string|integer|nil Character identifier being created or modified
---@field gender 'male'|'female'|nil Starting gender (defaults to `male`)
---@field firstName string|nil
---@field lastName string|nil
---@field birthDate string|nil
```
