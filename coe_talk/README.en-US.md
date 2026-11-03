# coe_talk

Complete real-time audio and voice system for the **COE** framework, built for the new native **FiveM Enhanced** standard (`voice_internal` / OneSync / RAGE Audio).

Fully replaces legacy external Mumble architectures (Murmur/port 64738/third-party VoIP) with an integrated audio stack, fast and featuring native noise and echo cancellation.

---

## Main features

1. **Native FiveM Enhanced voice stack**:
   - 3D spatial surround audio integrated with GTA V's RAGE audio engine (`voice_useNativeAudio` and `voice_use3dAudio`).
   - Strict transmission range with no network packet leakage (`voice_useSendingRangeOnly`).
   - No dependency on external VoIP servers.

2. **Proximity modes (voice range)**:
   - **Whisper**: 1.5 meters (privacy in vehicles and interiors).
   - **Normal**: 5.0 meters (everyday conversations).
   - **Shout**: 15.0 meters (tactical situations, confrontations, and pursuits).
   - Quick toggle with sound and visual feedback using **`Z`** (reconfigurable in FiveM settings) or the `/proximidade` and `/voz` commands.

3. **Tactical radio (Walkie-Talkie)**:
   - Frequencies from 1.0 to 999.9 MHz with 0.1 MHz tuning increments.
   - Profession/faction-protected channels (Channels 1 to 3 for Police/COE, 4 and 5 for EMS/Firefighters).
   - Tactical Push-To-Talk on **`CAPS LOCK`**, with characteristic transmission start/end sound (*mic clicks*).
   - Character animation holding the radio against the chest/shoulder while transmitting.
   - Adjust radio volume with `/radiovolume [0-100]`.

4. **Authentic sound filters (RAGE Audio Submixes)**:
   - **Radio effect**: tactical acoustic distortion and real-time high/low frequency cutoff.
   - **Phone effect**: telephone-line filter for mobile calls.

5. **NUI and visual feedback**:
   - Discreet widget in the lower corner integrated with `coe_ui` design tokens.
   - Dynamic microphone with a glowing pulse ring while the player speaks.
   - Voice range level bars (1 to 3) with tactical label.
   - Active radio frequency badge and `TX` transmission indicator.
   - Follows theme colors or player theme (`--coe-accent`).

---

## Commands

| Command | Description |
| --- | --- |
| `/voz` or `/proximidade` | Toggle between Whisper, Normal, and Shout |
| `/ptt` | Toggle between Push-To-Talk (N key) and continuous voice activation |
| `/radio [frequência]` | Tune to a frequency (e.g., `/radio 101.5` or `/radio 1` for tactical channel) |
| `/radiodesligar` or `/radio 0` | Disconnect from the current radio |
| `/radiovolume [0-100]` | Adjust radio reception volume |

---

## Default keys (keybinds)

- **`N`**: **Speak into microphone** (local voice Push-To-Talk).
- **`Z`**: Toggle voice range (Whisper 1.5m, Normal 5.0m, Shout 15.0m).
- **`CAPS LOCK`**: Radio Push-To-Talk (transmit on the frequency).

*(Each player can configure these in **ESC > Settings > Key Bindings > FiveM**)*.

---

## Exports

### Client

```lua
-- Retorna a distancia, rotulo e id do modo atual (ex: 5.0, "Normal", "normal")
local distance, label, id = exports.coe_talk:GetVoiceRange()

-- Define a distancia ou modo programaticamente ("whisper", "normal", "shout" ou numero em metros)
exports.coe_talk:SetVoiceRange('shout')

-- Retorna a frequencia de radio conectada (ou nil se desligado)
local freq = exports.coe_talk:GetRadioChannel()

-- Sintoniza uma frequencia (ou nil/0 para desligar)
exports.coe_talk:SetRadioChannel(101.5)

-- Retorna se o jogador local esta falando no microfone
local talking = exports.coe_talk:IsTalking()

-- Retorna se o jogador esta transmitindo no radio
local transmitting = exports.coe_talk:IsRadioTransmitting()

-- Chamada atual (definida pelo servidor) e saida da chamada; o client nao escolhe em qual chamada entra
local callId = exports.coe_talk:GetCallChannel()
exports.coe_talk:SetCallChannel(nil)

-- Volume da voz recebida (0-100)
exports.coe_talk:SetVoiceVolume(80)
```

### Server

```lua
-- Conecta um jogador a uma frequencia
exports.coe_talk:SetPlayerRadio(source, 911.0)

-- Retorna a frequencia de um jogador
local freq = exports.coe_talk:GetPlayerRadio(source)

-- Retorna a lista de sources em uma frequencia
local members = exports.coe_talk:GetRadioMembers(911.0)

-- Conecta jogadores a uma chamada privada (id: ate 64 caracteres [A-Za-z0-9_:-]; nil encerra)
exports.coe_talk:SetPlayerCall(source, 'chamada_123')

-- Chamada de um jogador e participantes de uma chamada
local callId = exports.coe_talk:GetPlayerCall(source)
local inCall = exports.coe_talk:GetCallMembers(callId)
```

`SetPlayerRadio` and `SetPlayerCall` only accept calls from `Config.Access.Resources` (default: `coe_mobile`) or from callers with the `coe.talk` ACE (`add_ace resource.<nome> coe.talk allow`). For other resources, they return `false, 'forbidden'`. Joining a call only happens through the server: there is no network event for the client to choose a call (which would allow listening to other people's calls). Voice and radio events from the client have a minimum interval of `Config.EventCooldownMs`.

Full contract in [`types.lua`](types.lua) and the [API reference](../reference/coe_talk.md).

---

## Automated tests

To run unit tests for rules and routing logic:

```powershell
lua test/rules_test.lua
lua test/server_talk_test.lua
```
