# coe_map

Map controls. The radar is still drawn by GTA; `coe_map` decides the mode and `coe_hud` adjusts to its size.

| Mode | How | Character controls |
|---|---|---|
| Minimap | default | retained |
| Expanded minimap | **Z** (toggle) | retained |
| Full map (GTA pause map) | **M** or `/destino` | map screen |

- On the full map, mark the destination with Enter (native GTA control).
- When expanded, a chip shows the distance to the destination.
- `/destino limpar` or the "Coe: clear destination" key (no default key) removes the destination.
- All keys can be rebound in Settings > Keyboard > FiveM.
- The native Z key (expand radar) is disabled to prevent a conflict.

## Integration

- Local event `coe_map:changed (mode, scale)` — `coe_hud` repositions the frame, location panel, and icons.
- Exports: `GetMode()` and `OpenFull()`.

## Configuration

- `Config.ExtendedScale` (1.9): used only by the HUD to offset icons and the location panel from the expanded minimap (native bigmap, no frame).
- `Config.FootZoom` (1250): zoom on foot; higher = farther out. `nil` uses the GTA default.

## Tests

`lua test\client_map_test.lua` (in the resource folder).

## API reference

[Exports, parameters, and error codes](../reference/coe_map.md), generated from [`types.lua`](types.lua).
