# coe_businesses

MariaDB registry of server businesses (mechanics, shops, gas stations, restaurants, police stations, hospitals, media, and others). Stores category, area, operating points (stashes, crafting tables, showroom), and category-specific rules. Editing is done in the **Businesses** tab of the basic staff panel (`coe_staff`) or a package's panel.

## Access from other resources

Restricted exports accept the patterns in `config.lua` (framework resources only) and, for packages and third-party scripts, the ACE on the resource principal, granted in `server.cfg` without editing the framework:

```cfg
add_ace resource.meu_script coe.businesses.write allow
add_ace resource.meu_script coe.businesses.permissions allow
```

Capabilities: `coe.businesses.write`, `.clock`, `.tablet`, `.permissions`, `.payroll`, `.admin`, and `.extend` (tabs and providers; `coe.businesses` grants all).

## Model

```lua
{
  id = 'bennys', category = 'mechanic', label = "Benny's", enabled = true,
  area = { kind = 'circle', x, y, z, radius }           -- ou { kind = 'polygon', points = {{x,y}...}, z, height }
  stations = { showroom = {x,y,z,radius}, crafts = {...}, stashes = {...}, clocks = {...} },
  rules = { ownerAccess = true, priceMultiplier = 1.0, clockRequired = true, clockOffsite = false, multiJob = true },
  owner = { characterId = '3', name = 'Fulano' },        -- opcional
  partners = { { characterId = '7', name = 'Sicrano' } } -- sócios (até Limits.MaxPartners)
}
```

Categories, supported points per category, and rule schemas are defined in `config.lua` (`Categories`, `Rules`, `Limits`).

## Exports (server)

- Read: `IsReady()`, `Categories()`, `RuleSchema()`, `List(category?)`, `Get(id)`.
- Write (ACE `coe.businesses.write`; default callers: `coe_shops`, which seeds shops, and the `coe_staff` panel; panels and packages that seed businesses receive the ACE in `server.cfg`): `Save(raw, by)`, `Seed(raw)` (creates only if not already present), `Delete(id, by)`.
- Access and team: `Access(businessId, characterId)`, `Partners(businessId)`, `Debtors(businessId)`.
- Roles: `Permissions()`, `RegisterPermissions(list)`, `Grades(businessId)`, `GradeOf(businessId, characterId)`, `Can(businessId, characterId, permission)`, `Salary(businessId, characterId)`, `Payroll(businessId)`.
- Clocking in: `Clock(source, businessId, stationId)`, `ClockIn(...)`, `ClockOut(...)`, `IsOnDuty(businessId, characterId)`, `CurrentDuty(source)`, `DutySummary()` (`coe.businesses.admin` only).
- Tablet: `TabletInstances(playerId)`, `TabletCall(playerId, appId, action, payload, instance)` (`coe.businesses.tablet` only).
- Extensions (ACE `coe.businesses.extend`): `RegisterTab(def)` and `RegisterProvider(kind, def)`; see the end of this file.

> **Cross-resource return values:** `Save`, `Seed`, `Delete`, `ClockIn`, `ClockOut`, `Clock`, and `TabletCall` return one value: the result or `{ error = code }` (as in `coe_crafting`, `coe_garages`, and `coe_factions`).

Server events: `coe_businesses:ready`, `coe_businesses:changed` (id), and `coe_businesses:dutyChanged` (source, businessId, onDuty, reason).

## Staff duty

