# coe_deepweb

The server's DeepWeb: an anonymous network accessed through **equipment tiers**, using `coe_crypto` crypto as its
currency. Phase 1: devices and tiers, anonymous identity, computers, and mining. Phase 2: the **onion browser** (address
bar, tabs, bookmarks) and network sites: **DuckDark** (search engine), **Rabbit** (forum), **Deep Market**
(crypto-escrow marketplace with pickup points), and **Fantasma** (staff profile for the hacking world, outside the
directory), as well as sites assembled from blocks in admin.

## Equipment tiers (`Tiers`)

| Tier | Device | How to access |
|---|---|---|
| 1 | Phone | **Onion** app, after installing the browser with the `onion_usb` USB drive |
| 2 | Tablet | **Onion** app (same USB drive) |
| 3 | Notebook (`laptop`) | Use the item: opens the computer anywhere |
| 4 | Desktop (`desktop_pc`) | Installed in a property; `/computador` nearby |
| 5 | Home server (`home_server`) | Installed in a property; `/computador` nearby |

Each network feature has a minimum tier (`Features`). The app's **Network** screen shows what is available, locked
(insufficient tier), or coming soon:

| Feature | Tier |
|---|---|
| Anonymous identity, DuckDark, Rabbit (read, post, comment, vote), Deep Market (browse) | 1 |
| Deep Market: purchase | 2 |
| Deep Market: sell, Rabbit: create community | 3 |
| Mining, install browser | 4 |
| Host a site (coming soon) | 5 |

System contracts and paid services remain "coming soon."

## Item sources

