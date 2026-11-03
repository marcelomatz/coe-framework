# coe_ems

Health and EMS. A package separate from the police; plug-and-play on top of `coe_businesses`. **Team, positions, and salaries live in the business** in the `ems` category (Hospitals): the doctor must be clocked in at an `ems` business and have the required position permission. Payment comes from the society account (`coe_economy`).

## Position permissions

Registered in `coe_businesses` at startup (`RegisterPermissions`): `ems.revive` (revive), `ems.treat` (treat), `ems.records` (view medical records). The business owner has all of them. Set them in the **Positions** tab of `coe_admin`.

## Patient states

`healthy` → `injured` → `unconscious` → `dead`. The client only reports what the game shows (healthy/injured/unconscious, see `EmsRules.CanReport`); dying from bleeding (`BleedoutSeconds`) and reviving are server decisions. Reviving requires `unconscious` (`dead` only with `ReviveDead`); treating requires `injured`. The deceased use `/respawn` and return to the first `ems` business with a circular area (or `Respawn`).

## API (server)

Single value or `{ error = code }` (`forbidden`, `not_on_duty`, `not_ems`, `invalid_state`, `too_far`, `unknown_patient`...).

- `State(source)`; `SetState(source, state)` (only `StateResources`).
- `Revive(doctor, patient, detail?)`, `Treat(...)`, `Records(doctor, characterId, limit?)` (only `ActionResources`). The server validates character, clock-in, category, position, state, and distance (`ActionRange`).
- Commands: `/reanimar <id>`, `/tratar <id>`, `/respawn`.
- Server events: `coe_ems:stateChanged` (source, characterId, from, to) and `coe_ems:treated` (doctor, patient, action, businessId). Client events: `coe_ems:state`, `coe_ems:revive`, `coe_ems:heal`, `coe_ems:respawn`.

## Medical record

Table `coe_ems_records` (patient, doctor, business, type `revive|treat|respawn`, short detail `[a-z0-9_]`), with no free-form text. Each action is recorded before being applied and is sent to the audit log.

## Out of scope for this phase

Stretchers, ambulances, beds, pharmacy/medical items, region-specific injuries, emergency calls, and integration with `coe_needs`/HUD are planned for future phases (#125). Tests: `lua test/rules_test.lua`.
