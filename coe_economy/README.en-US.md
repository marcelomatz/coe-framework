# coe_economy

Per-character balance, statement (`coe_economy_ledger`), and atomic operations. This is the billing foundation for housing, businesses, and mechanics.

- Account created on first use with `StartingBalance` (`config.lua`).
- Amounts are always positive integers; balance is `BIGINT UNSIGNED`, so a debit exceeding the balance fails and rolls back the transaction. The resource requires strict `sql_mode` at startup.
- Only authorized resources call the exports; caller name comes from the runtime. Framework defaults (`AllowedResources`): `coe_economy`, `coe_businesses`, `coe_jobs`, `coe_shops`, `coe_bank`, `coe_mobile`, `coe_staff` (basic staff panel), and `coe_rentals` (rent and deposit). Other resources (commercial packages and third-party scripts) receive the ACE in `server.cfg`: `add_ace resource.<name> coe.economy.money allow`. Job packages pay through `coe_jobs` and do not need it.

Exports (server): `GetBalance(characterId)`, `Credit(characterId, amount, reason, reference?)`, `Debit(...)`, `Transfer(fromId, toId, amount, reason, reference?)`. Return `true`/value or `nil, code` (`insufficient_funds`, `invalid_amount`, `balance_limit`, `same_account`, `forbidden`, `not_ready`...). `reason` matches `[a-z0-9_]{1,32}`.

> **Caution:** when called through `exports` from another resource, only the first return value is received; the error code from `nil, code` is lost, and the caller sees only `nil`. New exports (`Ledger`, `LedgerStats`, society) already return one value or `{ error = code }`. The remaining exports will be standardized in the same way as #167.

`IsReady()`: persistence is ready and the caller is authorized.

`Summary()`: economy totals for the admin Overview; only callers with `coe.economy.admin` (otherwise `{ error = 'forbidden' }`).

`Ledger(characterId, limit?)`: personal statement, newest first (`{ delta, reason, reference, created_at }`, up to 100), or `{ error = code }`. Used by `coe_bank`.

`LedgerStats(characterId, days, ignoredReasons?)`: `{ firstAt, inflow }`: epoch time of the first entry (or nil) and sum of inflows over the last `days` (1 to 365), excluding ignored reasons (up to 20); or `{ error = code }`. Full contract for all exports (including society and business accounts) is in [`types.lua`](types.lua) and the [API reference](../reference/coe_economy.md).

Commands: `/saldo` (player) and `coe_economy_credit <characterId> <amount>` (ACE `command.coe_economy_credit`).

New resources that charge users receive `coe.economy.money` by ACE; there is no need to edit `config.lua`. Capabilities: `coe.economy.money`, `coe.economy.society.collect`, `coe.economy.society.pay`, `coe.economy.society.bank`, and `coe.economy.admin` (summary, statements, and staff-panel payroll). `add_ace resource.<name> coe.economy allow` grants all.

## Society accounts and payroll

Each business has a society account (`coe_economy_societies`) with its own statement (`coe_economy_society_ledger`), created on first deposit. Exports (single return value or `{ error = code }`):

- `SocietyBalance(businessId)`, `SocietyLedger(businessId, limit?)`.
- `SocietyDeposit(businessId, characterId, amount)`: owner or staff of that business, from personal balance to society.
- `SocietyWithdraw(businessId, characterId, amount)`: requires the `business.funds` role permission (owner has all permissions).
- `SocietyCredit(businessId, amount, reason?)`: administrative contribution, `coe.economy.admin` only.
- `SocietyCollect(businessId, amount, reason)`: transfer of revenue already debited from a citizen (e.g. fines, ads) or a refund; only callers with `coe.economy.society.collect` (default: `coe_shops`).
- `SocietyCharge(businessId, amount, reason, reference?)`: business expense without a character (e.g. commercial property rent); only callers with `coe.economy.society.pay`. Insufficient balance: `insufficient_funds`.
- `RunPayroll(businessId)`: only `coe_economy`, `coe.economy.admin`, and `coe.economy.society.bank`; returns `{ paid, total, skipped }`.
- Business bank account (`coe.economy.society.bank` only, e.g. `coe_banking`, which checks role permissions and records who performed the operation): `BankSocietyPay(businessId, characterId, amount, reason, reference?)` (cash → personal account), `BankSocietyDeposit(businessId, characterId, amount, reason, reference?)` (personal account → cash, does not require business membership), `BankSocietyDebit`/`BankSocietyCredit(businessId, amount, reason, reference?)` (outflow/inflow without a personal account: cash, card, adjustment), `BankSocietyTransfer(fromId, toId, amount, reason, reference?)` (between businesses), and `BankSocietyLedger(businessId, filter)` (statement filtered by direction, reasons, days, and page, with period totals; also `coe.economy.admin`). Balances and limits are checked in the transaction; insufficient balance: `insufficient_funds`.

Payroll: every `PayrollIntervalMinutes` (default 30; 0 disables it), each active business pays the role salary (`coe_businesses:Payroll`) from the society to the character, **only to people on duty**. If the society lacks funds, the person is not paid and no debt accrues (`skipped`: `off_duty`, `insufficient_funds`, `balance_limit`). Payments and debits are atomic. Server event: `coe_economy:payrollPaid` (businessId, paid, total, skipped). Statement reasons: `society_deposit`, `society_withdraw`, `payroll`.

## Persistence and tests

Tables `coe_economy_accounts` and `coe_economy_ledger` (migration 1), `coe_economy_societies` and `coe_economy_society_ledger` (migration 2), versioned in `server/migrations.lua`. Tests: `lua test/rules_test.lua` (amount and reason validation, business statement filtering, and transactions without parameter gaps) and `lua test/server_test.lua` (exports with in-memory persistence: callers not in allowlist or ACE are rejected, amount validation, insufficient balance, cap, and transfer). The `commerce_scenario.lua` MariaDB integration scenario (`coe_database/test/integration`) covers accounts, society, and real-database statements.
