# coetarget

Client-side contextual targeting resource for interacting with entities and exposing actions provided by other resources. It does not implement server-authoritative rules or perform network requests.

## Files and responsibilities

- `config.lua`: toggle command, hold-to-activate key, and maximum target distance.
- `client.lua`: camera raycast, option filtering, navigation, local execution of the selected action, and exports for registering/removing options.
- `html/`: indicator and options list; labels are inserted as text.
- `fxmanifest.lua`: initializes NUI and client scripts.

## Configuration and usage

In `config.lua`, `Config.Command` toggles targeting, `Config.DefaultKey` sets the key to hold for activation, and `Config.MaxDistance` sets the raycast range. While active, the reticle disables attack and default aiming and lists the target's options. A left-click enters selection mode: options are frozen, the mouse cursor is released, and clicking an option executes it; `Esc`, right-click, or clicking outside cancels.

A consumer declares a dependency on `coetarget` and uses its resource adapter. In the inventory, `Inventory.Target` in `coe_inventory/client/target_adapter.lua` wraps the exports:

```lua
exports.coetarget:AddTargetEntity(entity, {
	{
		label = 'Abrir',
		canInteract = function(target) return DoesEntityExist(target) end,
		onSelect = function(target) print(target) end
	}
})
```

Options receive callbacks and local predicates; they are not serializable and cannot be registered by the server. `AddTargetEntity` requires an existing entity and an options list; `AddTargetModel` accepts a model hash or name. Every valid option needs `label` and an `onSelect` function; `canInteract` is optional.

Registrations: `AddTargetEntity(entidade, opções)`, `AddTargetModel(modelo, opções)` (any entity of that model, e.g., doors), and `AddTargetGlobal(tipo, opções)` with type `player`, `ped`, `vehicle`, or `object`; each has a corresponding `Remove...` (`RemoveTargetEntity`, `RemoveTargetModel`, `RemoveTargetGlobal`). For any aimed-at surface (including the map, with `entity = 0`), use `AddTargetSurface(opções)` and `RemoveTargetSurface(opções)`. Registrations are owned per resource: two resources can register on the same target and their options are combined; when a resource stops, its registrations are removed. Options accept `label`, `onSelect(entidade, opção)`, `canInteract(entidade, distância)`, and `distance` (default `Config.DefaultOptionDistance`, measured from the player). Errors in callbacks are isolated.

If no option is registered for the target, target only shows the indicator, with no options (there are no default actions). Click to enter selection mode and choose an option with the mouse; before executing, target revalidates range, `canInteract`, and the option registration. These actions provide local UX and do not replace server validation.

## Dependencies and security

Standalone client-side resource, with no `coe_core` dependency. Exports allow other resources to add actions, so callbacks should handle local state and never trust target data as authorization.

## Tests and limitations

Run `lua test\client_test.lua` from the resource folder. The test covers registration/removal, basic validation, key configuration, and idle UI state. Real raycast, natives, control navigation, Enhanced interactions, and NUI compatibility require an FXServer smoke test.

## API reference

[Exports, parameters, and error codes](../reference/coetarget.md), generated from [`types.lua`](types.lua).
