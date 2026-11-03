# Upgrade from the basic to the advanced script (FROM > TO map)

Both sides are in this repository. The official build and recipe include only the advanced version; this map is for servers that already have the basic version installed. Each advanced script that replaces a basic one declares this in its own `fxmanifest.lua`:

```lua
coe_supervisor_replaces 'coe_mobile'
```

When the package is running, `coe_supervisor` prevents the basic resource from starting. During boot, it holds the basic resource even if the package starts later alphabetically. If the package stops or fails to start, the basic version starts again automatically. If you have the basic version and purchase the package, just `ensure` the package: nothing from the basic version needs to be deleted.

In the server console, `coe_upgrades` displays the live map: each basic resource, its replacement, each one's status, and what the package imported from the basic version.

```
[coe_supervisor] FROM (basic) -> TO (package)
  coe_bank (stopped) -> coe_banking (ACTIVE)
  coe_mobile (stopped) -> coe_phone (ACTIVE)
      basic data: calls=12 conflicts=0 contacts=40 kept=1 messages=310 numbers=18
  coe_staff (stopped) -> coe_admin (ACTIVE)
  coe_workpad (stopped) -> coe_tablet (ACTIVE)
```

| FROM (basic) | TO (advanced) | Group |
|---|---|---|
| `coe_mobile` (basic phone) | `coe_phone` (COE OS smartphone) | COE OS Suite |
| `coe_workpad` (work tablet) | `coe_tablet` (COE OS tablet) | COE OS Suite |
| `coe_bank` (basic bank) | `coe_banking` (banking system) | Enterprise & Governance |
| `coe_staff` (basic staff panel) | `coe_admin` (administrative panel) | Enterprise & Governance |
| `coe_garage` (basic garage) | `coe_garages` (public, private, and fleet garages) | Automotive |

---

## `coe_mobile` → `coe_phone`

| | FROM `coe_mobile` | TO `coe_phone` |
|---|---|---|
| Item | `phone` | `phone` (same item) |
| Key and command | F1, `/telefone` | F1, `/celular` and `/telefone` (`CommandAliases`) |
| Number | `coe_mobile_numbers` (`555-0123`) | SIM in the device (`coe_phone_sims`, `5550123`): **same number** |
| Contacts | `coe_mobile_contacts` | Device contacts (`coe_phone_device_contacts`) |
| Messages | `coe_mobile_messages` | `coe_phone_messages` (read stays read; unread stays unread) |
| Calls | `coe_mobile_calls` | `coe_phone_calls` (`unreachable` becomes `unavailable`) |
| Settings | silent mode, volume, ringtone, wallpaper | Same settings on the device (defaults for the rest) |
| Voice | `coe_talk` | `coe_talk` |

**Automatic import** (`coe_phone/server/upgrade.lua`, on every startup):

- Each character from the basic version receives a "legacy" device (serial `MG` + ID) with a SIM using the same number, their contacts, and settings. The first phone they open takes over this device.
- **Characters who already had a smartphone line** keep that line; conversations from the old number are moved to it.
- **A number already used by someone else on the smartphone**: the character receives a new number, and their conversations and contacts are updated to use it (`conflicts` in the report).
- A conversation deleted by both sides in the basic version is not imported. If it was deleted by only one side, it reappears for that side: nothing is lost.
- Per-table watermark (`coe_phone_upgrades`). Switching back to the basic version and then to the smartphone imports only new data, without duplicating it.
- The `coe_mobile_*` tables are not modified or deleted.

## `coe_workpad` → `coe_tablet`

| | FROM `coe_workpad` | TO `coe_tablet` |
|---|---|---|
| Item | `business_tablet` | `business_tablet` (same item) |
| Key and command | F3, `/trabalho` | F3, `/tablet` and `/trabalho` (`CommandAliases`) |
| Duty | Duty app | **Duty** app (Work group; same app: work locations, role, salary, GPS, and clock out) |
| Free jobs | Free Jobs app (`coe_jobs`) | **Free Jobs** app (Work group; same app) |
| Career | Career app (`coe_jobs`) | Career app |
| Businesses | One app per business (`coe_businesses`) | Business app (one per business) |
| Data | None of its own | — |

ACE permissions for `coe_tablet`: `coe.businesses.tablet`, `coe.businesses.clock`, and `coe.jobs.tablet` (granted by default through `CoeAccess.FirstParty`).

## `coe_bank` → `coe_banking`

| | FROM `coe_bank` | TO `coe_banking` |
|---|---|---|
| Account | `coe_economy` balance | Same `coe_economy` balance |
| Cash | `money` item | `money` item |
| Branches | Counter with "E" and a blip | Same branches, counter, and blip |
| Statement | `bank_withdraw`, `bank_deposit`, `bank_transfer`, `bank_refund` | Same reasons: history remains consistent |
| Transfer | By citizen ID | By citizen ID |
| ATM | No card | **With `card_bank` card and PIN**: the customer requests the card at a branch |
| Data | None of its own | — |

There is nothing to import: money and statements are stored in `coe_economy`, which both resources use.

## `coe_staff` → `coe_admin`

| | FROM `coe_staff` | TO `coe_admin` |
|---|---|---|
| Open | F10, `/staff` | F10 (panel), `/coeadmin` and `/staff` (tools). Users with only tool ACE permissions go directly to the tools with F10 |
| Personal | noclip, invisible, invincible, coordinates, heal, revive, blip, teleport | **Staff Tools** > Personal (same tools, including `/noclip`) |
| Players | go to, bring, freeze, heal, revive, kick, item, money, groups | Tools > Players (same tools) |
| Vehicles | temporary, registered, repair, refuel, clean, flip, delete | Tools > Vehicles (same tools) |
| World | time, weather, announcement | Tools > World (same tools) |
| Businesses | create and edit | Tools > Businesses and the panel's Businesses tab |
| Permissions | `coe.staff.all`, `coe.staff.<module>` | **Same permissions remain valid**, plus `coe_admin.tools.all`, `coe_admin.tools.<module>`, and `coe_admin.root` |
| txAdmin | txAdmin admin grants all access | Same |
| Audit | `staff_*` in `coe_audit` | Same events |

Staff who used the basic version keep the same tools without changing `server.cfg`. The "Staff Tools" button appears in the panel for anyone with at least one tool permission.

---

## Upgrade checklist

1. Copy the advanced script (its capabilities are already granted by the framework).
2. `ensure` the package. You do not need to remove the basic version from `server.cfg` or delete tables.
3. Restart the server and run `coe_upgrades` in the console: the basic version should show as `stopped` and the package as `ACTIVE`, with a report of what was imported.
4. To return to the basic version, stop the package: the basic version starts automatically with its data.
