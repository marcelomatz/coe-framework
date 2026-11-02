# coe_apps

App store for **COE OS**. The same store and apps serve the tablet (`coe_tablet`) and smartphone (`coe_phone`); the device is identified by the calling resource (`HOSTS`), and each app specifies in `devices` where it runs.

## Apps

- **Store** (native): storefront by category with install and remove. A paid app is a **weekly subscription charged to a credit card** through the smartphone **Wallet**: the player chooses a card and confirms with face recognition or the phone password; `coe_phone` generates a one-time authorization (`ConsumePayment`) and the charge goes to that card (`coe_banking`, `CardPurchase`). The subscription is tied to the **card** (`card_id`) and renews on that same card even when the phone is not nearby. On a tablet, subscribing returns `wallet_required`. The first week is charged when subscribing, and renewal is automatic every `Subscriptions.PeriodDays` days (`RenewLeadSeconds` before expiration), even if the character is offline. If the card is blocked, replaced, or expired, has no credit account, has an overdue bill, or lacks available credit, the charge is rejected and, once the week expires, the app is removed from the device (with a notice if the player is online). Canceling removes the app and stops renewal; reinstalling during the paid week does not charge again (the Wallet is opened only to choose the renewal card). Subscriptions created before the Wallet have no card and are rejected at the next renewal; simply subscribe again. Installation is saved per character (`coe_apps_installed`) and the tablet home screen updates immediately.
- **Jobs**: `job`-type groups from `coe_core`, with roles, number on duty, the player's job, and reporting location (GPS, in `Jobs`).
- **Classifieds**: ads by category with title, description, and price (or "negotiable"). Charges `Fee` per ad (`classified_fee`, refunded if saving fails), stays live for `DurationHours`, and each character may have at most `MaxActive` active ads. Contact shows the author's name and ID. The author can end their own ad.
- **Insta**: photo feed with likes (double-click or button), "My posts" tab, and pagination. "New photo" opens the in-game camera: mouse aims, wheel zooms, **E** switches between selfie and rear camera, left click or Enter takes the photo, right click/Backspace cancels. The photo is resized on the device (`Photos.Width`, `Quality`, `MaxBytes`), captioned, and published.
- **Studio** (weekly subscription, smartphone only): editor for photos in the coe_phone Gallery. Preset filters with preview, adjustments (brightness, contrast, saturation, temperature, fade, vignette, sharpness, blur), aspect-ratio crop, rotate and mirror, resize (10–100%), text (position, color, and size), and frames. Hold **Before** to compare with the original. Everything is processed on the device and saved as a **copy** in the Gallery through the same validated camera path (`coe_phone` limits); the original never changes. It has no server handlers: it uses the phone's own gallery and camera actions.

## Photos

1. The camera uses `screenshot-basic`.
2. The device sends an already-resized photo via latent event (`coe_apps:photo`); the server validates it (JPEG only, base64, up to `MaxBytes`, one per `UploadCooldownSeconds`) and holds it pending for `PendingSeconds`, returning a token.
3. When published, the photo is sent to the host:
   - **Database** (default, no configuration): `coe_apps_insta_media` table; the post stores `media:<id>` and the device fetches the image on demand.
   - **HTTP**: set `set coe_apps_upload_url "https://..."` (and, if the service requires it, `set coe_apps_upload_key "..."`). The server sends a form-urlencoded POST with `Field=<base64>` (and `KeyField=<key>`) and reads the public URL from the JSON response at `ResponsePath`. Only `https://` URLs are accepted.

Apps allowed to send photos are listed in `Photos.Apps` (Insta and `coe_news` portals). Resources in `Photos.Callers` store the photo through the server exports `ClaimPhoto(playerId, token)` → `{ ok, image }`, `PhotoData(id)`, and `DeletePhoto(image)`.

Video support is for a future phase.

## Moderation

The `coe_apps.moderate` ACE permits deleting anyone's ads and posts (recorded in `coe_audit`).

```
add_ace group.admin coe_apps.moderate allow
```

## Integration

- `TabletVisible(playerId, appId)` and `TabletCall(playerId, appId, action, payload)`: accept calls only from devices in `HOSTS`. Store is always visible; other apps are visible only when installed.
- Client exports used by the device: `TakePhoto()` → `{ ok, image }` and `StorePhoto(image)` → `{ ok, token }`.
- UI: `html/apps.js` registers `store`, `jobs`, `classifieds`, and `insta` on the device; `html/editor.js` (+ `editor.css`) registers `editor` and serializes actions (the tablet accepts one every 250 ms).
- New app: entry in `Store` (here), entry in `coe_tablet/config.lua` `Apps` with `ownerCheck = true` and `resource = 'coe_apps'`, a set of handlers in `server/main.lua`, and a `register` in `html/apps.js`.

## Dependencies

`coe_core`, `coe_database`, `coe_logging`, and `screenshot-basic`; `coe_banking` for subscriptions (without it, subscribing returns `bank_unavailable` and renewals wait). It must be in the permission lists for `coe_database`, `coe_logging`, and `coe_audit`, in `Credit.PurchaseCallers` in `coe_banking`, and in `Wallet.PaymentCallers` in `coe_phone` (already included).

Test: `lua test/apps_test.lua` (from the resource folder).
