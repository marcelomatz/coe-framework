# coe_telecom

COE OS phone carrier. Manages lines (prepaid and postpaid), charges for voice and video calls and messages, generates postpaid bills, and provides the **My Line** app on the smartphone (`coe_phone`).

Optional: without `coe_telecom` started, the phone keeps working and calls and messages are free.

## How it works

- **Line**: belongs to the **number** (the `coe_phone` SIM), not the character. Created on first use, on the `DefaultPlan` (prepaid) with `StartingCredit` welcome credit. The SIM **holder** pays the monthly fee and bills; whoever has the SIM in their phone can call, top up, and pay bills, but only the holder can change plans (`not_holder`). A line without a holder (anonymous SIM, e.g., disposable) can only be prepaid (`holder_required`).
- **Migration**: old lines, bills, and statements (per character) are moved to the number the first time the holder uses the SIM.
- **Caller pays**: the recipient pays nothing. Billing is per minute started, after the `GraceSeconds` grace period.
- **Prepaid**: before dialing, the phone asks the carrier (`Authorize`). Without enough credit for one minute, the call does not go through (`no_credit`). With credit, the call ends automatically when it runs out (reason "Credit depleted"). Top-up is done in the app and debited from the bank account (`Recharges`, up to `MaxBalance`).
- **Postpaid**: monthly fee per `CycleDays`-day cycle. The Control plan includes a minute allowance (`allowance`) and charges for overage on the bill; the Unlimited plan has no overage.
- **Bill**: at the end of the cycle, a bill is generated and automatic debit is attempted. If the account does not have enough balance, it stays open for `GraceDays` days; after that, the line is **suspended** (cannot call or send messages, but can still receive them). Paying all outstanding bills in the app reactivates the line.
- **Change plan**: once every `PlanChangeHours`. Leaving postpaid closes the cycle immediately, with a prorated monthly fee. To switch to postpaid, the line must be active and have no outstanding bills.
- **Messages**: price is in `rates.sms` (0 = free). A suspended line cannot send messages.

## Configuration (`config.lua`)

| Key | Use |
| --- | --- |
| `AllowedCallers` | Resources allowed to call `Authorize`/`Charge` |
| `Carriers`, `DefaultCarrier` | Carriers (only one in this phase) |
| `Plans` | Plans: `kind` (`prepaid`/`postpaid`), `monthly`, `allowance`, `rates` |
| `StartingCredit`, `MaxBalance`, `Recharges` | Prepaid credit |
| `CycleDays`, `GraceDays`, `PlanChangeHours` | Billing cycle, grace period, and plan-change interval |
| `TickSeconds`, `UsageKeepDays` | Billing routine and statement cleanup |

Values are integers (the economy system only works with integers).

## Exports

| Export | Used by | Return |
| --- | --- | --- |
| `Authorize(number, kind, holder)` | `coe_phone` | `{ ok = true, maxSeconds }` (nil = unlimited) or `{ ok = false, error }` (`no_credit`, `line_suspended`) |
| `Charge(number, kind, seconds, peer, holder)` | `coe_phone` | `{ ok = true, cost }` |
| `LineOf(number)` | anyone | `{ plan, carrier, status, balance }` |
| `TabletVisible` / `TabletCall` | `coe_phone` | My Line app (`overview`, `recharge`, `pay`, `plan`) |

`number`: digits only (`5550123`). `holder`: SIM holder (`nil` = no holder), used to create the line. `kind`: `voice`, `video`, or `sms`.

The My Line app shows the line for the SIM in the phone currently in use (`exports.coe_phone:ActiveLine`); without a SIM, returns `no_sim`.

## Database

Debits and refunds appear in the statement with reasons `telecom` and `telecom_refund` (references `recharge` and `invoice_<id>`).

## Tables

`coe_telecom_lines` (one per number; `character_id` = holder), `coe_telecom_invoices`, and `coe_telecom_usage` (with `number`; migrations in `server/migrations.lua`).

## Tests

```
lua test/telecom_test.lua
```

## Future phases

Player-owned carriers and antennas (#241), mobile data (#242), broadband and Wi-Fi (#243), and hacking networks (#244).
