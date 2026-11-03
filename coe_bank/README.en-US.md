# coe_bank

Basic framework banking: the character's everyday account, without banking products.

- **Account**: the balance is held by `coe_economy` (one per character). **Cash** is the `money` item in `coe_inventory`.
- **Branch** (counter with an "E" prompt, "Bank" blip): balance, withdrawal, deposit, transfer by citizen ID, and statement, up to `MaxAgencyAmount` per operation.
- **ATM** (aim at any ATM model in `AtmModels`; surface target, since many ATMs are part of the map): balance, withdrawal, deposit, and the account character's latest transactions, up to `MaxAtmAmount` per operation. No card or PIN.
- **Transfer**: by citizen ID (the same as the `/id` command), including to offline recipients. The screen shows the recipient's name and asks for confirmation before sending. Online recipients are notified.

Outside basic banking (left to packages): cards and PINs, credit and statements, loans, business accounts, fees, and online banking.

## Packages that take over the bank

A package with full banking calls the `Yield()` export when it starts (and again on `coe_bank`'s `onResourceStart`). Basic banking hides its branches, ATMs, and blips, closes open screens, and rejects requests until the calling resource stops; then it resumes automatically. The capability is granted in `server.cfg`:

```
add_ace resource.<nome> coe.bank.yield allow
```

The framework does not name the package: the resource taking over is identified at runtime. `Status()` returns `{ active, yieldedBy }`.

Statement reasons are the same as those in a full banking system, so history remains consistent when switching: `bank_withdraw`, `bank_deposit`, `bank_transfer` (reference `state:<recipient ID>`), and `bank_refund`. Withdrawal and deposit references are `agency:<id>` or `atm`.

## Consistency

The account and inventory are separate resources; operations use compensation:

- Withdrawal: debit the account and give cash; if the inventory has no room, return the amount to the account (`bank_refund`).
- Deposit: remove cash and credit the account; if the credit fails, return the cash.

Failed refunds are logged (`bank_refund_failed`). Each player may have one operation at a time and there is a minimum interval between transactions (`ActionIntervalMs`). The server checks distance from the counter (branch) and from the point where the screen was opened; the screen closes after moving beyond `SessionRadius`.

## Configuration

`config.lua`: operation limits, quick-amount shortcuts (branch and ATM), statement length, interval between operations, session radius, ATM models, blip, and branches (`id`, `label`, coordinates, and `radius`).

## Interface

The branch and ATM use the same page (`html/`), styled with `coe_ui` (chamfered panel, `coe-*` buttons and fields, token-only colors), and follow the server theme and player color (`@coe_ui/theme_bridge.lua`). Transfers are confirmed with `CoeUI.confirm`.

## Tests

```
cd coe_bank
lua test/rules_test.lua
lua test/server_test.lua
```

`server_test.lua` exercises the server with mocked economy, inventory, database, and sessions: branch and ATM, withdrawal and deposit with refund, operation interval, online and offline recipient, transfer, limits, distance, and a package's `Yield`.
