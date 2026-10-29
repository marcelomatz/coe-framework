# coe_talk — API Reference

> Generated from `coe_talk/types.lua` by `tools/gen_reference.lua`. Do not edit by hand.

Server & Client voice communication exports.

## Exports

### `SetPlayerRadio(source, frequency)`

Assigns a player to a radio frequency (or leaves with `nil`/`0`). Restricted to `Config.Access.Resources` (defaults to `coe_mobile`) or callers with `coe.talk` ACE. Does not enforce job restrictions directly: caller validates authorization.

| Parameter | Type | Description |
|---|---|---|
| `source` | `integer` | Target player server ID |
| `frequency` | `number\|nil` | Radio frequency number |

**Returns**

- `boolean` `ok`
- `string|nil` `errorCode` — `forbidden`, `invalid_player`

### `GetPlayerRadio(source)`

Retrieves active radio frequency of a player.

| Parameter | Type | Description |
|---|---|---|
| `source` | `integer` | Target player server ID |

**Returns**

- `number|nil` `frequency`

### `SetPlayerCall(source, callId)`

Connects player into a voice call channel (or leaves with `nil`). This is the authoritative way to join calls: client never chooses call room directly. Same access rules as `SetPlayerRadio`.

| Parameter | Type | Description |
|---|---|---|
| `source` | `integer` | Target player server ID |
| `callId` | `string\|nil` | Call identifier string (up to 64 chars `[A-Za-z0-9_:-]`) |

**Returns**

- `boolean` `ok`
- `string|nil` `errorCode` — `forbidden`, `invalid_player`, `invalid_call`

### `GetPlayerCall(source)`

Retrieves current voice call identifier of a player.

| Parameter | Type | Description |
|---|---|---|
| `source` | `integer` | Target player server ID |

**Returns**

- `string|nil` `callId`

### `GetRadioMembers(frequency)`

Lists player server IDs active on a radio frequency.

| Parameter | Type | Description |
|---|---|---|
| `frequency` | `number` | Radio frequency |

**Returns**

- `integer[]` `members`

### `GetCallMembers(callId)`

Lists player server IDs active in a voice call.

| Parameter | Type | Description |
|---|---|---|
| `callId` | `string` | Call identifier |

**Returns**

- `integer[]` `members`

### `GetVoiceRange()`

Returns current local proximity voice mode (client-side).

**Returns**

- `number` `distance`
- `string` `label`
- `string` `id`

### `SetVoiceRange(modeOrDistance)`

Changes voice proximity mode by id (`whisper`, `normal`, `shout`) or radius distance.

| Parameter | Type | Description |
|---|---|---|
| `modeOrDistance` | `string\|number` | Mode string or numeric radius |

**Returns**

- `boolean` `ok`

### `GetRadioChannel()`

Returns current radio frequency of local player (client-side).

**Returns**

- `number|nil` `frequency`

### `SetRadioChannel(frequency)`

Requests server to connect local player to radio frequency (restricted channels require jobs; see `Config.Radio.restricted`).

| Parameter | Type | Description |
|---|---|---|
| `frequency` | `number\|nil` | Target frequency (`nil`/`0` to leave) |

**Returns**

- `boolean` `sent`

### `GetCallChannel()`

Returns current voice call identifier of local player (client-side).

**Returns**

- `string|nil` `callId`

### `SetCallChannel(callId)`

Leaves current call (`nil`). Joining a call is authoritative on server (`SetPlayerCall`).

| Parameter | Type | Description |
|---|---|---|
| `callId` | `nil` | Must be `nil` to leave |

**Returns**

- `boolean` `ok` — `false` when receiving an identifier

### `IsTalking()`

Returns whether local player is actively speaking over proximity voice (client-side).

**Returns**

- `boolean` `talking`

### `IsRadioTransmitting()`

Returns whether local player is currently transmitting over radio (client-side).

**Returns**

- `boolean` `transmitting`

### `SetVoiceVolume(volume)`

Sets incoming voice volume (0-100).

| Parameter | Type | Description |
|---|---|---|
| `volume` | `number` | Volume percentage (0-100) |

**Returns**

- `boolean` `ok`
