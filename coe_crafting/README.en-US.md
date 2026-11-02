# coe_crafting

Central crafting system. It contains recipes, rules, and execution; mechanics, commerce, and illegal crafting only specify **where** the bench is and **who** has access.

## Concepts

- **Recipe**: `id`, `label`, `category`, `timeMs`, `inputs[]`, `outputs[]` (multiple outputs are allowed). Deterministic: no chance of failure or bonus.
- **Bench (type)**: accepts recipe categories and defines the input source (`player`, `stash`, or `both`) and output destination (`player` or `stash`).
- **Context**: `{ inventoryId, stashId, access = function(playerId) -> bool[, reason] }`, provided by whoever opens the bench.

## Flow

`Begin` validates access, recipe, and materials, then reserves the player (one bench at a time). `Complete` checks again, consumes inputs (player first, then stash, for `both`), and delivers outputs. If anything fails, everything is returned. Audits `craft_completed`.

## Exports (server)

Return one value: the result or `{ error = code }`. Restricted to `AllowedResources`.

- `RegisterBench(type, def)`, `RegisterRecipe(recipe)`, `RemoveRecipe(id)`
- `Open(playerId, benchType, opts)`: opens the single panel. `opts = { label, stashId, recipes = { ids } | function(playerId) -> { ids }, position = { x, y, z, radius }, access = function(playerId, recipeId) -> bool[, reason] }`. Position, access, and recipe are checked again for every production (`Begin` and `Complete`).
- `Close(playerId)`
- `ListRecipes()`: catalog `{ id, label, category }`, restricted to `coe_admin` (used by the faction editor).
- `List`, `Begin`, `Complete`, `Cancel`, `Busy`: used by the panel itself; also useful for tests and flows without UI.

The `coe_crafting:ready` event fires at startup; callers registering benches must register again when they receive it.

## Interface

Single NUI panel (`html/`): lists recipes with the player's available amount of each ingredient, a progress bar, and an animation defined per bench (`animation = { dict, name }`). Client events come only from the server; `craft`, `refresh`, and `close` callbacks return to the server, which validates the session.

## Out of scope (v1)

Police alerts, XP/levels, craft failure, or bonuses.

## DeepWeb bench (`coe_deepweb`)

`coe_deepweb` registers the `deepweb_rig` bench (category `hacking`, DeepWeb only) and the `hacking_onion_usb` recipe (empty USB drive → USB drive with onion browser). It opens through the Onion app on an installed desktop or server, with the machine position and access checked for each production. The recipe appears in the admin catalog.

## Business benches (restaurants and shops)

The `crafts` stations for businesses whose category is in `CraftingConfig.BusinessBenches` (`restaurant`, `shop`, `other`) become `business_<category>` benches.
Access comes from `coe_businesses:Access`: owner (if `ownerAccess`) or an employee registered on the shop's team and clocked in (unless `clockRequired = false`).
The server revalidates access and distance for each action. Default recipes: `kitchen` (restaurant) and `retail` (shop), in `config.lua`. `other` uses the `workshop` category, with no recipes by default.
New ingredients are in `coe_inventory\data\coe_ingredients.lua`. The bench uses the nearest business stash (`stashes` station), opened by staff on site (`coe_businesses`); without a registered stash, ingredients come from the player.

## Faction benches (`coe_factions`)

The `crafts` stations registered to an active faction (**Groups > Points** tab in `coe_admin`) become `faction` benches (`CraftingConfig.FactionBench`, `source = 'both'`, `output = 'player'`).
- **Access and grade by recipe:** only members of that faction can see and open the bench (`not_member`). Listed recipes come from `exports.coe_factions:RecipesForFaction(factionId, characterId)`, and every production revalidates `exports.coe_factions:CanCraftInFaction(factionId, characterId, recipeId)` in `Begin` and `Complete` (`grade_too_low`).
- **Faction stashes:** the faction's `stashes` stations open on site with **E** for members (`stash:faction:<faction>:<stash>`) and also supply the nearest bench for that faction.

