---@meta
-- Contrato público de coe_inventory para LuaLS (autocompletar e checagem no editor).
-- Não é carregado pelo servidor (não consta no fxmanifest). Ver docs/ANNOTATIONS.md.

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

---@class CoeInventoryExports
local exports_coe_inventory = {}

---Cria (ou devolve) um inventário. Grava de forma síncrona.
---@param id string
---@param slotCount integer
---@param maxWeight number
---@return boolean ok
---@return string|nil errorCode
function exports_coe_inventory:CreateInventory(id, slotCount, maxWeight) end

---@param id string
---@return boolean ok
---@return string|nil errorCode
function exports_coe_inventory:DeleteInventory(id) end

---@param id string
---@return CoeInventory|nil inventory
---@return string|nil errorCode
function exports_coe_inventory:GetInventory(id) end

---@param id string
---@param slot integer
---@return table|nil item
---@return string|nil errorCode `invalid_slot`
function exports_coe_inventory:GetSlot(id, slot) end

---Troca dois slots. Gravação adiada (write-behind, `Config.Server.flushIntervalMs`).
---@param id string
---@param fromSlot integer
---@param toSlot integer
---@return boolean ok
---@return string|nil errorCode
function exports_coe_inventory:SwapSlots(id, fromSlot, toSlot) end

---Divide uma pilha para um slot vazio. Gravação adiada (write-behind).
---@param id string
---@param slot integer
---@param splitCount integer
---@return boolean ok
---@return integer|string|nil emptySlotOrError
function exports_coe_inventory:SplitItem(id, slot, splitCount) end

---Adiciona item. Gravação síncrona.
---@param id string
---@param itemName string
---@param count integer
---@param metadata table|string|nil
---@param requestedSlot integer|nil
---@return boolean ok
---@return integer|string|nil slotOrError
function exports_coe_inventory:AddItem(id, itemName, count, metadata, requestedSlot) end

---Remove quantidade de um slot. Gravação síncrona.
---@param id string
---@param slot integer
---@param count integer
---@return boolean ok
---@return string|nil errorCode `invalid_slot|invalid_count|insufficient_items|persistence_failed`
function exports_coe_inventory:RemoveItem(id, slot, count) end

---Consome um item usável. Gravação síncrona.
---@param id string
---@param slot integer
---@return boolean ok
---@return table|string|nil itemDataOrError
function exports_coe_inventory:UseItem(id, slot) end

---Altera chaves da metadata de um item, mantendo as demais. Gravação síncrona.
---@param id string
---@param slot integer
---@param patch table
---@return boolean ok
---@return string|nil errorCode `invalid_slot|invalid_item_metadata|empty_slot|persistence_failed`
function exports_coe_inventory:SetItemMetadata(id, slot, patch) end

---@param id string
---@param itemName string
---@param metadata table|string|nil
---@param strict boolean|nil
---@return integer|nil count
---@return string|nil errorCode
function exports_coe_inventory:GetItemCount(id, itemName, metadata, strict) end

---@return CoePersistenceStats
function exports_coe_inventory:GetPersistenceStats() end

---Abre um baú fixo (`stash:<id>`) para o jogador. Quem chama decide a autorização; o inventário só exige que o jogador continue perto de `position`. Cria o inventário na primeira abertura.
---@param playerId integer
---@param stashId string
---@param definition { label: string, slots: integer, maxWeight: integer|nil, position: { x: number, y: number, z: number }, radius: number }
---@return boolean ok
---@return string|nil errorCode `invalid_id|invalid_stash|container_limit|invalid_storage|no_active_character`
function exports_coe_inventory:OpenStash(playerId, stashId, definition) end

---Remove `count` unidades de um item por nome, varrendo os slots.
---@param id string
---@param itemName string
---@param count integer
---@return boolean ok
---@return string|nil errorCode `invalid_count|insufficient_items|persistence_failed`
function exports_coe_inventory:RemoveItemByName(id, itemName, count) end

---Registra uma nova definição de item no inventário.
---@param definition table
---@return boolean ok
---@return string|nil errorCode
function exports_coe_inventory:RegisterItem(definition) end

---Retorna todas as definições de itens registradas.
---@return table<string, table> items
function exports_coe_inventory:Items() end

---Retorna a definição de um item pelo nome.
---@param name string
---@return table|nil item
function exports_coe_inventory:GetItem(name) end

---Retorna o inventário de um contêiner pelo id.
---@param containerId string
---@return CoeInventory|nil inventory
---@return string|nil errorCode
function exports_coe_inventory:GetContainerInventory(containerId) end

---Retorna o inventário do personagem ativo do jogador.
---@param playerId integer
---@return CoeInventory|nil inventory
---@return string|nil errorCode
function exports_coe_inventory:GetPlayerInventory(playerId) end

---Retorna a instância do serviço global de inventário.
---@return table inventoryService
function exports_coe_inventory:GetInventoryObject() end
