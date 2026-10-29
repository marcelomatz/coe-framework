---@meta
-- Contrato público de coe_appearance para LuaLS. Não é carregado pelo cliente. Ver docs/ANNOTATIONS.md.
-- Todos os exports são client-side. A aparência é uma tabela no formato de `shared/schema.lua` (versão `Version()`).

---@class CoeAppearanceExports
local exports_coe_appearance = {}

---@class CoeAppearanceCreatorOptions
---@field mode 'create'|'appearance'|nil `create` (novo personagem, padrão) ou `appearance` (editar a existente)
---@field characterId string|integer|nil Personagem que está sendo criado/editado
---@field gender 'male'|'female'|nil Gênero inicial (padrão `male`)
---@field firstName string|nil
---@field lastName string|nil
---@field birthDate string|nil

---Abre o criador de personagem. O resultado chega pelos eventos locais `coe_appearance:creatorSubmit` e
---`coe_appearance:creatorCancelled`.
---@param options CoeAppearanceCreatorOptions
---@return boolean opened `false` se já estiver aberto, sem opções ou durante a geração de miniaturas
function exports_coe_appearance:OpenCreator(options) end

---Fecha o criador e deixa a tela escura: quem chamou monta a próxima cena e faz o fade in.
function exports_coe_appearance:CloseCreator() end

---Mostra um erro na tela do criador (ex.: falha ao salvar no servidor).
---@param message string|nil
function exports_coe_appearance:CreatorError(message) end

---@return boolean open
function exports_coe_appearance:IsCreatorOpen() end

---Aplica a aparência num ped que já é do modelo certo (não troca o modelo).
---@param ped integer
---@param appearance table
---@return boolean ok
function exports_coe_appearance:Apply(ped, appearance) end

---Troca o modelo do jogador local e aplica a aparência.
---@param appearance table
---@return boolean ok
function exports_coe_appearance:ApplyToPlayer(appearance) end

---Cria um ped local (não sincronizado) para cenas, com a aparência ou com a roupa padrão do gênero.
---Quem chamou apaga o ped.
---@param appearance table|nil
---@param x number
---@param y number
---@param z number
---@param heading number|nil
---@param gender 'male'|'female'|nil Usado quando `appearance` é nil
---@return integer|nil ped
function exports_coe_appearance:CreatePed(appearance, x, y, z, heading, gender) end

---Valida e normaliza uma aparência recebida (banco, outro resource). `nil` quando inválida.
---@param raw any
---@return table|nil appearance
function exports_coe_appearance:Normalize(raw) end

---Aparência inicial do gênero.
---@param gender 'male'|'female'
---@return table appearance
function exports_coe_appearance:Default(gender) end

---Versão do formato da aparência (`AppearanceSchema.Version`).
---@return integer version
function exports_coe_appearance:Version() end
