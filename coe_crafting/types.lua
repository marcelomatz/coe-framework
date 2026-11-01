---@meta
-- Contrato público de coe_crafting para LuaLS. Não é carregado pelo servidor.
-- Gerado a partir dos exports registrados no código; refine descrições e tipos ao mexer em cada export.

---@class CoeCraftingExports
local exports_coe_crafting = {}

---Export server `AdminCatalog` (server/main.lua).
---@return any
function exports_coe_crafting:AdminCatalog() end

---Export server `AdminDeleteBench` (server/main.lua).
---@param fn any
---@return any
function exports_coe_crafting:AdminDeleteBench(fn) end

---Export server `AdminDeleteMenu` (server/main.lua).
---@param fn any
---@return any
function exports_coe_crafting:AdminDeleteMenu(fn) end

---Export server `AdminDeleteRecipe` (server/main.lua).
---@param fn any
---@return any
function exports_coe_crafting:AdminDeleteRecipe(fn) end

---Export server `AdminSaveBench` (server/main.lua).
---@param fn any
---@return any
function exports_coe_crafting:AdminSaveBench(fn) end

---Export server `AdminSaveMenu` (server/main.lua).
---@param fn any
---@return any
function exports_coe_crafting:AdminSaveMenu(fn) end

---Export server `AdminSaveRecipe` (server/main.lua).
---@param fn any
---@return any
function exports_coe_crafting:AdminSaveRecipe(fn) end

---Export server `AdminSetBusinessMenu` (server/main.lua).
---@param fn any
---@return any
function exports_coe_crafting:AdminSetBusinessMenu(fn) end

---Export server `Begin` (server/main.lua).
---@param fn any
---@return any
function exports_coe_crafting:Begin(fn) end

---Export server `Busy` (server/main.lua).
---@param fn any
---@return any
function exports_coe_crafting:Busy(fn) end

---Export server `Cancel` (server/main.lua).
---@param fn any
---@return any
function exports_coe_crafting:Cancel(fn) end

---Export server `Close` (server/main.lua).
---@param fn any
---@return any
function exports_coe_crafting:Close(fn) end

---Export server `Complete` (server/main.lua).
---@param fn any
---@return any
function exports_coe_crafting:Complete(fn) end

---Export server `List` (server/main.lua).
---@param fn any
---@return any
function exports_coe_crafting:List(fn) end

---Catálogo para o painel: só id, nome e categoria de cada receita.
---@return any
function exports_coe_crafting:ListRecipes() end

---Export server `Open` (server/main.lua).
---@param fn any
---@return any
function exports_coe_crafting:Open(fn) end

---O dono do registro é o resource que chamou; ninguém sobrescreve receita ou bancada de outro.
---@param fn any
---@return any
function exports_coe_crafting:RegisterBench(fn) end

---Export server `RegisterRecipe` (server/main.lua).
---@param fn any
---@return any
function exports_coe_crafting:RegisterRecipe(fn) end

---Export server `RemoveRecipe` (server/main.lua).
---@param fn any
---@return any
function exports_coe_crafting:RemoveRecipe(fn) end
