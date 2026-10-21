---@meta
-- Contrato público de coe_jobs para LuaLS. Não é carregado pelo servidor. Ver docs/ANNOTATIONS.md.
-- Exports server-only. Os empregos ficam em jobs/*.lua; outros resources podem somar empregos com RegisterJob (só dados).
-- A carreira (XP total, habilidades e reputação) vale para todos os empregos.

---@class CoeJobPoint
---@field x number
---@field y number
---@field z number
---@field h number|nil Heading

---@class CoeJobDefinition
---@field id string `[a-z][a-z0-9_]`, 2 a 24 caracteres (`deposit` é reservado)
---@field label string
---@field kind 'gather'|'route'
---@field center CoeJobPoint|number[] NPC onde começa e encerra (aceita `{ x, y, z, h }`)
---@field levels integer[]|nil XP mínimo de cada nível, crescente e começando em 0
---@field levelBonus number|nil Bônus de pagamento por nível acima do 1 (padrão 0.05)
---@field vehicle table|nil `{ model, spawn, plate?, deposit?, returnRadius? }`
---@field tool table|nil Prop na mão durante a ação: `{ model, bone?, offset?, rotation? }`
---@field gather table|nil `{ nodes, sell = { points, price, ped?, label? }, seconds?, yield?, capacity?, nodeCooldown?, xp?, nodeProp?, animation?, unit?, units?, actionLabel? }`
---@field skills string[]|nil Habilidades que o emprego treina (`Career.skills`)
---@field tips string[]|nil Até 6 dicas somadas ao guia "Como funciona" (NPC e app Carreira)
---@field requires table|nil `{ career?, reputation?, skills? = { id = nível } }` para começar
---@field route table|nil `{ stops, pay, mode? ('deliver'|'collect'|'passenger'|'zone'), perRoute?, payPerKm?, bonus?, xp?, stopRadius?, vehicleRange?, stopProp?, carry?, carryAnimation?, recipients?, actionLabel?, pickupLabel?, dropLabel? }`; modo `zone`: `{ zones, perZone?, binModels, binCooldown?, rearDoor?, openLabel?, closeLabel? }` no lugar de `stops`

---@class CoeJobProgress
---@field xp integer
---@field tasks integer
---@field earned integer
---@field level integer
---@field maxLevel integer
---@field nextXp integer|nil

---@class CoeJobsExports
local exports_coe_jobs = {}

---Registra (ou atualiza) um emprego. O dono é o resource chamador; ao parar, os empregos dele saem e as sessões acabam.
---@param definition CoeJobDefinition
---@return true|string result `true` ou o código: `invalid_id`, `invalid_kind`, `invalid_nodes:<i>`, `id_taken`, ...
function exports_coe_jobs:RegisterJob(definition) end

---Remove um emprego registrado pelo próprio resource chamador.
---@param jobId string
---@return boolean removed
function exports_coe_jobs:UnregisterJob(jobId) end

---Catálogo público (o que vai aos clients).
---@return table[] jobs
function exports_coe_jobs:ListJobs() end

---Migrações aplicadas e pronto para registrar. Pacotes também podem ouvir o evento de servidor `coe_jobs:ready`.
---@return boolean ready
function exports_coe_jobs:IsReady() end

---Sessão de trabalho de um jogador online.
---@param playerId integer
---@return table|nil session `{ jobId, cargo, vehicle, progress, route?, cooldowns }`
function exports_coe_jobs:GetSession(playerId) end

---Progresso de um personagem em um emprego registrado.
---@param characterId string
---@param jobId string
---@return CoeJobProgress|nil progress
function exports_coe_jobs:GetProgress(characterId, jobId) end

---Carreira completa do personagem (online ou não): nível, reputação, habilidades, tempo trabalhado (`workedSeconds`)
---e cada emprego (nível, bônus, requisitos, `workedSeconds`, `firstAt`, `lastAt`). Usado pelo currículo do coe_elos.
---@param characterId string
---@return table|nil career
function exports_coe_jobs:GetCareer(characterId) end

---App Carreira do tablet: visível para todos com o coe_jobs pronto.
---@return boolean visible
function exports_coe_jobs:TabletVisible() end

---Ações do app Carreira: `profile` (carreira e últimos trabalhos) e `guide` (`payload.jobId`: guia "Como funciona"
---com o histórico do jogador no emprego). Só o coe_tablet chama.
---@param playerId integer
---@param appId string
---@param action string
---@param payload table|nil
---@return table result `{ ok, data }` ou `{ ok = false, error }`
function exports_coe_jobs:TabletCall(playerId, appId, action, payload) end
