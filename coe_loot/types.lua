---@meta
-- Contrato público de coe_loot para LuaLS. Não é carregado pelo servidor.
-- Ver docs/ANNOTATIONS.md. Tabelas de saque em `config.lua`; só resources de `Callers` usam os exports de sorteio.

---@class CoeLootExports
local exports_coe_loot = {}

---Sorteia uma tabela e entrega no inventário do personagem do jogador.
---@param playerId integer
---@param tableId string Ex.: `house_robbery`, `pedestrian_robbery`, `vehicle_break_in`, `store_robbery`
---@return CoeLootGiveResult result
function exports_coe_loot:Give(playerId, tableId) end

---Sorteia sem entregar (para pôr o saque num baú, num container ou no chão).
---@param tableId string
---@return CoeLootRollResult result
function exports_coe_loot:Roll(tableId) end

---Tabelas carregadas. Leitura livre.
---@return { id: string, label: string }[] tables
function exports_coe_loot:Tables() end

---@class CoeLootGiveResult
---@field ok boolean
---@field error string|nil `forbidden|unknown_table|no_character`
---@field given { item: string, count: integer }[]|nil Entregue
---@field lost { item: string, count: integer }[]|nil Não coube no inventário

---@class CoeLootRollResult
---@field ok boolean
---@field error string|nil `forbidden|unknown_table`
---@field items { item: string, count: integer, unique: boolean }[]|nil
