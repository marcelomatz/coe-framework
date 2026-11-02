# coe_tablet

> Upgrade to the basic work tablet (`coe_workpad`): `coe_supervisor` does not start the basic resource while this one is running. The basic resource's **Clock-in** and **Free jobs** apps are in the Work group (`server/work.lua`, `html/duty.js`, `html/freejobs.js`), and `/trabalho` also opens the tablet. Details in [`UPGRADES.md`](../UPGRADES.md).

**COE OS**: the character's tablet and control center for everything they have. One tablet brings together all apps the player can see; each system is an app, and each business or faction they belong to activates its own app.

Replaces the framework's basic work tablet (`coe_workpad`): on startup, and whenever `coe_workpad` restarts, it calls the `Yield` export (ACE `coe.workpad.yield`, granted by the framework in `CoeAccess.FirstParty`). The basic resource closes its screen and stops opening (F3 key, `/trabalho`, and `business_tablet` item) until `coe_tablet` stops. The Career and Business apps are the same in both; Clock-in and Free jobs are only in the basic resource.

- Sections (`Groups`): **Personal** (Bank, Vehicles, Home), **Applications** (Store and installed apps), **Work** (job apps), **Businesses** (one app per business), and **Illegal** (Hideout, one app per faction). Each app specifies its section in `group`.
- `everyone = true`: app for every character (Bank, Vehicles), with no job or item required.
- `instances = true`: the resource exposes `TabletInstances(playerId) -> { {id, label} }` and the tablet creates one app per instance (ID `<app>:<instance>`). `TabletCall` receives the instance as its 5th argument and revalidates access on every action.
- **Device**: same glass as the smartphone (`coe_phone`: light edge, reflection, chamfered corners), in landscape 16:10, with stow and brightness buttons along the top edge. No keyboard and no hacker-laptop look (`coe_deepweb`), but the same screen: wallpaper, status bar (COE OS, job profile, time, Wi-Fi, battery, stow, and control center), and chamfered `coe_ui` panels.
- **Home**: widgets on the left (clock and date, total and open apps, recent apps) and, on the right, search and apps by section (`Groups`) in colored tiles (`icon` and `color` for each app in `Config.Apps`; unknown icons use the app name's initial).
- **Dock**: up to 6 pinned apps at the bottom (default: the player's first 5 apps). Right-click an icon to pin or unpin it. The last button opens **open apps**.
- **Multitasking**: each open app keeps its own state when returning home or switching apps (up to 6 in memory; the oldest closes). Apps stay open when the tablet is stowed, and it reopens to the last-used app. **‹** returns home, **✕** closes the app; the open-apps screen lets you switch, close one, or close all. Apps for which the player has lost access (job, business) close automatically.
- **Control center**: brightness, interface size (S, M, L), and wallpaper (same options as the smartphone). Saved per player in local KVP (`coe_tablet:prefs`), validated in `shared/prefs.lua` (test: `lua test\prefs_test.lua`).
- ESC closes the control center or open-apps screen; inside an app it returns home; on the home screen it stows the tablet.
- Apps from other resources register with `CoeTablet.register(id, render(container, api))` and use `tb-*` classes (`nui://coe_ui/html/apps.css`, same as smartphone `coe_phone`).

- Open: `/tablet` or **F3** (`OpenKey`). Each player can change the key in Settings → Key Bindings → FiveM (`Abrir tablet (COE OS)`). Without apps for the player's job, the tablet does not open. The `coe_tablet.all` ACE shows all apps (admin/testing).
- Apps: `config.lua` (`Apps`) connects each app to jobs (`jobs`), minimum grade (`minGrade`), a responding resource (`resource`), and an interface script (`nui://<resource>/html/<arquivo>.js`).
- Security: the server revalidates job and grade on every action (`coe_tablet:call`), limits the rate (`CallCooldownMs`) and payload (`MaxPayloadBytes`). The app resource exposes `TabletCall(source, appId, action, payload, instance)` and only accepts calls from `coe_tablet`.
- Workshop app (`coe_mechanic`): scan the nearby vehicle, view part wear, replace a part, or perform a full service. Requires being within `TabletRadius` of the vehicle.
- **Career** app (`coe_jobs`, all): history of free jobs — career level, reputation, skills, and each job's bonuses, requirements, and GPS.
- **Bank** app (`coe_banking`): balance, statement, transfer, cards, bill, and loans.
- **Vehicles** app (`coe_garages`): character's vehicles, state, garage or location, with GPS.
- **Business** apps (`coe_businesses`, `instances`): one per business the character owns or works for. The owner and roles with `business.remote` (managers) manage remotely; the rest of the staff must be clocked in at that business (unless clock-in is not required). See the `coe_businesses` README.
- **Faction** apps (`coe_factions`, `instances`): one per active faction of the character, with members, roles, and unlocked production (read-only).
- **Home** app (`coe_doors`): appears for owners of any door location. Apps with `ownerCheck = true` only appear when the app resource's `TabletVisible(playerId, appId)` export returns `true` (profile's `canSee` function, rechecked on every action).
- **Hideout** app (`coe_housing`): lets the owner of an illegal property choose who else has access (`ownerCheck`).
- **Rentals** app (`coe_housing`): rental contracts for the player and their businesses, with status (current, overdue), daily rate, cycle, next charge, and GPS button (`ownerCheck`).
- **Store** and installable apps (`coe_apps`, `ownerCheck`): Store is built in; Jobs, Classifieds, and Insta appear after installation. See the `coe_apps` README.
- Additional app API: `api.camera()` (tablet screen is hidden while the player takes a photo, then returns `{ ok, image }`), `api.upload(image)` (uploads the photo to the server outside the action channel and returns `{ ok, token }`), `api.refresh()` (recalculates the home screen without closing the open app), and `api.icon(node, app)`. Responses with `data` larger than `LatentReplyBytes` (e.g., photos) are sent through a latent event.
- Shortcuts: each `Shortcuts` entry creates a command, without requiring an item, that opens the same tablet directly in the first listed app the player can see (e.g., `/casa` opens Home or Hideout; **‹ Home** shows the other apps). If none of the shortcut's apps are visible, the player receives that shortcut's `deniedMessage`.
- To create an app: register it in `Apps`, create a script that calls `CoeTablet.register(id, (container, api) => ...)`, and implement `TabletCall` in the resource.
- Work app access: by business category while on duty (`categories`, e.g., `mdt` for someone clocked in at a `police` business), by instance (`instances`, e.g., `business` and `faction`), or by `coe_core` job group (`jobs`, e.g., `workshop` for `mechanic` in `coe_core/config/groups.lua` or the mechanic shop owner/staff).
