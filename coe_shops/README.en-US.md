# coe_shops

Map convenience stores as `coe_businesses` businesses: **24/7**, **LTD Gasoline**, and **Rob's Liquor** (phase 1). Every store starts **staff-owned** (business without an owner) and can be transferred to a player by setting the owner in the Businesses tab of `coe_admin`.

Later phases: 2) fuel and gas station pumps (the LTD business is already in the `gas_station` category); 3) Ammu-Nation, clothing, barber shops, and tattoos; 4) supply deliveries (`GetShelves` already exposes stock).

## How it works

- Clerk (`mp_m_shopkeep_01`) in each store, with **Buy** target (`coetarget`). Short blip by type; LTD stores have no store blip (`blip = false`), the blip is the station's (`coe_fuel`), which uses the same business. Clerks and blips are created from the client config and appear even while the server is still opening stores; in that case, **Buy** responds "Store is still opening" and the console shows `shops_migrations_failed` (the server retries every 15 s).
- The clerk is created only when the store interior is loaded and is moved to the player's room if it was outside. `/lojadebug` (F8) shows the nearest store, clerk, position, and the clerk's and player's interior/room.
- The storefront (NUI) shows categories, search, stock, and cart. The server decides prices, stock, and payment; the player must be within `CounterRadius` (4 m) of the counter.
- Payment: **cash** (item `money`) belongs to the store; other methods are registered by other resources with `RegisterPaymentMethod` (see below), such as the card reader and the phone wallet from commercial packages. A full inventory refunds the purchase through the same method.
- Revenue goes to the business cash account (`coe_economy:SocietyCollect`, reason `shop_sale`) in both modes.

| Mode | When | Stock | Price |
| --- | --- | --- | --- |
| `staff` | Business has no owner | Infinite (automatically restocked) | Config table |
| `player` | Business has an owner | Store shelves; starts empty | Set by the owner, between `PriceBand.Min` (0.5×) and `PriceBand.Max` (3×) of the table price |

## Management (storefront Management tab)

| Who | Can |
| --- | --- |
| Owner | Everything, even while off duty |
| Clocked-in staff | Restock shelves with items from their own inventory (up to `MaxStock`, 500 per product) |
| Role with `shops.prices` | Set prices |
| Role with `shops.stock` | Remove items from shelves to inventory |
| ACE `coe_shops.manage` | View staff store report |

Report: today's and last 7 days' sales, cash account balance, and the last `ReportSales` (30) sales. Each store's business has an `estoque` stash and a `ponto` clock-in point at the counter (created only the first time; the owner can change them in admin).

## Tablet (business app)

Each store is a business, so it appears as an app in COE OS for the owner and staff (`coe_businesses`). The **Store** tab (for stores only, via `IsStore`) shows shelves (stock and price for each product), today's and last 7 days' sales, cash account, and latest sales; it lets the owner or a role with `shops.prices` change prices remotely (or restore the table price). Restocking and withdrawing remain at the counter because they affect the inventory of whoever is there. The screen is provided by `coe_shops` itself (`html/business.js` + `business.css`), registered with `coe_businesses:RegisterTab` (visible where `IsStore` returns `true`) and registered again whenever `coe_businesses` restarts.

## Payment methods from other resources

Any resource with the `coe.shops.payments` ACE can register a payment method (the registration disappears when it stops; register again on `onResourceStart` of `coe_shops`):

```lua
exports.coe_shops:RegisterPaymentMethod({
	id = 'card', label = 'Cartão na maquininha', order = 30,
	kind = 'pin',            -- instant | pin (escolhe uma opção e digita a senha) | device (passo no client)
	options = 'ShopOptions', -- opcional: (playerId) -> { detail?, available?, options = { { id, label } } }
	charge = 'ShopCharge',   -- (playerId, { option, pin, token }, total, descrição) -> { ok, ref } | { ok = false, error, left? }
	refund = 'ShopRefund',   -- (playerId, ref, total, descrição) -> { ok }
	client = nil             -- device: export client ({ amount, label, note }) -> { token } | { error }
})
```

The method is enabled by default; `Payments = { <id> = false }` in `config.lua` disables it. The sales report shows the registered label.

## Diagnostics

- Each client notifies the server when it builds stores and creates a clerk; the server console shows `shops_client_loaded` (stores and blips), `shops_client_clerk` (store, interior, height), and `shops_client_error`. If no `shops_client_loaded` appears after you join, the client script is not running.
- `/lojadebug` (F8) shows the nearest store and clerk state.

## Config

`config.lua` (`ShopsConfig`): `Categories`, `Products` (product → item, category, table price), `Types` (products, clerk, blip, business category), and `Stores` (business ID, name, type, and clerk `{ x, y, z, h }`). Cart limits in `Cart` (20 lines, 50 per product, total up to 50 000). Clerk positions are provisional: check and adjust them in-game.

New items in `coe_inventory` (`data/coe_shop_items.lua`) and effects in `coe_needs` (`ItemEffects`): sandwich, chips, chocolate, cereal bar, eCola, coffee, energy drink, beer, whiskey, vodka, and painkillers. Water is now consumable.

## Database

| Table | Contents |
| --- | --- |
| `coe_shops_shelves` | Player-owned store shelves: quantity and price per product (null = table price). |
| `coe_shops_sales` | Sales: store, character, mode, payment method, total, units, and items. |

Migrations in `coe_shops_schema_migrations`.

## Exports (server)

| Export | Return |
| --- | --- |
| `IsReady()` | `true` after migrations and business creation. |
| `IsStore(businessId)` | `true` if the business is a `coe_shops` store. |
| `BusinessTablet(playerId, characterId, businessId, payload)` | Store tab in the business app (only `coe_businesses`): `op` `overview` or `price`. |
| `GetShelves(storeId)` | `{ [produto] = { quantity, price } }` for a player-owned store, or `nil` (staff-owned or unknown store). |
| `RegisterPaymentMethod(def)` | Payment method from another resource (ACE `coe.shops.payments`): `true` or `{ error }` (`forbidden`, `invalid_method`, `method_taken`, `too_many_methods`). |

## Dependencies and allowlists

`coe_core`, `coe_database`, `coe_logging`, `coe_inventory`, `coe_businesses`, `coetarget`; optional at runtime:
`coe_economy`, `coe_audit`, `coe_notify`, and registered payment methods. `coe_shops` is included in the framework's default access settings (database, logs, notifications, auditing, business cash accounts, business records, role permissions, and tabs) and in `coe_supervisor`. Packages that charge at stores usually need `coe_shops` in their own caller list.

Audit events: `shop_sale`, `shop_price`, `shop_restock`, `shop_withdraw`.

## Tests

`test/rules_test.lua` (catalog, modes, price range, budget, stock, restocking, and withdrawing), `test/server_test.lua` (simulated natives and exports: purchases using all three payment methods, refund, player stock, management, and permissions), and `test/client_test.lua` (clerks and blips from config, without waiting for the server).
