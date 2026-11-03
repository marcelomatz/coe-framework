# coe_crypto

In-game cryptocurrency (**Noxcoin**, `NOX`): wallets with private keys, public network, exchange with floating quote, and mining. It is the DeepWeb currency (`coe_deepweb`): market purchases, services, and contracts in future phases are paid in it.

## Wallets

- A wallet is a public **address** (`nx` + 28 base58 characters) and a **private key** (`NXK-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX`). Anyone with the key can move the funds. The server stores only a key hash, using the framework's own format (`coe_core/lib/hash.lua`, iterated SHA-256 with salt). Wallets created with the old hash (FXServer bcrypt, which did not verify) remain valid when the same key is stored on a device, and the hash is rebuilt on first use.
- To move a wallet to another device: **Write on paper** or **Save to USB drive** (with the item in inventory, the wallet appears on any device), or **Import** by entering the address and key. Import explains what is wrong: mistyped address, incorrectly formatted key, nonexistent address, or a key belonging to another wallet (only the last counts as an attempt toward lockout).
- The key is stored in one of these places:
  - **On a device** (hot wallet): smartphone (`phone:<serial>`), tablet (`tablet:<character>`), or `coe_deepweb` computer (`laptop:<serial>`, `desktop:<serial>`, `server:<serial>`). Anyone using the device can access its wallets. Up to `Wallets.MaxPerDevice` per device.
  - **On paper** (`crypto_paper`) or a **USB drive** (`crypto_usb`), with `metadata { address, key, label }`. Whoever carries the item can use the wallet; the item can be stolen, handed over, or seized (`coe_police:Seize`).
- **New wallet** creates a key on the device (up to `Wallets.MaxCreatedPerDay` per character per day). **Import** requests address + key (e.g. copied from paper); `Wallets.ImportFailures` incorrect keys lock the device for `ImportLockSeconds`. **View key**, **Write on paper**, **Save to USB drive** (consumes an empty `usb_black`), and **Remove** (removes the key from the device; without another copy, funds become inaccessible).

## Network

- Public ledger (`coe_crypto_tx`): the **Explorer** shows the balance and transactions for any address. The ledger also stores, server-side only, the character and device that made each transaction (trail for investigations).
- Sending: fixed `Transfer.Fee` fee (burned), `Transfer.CooldownSeconds` interval per address, and optional public message. The destination must exist on the network. Balances are `BIGINT UNSIGNED` in strict mode: a debit exceeding the balance rolls back the entire transaction (the resource requires strict `sql_mode` at startup, like `coe_economy`).

## Exchange (`Exchange`)

- Buy and sell against the `coe_economy` bank balance (reasons `crypto_buy`, `crypto_sell`, `crypto_refund`). Orders are **identified** (linked to the character): the legal entry and exit point for crypto.
- Liquidity comes from a reserve wallet without a key (`ReserveAddress`, created with `Reserve` units). Without a reserve: `no_liquidity`.
- Quote in $ per coin: every `TickMinutes`, a random walk with reversion to the anchor (`MeanReversion`), noise (`Volatility`), and **net order flow impact** (`ImpactPerMillion`): heavy buying raises the price; heavy selling lowers it. `MinPrice`/`MaxPrice` limits. 24-hour history for the chart (`coe_crypto_prices`).
- `SpreadBps` spread on each side, order size from `MinOrder` to `MaxOrder`, daily limits per character (`DailyBuyLimit`, `DailySellLimit`), and `OrderCooldownSeconds` interval.
- If the bank rejects credit from a sale, the coins are returned to the wallet (`refund`); if the reserve fails on a purchase, the money is refunded.

## Mining (`Mining`)

`MintMining(entries)` (`Mining.Callers` only, currently `coe_deepweb`, at most one round per `TickMinutes`): each machine receives `EmissionPerTick * hash / max(total hash, ReferenceHash)`. A weak network emits less than the total; `MaxMined` applies only to mining (exchange reserve is separate issuance, `genesis`). Payments to the same address are combined and written in transactions of up to 30 payments.

## Market escrow (`Escrow`)

A keyless wallet (`Escrow.Address`, created empty at startup) that holds Deep Market payments from `coe_deepweb` until delivery. `Escrow.Callers` only: `HeldWallets(playerId, deviceKey)` lists wallets with an available key on the device and in inventory (with balance); `EscrowLock(playerId, deviceKey, from, amount, memo)` locks the amount plus network fee (requires the key, ledger entry `escrow_lock` with character and device); `EscrowRelease(to, amount, memo)` pays the seller, refunds the buyer, or sends the fee to the reserve (`escrow_out`, no fee). `ReserveAddress()` returns the exchange reserve.

## Crypto app

Installed through the **Store** (`coe_apps`, Finance category) on smartphone and tablet, and available on every `coe_deepweb` computer. Tabs: Wallets, Send, Exchange (quote, chart, buy, and sell), and Explorer.

## Exports

See [`reference/coe_crypto.md`](../reference/coe_crypto.md). `TabletVisible`/`TabletCall` (`coe_phone` and `coe_tablet` only), `ComputerCall` (`coe_deepweb` only), `MintMining` (`Mining.Callers` only), administration through `coe_admin` (`AdminOverview`, `AdminInspect`, `AdminSaveSettings`, `AdminResetSettings`, `AdminSetPrice`), and unrestricted read operations: `IsReady`, `Price`, `Balance`, `IsAddress`, `Format`.

## Tables

`coe_crypto_wallets` (address, key hash, balance, creator), `coe_crypto_keystore` (keys by device), `coe_crypto_tx` (ledger), `coe_crypto_prices` (quotes), `coe_crypto_state` (counters, e.g. `minted`), and `coe_crypto_settings` (settings editable by admin). Migrations in `server/migrations.lua`, tracked in `coe_crypto_schema_migrations`.

## Dependencies

`coe_core`, `coe_database`, `coe_logging`. Optional: `coe_economy` (exchange), `coe_inventory` (paper and USB drive), `coe_apps` (installation), `coe_phone` (device serial), `coe_audit`, `coe_notify`. It must be in the allowlists for `coe_database`, `coe_logging`, `coe_audit`, `coe_notify`, and `AllowedResources` in `coe_economy` (already included).

## Tests

```
cd coe_crypto
lua test/crypto_test.lua
lua test/server_test.lua
```
