# Inventory item icons

Generator for the icons in `coe_inventory/data/images` (semi-realistic, side view with light from the upper left, cast
shadow, transparent background). Each item is drawn in SVG by code and exported as 128×128 PNG and WebP files using the item name.

## Generate

```
pip install resvg-py pillow
python tools/item_icons/build.py tools/item_icons/svg coe_inventory/data/images
```

To generate only a few items, pass their names at the end: `... coe_inventory/data/images WEAPON_PISTOL burger`.

## Organization

| File | Contents |
|---|---|
| `lib.py` | Canvas (`Icon`), materials (gradient + outline), shapes, framing, and shadow |
| `parts.py` | Weapon parts: barrel, muzzle brake, rail, sights, scopes, grips, magazines, bipod |
| `firearms.py` | Parametric builders: rifle, bullpup, pistol, revolver, submachine gun, shotguns, precision rifles |
| `special.py` | Launchers, energy weapons, and unusual weapons |
| `melee.py` | Melee weapons, throwables, and objects used as weapons |
| `ammo.py` | Ammunition and accessories (suppressor, magazines, muzzle brakes, scopes) |
| `items.py` | Food, drinks, consumables, documents, electronics, parts, and trash |
| `catalog.py` | Registry `item name -> drawing + options` (one entry per image) |

## New item

1. Draw it with the primitives in `lib.py` (or reuse a builder with different options).
2. Register it in `catalog.py` with `reg('item_name', obj(function, box, ...))`.
3. Generate only that item and inspect the PNG.

Conventions: use materials from `MATERIALS` (do not use an arbitrary color for the object's body), use the material's own
dark outline, highlights with `ic.hl(...)`, and details with `ic.dark(...)`. Long objects (knives, bats, rocket ammo) go
diagonally with `rotate=-40`; long guns use `stretch` to remain recognizable at 64 px. Mk II variants use the framework's
highlight color (`#c4df9b`).
