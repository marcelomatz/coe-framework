# coe_phone

> Upgrade to the basic phone (`coe_mobile`): `coe_supervisor` does not start the basic resource while this one is running, and on every startup `server/upgrade.lua` brings over the number, contacts, conversations, calls, and settings of users of the basic phone (`UpgradeStatus()`, `coe_upgrades` command). Details in [`UPGRADES.md`](../UPGRADES.md).

COE OS smartphone. Opens with **F1** (or `/celular`), or by using the **Cell Phone** item in inventory, and brings together:

- **Phone**: keypad, recent calls, and your number. Calls with ringing, answer, reject, hang up, and hide call screen.
- **Contacts**: searchable address book; call, send a message, edit, and delete.
- **Messages**: conversations by number, with notifications and unread count. Messages to offline recipients are stored.
- **Camera** and **Gallery**: photos stored on the device itself (see below).
- **Wallet**: bank cards stored on the device for payment without carrying the physical card (see below).
- **Settings**: connections, sounds, display, home screen, passcode, and facial recognition.
- **Store apps** (`coe_apps`): Store, Jobs, Classifieds, and Insta, the same apps as on the tablet. They only appear after installation.

The tablet (`coe_tablet`, F3) and smartphone share the store and visual components (`nui://coe_ui/html/apps.css`).

Replaces the framework's basic phone (`coe_mobile`): on startup, and whenever `coe_mobile` restarts, it calls the `Yield` export (ACE `coe.mobile.yield`, granted by the framework in `CoeAccess.FirstParty`). The basic phone ends its calls, closes its screen, and stops opening (key, command, and `phone` item) until `coe_phone` stops. Both use the `phone` item and F1; while `coe_phone` is running, it is the only one that responds. The basic phone's numbers, contacts, and messages remain in the `coe_mobile_*` tables and are not imported: here, the number belongs to the SIM.

## Key

`F1` is the default. Each player can change it in **Settings > Key Bindings > FiveM > "Open smartphone (COE OS)"**. With the phone open, `F1` closes it and `Esc` goes back (or closes it on the home screen).

## Devices and SIM cards

Each phone is a device: the `phone` item receives a serial number (`metadata.serial`) the first time it is opened.
Passcode, facial recognition, settings, home screen, and contacts stay **on the device**. Anyone who has the item and knows the passcode can use the phone, even if it belongs to someone else. If there is more than one phone in inventory, F1 opens the last one used; using the item opens that particular device.

The number belongs to the **SIM** (item `sim_card`, `metadata.iccid`). A new phone for someone who does not yet own any SIM cards comes with one: `Number.Prefix` + `Number.Digits` random digits (default `555-0123`), with the character as holder. To switch: **Settings > SIM > Remove** returns the SIM to inventory; using the `sim_card` item (or **Settings > SIM > Insert**, which lists SIMs in inventory) inserts it into the phone in use (if there is an available slot; the model determines how many, `Models[*].sims`). Without a SIM, the phone opens but cannot call or send messages. Calls and messages go to the number; they ring on whichever phone has the SIM, held by whoever is online with it. Messages for a SIM outside a phone are stored.

Facial recognition stores the face of the person who enabled it; another person can only unlock using the passcode. Passcode errors are counted per device.

During the update, each character with a number received a migrated device (serial `MG…`) with their settings and contacts and the SIM with their old number; it is linked to the first phone item without a serial that the character opens. Use the `phone` item: the phone no longer works without it.

Exports:

| Export | Return |
| --- | --- |
| `NumberOf(characterId)` | Number (`555-0123`) of the first SIM the character holds, or `nil`. |
| `ActiveLine(playerId)` | SIM in the phone currently in use: `{ number, display, holder }` or `nil, 'no_phone' \| 'no_sim'`. Used by `coe_telecom`. |
| `ActiveDevice(playerId)` | Device currently in use: `{ serial }` or `nil, error`. Apps that bind a session to a device (e.g., `coe_mail`) use the serial number. |

## Calls

The server controls the state: dialing → in call → ended. If no one answers within `Calls.RingSeconds`, the call becomes missed and the recipient is notified. Busy, out of range (offline or without a phone), and nonexistent numbers are reported immediately. Out of range includes a SIM outside a device and a phone not carried by anyone online. All history is stored in `coe_phone_calls`.

