# coe_banking

Banking system built on `coe_economy`: branches, ATMs, cash, PIN-protected cards, and business accounts.

Replaces the framework's basic bank (`coe_bank`): on startup, and whenever `coe_bank` restarts, it calls the `Yield` export (ACE `coe.bank.yield`, granted by the framework in `CoeAccess.FirstParty`). Basic banking hides its branches, ATMs, and blips until `coe_banking` stops. Branches and statement reasons (`bank_withdraw`, `bank_deposit`, `bank_transfer`, `bank_refund`) are the same, so the player's history remains consistent.

- **Account**: the balance is held by `coe_economy` (one per character). **Cash** is the inventory item `money`.
- **Branch** (counter with an "E" prompt, "Bank" blip): balance, cash withdrawal and deposit, identity transfer (state ID, including to offline recipients), statement, and cards. A business owner, employee, or partner chooses when opening whether to use a personal account or one of the business accounts.
- **ATM** (aim at any ATM model in `AtmModels`; surface target, since many ATMs are part of the map and are not entities available to aim at): requires a `card_bank` in inventory and a 4-digit PIN. Withdrawal (quick or another amount), deposit, balance, and latest transactions, up to `MaxAtmAmount` per operation.

## Cards

- Issued at a branch with a customer-defined PIN; fee `CardFee` (debited from the account). Reissuing (replacement) blocks the previous card (`replaced`).
- **Validity** of `CardValidityDays` days (default 60). Once expired, the card no longer works at ATMs, and the branch offers "Renew card" (`CardRenewFee` fee, default 0). Renewal is a new issue: tier, limit, points, and history remain in the credit account and are not lost.
- **Virtual card**: requested at the branch, in online banking (tablet), or in the smartphone Wallet (`VirtualCardFee` fee, default 0). It has no item or PIN and exists only in the phone Wallet; it uses the same credit account. A new virtual card replaces the previous one (`replaced`) and does not affect the physical card.
- The `card_bank` item carries `metadata.cardId`. Anyone holding the card and knowing the PIN can use the cardholder's account (theft is part of RP); the cardholder revokes access by blocking the card at a branch.
- `MaxPinAttempts` consecutive incorrect PINs block the card (`pin`); the cardholder can unblock it by setting a new PIN at a branch. Lost/stolen (`lost`) and replaced cards are permanently blocked.
- The PIN is stored with salt and a hash using repeated rounds (`PinHashRounds`), never in plaintext.

## Business account

Each business's cash (the `coe_economy` society) is its own account, separate from personal accounts (`server/business.lua`, pure rules in `server/business_rules.lua`):

