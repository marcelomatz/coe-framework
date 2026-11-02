# coe_notify

NUI notification library for short messages intended for the player. It does not read logs or automatically turn internal errors into gameplay messages.

## Client-side API

```lua
local shown, errorCode = exports.coe_notify:Show('success', 'Item recebido.')
```

`Show(type, message, duration?)` accepts `success`, `info`, `warning`, or `error`. The optional duration must be between 1500 and 10000 ms (default: 4000 ms). Messages are limited to 240 bytes and inserted into the UI as text, never as HTML.

## Server-side API

Authorized resources can request a notification for an online player:

```lua
local sent, errorCode = exports.coe_notify:Notify(source, 'info', 'Personagem carregado.')
```

The server validates the caller, recipient, and arguments before sending the message only to the target client. The client→server route does not accept notification messages. The client also validates the origin of received events.

Framework resources that send notifications are authorized by default (`server.lua`). Packages and third-party scripts receive the ACE in `server.cfg`, without editing the framework: `add_ace resource.<nome> coe.notify allow`.

## Integration with logs

A business action can emit a structured audit event and a contextual notification, but these are distinct APIs: the log retains codes and safe diagnostic context; the notification contains only text appropriate for the player. Never send log context, SQL, private identifiers, or exception messages to the NUI.

## Tests and limits

Files: `client.lua` exposes the local API and validates events originating from the server; `server.lua` authorizes resources and routes messages to the player; `html/` renders the visual queue; `fxmanifest.lua` declares assets and entrypoints. Run `lua test\client_notify_test.lua` and `lua test\server_notify_test.lua` from the resource folder. Tests cover validation, rejection of untrusted origins/callers, and forwarding. Layout and NUI require an in-game smoke test; see [TEST_COVERAGE.md](../TEST_COVERAGE.md).

## API reference

[Exports, parameters, and error codes](../reference/coe_notify.md), generated from [`types.lua`](types.lua).
