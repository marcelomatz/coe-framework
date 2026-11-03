# coe_news

COE OS news outlets. Each media outlet is a **business** in the `media` category (`coe_businesses`) and has its **own app** on the smartphone and tablet, installed for free from the Store (News category):

| App | Outlet | Region | Business |
|---|---|---|---|
| `weazel` | Weazel News | Los Santos | `weazel_news` |
| `rebel` | Rebel News | Blaine County | `rebel_news` |

Both businesses are seeded on the first startup (area, "Newsroom" clock-in point, "Archive" stash, and roles). After that, the area, points, **owner**, and **staff** are managed in the Businesses tab of `coe_admin`.

## Portal (any reader)

- Headline and list of published articles, section filter, title/subtitle search, and pagination.
- Article view with cover photo, subtitle, byline, date, and view count (one per player per article while online).
- **Breaking** articles notify users who have the app installed (one per outlet every `Articles.BreakingCooldownMinutes`).
- Active ads appear as "Advertisement" every `Ads.FeedEvery` articles.

## Editorial line

Each outlet defines a slogan, editorial-line text, active sections (News, Events, Gossip, Opinion, Police, Economy, Sports), and the daily ad price. Requires the `news.editorial` permission.

## Newsroom

Article workflow: **draft → in review → published → offline** (can be republished).

| Action | Who |
|---|---|
| Write, edit your own draft, submit for review | `news.write` |
| Edit in review, return to author (with a note), publish (breaking or not), take offline, edit published article | `news.publish` |
| Delete | author (draft or in review) or `news.publish` |

- Cover image from the device camera (same upload as Insta, `coe_apps`); the old photo is deleted when replaced.
- "Byline: Newsroom" hides the author from the public (useful for gossip).
- Limits in `Articles` (sizes, `MaxDraftsPerAuthor`, `SaveCooldownSeconds`).

Seeded roles: Intern and Reporter (`news.write`), Editor (+ `news.publish`, `news.ads`), Editor-in-Chief (all + `business.staff`, `business.funds`, `business.remote`). The owner has all permissions. As with every business, staff must be clocked in to act (`clockRequired`); in the `media` category the clock-in point remains usable outside the area (`clockOffsite`) to cover stories on the street.

## Ads

1. Any citizen or business can buy through the app (Advertise tab): advertiser, title, text, and duration (`Ads.Days`). Payment is from a personal account or a business account where they have `business.funds`.
2. The amount (days × outlet price) is debited immediately and **held**.
3. Anyone with `news.ads` can approve or reject (Ads tab). Once approved, the ad runs for N days and the amount goes to the **outlet's business account**. If rejected, canceled by the buyer, or unanswered for `Ads.PendingHours`, the amount is returned to the payer.

Limits: `MaxPendingPerBuyer` per buyer, `MaxActivePerOutlet` active per outlet, daily price between `MinPricePerDay` and `MaxPricePerDay`.

## Equipment

TV camera (`news_camera`), microphone (`news_mic`), and boom microphone (`news_boom`) are `coe_inventory` items (`data/coe_base_items.lua`, images in `data/images/news_*.png`). Stock is stored in the business stash `Equipment.Stash` (default `arquivo`, the seeded "Archive" stash); staff restocks and withdraws items from the **Press** tab in admin, and staff members collect them from the stash. Using an item holds the equipment with a prop and animation (`client.lua`); use it again, press X (`Equipment.CancelKey`), or enter a vehicle to put it away. Visual only: nothing changes on the server. Each item's prop, bone, offset, rotation, and animation are configured in `Equipment.Items` and need in-game adjustment.

## Admin panel (Press tab)

Exports only for `AdminResources` (`coe_admin`), which checks the `coe_admin.news.manage` permission:

- `AdminOverview()`: outlets with editorial line, statistics (`NewsPersistence.Stats`: articles by status, views, ads, total and last-30-day revenue) and society account; section and equipment catalogs; limits.
- `AdminQuery(kind, { outlet, ... })`: `ads` (`group` = `pending`, `active`, or `history`, with buyer name), `articles` (`status`, `search`), `article` (`id`, with body), and `equipment` (stash stock and which staff member or owner has each item).
- `AdminAction(op, { outlet, admin, ... })`: `editorial`, `adApprove`, `adReject` (refunds the payer), `adTakedown` (`refund` = `none`, `remaining`, or `full`; refund comes from the outlet's account via `SocietyCharge` and goes back to the personal account or paying business account; if funds are insufficient, nothing changes), `articleUnpublish`, `articleRepublish`, `articleDelete` (deletes the photo), and `stock` (`item`, `count` from 1 to `MaxPerOperation`, `op` = `add` or `remove`; creates the stash inventory if it does not yet exist).

Every action is audited in `coe_audit` with `source = admin:<id>`. New ad status: `removed` (taken offline by staff). Staff, roles, and fleet are recorded by `coe_admin` itself (in `coe_businesses` and `coe_garages`), restricted to businesses in the `media` category.

## Integration

- Exports `TabletVisible(playerId, appId)` and `TabletCall(playerId, appId, action, payload)`, only for `coe_tablet` and `coe_phone`. The app must be installed (`coe_apps:HasApp`).
- Photos: `coe_apps` (`ClaimPhoto`, `PhotoData`, `DeletePhoto`; `Photos.Apps` and `Photos.Callers`).
- Money: `coe_economy` (`Debit`/`Credit` with reasons `news_ad`/`news_ad_refund`, `SocietyCharge`/`SocietyCollect`).
- Interface: `html/news.js` (+ `news.css`) registers every outlet in `OUTLETS`, with its color.
- Tables: `coe_news_outlets`, `coe_news_articles`, `coe_news_ads` (migrations in `server/migrations.lua`).

To add an outlet: add it to `Outlets` (config), the apps in `coe_apps`, `coe_phone`, and `coe_tablet`, and `OUTLETS` (`news.js`).

Tests: `lua test/news_test.lua` (rules) and `lua test/admin_test.lua` (admin panel exports with simulated economy, inventory, and database).

Outlet podcasts are planned for a later phase.
