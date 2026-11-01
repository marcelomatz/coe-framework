---@meta
-- Contrato público de coe_elos para LuaLS. Não é carregado pelo servidor. Ver docs/ANNOTATIONS.md.
-- Exports server-only. O app (smartphone e tablet) usa TabletCall; outros resources leem o perfil público.

---@class CoeElosExperience
---@field kind 'job'|'business' Emprego livre (coe_jobs) ou negócio (coe_businesses)
---@field title string Emprego ou cargo
---@field org string "Empregos livres" ou o nome do negócio
---@field subtitle string|nil Tipo do emprego ou categoria do negócio
---@field seconds integer Tempo trabalhado
---@field tasks integer|nil Tarefas (emprego livre)
---@field shifts integer|nil Turnos de ponto (negócio)
---@field level integer|nil Nível no emprego livre
---@field earned integer|nil Ganhos (só quando o dono mostra)
---@field firstAt integer|nil
---@field lastAt integer|nil
---@field current boolean Vínculo atual com o negócio
---@field note string|nil Comentário do dono

---@class CoeElosProfile
---@field stateId string
---@field name string
---@field headline string
---@field about string
---@field resume CoeElosExperience[] Só as experiências que o dono pôs no currículo
---@field summary table `{ seconds, count, current }`
---@field career table|nil `{ level, maxLevel, tier, completed, skills }` quando o dono mostra

---@class CoeElosExports
local exports_coe_elos = {}

---Migrações aplicadas e pronto.
---@return boolean ready
function exports_coe_elos:IsReady() end

---Perfil público de um personagem (o recorte de quem visita sem conexão, com o currículo), ou nil sem perfil.
---Base das candidaturas a vagas (fase 2).
---@param characterId string
---@return CoeElosProfile|nil profile
function exports_coe_elos:GetProfile(characterId) end

---App Elos visível no aparelho (instalado pela loja do coe_apps). Só coe_tablet e coe_phone chamam.
---@param playerId integer
---@param appId string
---@return boolean visible
function exports_coe_elos:TabletVisible(playerId, appId) end

---Ações do app: `state`, `saveProfile`, `setItem`, `search`, `person`, `request`, `respond`, `remove`.
---Só coe_tablet e coe_phone chamam.
---@param playerId integer
---@param appId string
---@param action string
---@param payload table|nil
---@return table result `{ ok, ... }` ou `{ ok = false, error }`
function exports_coe_elos:TabletCall(playerId, appId, action, payload) end