- **Access:** when opening a branch, a business owner, employee, or partner chooses an account (personal or business); **Switch account** returns to the choice. The business account has its own overview, sections, and rules.
- **Role permissions** (registered in `coe_businesses` with `RegisterPermissions`): `banking.view` (balance, statement, and reports), `banking.withdraw` (withdraw), `banking.transfer` (pay and transfer), `banking.cards` (business cards), `banking.loans` (loan payments), and `banking.payroll` (payroll and bonuses). The owner has all permissions; any banking permission allows viewing the account; anyone in the business may deposit; partners can monitor the account. Anyone with the old `business.funds` permission (`Business.LegacyPermission`) retains full access until the owner updates roles.
- **Overview and statement:** period results (today, 7, 30, or 90 days: inflows, outflows, period balance, and entries), alerts (overdue loan, cash insufficient for payroll), and a paginated statement filterable by period, inflows/outflows, and category (deposits, withdrawals, transfers, payroll and bonuses, cards, loans, revenue, expenses). Each bank transaction shows who performed it, the recipient, and description (table `coe_banking_business_ops`, linked to the `coe_economy` statement by reference `bop:<id>`); salaries and deposits show the person's name.
- **Deposit and withdrawal:** from the personal account or in cash (cash only at a branch). The statement includes the name of the person who performed it.
- **Transfers and payments:** from the business to a person (identity; credited to their personal account, reason `business_payment`) or another business (business code; credited to its cash account, `business_transfer`), with a description, up to `Business.MaxTransfer`.
- **Payroll:** next payroll (who is clocked in and how much they receive; who is off duty), notice if cash is insufficient, pay payroll now (same rules as automatic payroll, `coe_economy`'s `RunPayroll` export), bonus for a business member (`business_bonus`), and payments made in the last 30 days.
- **Business cards:** debit from cash, issued at a branch to someone in the business (owner or staff) with a PIN and daily limit (`Business.DefaultDailyLimit`, 0 = unlimited, up to `MaxDailyLimit`); the fee (`Business.CardFee`) comes from cash, and the plastic card (a `card_bank` item bearing the business name) is given to the requester to deliver to the cardholder. Works at ATMs (withdrawal and deposit into the business's cash account, `Business.AtmFee`) and in the phone Wallet (purchases through `CardPurchase`/`CardRefund`, debited from cash). The daily limit is reserved atomically; a reversed transaction returns the amount to the limit. The card stops working if the cardholder leaves the business. Up to `Business.MaxCards` active cards per business; limit, PIN change, and blocking are managed through the business account.
- **Loans:** business loans and loan requests to the bank (owner only, at a branch) belong to the business account; cash payments require `banking.loans`. Any debtor can still pay from their personal account (Credit tab).
- **Tablet:** **Bank** tab in each business app, registered with `coe_businesses:RegisterTab` (replaces Finance; `BusinessTablet` handler, accepted only from `coe_businesses`; screen in `window.CoeBusinessTabs.bank` in `html/business.js`): overview, statement, transfers, cards (limit and block), payroll, bonuses, and loan payments, with the same permissions. Cash, card issuance, PIN changes, and loan applications are branch-only.
- **Admin** (Bank > Businesses): list of accounts with balances, cards, and loans; per account, statement with who performed each transaction, staff cash adjustment (`admin_adjustment`), and cards (limit, block, unblock, validity). Exports `AdminBusinessAccounts`, `AdminBusinessAccount`, `AdminBusinessAdjust`, and `AdminBusinessCardLimit` (`coe_admin` only).

The interface (`html/business.js` + `html/bank-ui.css`) is the same at the branch and on the tablet.

## Credit

The card is hybrid: debit from the account and credit at the credit-account tier (one per character, **Credit** tab at the branch).

- **Relationship score (0 to 1000)**: account age (first statement entry), inflows during the last `InflowDays` days (excluding refunds, cash deposits, transfers, and adjustments so withdrawals and deposits do not inflate it), current balance, and statement history (on-time payments add points; late payments subtract them; current delinquency incurs `LateNowPenalty`).
- **Tiers** (`Credit.Tiers`): Essential, Gold, Platinum, and Black, with minimum score, limit, credit points per $100, fee per statement, and free ATM withdrawal. The customer requests a card or upgrade at the branch; the tier falls by one level at closing if the score is `DowngradeMargin` below the minimum. `config.lua` seeds the `coe_banking_tiers` table only on first startup; tiers are edited afterward in the admin panel (Bank tab).
- **Custom limit and lock:** staff can set a custom limit (up to `Credit.AdminMaxLimit`) and lock the tier to prevent downgrade.
- **Statement:** closes every `CycleDays` days and is due `DueDays` later. Minimum payment is `MinPaymentRate` (floor `MinPaymentFloor`). Unpaid balance becomes revolving credit (`RevolvingRate` at the next closing). Payment at a branch: full, minimum, or custom amount (reason `card_invoice`).
- **Late payment:** penalty (`LateFeeRate` + `LateFeeFlat`), daily interest (`LateDailyRate`), credit blocked until minimum is paid, and automatic balance debit after `AutoDebitDays`.
- A server loop processes closings, due dates, and interest every `TickSeconds`, even when the cardholder is offline. Each account is locked per character and uses optimistic writes (`version`).
- **ATM:** `AtmWithdrawFee` fee per withdrawal (reason `atm_fee`), waived for tiers with `freeAtm`.

- **Digital Wallet** (exports only for `WalletCallers`, currently `coe_phone`): `WalletEligible(playerId)` lists eligible cards (active physical cards in inventory and the character's active virtual card); `WalletLink(playerId, cardId, pin)` validates linking (`BankingRules.CanLink`: virtual card must belong to the cardholder; physical card must be held and its PIN provided; incorrect PIN counts toward attempts as at an ATM); `WalletCards(ids)` returns the status of up to 10 cards; `WalletIssueVirtual(playerId)` issues a virtual card.
- **Credit purchases** (`CardPurchase(cardId, amount, description)` and `CardRefund(cardId, amount, description)`): only for resources in `Credit.PurchaseCallers` (currently `coe_apps`, `coe_amzg`, `coe_shops`, `coe_fuel`, and `coe_phone`, which charges the Wallet for stores), up to `MaxPurchase` per purchase, charged to the cardholder's credit account. The card must be active (not blocked or expired) but need not be held: the payer chooses the card in the smartphone Wallet. It is added to the open statement's purchases (`purchase` entry) and earns points; a refund offsets open purchases first and then the closed statement (`refund` entry). Returns `{ ok, points, available }` / `{ ok, refunded }` or `{ ok = false, error }` (`no_card`, `card_blocked`, `card_expired`, `no_credit`, `credit_late`, `credit_limit`, `busy`).
- **POS terminal** (`PosCards(playerId)` and `PosPurchase(playerId, cardId, pin, amount, description)`, same callers as `Credit.PurchaseCallers`): in-person purchase requiring the **physical card in hand**. `PosCards` lists the player's active cards in inventory (`{ id, last4, holder, business }`); `PosPurchase` verifies the card in inventory and PIN (same attempts as ATM: `wrong_pin` with `left`, then `card_blocked`) and charges like `CardPurchase` (cardholder's credit, or business cash for a business card). In `coe_shops`, it is registered as the `card` payment method (`RegisterPaymentMethod`, kind `pin`), using `ShopOptions`, `ShopCharge`, and `ShopRefund` exports; registration repeats when `coe_shops` or `coe_businesses` restarts.

## Loans

Granted by staff (admin Bank tab): amount, total interest (%), and number of installments, within `Loans` limits (`MaxPrincipal`, `MaxRate`, `MaxInstallments`, `MaxActive`). The amount is deposited into the account (reason `bank_loan`), and installments are due every `IntervalDays` days with automatic balance debit. An unpaid installment becomes overdue (affecting the relationship score) until there is enough balance. In the branch's **Credit** tab, the customer pays an installment or pays off the loan early (reason `loan_payment`). Staff can forgive the balance (including late interest).

- **Relationship-based rates** (`Loans.Pricing`): bands `{ minScore, rate, lateDailyRate }`. Better scores mean lower contract interest (suggested to staff) and lower daily late interest. Late interest is fixed in the contract.
- **Daily late interest:** an overdue installment accrues compound interest for every full day late on the installment's outstanding amount (`loan_interest` entry in credit history). Each pass applies at most `MaxAccrueDays` days; the remainder is applied on the next pass. Paying the installment ends its interest accrual.
- **Business loan:** the owner applies from the business account at a branch (amount, installments, and purpose); the request enters the staff queue (admin, Bank > Requests), where staff approves (optionally adjusting interest and installments) or rejects with a reason. One pending request and up to `MaxActiveBusiness` active loans per business; if the business changes owner before a decision, approval is rejected (`owner_changed`). Once approved, funds are credited to business cash (reason `bank_loan`), and the debt is registered to the owner and partners at that time (`coe_banking_loan_debtors`). The score used is the debtors' average. Installments are debited from cash (reason `loan_payment`); if cash is insufficient, an installment becomes overdue, accrues interest, and affects all debtors' relationship scores. Anyone with `banking.loans` pays from business cash at the business account (branch or tablet); any debtor can also pay from their personal account (**Credit** tab).

## Administration exports

Only accept calls from `coe_admin` and return `true` or `{ error }`: `AdminTiers`, `AdminSaveTiers`, `AdminAccount`, `AdminSetCredit`, `AdminPoints`, `AdminCard` (`block`, `unblock`, `extend`), `AdminGrantLoan`, `AdminForgiveLoan`, `AdminLoanRequests`, and `AdminDecideRequest`.

## Consistency

The account and inventory are separate resources; operations use compensation:

- Withdrawal: debit the account and give cash; if the inventory has no room, refund (`bank_refund`).
- Deposit: remove cash and credit the account; if the credit fails, return the cash.
- Business account: each operation is recorded before moving money (pending → completed or failed); cash given after debit is returned to the account if the inventory has no room; a failed cash deposit returns the cash.

Failed refunds are logged (`refund_failed`). Statement reasons: `bank_withdraw`, `bank_deposit`, `bank_transfer` (reference `state:<ID>`), `bank_refund`, `card_fee`, `card_invoice`, `atm_fee`.

## Configuration

`config.lua`: fees, PIN attempts, operation limits, quick-withdrawal amounts, statement sizes, ATM session duration, ATM models, and branches (`id`, `label`, coordinates, and `radius`).

## Persistence

Tables `coe_banking_cards` (with `expires_at`), `coe_banking_credit` (with `custom_limit` and `tier_locked`), `coe_banking_credit_entries`, `coe_banking_tiers`, `coe_banking_loans` (with `late_rate`, `interest`, `interest_at`, and business), `coe_banking_loan_debtors`, and `coe_banking_loan_requests` (versioned migrations in `server/migrations.lua`, tracked in `coe_banking_schema_migrations`; v3 fills expiration dates for existing cards with issue date + 60 days; v4 leaves existing loans without late interest and records the cardholder as a debtor; v5 adds `kind` to cards: `physical` or `virtual`; v6 adds daily limits for business cards (`daily_limit`, `spent_amount`, `spent_day`) and `coe_banking_business_ops`). Business card: `account_type = 'business'` and `account_ref` = business ID.

## Tests

```
cd coe_banking
lua test/banking_test.lua
lua test/credit_test.lua
lua test/loan_test.lua
lua test/tablet_test.lua
lua test/business_test.lua
lua test/business_flow_test.lua
```

`business_test.lua` covers business-account rules (permissions, daily limit, destination, statement filters and categories, projected payroll); `business_flow_test.lua` exercises `server/business.lua` with mocked database, economy, businesses, and inventory (deposit, withdrawal, transfers, bonuses, payroll, card issue and limits, ATM, Wallet purchase, former member as cardholder, overview, tablet, and admin).

## Interface

The branch and ATM use the same page (`html/`), styled with `coe_ui`: chamfered panel (`coe-panel`), `coe-*` buttons and fields, token-only colors. They follow the server theme and the color chosen by the player with `/hud` (`@coe_ui/theme_bridge.lua`; the page requests the theme on each opening).

- **Branch:** side overview (balance, cash, available credit, and relationship) and Account, Cards, and Credit sections for personal accounts (Overview, Statement, Transfer, Cards, Payroll, and Loans for business accounts); a red dot marks a section with something overdue or no active card.
- **Credit:** the score target is always the first tier above the higher of the current tier and the tier unlocked by the score. Anyone upgraded (including by the bank, above their current score) does not see "X points remaining" for their existing tier or lower tiers; those appear as "Your tier" and "Below your tier."
- **ATM:** card selection, PIN via on-screen or physical keyboard (digits, Backspace, Enter), quick withdrawal, custom amount, deposit, and latest transactions.

## COE OS

**Bank** app in `coe_tablet` (`html/tablet_app.js`, `server/tablet.lua`, `TabletCall` export, accepted only from `coe_tablet`): balance, cards (including a virtual-card request), and statement; transfer by citizen ID; card blocking; statement payment (minimum or full) and loan payment (installment or full). Uses the same rules and limits as the branch.
