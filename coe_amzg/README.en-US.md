# coe_amzg

Virtual store (e-commerce) for the smartphone and tablet. Players choose products, pay with a credit card through the phone Wallet, and choose which property should receive the delivery. Purchases arrive in a box inside the property, near the interior entrance point.

## Flow

1. Install the **Amzg** app from the app store (`coe_apps`, Shopping category). It appears on both phone and tablet.
2. **Store**: search, categories, and storefront. The cart is retained while the resource is open.
3. **Cart**: items, occupied box space, address, shipping, and total. **Pay** works only on the phone: it opens the Wallet (`coe_phone`), which charges the selected card through `coe_banking:CardPurchase`. On the tablet, the button asks the player to use the phone.
4. The server recalculates the entire price. If the catalog changed since the storefront was opened, the purchase is rejected (`price_changed`) and nothing is charged.
5. **Orders**: status (in transit, delivered, collected, refunded) and estimated arrival.

## Delivery

- Valid addresses: residences, commercial properties, and hideouts the character can access (`coe_housing:DeliveryAddresses`).
- Shipping options in `Config.Shipping`: standard (30 min, free) and express (5 min, fee).
- Every `DeliveryTickSeconds`, expired orders become a box (`stash:amzg:<order>`) containing the items. If the property contract ended in the meantime, the amount is refunded to the card.
- The box (`Config.Box.Model`) appears only for people inside that property, queued near the interior point. Aim at it and use **Open Amzg box**: it opens like a stash.
- An empty box disappears (the order becomes "collected") and its inventory is deleted after `CollectDelaySeconds`. If someone returns items before then, it reappears.
- Visitors under someone else's contract cannot see boxes.

## Limits (`config.lua`)

- `Cart`: up to 10 lines, 50 units per line, 20 box slots, and maximum total.
- `Orders.MaxPending`: in-transit orders per character; `Orders.History`: listed orders.
- `Products`: up to 300 products, maximum price, and name length.
- `Promo`: banner badge length (`BannerTextMax`), carousel rotation (`RotateSeconds`), and how many products appear between grid banners (`InlineEvery`).

## Catalog

Starts with DeepWeb electronics (migration 2: Notebook, Desktop Computer, Home Server, and USB drive in the Electronics category, only if the item is not already registered). Edited in the admin panel (`coe_admin`, **Amzg** tab, business permission): each product points to an inventory item, with storefront name, category, price, order, and an option to pause without deleting. Stored in `coe_amzg_products`; orders in `coe_amzg_orders`.

### Promotions and banners

In the same editor, the **Promotion and banner** block sets a promotional price (lower than the regular price; 0 = no promotion), optional end date (future date; blank = no deadline), banner badge (blank = `-N% OFF`), and featured status. With an active promotion, the app shows "From $X to $Y" and the discount on the card; banners use the item image: a carousel at the top of the storefront (featured items, or all promotions in the category if nothing is featured) and smaller banners between products. A countdown appears when a deadline exists, along with an **Shop now** button that adds the item to the cart. The server determines the price: the catalog already sends the promotional price, checkout recalculates using the server clock, and an expired promotion returns to the regular price (the app reloads the storefront; a cart with the old price receives `price_changed`). Migration 3 adds `promo_price`, `promo_until`, `featured`, and `banner_text`.

## Exports

| Export | Caller | Usage |
| --- | --- | --- |
| `TabletVisible(playerId, appId)` | `coe_phone`, `coe_tablet` | App is installed on the device. |
| `TabletCall(playerId, appId, action, payload)` | `coe_phone`, `coe_tablet` | `catalog`, `addresses`, `checkout`, `orders`. |
| `AdminCatalog()` | `coe_admin` | Categories, products, and limits. |
| `AdminSaveProduct(input)` | `coe_admin` | Creates (without `id`) or updates a product. |
| `AdminDeleteProduct({ id })` | `coe_admin` | Removes a product. |

Admin exports reject other callers (`forbidden`).

## Dependencies

`coe_core`, `coe_database`, `coe_logging`, `coe_inventory`; at runtime, also `coe_housing` (addresses and current space, authorized through `DeliveryCallers`), `coe_apps` (`HasApp`), `coe_phone` (Wallet, `Wallet.PaymentCallers`), `coe_banking` (`PurchaseCallers`), `coe_notify`, `coe_audit`, and `coetarget`.

## Auditing

`amzg_order_placed`, `amzg_order_refunded`, `amzg_product_saved`, `amzg_product_deleted`.

## Tests

`lua test/amzg_test.lua` (price, space, and box-position rules).
