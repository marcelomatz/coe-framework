# coe_mdt

Police MDT, opened through `coe_tablet` (the **MDT** app). This is the police's most sensitive tool: all access is revalidated and data queries are logged.

## Access

- Only available to people **clocked in at a business in the `police` category**. `coe_tablet` makes the app available by category (`categories = { police = true }`), and the MDT **revalidates every action**: clock-in, category, and position permission. Going off duty or losing the position immediately removes access.
- Position permissions (registered in `coe_businesses`, assigned by position in the business):

| Permission | Grants access to |
|---|---|
| `mdt.access` | Open the MDT, view calls, warrants, and bulletins (required for everything) |
| `mdt.lookup` | Search citizens and license plates |
| `mdt.reports` | Create and read reports |
| `mdt.warrant_issue` | Issue warrants |
| `mdt.warrant_close` | Execute or revoke warrants |
| `mdt.bulletins` | Publish and close bulletins |

## Features

- **Calls**: list, respond to, and close calls through `coe_dispatch`.
- **Search**: citizen (name or 8-character ID) with warrants, criminal record (`coe_police`), vehicles, and reports; license plate with owner and bulletins.
- **Warrants**: issue, execute, revoke. Final states cannot be reversed. Limit on active warrants per citizen.
- **Bulletins**: notices with an expiry (1 to 72 h) and optional license plate.
- **Reports**: immutable, with an optional subject.

## Security

- Queries (`lookup`, `person`, `plate`, `warrants`, `reports`) are **written to `coe_mdt_access_log` before data is returned**; if logging fails, the query is denied.
- Per-officer limit: 20 queries and 12 writes per minute.
- Writes are also sent to `coe_audit`.
- Free text is sanitized and limited; the interface uses `textContent` only.
- `AccessLog(subject, limit)` export for internal affairs (`AuditResources` only).

## Events

- `coe_mdt:warrantIssued (officerSource, subjectCharacterId, charge)`
- `coe_mdt:warrantClosed (officerSource, subjectCharacterId, status)`

## Installation

`ensure coe_mdt` after `coe_businesses`, `coe_police`, `coe_dispatch`, and `coe_tablet`. Grant the `mdt.*` permissions to positions in the police business.
