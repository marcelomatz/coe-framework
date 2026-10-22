local exportsMap, netEvents, coreEvents, sent, threads = {}, {}, {}, {}, {}
local invoking = nil
local now = 1000
local saved, stored = {}, {}
local active = { [7] = 'c1', [8] = 'c2' }
local batches, failBatch = {}, false

source = 7
exports = setmetatable({}, { __call = function(_, name, fn) exportsMap[name] = fn end })
RegisterNetEvent = function() end
AddEventHandler = function(name, fn) netEvents[name] = fn end
TriggerClientEvent = function(name, target, payload) sent[#sent + 1] = { target = target, name = name, payload = payload } end
GetGameTimer = function() return now end
GetInvokingResource = function() return invoking end
GetCurrentResourceName = function() return 'coe_needs' end
CreateThread = function(fn) threads[#threads + 1] = fn end
Wait = function() error('stop') end
CoeLogger = { Create = function() return { log = function() end } end }
Core = {
	Events = { On = function(name, fn) coreEvents[name] = fn end },
	Players = { GetActiveCharacterId = function(src) return active[src] end }
}
NeedsPersistence = {
	IsReady = function() return true end,
	Initialize = function() return true end,
	Load = function(id) return stored[id] or false end,
	SaveMany = function(rows)
		if failBatch then return false, 'database_error' end
		batches[#batches + 1] = #rows
		for _, row in ipairs(rows) do saved[row[1]] = { hunger = row[2].hunger } end
		return true
	end,
	Save = function(id, s) saved[id] = { hunger = s.hunger, thirst = s.thirst, stress = s.stress }; return true end
}

dofile('../coe_core/lib/access.lua')
dofile('config.lua')
dofile('domain/needs.lua')
dofile('application/service.lua')

local function eq(a, b, msg)
	if a ~= b then error(('%s: esperado %s, obtido %s'):format(msg, tostring(b), tostring(a))) end
end
local function runThreads()
	local pending = threads
	threads = {}
	for _, fn in ipairs(pending) do
		local co = coroutine.create(fn)
		local ok, err = coroutine.resume(co)
		if not ok and err ~= 'stop' and not tostring(err):find('stop$') then error(err) end
	end
end
local function last(name)
	for i = #sent, 1, -1 do if sent[i].name == name then return sent[i].payload end end
end

-- carrega o personagem e envia o estado inicial
coreEvents['player.characterLoaded']({ source = 7, character = { characterId = 'c1' } })
runThreads()
eq(last('coe_needs:state').hunger, 90, 'estado inicial enviado')
eq(exportsMap.GetNeeds(7).thirst, 90, 'GetNeeds')
eq(exportsMap.GetNeeds(99), nil, 'sem personagem')

-- atividade: tempo medido pelo servidor
now = 2000
netEvents['coe_needs:activity']('sprint')
now = 62000
exportsMap.GetNeeds(7)
local snap = exportsMap.GetNeeds(7)
eq(snap.hunger, 89, 'tempo acima do limite e truncado em 30s')

-- atividade invalida e flood ignorados
netEvents['coe_needs:activity']('fly')
now = 62100
netEvents['coe_needs:activity']('walk')
now = 62200
netEvents['coe_needs:activity']('idle')

-- exports com autorizacao
invoking = 'resource_estranho'
eq(exportsMap.AddNeed(7, 'hunger', 10), 'caller_not_allowed', 'chamador nao autorizado')
IsPrincipalAceAllowed = function(principal, ace) return principal == 'resource.coe_admin' and ace == 'coe.needs' end
invoking = 'coe_admin'
eq(exportsMap.SetNeed(7, 'hunger', 40), true, 'resource com ACE coe.needs autorizado')
IsPrincipalAceAllowed = nil
invoking = 'coe_inventory'
eq(exportsMap.SetNeed(7, 'hunger', 50), true, 'SetNeed autorizado')
eq(exportsMap.AddNeed(7, 'thirst', 'x'), 'invalid_need', 'delta invalido')
eq(exportsMap.AddNeed(7, 'sede', 1), 'invalid_need', 'nome invalido')
eq(last('coe_needs:state').hunger, 50, 'mudanca enviada ao client')

-- consumo de item
coreEvents['inventory.itemUsed']('character:c1', 1, { name = 'burger' })
eq(exportsMap.GetNeeds(7).hunger, 85, 'burger sacia')
coreEvents['inventory.itemUsed']('character:c1', 1, { name = 'sem_efeito' })
coreEvents['inventory.itemUsed']('character:zzz', 1, { name = 'burger' })
eq(exportsMap.GetNeeds(7).hunger, 85, 'item sem efeito ou outro personagem ignorado')

-- salvar ao descarregar
coreEvents['player.characterUnloaded']({ source = 7 })
runThreads()
eq(saved.c1.hunger >= 80, true, 'estado salvo ao descarregar')
eq(exportsMap.GetNeeds(7), nil, 'entrada removida')

-- falha de leitura nao sobrescreve o banco
NeedsPersistence.Load = function() return nil, 'database_error' end
saved = {}
coreEvents['player.characterLoaded']({ source = 7, character = { characterId = 'c1' } })
runThreads()
coreEvents['player.characterUnloaded']({ source = 7 })
runThreads()
eq(saved.c1, nil, 'nao salva quando a leitura falhou')

-- salvamento periodico: um unico lote para todos os sujos; falha mantem sujo
local function load(id, src)
	coreEvents['player.characterLoaded']({ source = src, character = { characterId = id } })
end
threads = {}
dofile('application/service.lua')
NeedsPersistence.Load = function() return false end
load('c1', 7)
load('c2', 8)
local loops = {}
for _, fn in ipairs(threads) do loops[#loops + 1] = coroutine.create(fn) end
threads = {}
Wait = function() coroutine.yield() end
local function step()
	for _, co in ipairs(loops) do coroutine.resume(co) end
end
step()
exportsMap.SetNeed(7, 'hunger', 40)
exportsMap.SetNeed(8, 'hunger', 41)
saved, batches = {}, {}
failBatch = true
step() step() step()
eq(#batches, 0, 'falha nao conta como salvo')
failBatch = false
step() step() step()
eq(batches[1], 2, 'dois personagens num unico lote')
eq(saved.c2.hunger, 41, 'dados do segundo personagem')

print('coe_needs service tests passed')
