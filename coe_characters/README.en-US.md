# coe_characters

Character selection with a 3D scene and integration with the character creator (`coe_appearance`). Creates, selects, and archives characters for the player's persistent account. All ownership, limit, validation, and state rules are enforced server-side by `coe_core`; the NUI only sends requests and displays responses.

## Flow

- On joining, the player remains unable to move until Core loads the account and requires a selection.
- The server's initial list message (`playerJoining`) can arrive before this client registers its handlers. Therefore, when becoming active, the client sends `player.clientReady`, and Core resends `player.loaded` and `character.selectionRequired` if the session is selecting a character (limited to once per second and ignored in other states).
- The list shows only active characters belonging to the authenticated account.
- **Scene**: characters appear side by side as local peds (visible only to the player) at the location in `Scene` in `config.lua` (default: Galileo Observatory terrace, facing away from Los Santos at sunset), with time and weather fixed only for that player, a wide camera and a camera on the selected character with interpolation and depth of field, idle poses (native scenarios), and the selected character facing the camera. Characters without an appearance use the default look (the notice appears only in the UI). HUD (`coe_hud`) and minimap stay hidden from selection until the character spawns, through `coe_hud:setHidden`. To change the location: stand at the point facing the view, run `/coe_scene_anchor`, and copy the F8 output to `Scene.Anchor`/`Scene.Facing`; the ground is searched from that point. Without `coe_appearance`, selection works with NUI only.
- **NUI**: list on the left (arrow keys ↑ ↓ or click) and selected-character details on the right, with name, ID, age, gender, and **Play** (Enter or double-click).
- **Creation**: **Create character** opens the `coe_appearance` creator (identity, heritage, face, details, hair, clothing). On registration, the client sends `character.createRequest` with `birthDate`, `gender`, `appearance`, and `appearanceVersion`; server errors appear in the creator, and on success selection returns with the camera on the new character. Without `coe_appearance`, a simple form opens (name, date of birth, and gender only; NUI never sends appearance).
- **Existing characters without appearance**: when playing, they enter the creator once (appearance mode, without the identity step); the client sends `character.appearanceRequest` and, once saved, enters directly. `coe_core` only accepts setting appearance for a character that does not already have it.
- Rules (minimum/maximum age, genders) are validated server-side; simple-form options come from `Genders` in `config.lua` (they must match `coe_character_genders`).
- Character limit: default is five and can be changed by the server-only `coe_max_characters` convar.
- The command and open shortcut are configurable in `config.lua` (`Command`, `OpenKey`, and `KeyDescription`). `Debug = true` prints flow steps to the client's F8 console (`player.clientReady sent`, `selectionRequired received`, `NUI page loaded`, events rejected by source, and NUI JavaScript errors); disable it after validating the flow in game.
- Archiving preserves the record and its data. Archived characters do not appear in the list or count toward the active limit.
- Pressing `F7` requests switching the active character. The current session is ended on the server before displaying the list.

Selection does not send `player_id`, owner, or client license. IDs and names received by the UI are treated as untrusted input and validated by Core.

## Dependencies

`coe_core`, `coe_spawn`, and `coe_notify` must be started. Core requires `coe_database` and the MariaDB provider to be available before accepting connections. Successful create, select, and archive actions emit an audit event and a brief notification; internal log data is not sent to the UI.

## Files and tests

- `config.lua`: command, key, key mapping description, and scene (`Scene`).
- `client/scene.lua`: 3D scene (peds, cameras, time, weather, streaming through `SetFocusPosAndVel`).
- `client.lua`: validates server-side event source, connects NUI callbacks to the Core bus, and configures the shortcut.
- `html/`: list, selected-character view, simple form, and NUI callbacks. The page background must remain transparent: do not set `color-scheme: dark` on `:root`/`html`/`body`, because it makes the NUI opaque and covers the game (use it only on form controls).
- `fxmanifest.lua`: dependencies, config/client order, and NUI assets.

Run `lua test\client_test.lua` in the resource folder. The harness checks the `player.clientReady` notice, blocking forged events, forwarding requests, rejecting invalid payloads, selection response, key configuration, and creator integration (characters without appearance open the creator; appearance submission; creation submission with profile; server errors shown in the creator). NUI JavaScript, visual accessibility, and the real server flow have no automated tests in this resource; see [TEST_COVERAGE.md](../TEST_COVERAGE.md).

## Loading screen

`coe_loadscreen` uses `loadscreen_manual_shutdown`: this selector closes the loading screen when the 3D scene finishes initializing (`ShutdownLoadingScreen` and `ShutdownLoadingScreenNui`). The selection UI also remains hidden (`waitScene`) until the `reveal` message arrives after the scene fade-in; on each opening (including F7 and return from the creator) it appears only when the scene is ready. If selection does not open within `LoadingScreenTimeoutMs` (30 s) after `player.clientReady`, the loading screen closes anyway.
