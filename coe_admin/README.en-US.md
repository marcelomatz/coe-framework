# coe_admin

Administrative resource that consumes the shared Core and the `coe_inventory` exports. The panel provides an overview, item delivery by player ID, and management of persisted roles.

Replaces the framework's basic staff panel (`coe_staff`): it declares `coe_supervisor_replaces 'coe_staff'` and, while `coe_admin` is running, `coe_supervisor` does not start the basic panel. The basic panel's tools are included under **Staff tools** (`tools/`): Personal (noclip, invisible, invincible, coordinates, heal, revive, waypoint, and teleport; `/noclip`), Players (go to, bring, freeze, heal, revive, kick, item, money, and groups), Vehicles (temporary, registered, repair, refuel, clean, flip, and delete), World (time, weather, and announcement), and Businesses. Open them from the panel button, with `/staff`, or with F10 (for people with tools only). The basic panel's ACEs (`coe.staff.all`, `coe.staff.<module>`) remain valid, alongside `coe_admin.tools.all`, `coe_admin.tools.<module>`, and `coe_admin.root`; txAdmin admins receive all permissions. See [`UPGRADES.md`](../UPGRADES.md) for the complete map.

## Installation

Start `coe_logging`, `coe_notify`, `coe_database`, `coe_core`, and `coe_inventory` before the panel, and assign ACE permissions in `server.cfg`:

```cfg
ensure coe_logging
ensure coe_notify
ensure coe_database
ensure coe_core
ensure coe_inventory
ensure coe_admin

add_ace group.admin coe_admin.open allow
add_ace group.admin coe_admin.items.give allow
add_ace group.admin coe_admin.staff.manage allow
add_ace group.admin coe_admin.groups.manage allow
add_ace group.admin coe_admin.resources.manage allow
add_ace group.admin coe_admin.theme.manage allow
add_ace group.admin coe_admin.businesses.manage allow
add_ace group.admin coe_admin.players.view allow
add_ace group.admin coe_admin.news.manage allow
add_ace group.admin coe_admin.root allow
# Banco (alto nível): só root ou esta ACE explícita
# add_ace group.admin coe_admin.banking.manage allow
add_principal identifier.license:SUA_LICENSE group.admin
```

Open with `/coeadmin`. ACE names can be adjusted in `config.lua`. Avoid granting `coe_admin.staff.manage` to roles that should not administer other members.

## Permissions

- `coe_admin.open`: opens the overview.
- `coe_admin.items.give`: enables the player list and item delivery.
- `coe_admin.staff.manage`: enables role management within the manager's own permissions.
- `coe_admin.theme.manage`: the "Appearance" tab for choosing the global color theme (through `coe_ui`).
- `coe_admin.businesses.manage`: the "Businesses" tab (through `coe_businesses`; optional: without it, the tab displays a notice). Registers businesses by category (mechanics, shops, gas stations, restaurants, other): area (circle or polygon), stashes, crafting tables, showroom (mechanics), rules (`ownerAccess`, `priceMultiplier`, `clockRequired`, `clockOffsite`), and staff. Marking is done in the world: the panel disappears; walk to the location and use **E** (mark), **Enter** (finish the vertex list), and **Backspace** (cancel). Set the owner in the business panel itself, using the character ID (`/id` in game; the character can be offline). With `coe_crafting` started, the **Recipes and menus** tab creates custom recipes (ingredients, output, and duration) and menu types by category (e.g. Pizzeria, Burger Shop, Bar); under each business's **Menu** section with a workbench, choose a type and optionally customize that business's list.
  - **Properties** tab (through `coe_housing`), **Interior** section: catalog of native interiors with category filter, search, and thumbnails. "Use" assigns the interior to the property (and its interior point); "Visit and adjust" takes the admin to the interior in an isolated world, where **E** marks the point and **Backspace** cancels. "Generate missing thumbnails" visits each interior without a thumbnail, chooses an angle, and takes a screenshot with `screenshot-basic` (it must be started). "Custom point" keeps the interior marked manually (third-party MLO).
  - **Properties** tab, **Real estate** page: portfolio of all registered properties (interior thumbnail, type, occupancy, stash) with **Visit** (isolated world; `E`/`Backspace` returns), **Edit**, and **Contracts** (residents or business, daily rate, status, who is inside; **End** with confirmation, except initial and granted contracts). **Interiors** subpage: catalog with usage by property, **Visit**, and **Create property** (new registration already uses the interior; the door still needs marking).
  - **Properties** tab, **Illegals** page: hidden entrances to another environment (no map, no rent, outside the real-estate portfolio). Register with a door, interior, and stash like other properties, plus an owner and people with access (up to 10); the owner can also manage people with `/casa`.
  - **Doors** tab (through `coe_doors`): register locations (house, building, headquarters) with all their map/MLO doors (up to 12: single, double, garage door, gate). For each door, **Aim at door** hides the panel; aim with the camera, **E** marks each leaf (up to 2), **Enter** finishes, and **Backspace** cancels. Per door: name, type, locked-by-default, distance, and automatic locking. For the entire location: access (business with or without a point, faction with minimum grade, characters, items, and a `key` item with metadata `{"door":"<location id>"}`, which opens all doors) and password (only the hash is saved; remove or change it). In the **Location** tab, the owner (character) manages doors with `/casa`; each door can have exclusive access (up to 6 characters) and its own password.
  - **Amzg** tab (through `coe_amzg`; optional: without it, the tab displays a notice): virtual-store catalog for phone and tablet, in a grid with images and search. Each product points to an inventory item selected with a selector like the **Items** tab (categories, search, and images), with storefront name, category, price, order, and pause option.