| Item | Sources |
|---|---|
| `laptop`, `desktop_pc`, `home_server`, `usb_black` | **Amzg** (Electronics category, delivered to a property). Added to the catalog by migration 2 in `coe_amzg`; price and pause status are set in admin. |
| `onion_usb` | **Computer workbench** (installed desktop or server: Computer tab → Open workbench; 1 `usb_black` → 1 `onion_usb` in 45 s, `Craft`). **NPC contact** (below). **Robbery loot** (`coe_loot`: residence, pedestrian, vehicle, business). Factions: the `hacking_onion_usb` recipe may be unlocked when illegal benches exist (#161). |
| Used `laptop`, `usb_black` | Also dropped in robberies (`coe_loot`). |
| `crypto_paper`, `crypto_usb` | Created in the Crypto app (`coe_crypto`). |

## NPC contact (`Dealer`)

- A contact sells the onion USB drive for **cash** (payment first in `black_money`, then `money`). They are at one of
  the `Dealer.Spots` locations and move every `RotationMinutes` (same location for everyone). The location is not
  shown on the map: it circulates through RP. Staff can see where the contact is with `coe_deepweb_dealer` (ACE
  `command.coe_deepweb_dealer`).
- Server-wide stock per rotation (`perRotation`); when depleted, wait for the next location.
- Each sale has an `Alert.Chance` (20%) of creating a **Suspicious Deal** (`suspicious_deal`) call in `coe_dispatch`
  at that location: the first risk of attracting police attention.
- The ped is local (each client creates their own near the location), and purchases use the target (`coetarget`);
  the server checks distance, stock, and money. Coordinates are provisional: validate them in game.

## Onion browser (phone and tablet)

Using the `onion_usb` item installs the browser on the **phone currently in use** (the last one opened); if there is
no phone or the browser is already installed on it, it installs on the **tablet**. The USB drive is consumed. The
installation is tied to the device (`phone:<serial>`) or the character's tablet. The `onion` app appears only on
devices where it is installed (`TabletVisible`).

## Computers

- **Notebook:** using the item turns on the computer. Its serial (`metadata.serial`, e.g. `LT-7KQ2M9XA`) is written
  to the item the first time. Whoever has the notebook (and knows the password, if set) can use everything on it.
- **Desktop and server:** using the item **inside a property** (`coe_housing:CurrentSpace`: residence, commercial
  space, or hideout) installs the machine there, at the player's position. Up to `Install.MaxPerSpace` per space. To
  use it, run `/computador` within `Install.UseDistance` meters. **Disassemble** (Computer tab) returns the item with
  the same serial.
- The computer screen is a dedicated NUI (notebook or monitor frame), with a desktop and **Onion** and **Wallet**
  apps (`coe_crypto`, if started). The server checks for each action that the player still has the notebook or is near
  the machine in the same space; otherwise the computer closes.
- **Computer password** (optional, Computer tab): tied to the serial. Without it, nobody can enter, including the
  wallets stored on the machine. Repeated errors lock it for `Device.LockSeconds`.
- **Face recognition** (Computer tab, password required): registers the face of the person using it. That character
  opens the computer without entering the password (the bar displays "Unlocked by face recognition"); another person
  sees the face button, which rejects them, and can enter only with the password. Removing the password disables face
  recognition. Same behavior as the phone.
- Crypto wallets, password, and connected handle are tied to the **serial**: disassembling and reinstalling elsewhere
  carries everything along; the same is true if the machine is stolen.

## Anonymous identity

- Password-protected handle (`Handles`): 3 to 20 characters (lowercase, numbers, `.`, `_`, `-`); reserved names are
  blocked, including names disguised with dots. Each character can create up to `Handles.MaxPerCharacter`.
- The handle stays **connected on the device**, not on the character: whoever uses the device is signed in as you.
  Changing the password disconnects other devices. Repeated incorrect passwords lock the handle for
  `Handles.LockSeconds`.
- **My handles** (Identity tab): the handle's creator can reset the password without the old one; the handle is
  disconnected from other devices and connected on this one.
- Handle and computer passwords use the framework's own hash, `coe_core/lib/hash.lua` (iterated SHA-256 with salt),
  not FXServer bcrypt, which did not verify server-side. Old hashes are rebuilt on the first successful login.
- The server stores who created each handle (`owner_character`) and a reputation (future phase); none of this is sent
  to the client.

## Mining

- Desktops and servers mine (`Mining.Hash`: 10 and 40). In the **Mining** tab: choose the receiving wallet (any
  existing address on the network) and toggle mining on/off.
- Every `Mining.TickMinutes`, each running machine checks the property contract (`coe_housing:AddressActive`), charges
  power (`Mining.PowerCost`) to the **installer's bank account** (`coe_economy`, reason `deepweb_power`), and joins the
  `coe_crypto:MintMining` round. Without a contract or sufficient balance, the machine is excluded from the round
  (status is visible in the app). If the network rejects the round, power is refunded.

## Events and exports

- Exports (smartphone and tablet): `TabletVisible`, `TabletCall` (app `onion`). Admin (`coe_admin` only):
  `AdminOverview`, `AdminSaveSite`, `AdminDeleteSite`, `AdminSaveVendor`, `AdminDeleteVendor`, `AdminResolveOrder`,
  `AdminRemovePost`, `AdminReplyContact`, `AdminCloseContact`. See
  [`reference/coe_deepweb.md`](../reference/coe_deepweb.md).
- Computer: client → server `coe_deepweb:computer:nearby`, `coe_deepweb:computer:call`,
  `coe_deepweb:computer:close`; server → client `coe_deepweb:computer:open`, `coe_deepweb:computer:result`,
  `coe_deepweb:computer:close`. Computer wallet calls are forwarded to `coe_crypto:ComputerCall` with the device key.

## Tables

`coe_deepweb_handles` (handles), `coe_deepweb_sessions` (handle connected per device), `coe_deepweb_browsers`
(installed browser), `coe_deepweb_devices` (password per serial), `coe_deepweb_rigs` (installed machines: property,
space, position, mining), `coe_deepweb_bookmarks`, `coe_deepweb_sites`, `coe_deepweb_communities`,
`coe_deepweb_posts`, `coe_deepweb_comments`, `coe_deepweb_votes`, `coe_deepweb_listings`, `coe_deepweb_orders`,
`coe_deepweb_reviews`, and `coe_deepweb_state` (migration 3), `coe_deepweb_contacts`, and the sites' `listed` column
(migration 4). Migrations in `server/migrations.lua`, tracked in `coe_deepweb_schema_migrations`.

## Browser

- The **Onion** app (phone, tablet, and computers) is a browser: tabs (`Browser.MaxTabs`), back/forward, reload,
  home (`Browser.Home`, DuckDark), and address bar. Text that is not an address becomes a DuckDark search.
- Addresses: `<name>.onion[/path][/?q=search]` and internal pages `about:rede`, `about:identidade`,
  `about:mineracao`, `about:computador`, `about:favoritos`, `about:historico`.
- **Bookmarks** are stored on the device (`coe_deepweb_bookmarks`, up to `Browser.MaxBookmarks`): whoever uses the
  device can see them. **History** exists only for the open session and disappears when the browser closes.
- Unknown or offline domains display "The hidden service could not be reached."
- All network content is written with `textContent`: no player or staff HTML reaches the NUI.

## Sites (`coe_deepweb_sites`)

- **System sites** (`Sites.System`): `duckdark.onion` (app `search`), `rabbit.onion` (`forum`),
  `deepmarket.onion` (`market`), and `fantasma.onion` (`profile`). Recreated at each startup with config data; not
  editable in admin. `listed = false` removes a site from the DuckDark directory and search (only people who know
  the address can open it). Migration 4 replaced `bazar.onion` with `deepmarket.onion` (bookmarks and block links
  were rewritten; `bazar` became a reserved name).
- **Block-based** (empty app): created by staff in admin (**DeepWeb > Sites**). Blocks: `heading`, `text`, `quote`,
  `notice` (tone `info|warn|danger|success`), `list`, `divider`, `link` (`.onion` or `about:` address), and `listing`
  (Deep Market listing). Validated by `DeepwebRules.Blocks`; stored as JSON. The **Show in DuckDark** (`listed`)
  option hides the site from the directory and search.
- Reserved names are in `Sites.Reserved` (including names disguised with hyphens). The `owner_handle` column
  already exists for **player-hosted sites** (tier 5), in a future phase.

## DuckDark

Search (2 to 40 characters) across active and listed sites (title, description, keywords, domain), Rabbit posts, and
active Deep Market listings. Only content on the server is searched. With no query, the site directory is shown.

## Rabbit

- `r/<name>` communities (`Forum.Communities` are created on first startup), posts with title and text, threaded
  comments (up to `Forum.MaxDepth` levels), votes (+1/-1, not on one's own content), and `u/<handle>` profile with
  points (sum of scores) and Deep Market seller reviews.
- Sorting: hot (score weighted by age, `DeepwebRules.Hot`, past week), new, and top.
- Posting requires a connected handle; `PostCooldownSeconds` and `CommentCooldownSeconds` intervals apply per handle.
- **Create community** requires tier 3 (`forum_create`), up to `MaxCommunitiesPerHandle` per handle. The creator
  moderates by removing posts and comments in the community. Authors can also remove their own content. Staff can
  remove posts in admin.

## Deep Market

- **Listings**: from **NPC vendors** (no handle, registered in admin under **DeepWeb > Vendors**;
  `Market.Vendors` are added only once) or **players** (tier 3, connected handle, up to
  `MaxListingsPerHandle`). Type `item` (inventory item × quantity per unit) or `service`. Price is in currency
  (`0.5`), stored in units (`CoinDecimals`). The seller specifies the receiving wallet (`payout`).
- **Purchase** (tier 2): choose a wallet whose key is available on the device (`coe_crypto:HeldWallets`). The amount
  (plus network fee) goes to **escrow** (`coe_crypto:EscrowLock`), and stock is reserved.
- **Item**: each order selects a **pickup point** (`Market.Drops`). On the site, **Go deliver** (seller) or
  **Go collect** (buyer) **arms the point** for the character: GPS is set and, within `DropSpawnDistance`, a local box
  (`DropProp`) with a `coetarget` target is created. Delivery happens **through the target** at the location (event
  `coe_deepweb:drop:use`): the server checks that the point is armed (same character and handle, valid for
  `DropTicketMinutes`), distance (`DropDistance` horizontally and `DropHeight` vertically, since coordinates are
  provisional), order state, and inventory. Delivering removes items from the seller; collecting puts them in the
  buyer's inventory and escrow pays the seller (`EscrowRelease`), less the fee (`FeeBps`, sent to the exchange
  reserve). NPC vendor orders are created at the pickup point. Armed points are held in memory: after a resource
  restart, arm again from the site.
- **Service**: the seller marks it complete; the buyer **confirms** or **disputes** (with a reason). If there is no
  response within `AutoReleaseHours`, payment is released automatically. Disputes go to staff (**DeepWeb > Orders**),
  who can refund or pay the seller.
- **Cancellation**: the seller can cancel at any time; the buyer can cancel after `DeliverHours` without delivery.
  Escrow is refunded in full and stock is returned. Staff can also cancel paid and stuck orders.
- **Review** (1 to 5) after completion: appears in the seller profile and adds `rating - 3` to the handle's reputation.
- Delivering or collecting has a `Market.Alert.Chance` of creating a **Suspicious Deal** call in `coe_dispatch`.
- Robustness: conditional state change (`MoveOrder` only if still in the expected state), collection with intermediate
  `collecting` state, and `settled` marks payment as completed: if the crypto network fails, the market loop
  (1 min) retries. The same loop releases services and items left for more than `AutoReleaseHours`.
- The buyer never sees the seller's identity beyond the handle; the server stores the buyer character
  (`buyer_character`), and `coe_crypto`'s ledger stores who moved each amount.

## Staff profiles (`profile`)

System sites with `app = 'profile'` and a `profile` table in config: `handle`, `tagline`, `bio` (paragraphs separated
by blank lines), `skills`, `facts` (`{ label, value }`), `rules`, and `contact`. `fantasma.onion` is the account of the
staff member responsible for the hacking world; it is not shown in DuckDark.

With `contact = true`, the page has a form: requires a connected handle, text from `Contact.BodyMin` to
`Contact.BodyMax` characters, `Contact.CooldownSeconds` interval between messages from the handle, and up to
`Contact.MaxOpen` unanswered messages per site. Messages are stored in `coe_deepweb_contacts` (migration 4) and
appear in admin under **DeepWeb > Contacts**. Replies appear on the same page (latest `Contact.Shown`), and anyone
online with that handle receives a notification. Staff can also archive messages.

## Site screens (`html/sites.js`)

The browser (`deepweb.js`) loads `nui://coe_deepweb/html/sites.js` and looks for a renderer in
`window.CoeOnion.sites[app]` (`search`, `forum`, `market`, `profile`, and `blocks` for block-based sites); each site's
visual design is in `html/sites.css`. Layout adapts to available width (on a phone the NUI is small inside a wide
window, so screen-based `@media` does not work). An app without a renderer displays "This site did not open in your
browser."

Routes for each site:

| Site | Addresses |
|---|---|
| DuckDark (`search`) | root (search + directory), `/?q=text` (results from sites, Rabbit, and Deep Market) |
| Rabbit (`forum`) | root, `new`, `top`, `criar`, `r/<community>[/new\|top]`, `r/<community>/enviar`, `r/<community>/<id>`, `p/<id>`, `u/<handle>` |
| Deep Market (`market`) | root (`/?q=` search), `c/<category>`, `fornecedores`, `a/<id>`, `painel`, `painel/novo`, `painel/editar/<id>`, `pedido/<id>` |
| Profile (`profile`) | any path: profile and, with `contact`, form and handle messages |
| Blocks (`blocks`) | any path: renders the site's blocks (`listing` searches for the listing and displays its card) |

Each renderer is `function (page, ctx)`. `window.CoeOnion` provides DOM utilities (`el`, `button`, `input`,
`textarea`, `select`, `field`, `card`, `line`, `link(text, address, class, ctx.go)`, `when`, `ago`, `parse`) and
`errors` (messages by code). `ctx`:

| Field | Usage |
|---|---|
| `target` | `{ domain, path = { ... }, query, href }` for the open address |
| `site` | `{ domain, app, title, description, blocks, profile }` (blocks are JSON; `profile` is used for staff profiles) |
| `data` | `state` data (tier, connected handle, features) |
| `call(action, payload)` | Promise with `{ ok, ... }` or `{ ok = false, error }` |
| `request(action, payload, onDone, message)` | `call` with success/error notice and double-click guard |
| `alive()` | is this still the same page? (check before rendering after a call) |
| `go(address)`, `replace(address)` | navigate with or without a new history entry |
| `setTitle(text)`, `refresh()`, `reloadState()`, `status(text, type)`, `waypoint(x, y)`, `errorText(code)` | |

Server actions (all through the `onion` app; reads have no minimum interval):

| Action | Payload | Response |
|---|---|---|
| `site` | `{ address }` | `{ site }` or `not_found` |
| `directory` | | `{ sites = { { domain, app, title, description } } }` |
| `search` | `{ q }` | `{ query, sites, posts, listings }` |
| `forumHome` | `{ sort = hot\|new\|top, page }` | `{ communities, posts, more, me, canCreate }` |
| `forumCommunity` | `{ slug, sort, page }` | `{ community, posts, more, me, moderating }` |
| `forumPost` | `{ id }` | `{ post, comments (with depth, reading order), community, me }` |
| `forumUser` | `{ handle }` | `{ handle, karma, postCount, commentCount, posts, reviews }` |
| `forumSubmit` | `{ slug, title, body }` | `{ id, slug }` |
| `forumComment` | `{ postId, parentId?, body }` | `{ id }` |
| `forumVote` | `{ target = p\|c, id, value = 1\|-1\|0 }` | `{ vote, delta }` |
| `forumRemove` | `{ target, id }` | `{ ok }` |
| `forumCreate` | `{ slug, title, description }` | `{ slug }` |
| `marketHome` | `{ category?, q?, npc?, page }` | `{ listings, categories, more, me, canBuy, canSell, feeBps }` |
| `marketListing` | `{ id }` | `{ listing, reviews, wallets, maxQuantity, canBuy, ... }` |
| `marketBuy` | `{ id, quantity, from }` | `{ orderId, status }` |
| `marketMine` | | `{ listings, bought, sold, categories, canSell, maxListings, decimals }` |
| `marketOrder` | `{ id }` | `{ order }` with `actions`, `drop` (when the person needs to visit the point), and `canReview` |
| `marketSave` | `{ id?, title, description, kind, category, item, count, price (text), stock, payout, status? }` | `{ id }` |
| `marketListingStatus` | `{ id, status = active\|paused\|removed }` | `{ ok }` |
| `marketAct` | `{ id, action = deliver\|collect\|confirm\|dispute\|cancel, note? }` | `{ status }`; `not_at_drop` includes `drop` |
| `marketReview` | `{ id, rating, body }` | `{ ok }` |
| `contactThread` | `{ domain }` | `{ handle, messages = { { id, body, reply, status = open\|answered\|closed, createdAt, repliedAt } } }` |
| `contactSend` | `{ domain, body }` | `{ id }`; errors `invalid_message`, `contact_cooldown`, `contact_limit` |
| `bookmarks`, `bookmarkAdd { address, title }`, `bookmarkRemove { address }` | | |

## Future phases

1. **Hosting** (tier 5): the player builds their own block-based site on the home server (`owner_handle`), with new
   blocks (custom storefront, contact form, and scam pages for RP hacking).
2. **Contracts** between players with crypto escrow and arbitration.
3. **Police attention risk**: trails by device and wallet, mining generating "heat," and MDT queries.
4. System paid services (money laundering, tracking, information) and surveillance (GPS, microphones, cameras, vans).

## Dependencies

`coe_core`, `coe_database`, `coe_logging`, `coe_ui`. Optional: `coe_crypto` (wallet, mining, and Deep Market escrow),
`coe_dispatch` (alerts), `coe_inventory` (items), `coe_housing` (installation and contract), `coe_economy` (power),
`coe_phone`/`coe_tablet` (Onion app), `coe_audit`, `coe_notify`. It must be included in the allowlists for
`coe_database`, `coe_logging`, `coe_audit`, `coe_notify`, `AllowedResources` in `coe_economy`, and `DeliveryCallers`
in `coe_housing` (already included).

## Tests

```
cd coe_deepweb
lua test/deepweb_test.lua
lua test/server_test.lua
lua test/web_test.lua
lua test/persistence_test.lua
```
