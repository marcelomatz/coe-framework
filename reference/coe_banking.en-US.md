# coe_banking — API reference

> Generated from `coe_banking/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

Generated from the exports registered in code; refine descriptions and types when editing each export.

## Exports

### `AdminAccount(characterId)`

Server export `AdminAccount` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `characterId` | `any` |  |

**Returns**

- `any`

### `AdminBusinessAccount(businessId, filter)`

Server export `AdminBusinessAccount` (`server/business.lua`).

| Parameter | Type | Description |
|---|---|---|
| `businessId` | `any` |  |
| `filter` | `any` |  |

**Returns**

- `any`

### `AdminBusinessAccounts()`

Server export `AdminBusinessAccounts` (`server/business.lua`).

**Returns**

- `any`

### `AdminBusinessAdjust(businessId, delta, note)`

Staff adjustment to the business cash balance: a positive delta credits it; a negative delta debits it (`admin_adjustment` reason, with the note).

| Parameter | Type | Description |
|---|---|---|
| `businessId` | `any` |  |
| `delta` | `any` |  |
| `note` | `any` |  |

**Returns**

- `any`

### `AdminBusinessCardLimit(cardId, value)`

Operation: `limit` (`value` is the daily limit; `0` means no limit). Use AdminCard for blocking, unblocking, and expiration changes.

| Parameter | Type | Description |
|---|---|---|
| `cardId` | `any` |  |
| `value` | `any` |  |

**Returns**

- `any`

### `AdminCard(cardId, action)`

`action`: `block` | `unblock` | `extend` (new expiration starts now).

| Parameter | Type | Description |
|---|---|---|
| `cardId` | `any` |  |
| `action` | `any` |  |

**Returns**

- `any`

### `AdminDecideRequest(requestId, decision)`

`decision`: `{ approve = bool, rate, installments, reason }`. When approved, the funds are credited to the business account and the debt is shared by the current owner and partners; installments are debited from the account, and any shortfall becomes overdue for all of them.

| Parameter | Type | Description |
|---|---|---|
| `requestId` | `any` |  |
| `decision` | `any` |  |

**Returns**

- `any`

### `AdminForgiveLoan(loanId)`

Server export `AdminForgiveLoan` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `loanId` | `any` |  |

**Returns**

- `any`

### `AdminGrantLoan(characterId, input)`

`input`: `{ principal, rate (total %), installments, note }`. Funds are credited to the account; installments are debited automatically.

| Parameter | Type | Description |
|---|---|---|
| `characterId` | `any` |  |
| `input` | `any` |  |

**Returns**

- `any`

### `AdminLoanRequests()`

Queue of business loan requests: pending requests and the latest decisions.

**Returns**

- `any`

### `AdminPoints(characterId, delta)`

Server export `AdminPoints` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `characterId` | `any` |  |
| `delta` | `any` |  |

**Returns**

- `any`

### `AdminSaveTiers(list)`

Server export `AdminSaveTiers` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `list` | `any` |  |

**Returns**

- `any`

### `AdminSetCredit(characterId, data)`

`data`: `{ tier, customLimit (number or false), tierLocked }`. Creates a credit account if one does not exist.

| Parameter | Type | Description |
|---|---|---|
| `characterId` | `any` |  |
| `data` | `any` |  |

**Returns**

- `any`

### `AdminTiers()`

Server export `AdminTiers` (`server/main.lua`).

**Returns**

- `any`

### `BusinessTablet(playerId, characterId, businessId, payload)`

Server export `BusinessTablet` (`server/business.lua`).

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `any` |  |
| `characterId` | `any` |  |
| `businessId` | `any` |  |
| `payload` | `any` |  |

**Returns**

- `any`

### `CardPurchase(cardId, amount, description)`

Returns `{ ok = true, points, available }` or `{ ok = false, error }` (`no_card`, `card_blocked`, `card_expired`, `no_credit`, `credit_late`, `credit_limit`, `busy`).

| Parameter | Type | Description |
|---|---|---|
| `cardId` | `any` |  |
| `amount` | `any` |  |
| `description` | `any` |  |

**Returns**

- `any`

### `CardRefund(cardId, amount, description)`

Server export `CardRefund` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `cardId` | `any` |  |
| `amount` | `any` |  |
| `description` | `any` |  |

**Returns**

- `any`

### `PosCards(playerId)`

Server export `PosCards` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `any` |  |

**Returns**

- `any`

### `PosPurchase(playerId, cardId, pin, amount, description)`

Server export `PosPurchase` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `any` |  |
| `cardId` | `any` |  |
| `pin` | `any` |  |
| `amount` | `any` |  |
| `description` | `any` |  |

**Returns**

- `any`

### `ShopCharge(playerId, payment, amount, description)`

Server export `ShopCharge` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `any` |  |
| `payment` | `any` |  |
| `amount` | `any` |  |
| `description` | `any` |  |

**Returns**

- `any`

### `ShopOptions(playerId)`

Store payment terminal (registered with coe_shops:RegisterPaymentMethod, method `card`): options are active physical cards in hand; the charge requires the PIN. The caller remains the store (`Credit.PurchaseCallers`).

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `any` |  |

**Returns**

- `any`

### `ShopRefund(_, ref, amount, description)`

Server export `ShopRefund` (`server/main.lua`).

| Parameter | Type | Description |
|---|---|---|
| `_` | `any` |  |
| `ref` | `any` |  |
| `amount` | `any` |  |
| `description` | `any` |  |

**Returns**

- `any`

### `TabletCall(playerId, appId, action, payload)`

Called only by coe_tablet. Every action returns the updated statement in `bank`.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `any` |  |
| `appId` | `any` |  |
| `action` | `any` |  |
| `payload` | `any` |  |

**Returns**

- `any`

### `TabletVisible(playerId, appId)`

Bank app visible on the device: only for coe_tablet and coe_phone, when banking is ready.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `integer` |  |
| `appId` | `string` | `bank` |

**Returns**

- `boolean` `visible`

### `WalletCards(cardIds)`

Current status of a wallet's cards (up to 10 IDs): `{ ok, cards = { [id] = view } }`; nonexistent cards are omitted.

| Parameter | Type | Description |
|---|---|---|
| `cardIds` | `any` |  |

**Returns**

- `any`

### `WalletEligible(playerId)`

Cards the player can add to the wallet: active physical cards in inventory and the account's active virtual card.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `any` |  |

**Returns**

- `any`

### `WalletIssueVirtual(playerId)`

Requests a virtual card through the wallet (same rules as at a branch); returns the issued card.

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `any` |  |

**Returns**

- `any`

### `WalletLink(playerId, cardId, pin)`

Links a card: either the account's virtual card or a physical card in hand with its PIN (errors count as they do at an ATM).

| Parameter | Type | Description |
|---|---|---|
| `playerId` | `any` |  |
| `cardId` | `any` |  |
| `pin` | `any` |  |

**Returns**

- `any`