- `coe_admin.players.view`: **Players** tab (read-only profile, also opened by clicking an online player). Shows, for each online or offline character: identity, account and sibling characters, identifiers (masked), groups, needs, inventory (through `coe_inventory:GetInventory('character:<id>')`, memory first), vehicles and keys, each vehicle's garage, properties, businesses (owner/employee), and economy (balance and latest 25 transactions). Each section loads independently: if a source is unavailable, only that section displays a notice. Each opening is audited (`admin_profile_viewed`) and limited to one query every 500 ms per admin. Profiles are read directly from the database (queries indexed by `character_id`, without cache); inventory comes from the service, which reflects changes not yet saved.
- `coe_admin.resources.manage`: "Framework" tab for restarting framework resources in dependency order (through `coe_supervisor`, which must be ensured in `server.cfg`). The panel may close during the restart.
- Shortcut: `Config.OpenKey` (default `F10`; `nil`/`false` disables it) opens/closes the panel; without ACE permission, nothing happens. Players can remap it under Settings > Key Bindings.
- `coe_admin.groups.manage`: **Groups** tab for managing **illegal factions** (gangs, mafias, ghettos, chop shops) from `coe_factions`: create/edit/remove factions with category, grades, permitted crafts (minimum grade per recipe), and members, including offline members (search by character name). Jobs are not managed here; they belong to businesses. Each change is audited (`faction_saved`, `faction_deleted`, `faction_member_set`, `faction_member_removed`). Game groups never grant access to the panel.
- `coe_admin.news.manage`: **Press** tab (through `coe_news`; optional: without it, the tab displays a notice). One tab per outlet (Weazel News, Rebel News), with sections: **Overview** (stories by status, reads, ads, total and last-30-day revenue, company cash, online and clocked-in staff, fleet); **Business and resources** (identity, owner, partners, area, newsroom point, stashes, and rules; shortcut to the Businesses tab when the admin also has `businesses.manage`); **Editorial line** (slogan, text, sections, and ad price per day); **Team and roles** (who is online, roles with salary and `news.*`/`business.*` permissions, hiring by search and dismissal; saved to `coe_businesses` without requiring business-management permission); **Equipment and fleet** (camera, microphone, and boom inventory in the outlet stash, restock and withdraw, which team member has each; vehicles from the outlet's business garages, add with suggestions and remove); **Advertising** (pending, live, and history; approve, reject with refund, take offline without refund, either for remaining days or the full amount, which is deducted from the outlet's cash); **Stories** (filter by status and search, read, take offline, republish, delete). Queries and actions go through `coe_admin:newsQuery`/`coe_admin:newsAction`; `coe_news` revalidates and audits (`news_*_admin`, `news_equipment_*`, `news_team_saved`). The Administrator role includes this by default.
- `coe_admin.deepweb.manage`: **DeepWeb** tab (through `coe_deepweb`, included in Administrator and root). **Sites**: create and edit `.onion` sites assembled from blocks (title, text, quote, notice, list, divider, link, and Deep Market listing), with description and keywords for DuckDark and an option to omit the site from the directory and search; system sites are view-only. **Vendors**: Deep Market NPC listings (item or service, category, price in currency, stock, pause). **Orders**: disputes (refund or pay the seller) and paid orders not delivered (cancel and refund). **Rabbit**: recent posts, with removal. **Contacts**: player messages to staff profiles (e.g. `fantasma.onion`); replies appear on the page for the handle, which receives a notification if online, and messages can be archived. Actions go through `coe_admin:deepweb` and the `Admin*` exports from `coe_deepweb`, which validate and audit.
- `coe_admin.root`: full access and permission to assign any configured role.
- `coe_admin.banking.manage`: **Bank** tab (through `coe_banking`), restricted to high-level staff: it cannot be included in any `Config.Roles` role or assigned through the panel; it comes from `coe_admin.root` or an explicit ACE. Edit credit-card tiers (name, minimum score, limit, points per $100, annual fee, free withdrawal; saved in the database and applied immediately) and, by customer (search by name or ID, online or offline): balance and relationship, grant credit at any tier with a custom limit and downgrade lock, adjust points, block/unblock cards and renew validity, grant a loan (amount, total interest suggested by score, weekly installments with automatic debit; late payments accrue daily interest based on score), and forgive a loan balance. **Businesses** subtab: business accounts (cash for each business) with balances, cards, and loans; per account, statement for a period with the person who performed each operation, staff cash adjustment, and business cards (daily limit, block, unblock, validity). **Requests** subtab: business loan request queue with borrowers' average score and suggested interest; approve (adjusting interest and installments) to credit business cash, or reject with a reason. The **Businesses** tab preserves partners set by the owner on the tablet; changing or removing the owner dissolves the partnership. Every query and action is audited (`bank_admin_view`, `bank_admin_<action>`).
- `coe_admin.crypto.manage`: **Crypto** tab (through `coe_crypto`, included in Administrator, `coe_admin.banking.manage`, and `coe_admin.root`). Displays the live overview (current quote, buy/sell price with spread, change, net flow, exchange reserve, and total mined), allows setting the quote immediately (`AdminSetPrice`), editing and saving all `CryptoConfig` settings (currency identity, wallet limits and import protection, transfer fees and limits, exchange parameters and price formation, issuance and mining cap; saved in `coe_crypto_settings` and applied immediately), or restoring `config.lua` defaults (`AdminResetSettings`).