Each business has clock-in stations (`stations.clocks`) and duty rules: `clockRequired` (default true: owner and staff can only operate and manage **that business** while clocked in; an owner of multiple businesses clocks in at each one) and `clockOffsite` (default false: leaving the area ends the shift; when enabled, the shift remains open outside the area). The `multiJob` rule (default true; **false** for police and EMS) controls whether staff can hold other jobs: when disabled, it is exclusive, and `Save` rejects (`multiple_jobs`) anyone already on staff at another active business, and vice versa. The owner does not count as a job, so may own any number of businesses. Regardless of this rule, a player can be clocked in at only one business at a time (`on_duty_elsewhere`). Duty state is held in memory (`server/duty.lua`) and ends when the player leaves the server. Exports: `ClockIn(source, characterId, businessId, at, atStation)` and `ClockOut(source, reason)` (`WriterResources`, or `ClockResources`/ACE `coe.businesses.clock`, such as the work tablet `coe_workpad`, which clocks out the caller's own player; the caller validates staff membership and location), `IsOnDuty(businessId, characterId)`, and `CurrentDuty(source)`. Reasons for ending a shift: `clock_out`, `left_area`, `business_closed`. Tests: `lua test/duty_test.lua`.

## Notes

- Categories and their consumers: `mechanic` (`coe_mechanic`), `shop`, `restaurant`, and `other` (workbenches and stashes through `coe_crafting`), `gas_station` (stashes and duty point for now), `police` (`coe_police`, `coe_mdt`, `coe_dispatch`), `ems` (`coe_ems`, `coe_dispatch`), and `media` (`coe_news`). `ruleDefaults` changes defaults by category: police and EMS start with `multiJob = false`; media starts with `clockOffsite = true`.
- The `media` category (Media: stashes and duty point; duty remains active outside the area) is used by `coe_news` outlets (Weazel News and Rebel News), with `news.*` permissions.
- The owner is part of the business: `owner = { characterId, name }` (optional), set by `coe_admin` using the character's `stateId`, online or offline. `coe_mechanic` grants the owner full access to the shop tablet.
- `coe_businesses` table (team, roles, partners, and rules are stored in JSON `data`), migrations tracked in `coe_businesses_schema_migrations`.
- Tests: `lua test/registry_test.lua`, `access_test.lua`, `duty_test.lua`, `grades_test.lua`, and `tablet_test.lua`.

## Crafting stations and isolation between businesses

The `crafts` stations for `restaurant`, `shop`, and `other` businesses become `coe_crafting` workbenches (bridge in `coe_crafting\server\bridge.lua`). The mechanic shop continues to use the `coe_mechanic` flow.
Access is per business: owner (`ownerAccess`) or employee registered on **that business's team** (`staff`, **Team** tab in `coe_admin`) and clocked in (one active duty point per player; see `IsOnDuty`; `clockRequired = false` waives clock-in, but only for the business's own staff). A job does not grant access. An owner or employee of one business cannot operate at another; recipes, benches, and stashes are separated by business and category. Details and limitations in `coe_crafting\README.md`.

## Team and duty (all businesses)

- `staff`: list of `{characterId, name}` per business (maximum `Limits.MaxStaff`), edited in the **Team** tab in `coe_admin`. Businesses never share staff, even if they have the same job. Migration: anyone previously on staff by job must be added to the team again.
- `Access(businessId, characterId)` export → `{ owner, staff, partner, canClock, canWork }`; this is the only decision source used by `coe_mechanic` and `coe_crafting`.
- Partners (`partners`): share responsibility for business debts with the owner (business loans from `coe_banking`). Partner status grants neither work access nor job status. They join only by invitation from the owner on the tablet, with acceptance; the owner can remove them. Exports `Partners(businessId)` and `Debtors(businessId)` (owner first, then partners; empty if there is no owner). `coe_admin` preserves the list when saving and clears it when the owner changes.
- `Clock(source, businessId, stationId)` export (restricted by `coe.businesses.clock`), `/ponto` command, and prompt (E) at non-mechanic business clock-in points. At these businesses, stashes (`stashes`) also have an (E, "Open stash") prompt: only the owner and staff, near the point, opened through `coe_inventory`'s `OpenStash` with ID `stash:business:<business>:<stash>`; `coe_crafting` uses the nearest stash as the ingredient source. When someone leaves the team, their duty ends (`not_staff`).

## Roles, salaries, and permissions

Jobs, roles, and salaries live **inside the business** (`coe_jobs` handles only independent jobs). Each business has `grades` (up to `Limits.MaxGrades`): `{ id, label, level 0..99, salary, permissions[] }`; IDs and levels are unique and the lowest level is the entry role. Each staff member has a `grade`; without one, they receive the entry role, and a nonexistent role is rejected (`invalid_staff_grade`). Invalid data returns `invalid_grades`. Edited under **Roles** and **Team** in `coe_admin`. Nothing is shared between businesses, including roles.

Permissions use the `prefix.action` format. The base catalog is `business.funds`, `business.staff`, `business.fleet`, and `business.remote` (remote management through the tablet); resources with `coe.businesses.permissions` (default: `coe_economy` and `coe_shops`; packages receive the ACE) register their permissions with `RegisterPermissions({ { name = 'police.arrest', label = 'Arrest' } })` (the prefix is the resource name without `coe_`).

