-- Fluxos do servidor (server/main.lua) com natives, exports e persistência falsos em memória:
-- navegador onion, apelidos, notebook, instalação de desktop/servidor, senha do computador, mineração e desmontagem.
dofile('config.lua')
dofile('locales/pt-br.lua')
dofile('shared/rules.lua')
local function loadFramework(path)
	local candidates = {
		'../' .. path,
		'../tools/compat/' .. path,
		'../[coe-framework]/' .. path,
		'../../coe-framework/' .. path
	}
	for _, c in ipairs(candidates) do
		local f = io.open(c, 'r')
		if f then f:close() return dofile(c) end
	end
	error('Cannot find framework file: ' .. path)
end

loadFramework('coe_core/lib/hash.lua')

local config = DeepwebConfig
local failures = 0

local function eq(actual, expected, message)
	if actual ~= expected then
		failures = failures + 1
		print(('FAIL %s: esperado %s, obtido %s'):format(message, tostring(expected), tostring(actual)))
	end
end

-- Ambiente FiveM falso ---------------------------------------------------------------------------------

local invoking = 'coe_phone'
local now = 1000000
local timer = 0
local registered, netEvents, itemHandlers, threads, sent, notices = {}, {}, {}, {}, {}, {}

function GetInvokingResource() return invoking end
function GetGameTimer() timer = timer + 1000; return timer end
function GetResourceState() return 'started' end
-- O bcrypt do FXServer não confere (o defeito visto em jogo): o resource precisa funcionar sem ele.
function VerifyPasswordHash() return false end
function AddEventHandler() end
local commands = {}
function RegisterCommand(name, fn) commands[name] = fn end
function RegisterNetEvent(name, fn) netEvents[name] = fn end
function TriggerClientEvent(name, playerId, ...) sent[#sent + 1] = { name = name, playerId = playerId, args = { ... } } end
function Wait() coroutine.yield() end
function CreateThread(fn) local co = coroutine.create(fn); threads[#threads + 1] = co; assert(coroutine.resume(co)) end
function GetPlayers() return { '1', '2' } end
local positions = { [1] = { x = 10.0, y = 10.0, z = 0.0 }, [2] = { x = 50.0, y = 50.0, z = 0.0 } }
function GetPlayerPed(playerId) return playerId end
function GetEntityCoords(ped) return positions[ped] end
function GetEntityHeading() return 90.0 end
json = { encode = function() return '{}' end }
os.time = function() return now end

Core = {
	Players = { GetActiveCharacterId = function(playerId) return playerId == 1 and 11 or (playerId == 2 and 22 or nil) end },
	Events = { On = function(name, fn) itemHandlers[name] = fn end }
}

local bank = { ['11'] = 1000, ['22'] = 0 }
local inventory = { ['character:11'] = {}, ['character:22'] = {} }
local spaces = { [1] = { propertyId = 'casa_1', owner = 'c11' } }
local contracts = { ['casa_1|c11'] = true }
local mintReply = nil
local alerts, benches, recipes, craftOpened = {}, {}, {}, {}
local minted = {}

local function resource(methods)
	return setmetatable({}, { __index = function(_, name)
		return function(_, ...)
			local fn = methods[name]
			if fn then return fn(...) end
			return true
		end
	end })
end

local stub = {
	coe_phone = resource({ ActiveDevice = function(playerId) return playerId == 1 and { serial = 'PH1' } or nil end }),
	coe_inventory = resource({
		GetSlot = function(id, slot) return inventory[id][slot] end,
		SetItemMetadata = function(id, slot, patch)
			for key, value in pairs(patch) do inventory[id][slot].metadata[key] = value end
			return true
		end,
		RemoveItem = function(id, slot) if not inventory[id][slot] then return false end; inventory[id][slot] = nil; return true end,
		AddItem = function(id, name, count, metadata)
			local items = inventory[id]
			local slot = 1
			while items[slot] do slot = slot + 1 end
			items[slot] = { name = name, count = count, metadata = metadata or {} }
			return true
		end,
		GetItemCount = function(id, name, metadata)
			local count = 0
			for _, item in pairs(inventory[id]) do
				if item.name == name and (not metadata or item.metadata.serial == metadata.serial) then count = count + (item.count or 1) end
			end
			return count
		end,
		RemoveItemByName = function(id, name, count)
			count = count or 1
			for slot, item in pairs(inventory[id]) do
				if item.name == name and (item.count or 1) >= count then
					item.count = (item.count or 1) - count
					if item.count <= 0 then inventory[id][slot] = nil end
					return true
				end
			end
			return false
		end
	}),
	coe_housing = resource({
		CurrentSpace = function(playerId) return spaces[playerId] end,
		AddressActive = function(propertyId, owner) return contracts[propertyId .. '|' .. owner] == true end
	}),
	coe_economy = resource({
		Debit = function(id, amount) id = tostring(id); if bank[id] < amount then return nil end; bank[id] = bank[id] - amount; return true end,
		Credit = function(id, amount) id = tostring(id); bank[id] = bank[id] + amount; return true end
	}),
	coe_crypto = resource({
		IsReady = function() return true end,
		IsAddress = function(address) return type(address) == 'string' and address:sub(1, 2) == 'nx' and #address == 30 end,
		Balance = function(address) return address == 'nx' .. string.rep('a', 28) and 0 or nil end,
		Format = function(units) return tostring(units) .. ' NOX' end,
		ComputerCall = function(playerId, key) return { ok = true, key = key } end,
		MintMining = function(entries)
			minted[#minted + 1] = entries
			if mintReply then return mintReply end
			local payouts = {}
			for _, entry in ipairs(entries) do payouts[entry.address] = (payouts[entry.address] or 0) + entry.hash * 10 end
			return { ok = true, payouts = payouts }
		end
	}),
	coe_dispatch = resource({ Alert = function(code, x, y) alerts[#alerts + 1] = { code = code, x = x, y = y }; return 1 end }),
	coe_crafting = resource({
		RegisterBench = function(id, def) benches[id] = def; return def end,
		RegisterRecipe = function(recipe) recipes[recipe.id] = recipe; return recipe end,
		Open = function(playerId, bench, opts) craftOpened[#craftOpened + 1] = { playerId = playerId, bench = bench, opts = opts }; return { ok = true } end
	}),
	coe_notify = resource({ Notify = function(playerId, kind, message) notices[#notices + 1] = { playerId = playerId, kind = kind, message = message } end })
}
exports = setmetatable({}, {
	__call = function(_, name, fn) registered[name] = fn end,
	__index = function(_, name) return stub[name] or resource({}) end
})

-- Persistência em memória (mesmo contrato de server/persistence.lua).
local db = { handles = {}, sessions = {}, browsers = {}, devices = {}, rigs = {}, nextRig = 0 }
DeepwebPersistence = {}
function DeepwebPersistence.Initialize() return true end
local function copyHandle(h) return h and { id = h.id, handle = h.handle, hash = h.hash, owner = h.owner, reputation = 0, createdAt = h.createdAt } or false end
function DeepwebPersistence.HandleByName(name)
	for _, h in ipairs(db.handles) do if h.handle == name then return copyHandle(h) end end
	return false
end
function DeepwebPersistence.HandleById(id) return copyHandle(db.handles[id]) end
function DeepwebPersistence.HandlesOf(characterId)
	local list = {}
	for _, h in ipairs(db.handles) do if h.owner == characterId then list[#list + 1] = { id = h.id, handle = h.handle } end end
	return list
end
function DeepwebPersistence.InsertHandle(name, hash, characterId, at)
	for _, h in ipairs(db.handles) do if h.handle == name then return nil, 'handle_taken' end end
	db.handles[#db.handles + 1] = { id = #db.handles + 1, handle = name, hash = hash, owner = characterId, createdAt = at }
	return #db.handles
end
function DeepwebPersistence.UpdateHandlePassword(id, hash) db.handles[id].hash = hash; return true end
function DeepwebPersistence.TouchHandle() return true end
function DeepwebPersistence.Session(key) return db.sessions[key] and copyHandle(db.handles[db.sessions[key]]) or false end
function DeepwebPersistence.SetSession(key, id) db.sessions[key] = id; return true end
function DeepwebPersistence.ClearSession(key) db.sessions[key] = nil; return true end
function DeepwebPersistence.ClearOtherSessions(id, key)
	for other, handleId in pairs(db.sessions) do if handleId == id and other ~= key then db.sessions[other] = nil end end
	return true
end
function DeepwebPersistence.BrowserInstalled(key) return db.browsers[key] == true end
function DeepwebPersistence.InstallBrowser(key) db.browsers[key] = true; return true end
function DeepwebPersistence.Device(key) return db.devices[key] and { kind = db.devices[key].kind, hash = db.devices[key].hash, face = db.devices[key].face or '' } or false end
function DeepwebPersistence.SetDeviceFace(key, characterId) db.devices[key].face = characterId or ''; return true end
function DeepwebPersistence.EnsureDevice(key, kind) db.devices[key] = db.devices[key] or { kind = kind, hash = '' }; return true end
function DeepwebPersistence.SetDevicePassword(key, hash) db.devices[key].hash = hash; return true end
local function copyRig(r)
	if not r then return false end
	local c = {}
	for k, v in pairs(r) do c[k] = v end
	return c
end
function DeepwebPersistence.RigsInSpace(propertyId, owner)
	local list = {}
	for _, r in pairs(db.rigs) do if r.propertyId == propertyId and r.owner == owner then list[#list + 1] = copyRig(r) end end
	table.sort(list, function(a, b) return a.id < b.id end)
	return list
end
function DeepwebPersistence.RigById(id) return copyRig(db.rigs[id]) end
function DeepwebPersistence.MiningRigs()
	local list = {}
	for _, r in pairs(db.rigs) do if r.mining then list[#list + 1] = copyRig(r) end end
	table.sort(list, function(a, b) return a.id < b.id end)
	return list
end
function DeepwebPersistence.InsertRig(data)
	db.nextRig = db.nextRig + 1
	local r = { id = db.nextRig, payout = '', mining = false, minedTotal = 0, lastPayout = 0, lastStatus = '', lastTickAt = 0 }
	for k, v in pairs(data) do r[k] = v end
	db.rigs[r.id] = r
	return r.id
end
function DeepwebPersistence.DeleteRig(id) if not db.rigs[id] then return false end; db.rigs[id] = nil; return true end
function DeepwebPersistence.SetMining(id, payout, enabled) db.rigs[id].payout = payout; db.rigs[id].mining = enabled; return true end
function DeepwebPersistence.RecordTick(id, status, payout, at)
	local r = db.rigs[id]
	if r then r.lastStatus = status; r.lastPayout = payout; r.minedTotal = r.minedTotal + payout; r.lastTickAt = at end
	return true
end

dofile('server/main.lua')
-- O último thread criado ao carregar é o da inicialização e da mineração; os seguintes são de itens usados.
local loadThreads = #threads

local function lastSent(name)
	for index = #sent, 1, -1 do if sent[index].name == name then return sent[index] end end
end

local function useItem(characterId, slot)
	itemHandlers['inventory.itemUsed']('character:' .. characterId, slot, inventory['character:' .. characterId][slot])
	for index = loadThreads + 1, #threads do if coroutine.status(threads[index]) == 'suspended' then coroutine.resume(threads[index]) end end
end

local function computer(playerId, app, action, payload)
	source = playerId
	netEvents['coe_deepweb:computer:call'](#sent + 1, app, action, payload)
	return lastSent('coe_deepweb:computer:result').args[2]
end

local function onion(playerId, action, payload)
	invoking = 'coe_phone'
	return registered.TabletCall(playerId, 'onion', action, payload or {})
end

-- Navegador onion -------------------------------------------------------------------------------------
eq(registered.TabletVisible(1, 'onion'), false, 'sem navegador o app não aparece')
eq(onion(1, 'state').error, 'not_installed', 'sem navegador não navega')
inventory['character:11'][1] = { name = config.Items.Browser, count = 1, metadata = {} }
useItem(11, 1)
eq(db.browsers['phone:PH1'], true, 'instalado no celular em uso')
eq(inventory['character:11'][1], nil, 'pen drive consumido')
eq(registered.TabletVisible(1, 'onion'), true, 'app aparece no celular')
local state = onion(1, 'state')
eq(state.tier.level, 1, 'celular é nível 1')
eq(state.handle, nil, 'sem apelido conectado')

-- Credenciais fictícias usadas só neste teste.
local FIXTURE = { first = 'segredo1', wrong = 'errada!', other = 'outra123', fresh = 'nova1234', pinWrong = '0000', pin = '1234' }

-- Apelidos --------------------------------------------------------------------------------------------
eq(onion(1, 'handleCreate', { name = 'policia', password = FIXTURE.first }).error, 'handle_reserved', 'apelido reservado')
eq(onion(1, 'handleCreate', { name = 'Ghost', password = FIXTURE.first }).ok, true, 'cria apelido')
eq(onion(1, 'state').handle.name, 'ghost', 'apelido conectado no aparelho')
eq(onion(1, 'handleLogout').ok, true, 'sai')
for _ = 1, config.Handles.LoginFailures do onion(1, 'handleLogin', { name = 'ghost', password = FIXTURE.wrong }) end
eq(onion(1, 'handleLogin', { name = 'ghost', password = FIXTURE.first }).error, 'login_locked', 'bloqueio por senha errada')
now = now + config.Handles.LockSeconds
eq(onion(1, 'handleLogin', { name = 'ghost', password = FIXTURE.first }).ok, true, 'entra depois do bloqueio')
eq(onion(1, 'mining', {}).error, 'unknown_action', 'celular não tem mineração')
eq(CoeHash.IsCurrent(db.handles[1].hash), true, 'senha do apelido no hash próprio')
eq(onion(1, 'handleLogout').ok, true, 'sai de novo')
eq(onion(1, 'handleLogin', { name = 'GHOST', password = FIXTURE.first }).ok, true, 'entra com o apelido em maiúsculas')
-- Esqueci a senha: só quem criou redefine
db.browsers['tablet:22'] = true
invoking = 'coe_tablet'
eq(registered.TabletCall(2, 'onion', 'handleReset', { name = 'ghost', password = FIXTURE.other }).error, 'not_owner', 'outro personagem não redefine (no tablet dele)')
eq(onion(1, 'handleReset', { name = 'ghost', password = FIXTURE.fresh }).ok, true, 'dono redefine a senha')
eq(onion(1, 'handleLogout').ok, true, 'sai')
eq(onion(1, 'handleLogin', { name = 'ghost', password = FIXTURE.first }).error, 'wrong_credentials', 'senha antiga não vale')
eq(onion(1, 'handleLogin', { name = 'ghost', password = FIXTURE.fresh }).ok, true, 'entra com a senha nova')
-- Apelido antigo (bcrypt que não confere) continua recuperável pelo dono
db.handles[1].hash = '$2b$10$antigo'
eq(onion(1, 'handleReset', { name = 'ghost', password = FIXTURE.first }).ok, true, 'dono recupera apelido de hash antigo')

-- Notebook ---------------------------------------------------------------------------------------------
inventory['character:11'][2] = { name = config.Items.Laptop, count = 1, metadata = {} }
useItem(11, 2)
local opened = lastSent('coe_deepweb:computer:open')
eq(opened and opened.args[1].kind, 'laptop', 'notebook abre')
local serial = inventory['character:11'][2].metadata.serial
eq(DeepwebRules.IsSerial(serial), true, 'série gravada no item')
eq(opened.args[1].locked, false, 'sem senha abre direto')
eq(computer(1, 'onion', 'state').tier.level, 3, 'notebook é nível 3')
eq(computer(1, 'crypto', 'state').key, 'laptop:' .. serial, 'carteira recebe a chave do notebook')
eq(computer(1, 'onion', 'devicePassword', { new = '1234' }).hasPassword, true, 'define senha')
useItem(11, 2)
eq(lastSent('coe_deepweb:computer:open').args[1].locked, true, 'reabre bloqueado')
eq(computer(1, 'onion', 'state').error, 'locked', 'bloqueado não navega')
eq(computer(1, 'system', 'unlock', { password = FIXTURE.pinWrong }).error, 'wrong_password', 'senha errada')
eq(computer(1, 'system', 'unlock', { password = FIXTURE.pin }).ok, true, 'desbloqueia')
eq(computer(1, 'onion', 'state').computer.hasPassword, true, 'estado mostra a senha')
eq(computer(1, 'onion', 'deviceFace', { enabled = true }).face, true, 'cadastra o rosto')
eq(computer(1, 'onion', 'state').computer.faceMine, true, 'estado mostra o rosto de quem usa')
useItem(11, 2)
local faceOpen = lastSent('coe_deepweb:computer:open').args[1]
eq(faceOpen.locked, false, 'o rosto cadastrado abre sem senha')
eq(faceOpen.faceUnlocked, true, 'avisa que abriu pelo rosto')
-- Outra pessoa com o notebook: pede a senha, o rosto não serve
inventory['character:22'][9] = inventory['character:11'][2]
inventory['character:11'][2] = nil
useItem(22, 9)
local otherOpen = lastSent('coe_deepweb:computer:open').args[1]
eq(otherOpen.locked, true, 'outra pessoa vê o bloqueio')
eq(otherOpen.face, true, 'bloqueio oferece o rosto')
eq(computer(2, 'system', 'unlock', { face = true }).error, 'face_not_recognized', 'rosto de outra pessoa não abre')
eq(computer(2, 'system', 'unlock', { password = FIXTURE.pin }).ok, true, 'com a senha abre')
inventory['character:11'][2] = inventory['character:22'][9]
inventory['character:22'][9] = nil
useItem(11, 2)
eq(computer(1, 'onion', 'deviceFace', { enabled = false }).face, false, 'desliga o rosto')
useItem(11, 2)
eq(lastSent('coe_deepweb:computer:open').args[1].locked, true, 'sem rosto volta a pedir a senha')
eq(computer(1, 'system', 'unlock', { password = FIXTURE.pin }).ok, true, 'desbloqueia pela senha')
inventory['character:11'][2] = nil
eq(computer(1, 'onion', 'state').error, 'device_gone', 'sem o notebook o computador fecha')

-- Desktop e servidor ------------------------------------------------------------------------------------
inventory['character:22'][1] = { name = config.Items.Server, count = 1, metadata = {} }
useItem(22, 1)
eq(notices[#notices].kind, 'error', 'fora de imóvel não instala')
eq(inventory['character:22'][1] ~= nil, true, 'item fica com o jogador')
inventory['character:11'][3] = { name = config.Items.Server, count = 1, metadata = {} }
useItem(11, 3)
eq(db.rigs[1] and db.rigs[1].kind, 'server', 'servidor instalado')
eq(db.rigs[1].propertyId, 'casa_1', 'no imóvel do jogador')
eq(inventory['character:11'][3], nil, 'item sai do inventário')
source = 1
netEvents['coe_deepweb:computer:nearby']()
eq(lastSent('coe_deepweb:computer:open').args[1].kind, 'server', '/computador abre o servidor')
eq(computer(1, 'onion', 'state').rig.hash, config.Mining.Hash.server, 'mostra a mineração')
eq(computer(1, 'onion', 'mining', { address = 'nx' .. string.rep('b', 28), enabled = true }).error, 'unknown_address', 'carteira inexistente')
eq(computer(1, 'onion', 'mining', { address = '', enabled = true }).error, 'no_payout', 'ligar sem carteira')
local payout = 'nx' .. string.rep('a', 28)
eq(computer(1, 'onion', 'mining', { address = payout, enabled = true }).ok, true, 'liga a mineração')

-- Rodada: cobra energia e paga
local function tick()
	assert(coroutine.resume(threads[loadThreads]))
end
tick()
eq(bank['11'], 1000 - config.Mining.PowerCost.server, 'energia cobrada de quem instalou')
eq(db.rigs[1].lastStatus, 'ok', 'rodada ok')
eq(db.rigs[1].lastPayout, config.Mining.Hash.server * 10, 'pagamento da máquina')
-- Rede recusa: energia estornada
mintReply = { ok = false, error = 'too_soon' }
local before = bank['11']
tick()
eq(bank['11'], before, 'energia estornada quando a rede recusa')
eq(db.rigs[1].lastStatus, 'network', 'estado da recusa')
mintReply = nil
-- Contrato vencido: fica fora e não cobra
contracts['casa_1|c11'] = nil
before = bank['11']
tick()
eq(bank['11'], before, 'sem contrato não cobra')
eq(db.rigs[1].lastStatus, 'no_contract', 'estado sem contrato')
contracts['casa_1|c11'] = true
-- Sem saldo para energia
bank['11'] = 5
tick()
eq(db.rigs[1].lastStatus, 'no_power', 'sem saldo para energia')

-- Bancada no computador: fecha o computador e abre o craft no lugar da máquina
eq(benches[config.Craft.Bench] ~= nil, true, 'bancada registrada no coe_crafting')
eq(recipes.hacking_onion_usb.outputs[1].item, 'onion_usb', 'receita do pen drive onion')
eq(computer(1, 'onion', 'workbench').ok, true, 'abre a bancada')
eq(craftOpened[#craftOpened] and craftOpened[#craftOpened].bench, config.Craft.Bench, 'craft aberto na bancada da DeepWeb')
eq(craftOpened[#craftOpened].opts.access(1), true, 'acesso perto da máquina')
positions[1] = { x = 30.0, y = 10.0, z = 0.0 }
eq(craftOpened[#craftOpened].opts.access(1), false, 'longe da máquina perde o acesso')
positions[1] = { x = 10.0, y = 10.0, z = 0.0 }
netEvents['coe_deepweb:computer:nearby']()

-- Longe da máquina o computador fecha; perto, desmonta e devolve o item com a série
positions[1] = { x = 30.0, y = 10.0, z = 0.0 }
eq(computer(1, 'onion', 'state').error, 'device_gone', 'longe da máquina o computador fecha')
positions[1] = { x = 10.0, y = 10.0, z = 0.0 }
netEvents['coe_deepweb:computer:nearby']()
local rigSerial = db.rigs[1].serial
eq(computer(1, 'onion', 'uninstall').ok, true, 'desmonta')
eq(db.rigs[1], nil, 'máquina removida')
local back
for _, item in pairs(inventory['character:11']) do if item.name == config.Items.Server then back = item end end
eq(back and back.metadata.serial, rigSerial, 'item volta com a mesma série')
eq(lastSent('coe_deepweb:computer:close') ~= nil, true, 'computador fecha ao desmontar')

-- Contato NPC: vende em espécie, prefere dinheiro sujo, estoque por rodízio e pode chamar a polícia
local spotIndex = DeepwebRules.DealerRotation(config, now)
local spot = config.Dealer.Spots[spotIndex]
config.Dealer.Alert.Chance = 1
positions[2] = { x = spot.x, y = spot.y, z = spot.z }
inventory['character:22'] = { { name = 'money', count = 10000, metadata = {} }, { name = 'black_money', count = 3000, metadata = {} } }
source = 2
netEvents['coe_deepweb:dealer:buy'](1)
local onion = 0
for _, item in pairs(inventory['character:22']) do if item.name == 'onion_usb' then onion = onion + 1 end end
eq(onion, 1, 'comprou o pen drive onion')
eq(inventory['character:22'][2].count, 3000 - config.Dealer.Stock[1].price, 'pagou com dinheiro sujo')
eq(inventory['character:22'][1].count, 10000, 'dinheiro limpo intacto')
netEvents['coe_deepweb:dealer:buy'](1)
eq(notices[#notices].message:find('Calma') ~= nil, true, 'intervalo entre compras')
for _ = 2, config.Dealer.Stock[1].perRotation do
	now = now + config.Dealer.CooldownSeconds
	netEvents['coe_deepweb:dealer:buy'](1)
end
now = now + config.Dealer.CooldownSeconds
netEvents['coe_deepweb:dealer:buy'](1)
eq(notices[#notices].message:find('Acabou') ~= nil, true, 'estoque do rodízio esgotado')
positions[2] = { x = spot.x + 50, y = spot.y, z = spot.z }
local before = #notices
now = now + config.Dealer.CooldownSeconds
netEvents['coe_deepweb:dealer:buy'](1)
eq(#notices, before, 'longe do contato não compra')
eq(#alerts, config.Dealer.Stock[1].perRotation, 'cada venda abriu chamado (chance 100% no teste)')
for _, alert in ipairs(alerts) do eq(alert.code, config.Dealer.Alert.Code, 'código do chamado') end

-- Limite por espaço
for slot = 10, 10 + config.Install.MaxPerSpace do
	inventory['character:11'][slot] = { name = config.Items.Desktop, count = 1, metadata = {} }
	useItem(11, slot)
end
local count = 0
for _ in pairs(db.rigs) do count = count + 1 end
eq(count, config.Install.MaxPerSpace, 'respeita o limite por espaço')

if failures > 0 then
	print(('%d falha(s)'):format(failures))
	os.exit(1)
end
print('deepweb server_test: ok')
