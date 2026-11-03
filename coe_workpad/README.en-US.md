# coe_workpad

Basic framework work tablet, focused on jobs and businesses. Opens with **F3** (each player can change it in Settings > Key Bindings > FiveM, "Open work tablet"), with `/trabalho`, or by using the item, and only if the `business_tablet` item (Business Tablet) is in inventory.

Home screen with clock, current duty status (clocked in or free job), and apps in two sections:

- **Work**
  - **Clock-in**: where the character is clocked in and for how long, button to clock out, and work locations (owner or staff) with role, role salary, clock-in rule, and GPS to the clock-in point.
  - **Free jobs** (`coe_jobs`): jobs open to any citizen, with pay, vehicle deposit, what you have already earned, unmet requirements, and GPS to the contact. Filter "Available to me".
  - **Career** (`coe_jobs`, `html/career.js`): level, reputation, skills, and each job with the "How it works" guide.
- **Businesses**: one app per business the character owns or works for (`coe_businesses`, `html/tablet_app.js`), with overview, finances, staff, partners, access, structure, fleet, properties, and tabs registered by other resources. Access follows business rules (owner and managers remotely; the rest of the staff must be clocked in).

Apps from stopped resources do not appear; apps the player loses while the tablet is open close automatically. Up to 6 apps remain open in memory (state is restored when switching apps). Esc returns home; on the home screen it stows the tablet. Entering a vehicle, dying, or opening the pause menu also stows it.

## Apps from other resources

The tablet follows the same contract as package tablets, so an app written for one works on the other:

- Server: the resource exposes `TabletCall(playerId, appId, action, payload, instance)` (`TabletInstances(playerId) -> { {id, label, category} }` for one app per instance). The tablet revalidates the app list on every action, limits the rate (`CallCooldownMs`) and payload size (`MaxPayloadBytes`), and passes the instance from the server, never from the payload.
- Interface: the script (`nui://<resource>/html/<arquivo>.js`) calls `window.CoeTablet.register(id, function (container, api) { ... })`. The `api` has `call(app, action, payload)`, `status(texto, tipo)`, `errorText(codigo)`, `waypoint(x, y)`, and `refresh()`. Visual components are the `tb-*` classes from `nui://coe_ui/html/apps.css`.
- A new app is added to `config.lua` (`Apps`): `resource`, `script`, `group`, `order`, `icon`, and, if applicable, `instances`.

Access: `coe_jobs` (Career app) and `coe_businesses` (Business app and clock-out) include `coe_workpad` in their defaults (`TabletResources`, `ClockResources`). The Clock-in app only clocks out the current player's character.

## Packages that take over the tablet

A package with a complete tablet calls the `Yield()` export on startup (and again on `onResourceStart` of `coe_workpad`). The basic tablet closes and stops opening (key, command, and item) until the calling resource stops; it then returns automatically. Grant the capability in `server.cfg`:

```
add_ace resource.<nome> coe.workpad.yield allow
```

The framework does not name the package: the resource taking over is determined at runtime. `Status()` returns `{ active, yieldedBy }`.

## Configuration

`config.lua`: item, command and key, sections, apps, business category labels, rate and payload limits, `Yield` ACE, and tablet-in-hand animation.

## Interface

Landscape device in the `coe_ui` visual style (frame and chamfered panels, colors only from tokens), following the server theme and player color (`@coe_ui/theme_bridge.lua`). Clocking out is confirmed with `CoeUI.confirm`.

## Tests

```
cd coe_workpad
lua test/rules_test.lua
lua test/server_test.lua
```

`server_test.lua` exercises the server with simulated inventory, businesses, and jobs: required item, app list with instances, forwarding to the app resource, access revalidated on every action, rate and payload limits, stopped resource, Clock-in (time and clock-out), Free jobs, item use, and a package's `Yield`.