- Read: `Permissions()`, `Grades(businessId)`, `GradeOf(businessId, characterId)`, `Can(businessId, characterId, permission)` (the owner has all permissions when `ownerAccess` is enabled; staff use their role and must be on duty when `clockRequired`).
- Payroll (`coe.businesses.payroll`; default: `coe_economy`): `Salary(businessId, characterId)` and `Payroll(businessId)`.
- Server events: `coe_businesses:staffChanged` (id, characterId, change `added|removed|grade`, grade) and `coe_businesses:gradesChanged` (id).
- `police` (Police stations) and `ems` (Hospitals) categories, consumed by `coe_police` and `coe_ems`. Tests: `lua test/grades_test.lua`.

## Business tablet

The tablet `business` app (`html/tablet_app.js`, logic in `server/tablet.lua`, `TabletCall` export restricted to `TabletResources` and ACE `coe.businesses.tablet`). Hosted by the basic work tablet (`coe_workpad`) or a package tablet. Each business the character owns or works for becomes an app (`TabletInstances` export). The business is the app instance and is revalidated for each action: the **owner** and roles with the `business.remote` permission (managers) manage it remotely, each with their own role permissions; the rest of the team must be **clocked in** at that business (unless clock-in is optional). Anyone who is neither owner nor employee gets `forbidden`.

- Overview: role, owner, team, cash (only with `business.funds`), and rules.
- Tabs from other resources: registered with `RegisterTab` (see below), displayed after Overview. The `tab` action forwards to the resource's `handler` export along with the app's business and caller; the resource checks access for each operation. A tab can replace one of the built-in tabs (`replaces`, e.g. business banking instead of Finance); if it becomes unavailable, the replaced tab returns.
- Finance (`business.funds`): society balance, payroll, entries, deposits, and withdrawals through `coe_economy`.
- Team: list (salaries visible only with `business.staff` or `business.funds`); hiring by online citizen ID, changing roles, and dismissal require `business.staff`. A non-owner can only change roles below their own. Hiring is an offer: the citizen sees a confirmation and has `OfferSeconds` (60 s) to accept; one pending offer per person. On acceptance, everything is revalidated and saved with `Save`, which applies `multiJob`.
- Partners: list visible to all on-duty staff; only the owner can invite (online citizen ID, same offer and acceptance period as hiring, with notice that partners are liable for business debts) and remove. Existing debts remain with those who were partners when the loan was taken out.
- Access (`business.staff`): read-only matrix of roles and permissions.
- Structure: area and points (clock-in, stashes, benches, showroom) with GPS button. Visible to all staff on duty.
- Fleet: vehicles in business garages, status, and current user, from the registered `fleet` provider (`RegisterProvider`). Releasing/blocking access for staff requires `business.fleet`. Without a provider, `garages_unavailable`.
- Properties: commercial properties from the `properties` provider (rented or admin-granted) and garages from the `fleet` provider.
- Future phases: Police and EMS apps in COE OS (#229), business levels (#172), and card terminal (#262). Tests: `lua test/tablet_test.lua`.

## App extensions (tabs and providers)

Resources with the `coe.businesses.extend` ACE (default: `coe_shops`) integrate with the app without editing the framework. Registrations disappear when the resource stops; register again on `coe_businesses`'s `onResourceStart`.

```lua
exports.coe_businesses:RegisterTab({
	id = 'fuel', label = 'Posto', order = 10,                    -- abaixo de 50 fica antes das abas do pacote padrão
	script = 'html/business.js', css = 'html/business.css',      -- caminhos dentro do próprio resource
	handler = 'BusinessTablet',  -- (playerId, characterId, businessId, payload) -> resposta da aba
	visible = 'IsStation',       -- opcional: (businessId) -> boolean
	replaces = nil               -- opcional: id de uma aba daqui (ex.: 'finance')
})
exports.coe_businesses:RegisterProvider('fleet', { list = 'BusinessFleet', setStaff = 'SetFleetStaffAccess' })
exports.coe_businesses:RegisterProvider('properties', { list = 'BusinessProperties' })
```

The tab script registers in the tablet browser:

```js
window.CoeBusinessTabs = window.CoeBusinessTabs || {};
window.CoeBusinessTabs.fuel = {
	errors: { not_a_station: 'Este negócio não é um posto.' }, // opcional: textos dos códigos de erro
	unavailable: [],             // opcional: códigos que escondem a aba (a substituída volta)
	state: (result) => result,   // opcional: o que guardar da resposta do `overview`
	render(root, state, api) {}  // api: request(op, payload) -> Promise, update(state), render(), status(texto, tipo),
	                             // errorText(código), gps(x, y, texto?), channel = 'tablet'
};
```

Registration errors: `forbidden`, `invalid_tab`, `tab_taken`, `too_many_tabs`, `invalid_provider`.