## Unaffiliated clandestine benches (illegal crafting)

Benches not linked to a business or faction, registered in **Businesses > Recipes and menus > Illegal benches** (`CraftingConfig.IllegalBench`, type `illegal`, category `illegal`).
- **Open access:** available to any player with an active character.
- **Player-only consumption:** `source = 'player'` and `output = 'player'` (no stash).
- **Recipes:** offer every recipe in the `illegal` category (`illegal_lockpick`, `illegal_ziptie`, `illegal_armour`, and custom recipes created in the panel) or only the subset selected for that bench.

## Isolation and security rules

- **Record owner:** each recipe and bench belongs to the resource that registered it (`GetInvokingResource`). Another resource cannot replace or remove it (`id_conflict`); only `coe_admin` (panel overrides) can.
- **Categories:** `CraftingConfig.CategoryOwners` defines who registers in each category (`mechanic` only `coe_mechanic`; `kitchen`/`retail`/`workshop`/`illegal` only `coe_crafting`). A recipe in another owner's category is rejected (`category_forbidden`). A bench sees and executes only recipes in its categories.
- **`business_*`, `faction`, and `illegal` benches:** reserved for `coe_crafting` (`reserved_bench`). External resources register only their own benches.
- **Business menus:** priority order: business-customized menu, selected menu type, `CraftingConfig.BusinessRecipes = { [businessId] = { 'recipe', ... } }`, and, if none of these are set, all recipes in the bench categories. Filtering applies both when listing and producing.
- **Business access:** owner (`ownerAccess`) or staff of **that** business (`coe_businesses:Access`), clocked in. Duty is per business, with only one active per player. An owner of one business cannot operate at another.
- **Revalidation:** the server checks access, distance, business category, or faction grade when opening, starting, and completing. Losing access or minimum grade during crafting cancels without consuming anything.
- **Stash and product:** the bench uses the nearest business stash (`stash:business:<business>:<stash>`) or faction stash (`stash:faction:<faction>:<stash>`). Crafting consumes only from that stash and the crafting player; the product goes only to the player who crafted it.

## Recipes, menus, and illegal benches (admin panel)

Stored in `coe_crafting_catalog` (`server/catalog.lua`, `server/persistence.lua`). Edited under **Businesses > Recipes and menus** in `coe_admin` (exports `AdminCatalog`, `AdminSaveRecipe`, `AdminDeleteRecipe`, `AdminSaveMenu`, `AdminDeleteMenu`, `AdminSaveBench`, `AdminDeleteBench`, `AdminSetBusinessMenu`, `coe_admin` only).

- **Custom recipes:** only in categories from `EditableCategories` (`kitchen`, `retail`, `workshop`, `illegal`). `config.lua` recipes appear as defaults (read-only, `reserved_recipe`). Every item must exist in `coe_inventory` (`unknown_item`). Limit: `MaxCustomRecipes`.
- **Menu types:** e.g. Pizzeria, Burger Shop, Bar. Each type belongs to a business category with a bench and lists recipes for that bench (up to `MaxMenuRecipes`). Limit: `MaxMenus`.
- **Illegal benches:** free-world points (`id`, `label`, `enabled`, `x`, `y`, `z`, `radius`, `recipes`), up to `MaxIllegalBenches`.
- **Business menu:** under the business's **Menu** section: choose a type and optionally customize the list for that business only. If the business changes category, the saved menu is ignored.

## Bench denial reasons

The player receives the exact reason, and the server records `craft_denied` with it: `off_duty` (a staff member who has not clocked in; the bench appears with "Clock in to craft"), `not_staff`, `not_member`, `grade_too_low`, `too_far`, `unavailable` (`coe_businesses`/`coe_factions` unavailable), and `forbidden`.

## Tests

`test\crafting_test.lua` (core), `test\business_test.lua` (access and business, faction, and illegal stations), `test\isolation_test.lua` (isolation across businesses, factions, grades, categories, and stashes), and `test\catalog_test.lua` (custom recipes, menu types, illegal benches, and business menus).
