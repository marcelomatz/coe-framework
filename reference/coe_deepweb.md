# coe_deepweb — referência da API

> Gerado de `coe_deepweb/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

computadores usam a NUI própria do resource (eventos `coe_deepweb:computer:*`).

## Exports

### `TabletVisible(playerId, appId)`

O app `onion` aparece no aparelho em uso? Só depois de instalar o navegador pelo pen drive (`onion_usb`).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `integer` |  |
| `appId` | `string` |  |

**Retorno**

- `boolean` `visible`

### `TabletCall(playerId, appId, action, payload)`

Ação do app `onion` no smartphone ou no tablet.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `integer` |  |
| `appId` | `string` |  |
| `action` | `string` | Identidade: `state\|handleCreate\|handleLogin\|handleLogout\|handlePassword\|handleReset`; navegador: `bookmarks\|bookmarkAdd\|bookmarkRemove\|site\|directory\|search\|contactThread\|contactSend`; Rabbit: `forumHome\|forumCommunity\|forumPost\|forumUser\|forumSubmit\|forumComment\|forumVote\|forumRemove\|forumCreate`; Deep Market: `marketHome\|marketListing\|marketBuy\|marketMine\|marketOrder\|marketSave\|marketListingStatus\|marketAct\|marketReview` |
| `payload` | `table\|nil` |  |

**Retorno**

- `table` `result` — `{ ok, ... }` ou `{ ok = false, error }`

### `AdminOverview()`

Panorama da DeepWeb para o admin: sites, fornecedores NPC, pedidos em disputa ou pagos sem entrega, posts recentes e contatos dos perfis. Só `coe_admin`.

**Retorno**

- `table` `result` — `{ available, ready, sites, vendors, orders, posts, contacts, categories, decimals, blockTypes }` ou `{ error }`

### `AdminSaveSite(raw)`

Cria ou atualiza um site por blocos (`.onion`). Sites de sistema não são editáveis. Só `coe_admin`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `raw` | `table` | `{ domain, title, description, keywords, blocks, active, listed }` (`listed = false`: fora do diretório e da busca) |

**Retorno**

- `table` `result` — `{ ok, domain }` ou `{ error, index }`

### `AdminDeleteSite(raw)`

Apaga um site por blocos. Só `coe_admin`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `raw` | `table` | `{ domain }` |

**Retorno**

- `table` `result` — `{ ok }` ou `{ error }`

### `AdminSaveVendor(raw)`

Cria ou atualiza um anúncio de fornecedor NPC do Deep Market (preço em texto de moeda, ex.: `0,5`). Só `coe_admin`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `raw` | `table` | `{ id?, vendor, kind, category, title, description, item, count, price, stock, status }` |

**Retorno**

- `table` `result` — `{ ok, id }` ou `{ error }`

### `AdminDeleteVendor(raw)`

Remove um anúncio de fornecedor NPC (pedidos em andamento continuam). Só `coe_admin`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `raw` | `table` | `{ id }` |

**Retorno**

- `table` `result` — `{ ok }` ou `{ error }`

### `AdminResolveOrder(raw)`

Decide um pedido em disputa (ou cancela um pago sem entrega): `buyer` devolve, `seller` paga o vendedor. Só `coe_admin`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `raw` | `table` | `{ id, decision }` |

**Retorno**

- `table` `result` — `{ ok, status }` ou `{ error }`

### `AdminRemovePost(raw)`

Remove um post do Rabbit. Só `coe_admin`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `raw` | `table` | `{ id }` |

**Retorno**

- `table` `result` — `{ ok }` ou `{ error }`

### `AdminReplyContact(raw)`

Responde uma mensagem de contato de um site de perfil (ex.: `fantasma.onion`) e avisa o apelido se estiver online. Só `coe_admin`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `raw` | `table` | `{ id, reply }` |

**Retorno**

- `table` `result` — `{ ok }` ou `{ error }` (`invalid_reply`, `contact_closed`, `not_found`)

### `AdminCloseContact(raw)`

Arquiva uma mensagem de contato. Só `coe_admin`.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `raw` | `table` | `{ id }` |

**Retorno**

- `table` `result` — `{ ok }` ou `{ error }`

