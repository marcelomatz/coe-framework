-- Substituição de básicos por pacotes: regras puras e o servidor com natives simulados (boot com e sem o pacote,
-- pacote parando e voltando, ensure manual do básico, Restart recusado).
dofile('replace.lua')

local function eq(actual, expected, message)
	if actual ~= expected then
		error(('%s: esperado %s, veio %s'):format(message, tostring(expected), tostring(actual)), 2)
	end
end

-- Regras puras ---------------------------------------------------------------------------------------------------

local resources = {
	coe_mobile = { state = 'stopped', replaceable = true, replaces = {} },
	coe_core = { state = 'started', replaceable = false, replaces = {} },
	pack_phone = { state = 'stopped', replaces = { 'coe_mobile' } },
	evil = { state = 'started', replaces = { 'coe_core', 'evil' } },
	zz_phone = { state = 'missing', replaces = { 'coe_mobile' } }
}
local map = SupervisorReplace.Map(resources)
eq(#map.coe_mobile, 2, 'dois substitutos declarados')
eq(map.coe_mobile[1], 'pack_phone', 'ordem alfabetica')
eq(map.coe_core, nil, 'basico sem coe_supervisor_replaceable nao e substituivel')
eq(map.evil, nil, 'nao substitui a si mesmo')

local ok, by = SupervisorReplace.CanStart('coe_mobile', map, resources, false)
eq(ok, false, 'boot: pacote instalado segura o basico')
eq(by, 'pack_phone', 'quem segura')
eq(SupervisorReplace.CanStart('coe_mobile', map, resources, true), true, 'depois do boot, pacote parado nao segura')
resources.pack_phone.state = 'started'
eq(SupervisorReplace.CanStart('coe_mobile', map, resources, true), false, 'pacote rodando segura sempre')
eq(SupervisorReplace.CanStart('coe_core', map, resources, false), true, 'nao substituivel inicia')

resources.coe_mobile.state = 'started'
local actions = SupervisorReplace.Reconcile(map, resources, {})
eq(actions[1].op, 'stop', 'pacote subiu depois: para o basico')
eq(actions[1].replacer, 'pack_phone', 'substituto')
resources.coe_mobile.state = 'stopped'
resources.pack_phone.state = 'stopped'
actions = SupervisorReplace.Reconcile(map, resources, { coe_mobile = true })
eq(actions[1].op, 'start', 'pacote parou: basico volta')
eq(#SupervisorReplace.Reconcile(map, resources, {}), 0, 'basico parado por fora nao volta sozinho')

-- Servidor com natives simulados ---------------------------------------------------------------------------------

local order, states, meta, handlers, threads = {}, {}, {}, {}, {}
local now, canceled, started, stopped = 0, false, {}, {}

local function add(name, data)
	order[#order + 1] = name
	states[name] = 'stopped'
	meta[name] = data or {}
end

function GetNumResources() return #order end
function GetResourceByFindIndex(index) return order[index + 1] end
function GetResourceState(name) return states[name] or 'missing' end
function GetNumResourceMetadata(name, key)
	local value = meta[name] and meta[name][key]
	return type(value) == 'table' and #value or (value and 1 or 0)
end
function GetResourceMetadata(name, key, index)
	local value = meta[name] and meta[name][key]
	if type(value) == 'table' then return value[index + 1] end
	return value
end
function GetGameTimer() return now end
function Wait() coroutine.yield() end
function CreateThread(fn) local co = coroutine.create(fn); threads[#threads + 1] = co; assert(coroutine.resume(co)) end
function AddEventHandler(name, fn) handlers[name] = handlers[name] or {}; table.insert(handlers[name], fn) end
function CancelEvent() canceled = true end
function GetInvokingResource() return "pack_admin" end
function exports() end
function print() end
function TriggerClientEvent() end
function ExecuteCommand() end
CoeAccess = { Allowed = function() return true end }

local function fire(name, resource)
	for _, fn in ipairs(handlers[name] or {}) do fn(resource) end
end

-- Inicia como o servidor: onResourceStarting cancelável, depois onResourceStart.
function StartResource(name)
	canceled = false
	fire('onResourceStarting', name)
	if canceled then
		return false
	end
	states[name] = 'started'
	started[#started + 1] = name
	fire('onResourceStart', name)
	return true
end
function StopResource(name)
	states[name] = 'stopped'
	stopped[#stopped + 1] = name
	fire('onResourceStop', name)
	return true
end

local function tick(ms)
	now = now + ms
	for _, co in ipairs(threads) do
		if coroutine.status(co) == 'suspended' then assert(coroutine.resume(co)) end
	end
end

local function settle()
	for _ = 1, 6 do tick(1000) end
end

add('coe_supervisor')
add('coe_mobile', { coe_supervisor_replaceable = 'yes' })
add('pack_phone', { coe_supervisor_replaces = { 'coe_mobile' } })
add('coe_staff', { coe_supervisor_replaceable = 'yes' })
add('pack_admin', { coe_supervisor_replaces = { 'coe_staff' } })
add('coe_bank', { coe_supervisor_replaceable = 'yes' })
add('pack_bank', { coe_supervisor_replaces = { 'coe_bank' } })

SupervisorConfig = { Ace = 'coe.supervisor', Managed = { 'coe_mobile', 'coe_staff', 'coe_bank' }, Catalog = {},
	CriticalRestartSize = 6, Replacements = { Enabled = true, SettleMs = 4000 } }
local exported = {}
exports = setmetatable({}, { __call = function(_, name, fn) exported[name] = fn end })
function RegisterCommand() end
function IsPlayerAceAllowed() return false end
dofile('plan.lua')
dofile('server.lua')
states.coe_supervisor = 'started'

-- Boot: ensure [coe-dev] em ordem alfabética (pack_admin antes de coe_staff; coe_mobile antes de pack_phone).
-- pack_bank está instalado mas não foi ensured.
for _, name in ipairs({ 'pack_admin', 'coe_bank', 'coe_mobile', 'pack_phone', 'coe_staff' }) do
	StartResource(name)
end
eq(states.coe_mobile, 'stopped', 'telefone basico nao sobe com o smartphone instalado')
eq(states.coe_staff, 'stopped', 'painel basico nao sobe com o pack_admin rodando')
eq(states.coe_bank, 'stopped', 'banco basico segurado no boot (pack_bank instalado)')
eq(states.pack_phone, 'started', 'smartphone sobe')
settle()
eq(states.coe_bank, 'started', 'pack_bank nao subiu: banco basico volta depois do boot')
eq(states.coe_mobile, 'stopped', 'telefone basico continua fora')

-- Restart do básico substituído é recusado; a lista mostra quem substitui.
eq(exported.Restart('coe_mobile'), 'resource_replaced', 'restart recusado')
local list = exported.List()
local byName = {}
for _, entry in ipairs(list) do byName[entry.name] = entry end
eq(byName.coe_mobile.replacedBy, 'pack_phone', 'lista mostra o substituto')

-- O pacote para: o básico volta.
StopResource('pack_phone')
settle()
eq(states.coe_mobile, 'started', 'smartphone parou: telefone basico volta')

-- O pacote volta: o básico sai.
StartResource('pack_phone')
settle()
eq(states.coe_mobile, 'stopped', 'smartphone voltou: telefone basico sai')

-- ensure manual do básico com o pacote rodando é recusado.
eq(StartResource('coe_mobile'), false, 'ensure manual recusado')

-- pack_bank sobe depois: o banco básico para.
StartResource('pack_bank')
settle()
eq(states.coe_bank, 'stopped', 'pack_bank subiu: banco basico para')

-- Mapa no console
exports.pack_phone = { UpgradeStatus = function() return { ok = true, numbers = 3, messages = 10 } end }
local lines = SupervisorUpgradeLines()
local text = table.concat(lines, '\n')
eq(text:find('coe_mobile (stopped) -> pack_phone (ATIVO)', 1, true) ~= nil, true, 'mapa mostra o substituto ativo')
eq(text:find('dados do básico: messages=10 numbers=3', 1, true) ~= nil, true, 'mapa mostra o que foi importado')
eq(text:find('coe_staff (stopped) -> pack_admin (ATIVO)', 1, true) ~= nil, true, 'painel')

io.write('coe_supervisor replace_test: ok\n')
