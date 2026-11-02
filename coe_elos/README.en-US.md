# coe_elos

**Elos**, COE OS's professional network, on smartphone and tablet. Installed on every device (`coe_apps`, Social category). Phase 1: profile, resume, and connections. Jobs, company profiles, and applications arrive in phase 2, when Elos replaces the Jobs app.

## Profile

- Name and ID (the same as `/id`) come from the character; the player writes the **introduction** (up to 80 characters) and **About** (up to 600).
- **Public**: anyone can see the full profile. **Private**: connections only; others see name, introduction, and connection count.
- **Show career**: career level, reputation, and skills from independent jobs (`coe_jobs`).
- **Show earnings**: how much was earned in each experience (off by default).

## Resume

The resume comes from the character's actual history; the player chooses what to show and writes a comment.

| Source | Included information |
| --- | --- |
| Independent jobs (`coe_jobs:GetCareer`) | Each job with at least one task: time worked, tasks, level, earnings, first and last time. |
| Businesses (`coe_businesses`) | Duty hours summed at the end of each shift (`coe_businesses:dutyChanged` and on leaving the game), shifts, most recent role, first/last time; current affiliations (staff or owner) appear as **Current**, even with no hours. |

- Shifts shorter than `Resume.MinShiftSeconds` (60 s) do not count.
- Up to `Resume.MaxItems` experiences on the resume. Hours, tasks, and roles cannot be edited.
- Anyone already on duty when Elos starts begins accumulating time at that point.
- Time in independent jobs is summed by `coe_jobs` (migration 4) from when the update was introduced; jobs already recorded in `coe_jobs_sessions` were summed by the migration.

## Connections

- Search by name (3 or more letters) or full ID among people who have opened Elos.
- Connection request requires acceptance: the other person receives a notification (if online) and accepts or rejects in the **Network** tab. Requesting a connection from someone who already requested you connects immediately.
- Cancel an outgoing request or remove a connection at any time.
- Limits: `Network.MaxConnections` (300) and `Network.MaxPendingOut` (30 pending outgoing requests).

## Database

| Table | Contents |
| --- | --- |
| `coe_elos_profiles` | Profile (name and ID copied for search and offline visits, introduction, about, visibility, options). |
| `coe_elos_items` | Resume experiences (`job`/`business` + ID) and comment. |
| `coe_elos_work` | Hours and shifts by character and business, most recent role, first and last time. |
| `coe_elos_connections` | One row per pair: requester, recipient, `pending` or `accepted`. |

Migrations in `coe_elos_schema_migrations`.

## Exports (server)

`IsReady`, `GetProfile(characterId)` (public profile with resume, basis for applications), `TabletVisible`, and `TabletCall` (`coe_tablet` and `coe_phone` only). Reference: [reference/coe_elos.md](../reference/coe_elos.md).

## Tests

`lua test\rules_test.lua` (profile, resume built from history, visibility, requests) and `lua test\server_test.lua` (state, profile, resume only from real experiences, business duty hours, search, connections, private profile, and `GetProfile`, with mocked natives and database).

## Dependencies and allowlists

`coe_core`, `coe_database`, `coe_logging`; uses `coe_jobs`, `coe_businesses`, `coe_apps`, and `coe_notify` when started. It is in `ALLOWED_CALLERS` in `coe_database`, and in the allowlists for `coe_logging`, `coe_notify`, and `coe_supervisor`.