Voice (`server/voice.lua`): uses the FiveM voice API for GTAV Enhanced, controlled only by the server. On answer, the server creates a non-spatial channel (`CreateVoiceChannel(0, 0.0)`) with both players (`AddPlayerToVoiceChannel`); on hangup, it deletes the channel (`DeleteVoiceChannel`). Does not use Mumble natives or pma-voice (unsupported in Enhanced). Requires `voice_internal` (or an external voice server) in `server.cfg`. Proximity voice continues: people near someone talking on the phone can also hear that side of the conversation.

Dying or disconnecting from the server ends the call.

Video call: **Video** button on the keypad, recent calls, and contacts. Uses the same voice channel (there is no actual video); the screen and history show that it was a video call, and the carrier charges the video rate.

## Carrier (`coe_telecom`)

Optional. When started, the phone asks the carrier before dialing or sending a message (`Authorize`) and reports usage at the end (`Charge`), always using the SIM number. The caller pays. Without prepaid credit, the call does not go through; with credit, it ends automatically when credit runs out ("Credit depleted"). A suspended line (overdue bill) cannot call or send messages, but can receive them. The **My Line** app (`sim` icon) shows balance, plan, usage, bills, top-up, and plan changes. Without `coe_telecom`, calls and messages are free. Details in the `coe_telecom` README.

## Home screens

The home screen has multiple pages (up to `Home.MaxPages`, with `Home.PageSize` apps each) and a bottom dock (`Home.DockSize`). Switch pages using the dots, mouse wheel, swiping sideways, or arrow keys.

Hold an app to enter edit mode: drag it to another position, to the dock, to a dot (another page), or to the edge (turns the page; on the last page, creates a new one). Dropping an app over one in a full list swaps their positions. The **+ Page**, **Delete page** (only an empty page), and **Done** buttons are at the bottom. Layout is saved on the device; **Settings > Home screen > Restore** returns to the default. New apps go on the first page with space.

## Settings

| Group | Options |
| --- | --- |
| Connections | Airplane mode (turns off Wi-Fi and Bluetooth), Wi-Fi, Bluetooth. |
| Sounds | Silent, vibrate, do not disturb, volume (0 to 10), and ringtone (Classic, Digital, Soft, Pulse). |
| Display | Brightness and wallpaper. |
| Home screen | Edit and restore. |
| Security | Numeric passcode and facial recognition (requires passcode). |
| SIM | SIM cards in the device (number and whether you are the holder), Remove, and, in an empty slot, Insert a SIM from inventory. |
| About | Model and serial number. |

Do not disturb silences the ringtone, vibration, message alerts, and missed-call alerts. Defaults are in `Settings.Defaults`.

## Signal

The bar shows 0 to 4 bars according to the distance from the nearest tower (`Signal.Towers`, ranges in `Signal.Ranges`). Indoors, one bar is lost; underwater, there is no signal. The server recalculates based on the player's position: without signal or in airplane mode, calls and messages cannot be sent, and callers hear "out of range".

## Passcode and facial recognition

With a passcode set, the phone opens locked. Enter it using the on-screen or physical keypad. Entering the wrong code `Passcode.Attempts` times locks the device for `Passcode.LockoutSeconds`. With facial recognition enabled, the device unlocks automatically (with the option to use the passcode). When locked, only calls can be answered or rejected. The passcode is stored as a hash.

## Camera and Gallery

The **Camera** shutter stows the phone and opens the in-game camera (requires `coe_apps` started and `screenshot-basic`): mouse to aim, wheel to zoom, **E** to switch to selfie, click to take a photo, and right-click to cancel. The photo is resized to the resolution and quality of the model's camera (`Models.*.camera`), gets a thumbnail, and is added to the **Gallery**.

Photos are stored **on the device** (serial), like contacts: anyone who gets the phone and knows the passcode can see the photos; switching phones does not transfer photos. Each model has its own storage (`Models.*.storage`, in MB); when full, the camera refuses new photos until some are deleted. The Gallery shows thumbnails (most recent first), storage usage, and each full photo with date, navigation between photos, and **Delete** (tap twice to confirm). With **Studio** (weekly Store subscription, coe_apps) installed, the opened photo has an **Edit** button; the edit is saved as a new photo and counts against storage.

