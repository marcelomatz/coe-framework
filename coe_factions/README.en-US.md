# coe_factions

Illegal factions (gangs, mafias, ghettos, chop shops, and others): registration, grades, members, and unlocked crafting recipes. Jobs are not managed here: they belong to businesses (`coe_businesses`). Legacy job groups (`police`, `ambulance`, `mechanic`) remain in `coe_core` and have no interface.

## Model

- `coe_faction_registry(faction_id, config JSON)`: name, category, active/inactive status, grades (0 to 9, with names), unlocked crafting recipes (`recipe` + `minGrade`), and physical stations (`stations = { crafts = {...}, stashes = {...} }`).
- `coe_faction_members(faction_id, character_id, grade)`: membership by character, including offline characters. A character can belong to more than one faction.
- Own migrations in `coe_factions_schema_migrations`. Everything is created and edited through the admin panel (Groups tab).

## Rules

- An unlocked recipe is available to members of an **active** faction whose grade is greater than or equal to the recipe's minimum grade.
- An inactive faction does not unlock crafting or expose workbenches/stashes in the world, but its members are retained.
- A grade in use by any member cannot be removed (`grade_in_use`).
- Deleting a faction also deletes its member links.
- Limits in `config.lua`: 10 grades, 64 recipes, 8 stations of each type (`crafts` and `stashes`), 200 members per faction, 200 factions.

## API (server exports)

Returns are a single value or `{ error = code }`.

| Export | Who can call it | Description |
|---|---|---|
| `IsReady()` | anyone | Service is loaded. |
| `Categories()` | anyone | Available categories. |
| `List()`, `Get(id)` | `coe_admin`, `coe_crafting`, `coe_doors` | Read factions and their stations. |
| `Save(raw)`, `Delete(id)` | `coe_admin` | Manage factions. |
| `Members(id)`, `SetMember(id, characterId, grade)`, `RemoveMember(id, characterId)` | `coe_admin` | Manage members. |
| `Memberships(characterId)` | `coe_admin`, `coe_crafting`, `coe_doors` | Character's factions and grades. |
| `PauseMenuFaction(characterId)` | `coe_pausemenu` | First active faction `{ label, grade }` for the dossier; registered with `coe_pausemenu:RegisterFactionProvider`. |
| `RecipesFor(characterId)` | `coe_admin`, `coe_crafting` | Recipes unlocked across all of the character's factions: `{ recipe, factionId, grade }`. |
| `RecipesForFaction(factionId, characterId)` | `coe_admin`, `coe_crafting` | IDs of recipes unlocked for the character in that specific faction. |
| `CanCraft(characterId, recipeId)` | `coe_admin`, `coe_crafting` | Whether any of the character's factions unlocks the recipe. |
| `CanCraftInFaction(factionId, characterId, recipeId)` | `coe_admin`, `coe_crafting` | Whether the character belongs to the active faction and meets the recipe's minimum grade there. |

Events: `coe_factions:changed` (any change) and `coe_factions:ready`.

## Crafting use

Faction `crafts` and `stashes` stations are operated by `coe_crafting`. A faction workbench uses `exports.coe_factions:RecipesForFaction(factionId, characterId)` to build the list of recipes the member is allowed to craft and `CanCraftInFaction(factionId, characterId, recipeId)` to revalidate membership and minimum grade in `Begin` and `Complete`, consuming supplies from the player and the nearest faction stash (`stash:faction:<faction>:<stash>`).

## Security

- Writes are restricted to `coe_admin` (validated through `GetInvokingResource`); the panel requires the `coe_admin.groups.manage` permission and audits every change.
- Inputs are validated in `server/rules.lua` (pure and tested): IDs `[a-z0-9_]`, text without control characters or `<>`, consistent grades and crafting recipes.
- No police alert for now.

## COE OS

`TabletResources` (`coe_tablet`) can call `TabletInstances(playerId)` (active factions for the character) and `TabletCall(playerId, 'faction', 'overview', _, factionId)`: one app per faction, with position, members, and production unlocked for that position. Read-only; membership is revalidated on every call.

## Files

- `config.lua`: categories, limits, and who can read/write.
- `server/rules.lua`: validation and access rules (pure).
- `server/tablet.lua`: faction app logic in COE OS (`TabletInstances` and `TabletCall`).
- `server/persistence.lua`, `server/migrations.lua`: database.
- `server/main.lua`: faction cache and exports.
- `test/rules_test.lua`, `test/tablet_test.lua`: tests.