Roles defined in `Config.Roles` are saved by license in the MariaDB `coe_admin_staff` table, created by the versioned migration in `server/migrations.lua` (tracked in `coe_admin_schema_migrations`). A manager can assign only roles whose permissions they already have; only `coe_admin.root` can assign any configured role. The MVP starts with an empty table and does not import old KVP data. Actions are reauthorized on the server regardless of NUI state.

Item grants accept optional JSON metadata, validate the item against the `coe_inventory` catalog, require the recipient to have an active character, and persist through the `AddItem` export. The inventory's `GetPlayerInventory(source)` API resolves identity through Core; the panel does not construct inventory IDs or use license as the character key. Licenses maintained by the admin are used only for internal staff identification. The server imports `Core` for shared validation and rechecks all permissions server-side.

Item-grant and role-management actions generate structured audit events through `coe_logging`, without persisting license, item metadata, or player names in the log context. Denied panel access uses `coe_notify` for local feedback.

## Script map

- `config.lua`: command, ACE permissions, and role catalog.
- `server.lua`: server-side authorization, panel data projection, item grants, role management, factions, and auditing.
- `server/persistence.lua`: staff schema and MariaDB adapter.
- `server/directory.lua`: character search by name or ID (pure and testable).
- `server/profile.lua`: player profile loading by section (testable with a fake database).
- `server/analytics.lua`: Overview aggregates and background-refresh cache.
- `server/staff.lua`: pure business-team editing rule (Businesses and Press tabs), tested in `test/staff_test.lua`.
- `client.lua`: command, NUI integration, requests, and results.
- `html/`: administrative UI (`news.js`: Press tab).
- `fxmanifest.lua`: dependencies, script order, and assets.

## Character search and analytics

- Online players show the active character name (`coe_core:GetActiveCharacter`, memory, no database); the account appears as secondary text.
- Owners and employees are chosen by name or ID search. Search is prefix-based (minimum 2 characters, up to 3 terms), uses the `first_name`/`last_name` indexes (migration v7) and the unique `state_id` index, with `LIMIT`. Online characters are read from memory first.
- Cost-control layers: 30-second TTL cache (maximum 200 entries, including empty results), minimum per-admin interval on the server, and 300 ms debounce on the client.
- A regular MariaDB view is not materialized and does not reduce cost; therefore, this design uses indexes and an in-memory cache.
- Analytics: nearly everything is calculated from data already in memory. Character count and economy summary are aggregate queries cached for 60 seconds and refreshed in the background (they never block panel opening).
- Consumed exports: `coe_businesses:DutySummary`, `coe_economy:Summary` (`coe_admin` only).

## Tests and gaps

Run the tests in the `test` folder from the resource folder (`lua test\staff_test.lua`, `persistence_test.lua`, `directory_test.lua`, `analytics_test.lua`, `profile_test.lua`). Tests cover schema, reading/writing/removal, and failure propagation through a fake provider. Authorization handlers, NUI, administrative actions, and inventory integration still need dedicated tests; online actions should also be validated in FXServer. See [TEST_COVERAGE.md](../TEST_COVERAGE.md).
