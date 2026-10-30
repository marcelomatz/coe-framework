# coe_inventory — referência da API

> Gerado de `coe_inventory/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

Não é carregado pelo servidor (não consta no fxmanifest). Ver docs/ANNOTATIONS.md.

## Exports

### `CreateInventory(id, slotCount, maxWeight)`

Cria (ou devolve) um inventário. Grava de forma síncrona.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `id` | `string` |  |
| `slotCount` | `integer` |  |
| `maxWeight` | `number` |  |

**Retorno**

- `boolean` `ok`
- `string|nil` `errorCode`

### `DeleteInventory(id)`

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `id` | `string` |  |

**Retorno**

- `boolean` `ok`
- `string|nil` `errorCode`

### `GetInventory(id)`

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `id` | `string` |  |

**Retorno**

- `CoeInventory|nil` `inventory`
- `string|nil` `errorCode`

### `GetSlot(id, slot)`

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `id` | `string` |  |
| `slot` | `integer` |  |

**Retorno**

- `table|nil` `item`
- `string|nil` `errorCode` — `invalid_slot`

### `SwapSlots(id, fromSlot, toSlot)`

Troca dois slots. Gravação adiada (write-behind, `Config.Server.flushIntervalMs`).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `id` | `string` |  |
| `fromSlot` | `integer` |  |
| `toSlot` | `integer` |  |

**Retorno**

- `boolean` `ok`
- `string|nil` `errorCode`

### `SplitItem(id, slot, splitCount)`

Divide uma pilha para um slot vazio. Gravação adiada (write-behind).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `id` | `string` |  |
| `slot` | `integer` |  |
| `splitCount` | `integer` |  |

**Retorno**

- `boolean` `ok`
- `integer|string|nil` `emptySlotOrError`

### `AddItem(id, itemName, count, metadata, requestedSlot)`

Adiciona item. Gravação síncrona.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `id` | `string` |  |
| `itemName` | `string` |  |
| `count` | `integer` |  |
| `metadata` | `table\|string\|nil` |  |
| `requestedSlot` | `integer\|nil` |  |

**Retorno**

- `boolean` `ok`
- `integer|string|nil` `slotOrError`

### `RemoveItem(id, slot, count)`

Remove quantidade de um slot. Gravação síncrona.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `id` | `string` |  |
| `slot` | `integer` |  |
| `count` | `integer` |  |

**Retorno**

- `boolean` `ok`
- `string|nil` `errorCode` — `invalid_slot|invalid_count|insufficient_items|persistence_failed`

### `UseItem(id, slot)`

Consome um item usável. Gravação síncrona.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `id` | `string` |  |
| `slot` | `integer` |  |

**Retorno**

- `boolean` `ok`
- `table|string|nil` `itemDataOrError`

### `SetItemMetadata(id, slot, patch)`

Altera chaves da metadata de um item, mantendo as demais. Gravação síncrona.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `id` | `string` |  |
| `slot` | `integer` |  |
| `patch` | `table` |  |

**Retorno**

- `boolean` `ok`
- `string|nil` `errorCode` — `invalid_slot|invalid_item_metadata|empty_slot|persistence_failed`

### `GetItemCount(id, itemName, metadata, strict)`

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `id` | `string` |  |
| `itemName` | `string` |  |
| `metadata` | `table\|string\|nil` |  |
| `strict` | `boolean\|nil` |  |

**Retorno**

- `integer|nil` `count`
- `string|nil` `errorCode`

### `GetPersistenceStats()`

**Retorno**

- `CoePersistenceStats`

### `OpenStash(playerId, stashId, definition)`

Abre um baú fixo (`stash:<id>`) para o jogador. Quem chama decide a autorização; o inventário só exige que o jogador continue perto de `position`. Cria o inventário na primeira abertura.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `integer` |  |
| `stashId` | `string` |  |
| `definition` | `{` | label: string, slots: integer, maxWeight: integer\|nil, position: { x: number, y: number, z: number }, radius: number } |

**Retorno**

- `boolean` `ok`
- `string|nil` `errorCode` — `invalid_id|invalid_stash|container_limit|invalid_storage|no_active_character`

### `RemoveItemByName(id, itemName, count)`

Remove `count` unidades de um item por nome, varrendo os slots.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `id` | `string` |  |
| `itemName` | `string` |  |
| `count` | `integer` |  |

**Retorno**

- `boolean` `ok`
- `string|nil` `errorCode` — `invalid_count|insufficient_items|persistence_failed`

### `RemoveItemsByMetadata(id, itemName, filter)`

Remove todas as unidades de um item cuja metadata contém `filter` (comparação parcial). Ex.: as chaves de um veículo.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `id` | `string` |  |
| `itemName` | `string` |  |
| `filter` | `table` | chaves e valores que a metadata precisa ter |

**Retorno**

- `integer|false` `removed` — unidades removidas (0 quando não havia)
- `string|nil` `errorCode` — `invalid_item_metadata|persistence_failed`

### `RegisterItem(definition)`

Registra uma nova definição de item no inventário.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `definition` | `table` |  |

**Retorno**

- `boolean` `ok`
- `string|nil` `errorCode`

### `Items()`

Retorna todas as definições de itens registradas.

**Retorno**

- `table<string,` `table>` — items

### `GetItem(name)`

Retorna a definição de um item pelo nome.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `name` | `string` |  |

**Retorno**

- `table|nil` `item`

### `GetContainerInventory(containerId)`

Retorna o inventário de um contêiner pelo id.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `containerId` | `string` |  |

**Retorno**

- `CoeInventory|nil` `inventory`
- `string|nil` `errorCode`

### `GetPlayerInventory(playerId)`

Retorna o inventário do personagem ativo do jogador.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `integer` |  |

**Retorno**

- `CoeInventory|nil` `inventory`
- `string|nil` `errorCode`

### `GetInventoryObject()`

Retorna a instância do serviço global de inventário.

**Retorno**

- `table` `inventoryService`

## Tipos

```lua
---@class CoeItemStack
---@field name string Nome do item (chave em `Items`)
---@field count integer
---@field metadata table|nil

---@class CoeInventory
---@field id string `character:<id>` ou `container:<...>`
---@field slots integer
---@field maxWeight number
---@field items table<integer, table|false> Slot -> item (nil/false = vazio)

---@class CoePersistenceStats
---@field dirty integer Inventários com troca de slots ainda não gravada
---@field cached integer Inventários no cache em memória
---@field evicted integer Inventários despejados por ociosidade
---@field flushes integer
---@field flushed integer
---@field failures integer
---@field lastFlushMs integer
---@field maxFlushMs integer
```

