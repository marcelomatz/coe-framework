# coe_apps — referência da API

> Gerado de `coe_apps/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

Gerado a partir dos exports registrados no código; refine descrições e tipos ao mexer em cada export.

## Exports

### `ClaimPhoto(playerId, token)`

Guarda a foto enviada pelo aparelho (token do upload) e devolve { ok, image } (`media:<id>` ou URL https).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `any` |  |
| `token` | `any` |  |

**Retorno**

- `any`

### `DeletePhoto(image)`

Export server `DeletePhoto` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `image` | `any` |  |

**Retorno**

- `any`

### `HasApp(playerId, appId, device)`

Outros resources com apps na loja (ex.: coe_amzg) conferem se o personagem instalou o app no aparelho.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `any` |  |
| `appId` | `any` |  |
| `device` | `any` |  |

**Retorno**

- `any`

### `PhotoData(id)`

Conteúdo de uma foto guardada no banco (`media:<id>`).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `id` | `any` |  |

**Retorno**

- `any`

### `StorePhoto(image)`

Export client `StorePhoto` (client/camera.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `image` | `any` |  |

**Retorno**

- `any`

### `TabletCall(playerId, appId, action, payload)`

Export server `TabletCall` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `any` |  |
| `appId` | `any` |  |
| `action` | `any` |  |
| `payload` | `any` |  |

**Retorno**

- `any`

### `TabletVisible(playerId, appId)`

Export server `TabletVisible` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `any` |  |
| `appId` | `any` |  |

**Retorno**

- `any`

### `TakePhoto()`

Export client `TakePhoto` (client/camera.lua).

**Retorno**

- `any`

