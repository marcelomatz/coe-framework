# coe_dispatch

Dispatches calls and alerts to **police** and **EMS**, plug-and-play on top of `coe_businesses`. Recipients are those **on duty** at a business in the call's category (`police` or `ems`); there is no parallel player list. Designed for use by `coe_ems`, `coe_police`, heists, and any resource that needs to call medical or police assistance.

## Flow

1. A resource (or citizen) creates a call with a **code** (`robbery`, `shots_fired`, `person_down`...). The code defines category, priority (1 = most urgent), and label; see `config.lua`.
2. The server validates code and position, **adds reports** to an identical nearby call (`DedupeRadius`, `DedupeSeconds`), and sends it to those on duty in that category. A blip appears on the client (flashing at priority 1), and an alert plays.
3. The police officer/medic uses `/atender <id>` (sets the route) and `/encerrar <id>`. Calls expire automatically after `TtlSeconds`.

## Commands

- `/chamado <codigo>`: a citizen requests help (`help_police`, `help_ems`) at their own position, with a `CitizenCooldownSeconds` cooldown.
- `/chamados`: lists calls in the caller's category by urgency.
- `/atender <id>`, `/encerrar <id>`: requires being on duty in the call's category.

## API (server)

Only `ActionResources` may call it. Returns one value or `{ error = code }`.

- `Alert(code, x, y, z)`: creates (or adds a report to) a call and returns its ID.
- `Active(source)`: calls visible to someone on duty.
- `Accept(source, id)`, `Close(source, id)`.

Server events: `coe_dispatch:created (id, category, code, source)`, `coe_dispatch:accepted (id, source)`, `coe_dispatch:closed (id, source)`. Client events: `coe_dispatch:call`, `coe_dispatch:route`, `coe_dispatch:clear`.

## Integration

- `coe_ems` creates `person_down` when a patient becomes unconscious, if `coe_dispatch` is active.
- Heists should call `exports.coe_dispatch:Alert('store_robbery', x, y, z)` (`coe_heists` is already listed in `ActionResources`).
- `coe_deepweb` creates `suspicious_deal` (Suspicious Deal) for some sales through the DeepWeb contact; `coe_loot` is in `ActionResources` for robbery scripts.
- New codes: add them to `Codes` in `config.lua`.

## Limits of this phase

Calls are held in memory (ephemeral), and creation/closure are audited. Outside this phase: MDT/tablet panel, client-side gunshot-detection alerts, radio channels, and durable call history. Tests: `lua test/rules_test.lua`. Server startup order: `ensure coe_dispatch` after `coe_businesses`.
