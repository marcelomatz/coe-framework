# coe_garages

Business-independent garages, registered in the admin **Garages** tab (`coe_garage_registry`). Each garage has 1 to 8 spaces (opening, exit, and storage point; the marked direction is the exit heading) and an optional blip.

Types:

- **Public** (`public`): stores a player's personal vehicles. Level 1: 1 car + 1 motorcycle (`config.lua`, `Levels`); the level is a hook for future upgrades. Blip enabled by default.
- **Business** (`business`): a business fleet. The owner set on the business authorizes each vehicle for individuals (by stateId) and/or the staff. "Staff" means people on the business team who can operate according to `coe_businesses` (`Access`: clocked in when `clockRequired`).
- Fleet purchase by another resource (`FleetResources`, currently `coe_fuel`): `AddBusinessFleet(businessId, model, staff)` creates the vehicle in the business's first business garage (without one: `no_fleet_garage`) and, with `staff = true`, grants access to the team.
- Business tablet: the `fleet` provider is registered with `coe_businesses:RegisterProvider` (and registered again when `coe_businesses` restarts). `BusinessFleet(businessId)` and `SetFleetStaffAccess(businessId, vehicleId, enabled)` serve only `BusinessResources` (`coe_businesses`), which verifies clock-in and the `business.fleet` permission.
- **Organization** (`job`): police, hospital, fire department, etc. Anyone with one of the specified jobs can use all vehicles.

Residential garages are planned for later as a new type.

Usage: on foot, `E` opens the garage; in a vehicle, `E` stores it. Retrieval gives the player a key; storing a fleet vehicle revokes its keys.

Fleet management through admin: in a saved business or organization garage, the "Fleet" section lists vehicles and adds them from the catalog (with an image from docs.fivem.net; addon vehicles without an image show the model) or removes vehicles that are stored. You cannot change the type or delete a garage that still has a fleet.

Command (ACE `command.coe_fleet_add`): `coe_fleet_add <garage> <model> [plate]`.

Tables: `coe_garage_registry`, `coe_garage_slots`, `coe_fleet` (`garage_id`), `coe_fleet_access`.

## COE OS

The **Vehicles** app in `coe_tablet` (`html/tablet_app.js`, `server/tablet.lua`, export `TabletCall`, read-only): the character's vehicles with state, plate, mileage, and the garage where they are stored or their current position, with a GPS button. Tests: `lua test/registry_test.lua`, `test/rules_test.lua`, and `test/tablet_test.lua`.
