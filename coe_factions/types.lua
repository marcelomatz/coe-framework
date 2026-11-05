---@meta
-- Contrato público de coe_factions para LuaLS. Não é carregado pelo servidor.
-- Gerado a partir dos exports registrados no código; refine descrições e tipos ao mexer em cada export.

---@class CoeFactionsExports
local exports_coe_factions = {}

---Export server `CanCraft` (server/main.lua).
---@param characterId any
---@param recipeId any
---@return any
function exports_coe_factions:CanCraft(characterId, recipeId) end

---Export server `CanCraftInFaction` (server/main.lua).
---@param factionId any
---@param characterId any
---@param recipeId any
---@return any
function exports_coe_factions:CanCraftInFaction(factionId, characterId, recipeId) end

---Export server `Categories` (server/main.lua).
---@return any
function exports_coe_factions:Categories() end

---Export server `Delete` (server/main.lua).
---@param factionId any
---@return any
function exports_coe_factions:Delete(factionId) end

---Export server `Get` (server/main.lua).
---@param factionId any
---@return any
function exports_coe_factions:Get(factionId) end

---Export server `IsReady` (server/main.lua).
---@return any
function exports_coe_factions:IsReady() end

---Export server `List` (server/main.lua).
---@return any
function exports_coe_factions:List() end

---Export server `Members` (server/main.lua).
---@param factionId any
---@return any
function exports_coe_factions:Members(factionId) end

---Export server `Memberships` (server/main.lua).
---@param characterId any
---@return any
function exports_coe_factions:Memberships(characterId) end

---Facção no dossiê de identidade: a primeira facção ativa do personagem.
---@param characterId any
---@return any
function exports_coe_factions:PauseMenuFaction(characterId) end

---Export server `RecipesFor` (server/main.lua).
---@param characterId any
---@return any
function exports_coe_factions:RecipesFor(characterId) end

---Receitas liberadas especificamente numa facção para o membro; nil se não for membro ou facção inativa.
---@param factionId any
---@param characterId any
---@return any
function exports_coe_factions:RecipesForFaction(factionId, characterId) end

---Export server `RemoveMember` (server/main.lua).
---@param factionId any
---@param characterId any
---@return any
function exports_coe_factions:RemoveMember(factionId, characterId) end

---Export server `Save` (server/main.lua).
---@param raw any
---@return any
function exports_coe_factions:Save(raw) end

---Export server `SetMember` (server/main.lua).
---@param factionId any
---@param characterId any
---@param grade any
---@return any
function exports_coe_factions:SetMember(factionId, characterId, grade) end

---Export server `TabletCall` (server/main.lua).
---@param playerId any
---@param appId any
---@param action any
---@param payload any
---@param factionId any
---@return any
function exports_coe_factions:TabletCall(playerId, appId, action, payload, factionId) end

---Export server `TabletInstances` (server/main.lua).
---@param playerId any
---@return any
function exports_coe_factions:TabletInstances(playerId) end
