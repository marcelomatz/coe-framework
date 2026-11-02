# coe_doors

Doors and locks for map doors and MLOs. Registration is in the admin **Doors** tab (`coe_doors_registry`).

- **Location:** each record is a location (house, building, headquarters) with up to 12 doors (`Limits.MaxEntries`). Access, PIN, and key belong to the location and apply to all its doors; each door locks and unlocks separately.
- **Door:** type (single, double, garage door, gate), 1 or 2 leaves captured by aiming at the object, plus its own name, distance, automatic lock, and default state. The client registers leaves in the game's door system and applies the locked/unlocked state for everyone. Garages and gates accept leaves farther apart (`WideLeafGap`) and distance up to 12 m (from inside a vehicle); when unlocked, they remain open (on foot or in a car) until closed by someone.
- **Interaction:** near the door (1 to 6 m; garage/gate up to 12 m), the standard `coe_ui` notice shows its state and **E** to lock/unlock (open/close for garages and gates). The server checks distance, access, and rate limit.
- **Access** (any rule is sufficient, for every door at the location):
  - **Character:** list of characters (search by name or ID, including offline).
  - **Business/corporation:** owner, partners, and staff; optionally only while clocked in (`coe_businesses`).
  - **Faction:** members with minimum grade (`coe_factions`, `ReaderResources`).
  - **Items:** up to 4 items that open the door (e.g. access card).
  - **Key:** `key` item with metadata `{"door":"<location id>"}` (issued from the admin **Items** tab); opens every door at the location.
- **PIN:** numeric keypad (4 to 8 digits) for those without rule-based access. Stored only as salted SHA-256; after `Pin.MaxAttempts` (5) errors, the player waits `Pin.LockoutSeconds` (60 s) at that location (audited: `door_pin_lockout`).
- **Owner:** character set in admin (**Location** tab). Opens all doors at the location and manages each door on the tablet (`/casa`, **Home** app).
- **Exclusive door:** only the owner and up to 6 people (`Limits.MaxEntryCharacters`) can open it; the location key, access rules, and PIN do not apply.
- **Door PIN:** required to unlock even for people with access (including the owner); locking does not require it. If both location and door PINs are set, the keypad requests them in sequence. Both are stored only as hashes.
- On the tablet, the owner can make doors exclusive, add people by ID (`/id`, must be in the city), remove people, and set/remove each door's PIN (audited: `door_owner_<action>`). General location access is managed only in admin.
- **Automatic lock:** optional, per door, in seconds (up to 1 hour) after unlocking. A new interaction with the door restarts the timer.
- **State:** in memory. On server (or resource) restart, each door returns to its registered default ("Locked by default").

## Exports (server)

- `coe_admin` only: `List()`, `Save(local)` (`isNew` rejects a duplicate ID), `Delete(id)`.
- Unrestricted: `IsLocked(id)`, `SetLocked(id, locked)` (robberies, events, business scripts), `CanAccess(playerId, id)`, `IsReady()`. `id` is `"<location>:<door>"` for one door or `"<location>"` for all (`IsLocked` is `true` only if all are locked).
- `coe_tablet` only: `TabletVisible(playerId)` (owns a location) and `TabletCall(playerId, 'home', action, data)` with `list`, `restrict`, `allow` (`stateId`), `revoke` (`characterId`), `pin`, `clearPin`.

Legacy registrations (one door per record) are read as a location with a `main` door; saving converts them to the new format.

Errors: `invalid_id`, `invalid_label`, `invalid_doors`, `invalid_entry`, `duplicate_entry`, `entry_limit`, `invalid_distance`, `invalid_autolock`, `invalid_access`, `invalid_pin`, `invalid_owner`, `duplicate_id`, `door_limit`, `unknown_door`, `not_ready`, `forbidden`. Tablet: `not_owner`, `unknown_entry`, `target_not_found`, `target_not_online`, `is_owner`, `already_allowed`, `allowed_limit`, `unknown_person`, `no_character`.

## Script map

- `config.lua`: limits, distances, PIN, and key item.
- `server/rules.lua`: registration validation, PIN, and access evaluation (pure, tested in `test/doors_test.lua`).
- `server/sha256.lua`: pure Lua SHA-256.
- `server/persistence.lua` / `server/migrations.lua`: `coe_doors_registry` table (JSON per location).
- `server/main.lua`: state, network events, automatic locking, and exports.
- `client/main.lua`: game door system, notice, and keypad.
- `html/`: PIN keypad, standard notice (`coe_ui`), and tablet **Home** app (`tablet_app.js`).

## In-game validation

1. `ensure coe_doors` (already included in `ensure [coelho]`).
2. Admin → **Doors** → **+ New** → **Doors** tab → **Aim at door**: aim, press **E** for each leaf, then **Enter**. Use **+ Add door** for rear doors, garage, gate, etc., and choose the type for each one.
3. Set access and/or PIN and save. Walk near any door at the location: the notice shows the state; **E** toggles only that door.
4. Set an owner (**Location** tab). As that character, run `/casa`: make a door exclusive, add someone by `/id`, and set a PIN. Confirm the location key does not open the exclusive door and the PIN is requested when unlocking.