## Wallet

`coe_banking` cards stored **on the device** (`coe_phone_wallet`, up to `Wallet.MaxCards`), with no cloud backup. Requires the phone passcode. Add the **physical** card in inventory (entering the card PIN; failed attempts count as at the ATM) and the character's **virtual card**, which can be requested in Wallet, at a branch, or in online banking. Once linked, the physical card does not need to be carried. One card is the **default**; requesting a new virtual card removes the previous one (replaced) from Wallet.

Payment (`api.pay({ amount, label, note })` in NUI): a sheet with active cards, confirmed using the **registered face** (if enabled and if the device's face matches the person using it) or the phone **passcode**. The server generates a one-time authorization, valid for `Wallet.PaymentSeconds`, which the paying resource consumes with the `ConsumePayment(playerId, token, amount)` export (only `Wallet.PaymentCallers`; returns `cardId` or `nil, error`) and charges to the card through `coe_banking`. Currently used for Store subscriptions (`coe_apps`). At `coe_shops` stores, Wallet is available as the `wallet` payment method (`RegisterPaymentMethod`, kind `device`): the store client calls `RequestPayment` and the store server charges using the `ShopCharge`/`ShopRefund` exports here, which consume the token and charge the card.

Other resources request payment through the client export `RequestPayment({ amount, label, note })`: it opens the phone if it is stowed (waits up to 8 s), shows the payment sheet, and returns `{ token, cardId }` or `{ error }` (`cancelled`, also on timeout; `phone_unavailable`, `invalid_amount`). Closing the phone cancels the request; the phone closes again if it was opened by the request. The token is passed to the resource's server, which calls `ConsumePayment`.

## Side buttons

Left: silent-mode switch, volume +, and volume −. Right: power (saves anything pending and stows the phone). The volume buttons and switch also silence the ringtone for an incoming call.

## Configuration (`config.lua`)

| Key | Use |
| --- | --- |
| `Command`, `OpenKey` | Command and default key. |
| `Devices` | Phone items and each one's model (`phone = 'coe_one'`). |
| `Models` | Models: display name (`label`), number of SIM slots (`sims`), storage in MB (`storage`), and camera (`camera.width`, `camera.quality`). |
| `SimItem` | SIM item (`sim_card`). |
| `Number` | Prefix and number of digits for new numbers. |
| `Calls` | Ring time and size of recent calls list. |
| `Contacts`, `Messages` | Contact and message limits (length, history, sending interval). |
| `Wallet` | Cards per device, payment authorization validity, maximum amount, and resources allowed to consume payments. |
| `Photos` | Maximum photo and thumbnail size, thumbnail width, photos per page, interval between photos, and upload rate. |
| `RingVolume` | Maximum ringtone volume (0 to 1), reached at volume 10 in Settings. |
| `Home` | Apps per page, maximum pages, and dock size. |
| `Settings` | Setting defaults, ringtones, wallpapers, brightness and passcode limits. |
| `Signal` | Towers and distance ranges for signal bars. |
| `Apps` | Device apps: native (`native`) or from another resource (`resource` + `script`). `dock` pins the app in the dock. |

## Tables

`coe_phone_devices` (device: model, original owner, face, passcode hash, settings, and home screen),
`coe_phone_sims` (SIM: number, holder, device, and slot), `coe_phone_device_contacts`, `coe_phone_photos` (device photos: image, thumbnail, size, and photographer), `coe_phone_wallet` (cards in the device Wallet), `coe_phone_messages`, and
`coe_phone_calls` (by number). Migrations in `server/migrations.lua`, tracked in `coe_phone_schema_migrations`.
`coe_phone_numbers`, `coe_phone_contacts`, and `coe_phone_settings` are from the old model (per character) and are no longer used; they remain for reference. Integration test: `coe_database/test/integration/phone_telecom_scenario.lua`.

## Tests

```
cd coe_phone
lua test/phone_test.lua
```
