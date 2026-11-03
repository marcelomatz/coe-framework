# coe_mobile

Basic framework phone: the character has a number and can use Phone, Contacts, Messages, and basic Settings.

- **Device**: the `phone` item from `coe_inventory`. Without it in the inventory, the phone cannot be opened, make calls, receive calls, or receive message notifications (callers hear "out of service"; messages are stored). Open with **F1** (each player can change it under Settings > Key Bindings > FiveM, "Open phone"), with `/telefone`, or by using the item.
- **Number**: one per character, generated on first use (`555-0123`, prefix and digits in `config.lua`) and fixed afterward. No SIM card or password.
- **Phone**: keypad and recents (outgoing, received, missed, declined, busy, and out-of-service calls). Voice goes through `coe_talk` (phone effect) on a channel with an unpredictable ID, created by the server when answered. The call rings for `Calls.RingSeconds`; no answer results in a missed call, with a notification for the person who did not answer. With the phone closed, the call appears in the corner of the screen with a hint for the answer key.
- **Contacts**: name and number, with search; up to `Contacts.Max` per character.
- **Messages**: conversations by number, including with offline recipients. Unread messages appear on the app icon and in the conversation. Deleting a conversation deletes it only on your side.
- **Settings**: silent mode, volume, ringtone (generated on the screen itself, no audio files), and wallpaper.

Not included in the basic phone (available in packages): SIM cards and carrier, password and unlocking, camera and gallery, wallet, app store, and antenna signal.

## Packages that take over the phone

A package with a full smartphone calls the `Yield()` export at startup (and again on `onResourceStart` of `coe_mobile`). The basic phone ends ongoing calls, closes screens, and stops opening (key, command, and item) until the calling resource stops; then it resumes automatically. The capability comes from `server.cfg`:

```
add_ace resource.<nome> coe.mobile.yield allow
```

The framework does not reference the package by name: the resource that takes over is determined at runtime. `Status()` returns `{ active, yieldedBy }`. `NumberOf(characterId)` returns the character's number in the basic phone (or nil, without generating one).

The basic phone's numbers, contacts, and messages are stored in the `coe_mobile_*` tables; a package decides whether to import this data.

## Security

- Everything goes through the server (`coe_mobile:request`, request and response). The screen does not choose the caller number, voice channel, or notification recipient.
- Each call's voice channel is selected by the server and applied through the `SetPlayerCall` export from `coe_talk`.
- Names and messages are cleaned (control characters, valid UTF-8, length in characters). The screen builds everything with `textContent`.
- Minimum interval between writes (`ActionIntervalMs`) and between messages (`Messages.CooldownMs`), one operation per player at a time.

## Configuration

`config.lua`: item, command, and key; number format; ring duration and recent-call list size; contact and message limits; default settings (ringtones and available wallpapers); interval between operations; `Yield` ACE; and phone-in-hand animation.

## Interface

The device appears in the bottom-right corner, styled like `coe_ui` (chamfered corners, colors only from tokens, `coe-*` fields and buttons), and follows the server theme and player's color (`@coe_ui/theme_bridge.lua`). Deleting a contact or conversation asks for confirmation through `CoeUI.confirm`.

## Tests

```
cd coe_mobile
lua test/rules_test.lua
lua test/persistence_test.lua
lua test/server_test.lua
```

`server_test.lua` exercises the server with mocked inventory, voice, notifications, and persistence: number generation on first use (skipping collisions), required item, contacts, online and offline messages, answered, declined, missed, cancelled, busy, and out-of-service calls, disconnect of a player, settings, item use, character change, and a package's `Yield`.
