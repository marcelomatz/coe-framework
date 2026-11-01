-- Apps Ponto e Empregos livres do COE OS (os mesmos do tablet de trabalho básico), com exports simulados.
dofile('config.lua')
dofile('shared/work_rules.lua')

local failures = 0
local function eq(actual, expected, label)
	if actual ~= expected then
		failures = failures + 1
		print(('FAIL %s: esperado %s, veio %s'):format(label, tostring(expected), tostring(actual)))
	end
end

local exported, handlers, clientEvents = {}, {}, {}
local invoking = 'coe_tablet'
local states = { coe_businesses = 'started', coe_jobs = 'started' }
local onDuty = { [1] = 'mecanica' }
local clockedOut = {}
source = nil
function GetResourceState(name) return states[name] or 'missing' end
function GetCurrentResourceName() return 'coe_tablet' end
function GetInvokingResource() return invoking end
function AddEventHandler(name, fn) handlers[name] = fn end
function TriggerClientEvent(name, target, ...) clientEvents[#clientEvents + 1] = { name = name, target = target, args = { ... } } end
Core = { Players = { GetActiveCharacterId = function(id) return id == 1 and 11 or nil end } }
exports = setmetatable({}, {
	__call = function(_, name, fn) exported[name] = fn end,
	__index = function(_, resource)
		if resource == 'coe_businesses' then
			return {
				List = function() return {
					{ id = 'mecanica', label = 'Oficina Central', category = 'mechanic', stations = { clocks = { { x = 10, y = 20 } } }, rules = {} },
					{ id = 'loja', label = 'Loja 24/7', category = 'shop', area = { kind = 'circle', x = 5, y = 6 }, rules = { clockRequired = false } },
					{ id = 'outra', label = 'Outra', category = 'other' }
				} end,
				Access = function(_, businessId, characterId)
					if characterId ~= '11' then return nil end
					if businessId == 'mecanica' then return { staff = true } end
					if businessId == 'loja' then return { owner = true } end
					return nil
				end,
				GradeOf = function() return { label = 'Mecânico', salary = 300 } end,
				CurrentDuty = function(_, playerId) return onDuty[playerId] end,
				ClockOut = function(_, playerId) clockedOut[#clockedOut + 1] = playerId; onDuty[playerId] = nil return true end
			}
		end
		if resource == 'coe_jobs' then
			return {
				GetSession = function() return { jobId = 'taxi' } end,
				ListJobs = function() return {
					{ id = 'miner', label = 'Minerador', gather = { sell = { price = 30 }, unit = 'pedra' }, center = { 1, 2 } },
					{ id = 'taxi', label = 'Taxista', route = { pay = 50 }, vehicle = { deposit = 200 } }
				} end,
				GetCareer = function() return { jobs = { { id = 'miner', allowed = false, lockedReason = 'Nível 2' } } } end
			}
		end
		if resource == 'coe_logging' then return { Log = function() end } end
		return setmetatable({}, { __index = function() return function() end end })
	end
})
os.time = function() return 1000 end
dofile('server/work.lua')

eq(exported.TabletVisible(1, 'duty'), true, 'ponto visivel')
eq(exported.TabletVisible(1, 'nope'), false, 'app desconhecido')
states.coe_jobs = 'stopped'
eq(exported.TabletVisible(1, 'freejobs'), false, 'sem coe_jobs some')
states.coe_jobs = 'started'
invoking = 'outro'
eq(exported.TabletCall(1, 'duty', 'overview').error, 'forbidden', 'so o proprio tablet chama')
eq(exported.TabletVisible(1, 'duty'), false, 'visivel so para o tablet')
invoking = 'coe_tablet'

handlers['coe_businesses:dutyChanged'](1, 'mecanica', true)
eq(clientEvents[#clientEvents].name, 'coe_tablet:duty', 'aviso para a tela')
os.time = function() return 1600 end
local view = exported.TabletCall(1, 'duty', 'overview')
eq(view.ok, true, 'ponto')
eq(#view.data.workplaces, 2, 'locais do personagem')
eq(view.data.workplaces[1].id, 'mecanica', 'de ponto primeiro')
eq(view.data.workplaces[1].role, 'Mecânico', 'cargo')
eq(view.data.workplaces[1].x, 10, 'gps no relogio')
eq(view.data.workplaces[2].role, 'Dono', 'dono')
eq(view.data.duty.seconds, 600, 'tempo de ponto')
local out = exported.TabletCall(1, 'duty', 'clockOut')
eq(out.ok, true, 'encerra o ponto')
eq(clockedOut[1], 1, 'ponto encerrado no coe_businesses')
eq(exported.TabletCall(1, 'duty', 'clockOut').error, 'not_on_duty', 'sem ponto')

local jobs = exported.TabletCall(1, 'freejobs', 'list')
eq(jobs.ok, true, 'empregos')
eq(jobs.data.jobs[1].id, 'taxi', 'emprego atual primeiro')
eq(jobs.data.jobs[2].allowed, false, 'bloqueado')
eq(jobs.data.jobs[2].pay[1], '$ 30 por pedra vendido', 'pagamento')
eq(exported.TabletCall(2, 'freejobs', 'list').error, 'no_character', 'sem personagem')
eq(exported.TabletCall(1, 'freejobs', 'hack').error, 'invalid_action', 'acao invalida')

if failures > 0 then error(failures .. ' falha(s)') end
print('coe_tablet work_test: ok')
