local config = DeepwebConfig

local ready = false
local locks = {}
local lastCall = {}
local computers = {}
local loginFails = {}
local deviceFails = {}
local browsers = {}

-- Ações dos apps (onion). Os módulos do navegador (server/sites.lua, forum.lua, market.lua) acrescentam as suas.
DeepwebApp = {}
local App = DeepwebApp
-- Ações só de leitura: fora do intervalo mínimo entre chamadas (o navegador carrega páginas seguidas).
local readActions = { state = true }
local readyHooks = {}

local KIND_PREFIX = { laptop = 'LT', desktop = 'DT', server = 'SV' }
local ITEM_KIND = {
	[config.Items.Laptop] = 'laptop',
	[config.Items.Desktop] = 'desktop',
	[config.Items.Server] = 'server'
}
local KIND_ITEM = { laptop = config.Items.Laptop, desktop = config.Items.Desktop, server = config.Items.Server }

local function log(level, category, event, context)
	pcall(function()
		return exports.coe_logging:Log(level, category, event, context)
	end)
end

local function audit(event, context)
	pcall(function()
		return exports.coe_audit:Record('info', 'audit', event, context)
	end)
end

local function notify(playerId, kind, message)
	pcall(function()
		exports.coe_notify:Notify(playerId, kind, message)
	end)
end

local rawLocales = (type(Locales) == 'table' and Locales) or {}
local _t_inst = (Core and Core.Locale and Core.Locale.New) and Core.Locale.New({
	default = (config and config.Locale) or (Core and Core.Locale and Core.Locale.GetDefaultLang()) or 'pt-BR',
	locales = rawLocales
})
local _t = function(k, params)
	local text
	if type(_t_inst) == 'table' then
		if _t_inst.T then
			return _t_inst:T(k, params)
		end
		local lang = _t_inst.lang or 'pt-BR'
		local dict = (_t_inst.locales and _t_inst.locales[lang]) or rawLocales[lang] or rawLocales['pt-BR']
		text = (dict and dict[k])
	elseif type(_t_inst) == 'function' then
		return _t_inst(k, params)
	end
	if not text then
		text = (rawLocales['pt-BR'] and rawLocales['pt-BR'][k]) or k
	end
	if text and params then
		for pk, pv in pairs(params) do
			text = text:gsub('%%{' .. pk .. '}', tostring(pv))
		end
	end
	return text
end

local function characterOf(playerId)
	local characterId = Core.Players.GetActiveCharacterId(playerId)
	return characterId and tostring(characterId) or nil
end

-- Senhas com o hash próprio do framework (coe_core/lib/hash.lua): não dependem do bcrypt do FXServer.
local function hash(secret)
	return CoeHash.Secret(secret)
end

local function verify(secret, stored)
	return CoeHash.Verify(secret, stored)
end

local function withLock(key, run)
	if locks[key] then
		return { ok = false, error = 'busy' }
	end
	locks[key] = true
	local ok, result = pcall(run)
	locks[key] = nil
	if not ok then
		log('error', 'gameplay', 'deepweb_action_failed', { error_code = tostring(result):sub(1, 120) })
		return { ok = false, error = 'database_error' }
	end
	return result
end

local function call(resource, name, ...)
	if GetResourceState(resource) ~= 'started' then
		return nil
	end
	local arguments = { ... }
	local ok, result = pcall(function()
		return exports[resource][name](exports[resource], table.unpack(arguments))
	end)
	return ok and result or nil
end

local function inventoryOf(characterId)
	return 'character:' .. characterId
end

local function playerCoords(playerId)
	local ped = GetPlayerPed(playerId)
	if not ped or ped == 0 then
		return nil
	end
	local coords = GetEntityCoords(ped)
	return { x = coords.x, y = coords.y, z = coords.z, heading = GetEntityHeading(ped) }
end

-- Navegador onion no celular e no tablet ---------------------------------------------------------------

local function handheldKey(playerId, device, character)
	if device == 'tablet' then
		return DeepwebRules.DeviceKey('tablet', character)
	end
	local info = call('coe_phone', 'ActiveDevice', playerId)
	if type(info) ~= 'table' or type(info.serial) ~= 'string' then
		return nil
	end
	return DeepwebRules.DeviceKey('phone', info.serial)
end

-- Instalação é permanente: o resultado positivo fica em memória.
local function browserInstalled(key)
	if browsers[key] then
		return true
	end
	local installed = DeepwebPersistence.BrowserInstalled(key)
	if installed then
		browsers[key] = true
	end
	return installed == true
end

-- Usar o pen drive: instala no celular em uso; sem celular (ou já instalado nele), no tablet.
local function installBrowser(playerId, character, slot)
	local targets = {}
	local phoneKey = handheldKey(playerId, 'phone', character)
	if phoneKey then
		targets[#targets + 1] = { key = phoneKey, label = 'celular' }
	end
	targets[#targets + 1] = { key = DeepwebRules.DeviceKey('tablet', character), label = 'tablet' }
	for _, target in ipairs(targets) do
		if not browserInstalled(target.key) then
			if not DeepwebPersistence.InstallBrowser(target.key, character, os.time()) then
				notify(playerId, 'error', _t('install_browser_failed'))
				return
			end
			browsers[target.key] = true
			call('coe_inventory', 'RemoveItem', inventoryOf(character), slot, 1)
			audit('deepweb_browser_installed', { character_id = character, target = target.label })
			notify(playerId, 'success', _t('browser_installed', { target = target.label }))
			return
		end
	end
	notify(playerId, 'info', phoneKey and _t('browser_already_installed')
		or _t('browser_open_hint'))
end

-- Computadores -----------------------------------------------------------------------------------------

local function computerApps()
	local list = {}
	for _, app in ipairs(config.ComputerApps) do
		if not app.resource or GetResourceState(app.resource) == 'started' then
			list[#list + 1] = { id = app.id, label = app.label, script = app.script }
		end
	end
	return list
end

local function profileOf(session)
	local tier = config.Tiers[session.kind]
	return {
		kind = session.kind, label = tier.label, level = tier.level, serial = session.serial,
		locked = not session.unlocked, apps = computerApps(),
		-- face: o computador tem reconhecimento facial; faceUnlocked: abriu pelo rosto de quem está usando.
		face = session.face == true, faceUnlocked = session.faceUnlocked == true
	}
end

-- Abre um computador para o jogador: senha (se houver) e perfil enviado ao cliente.
local function openComputer(playerId, session)
	local device = DeepwebPersistence.Device(session.key)
	if device == nil then
		notify(playerId, 'error', _t('computer_start_failed'))
		return
	end
	if not device then
		DeepwebPersistence.EnsureDevice(session.key, session.kind, os.time())
		device = { kind = session.kind, hash = '' }
	end
	-- Reconhecimento facial: o rosto cadastrado abre sem senha; outra pessoa usa a senha.
	session.face = device.hash ~= '' and device.face ~= ''
	session.faceUnlocked = session.face and device.face == session.character
	session.unlocked = device.hash == '' or session.faceUnlocked
	computers[playerId] = session
	TriggerClientEvent('coe_deepweb:computer:open', playerId, profileOf(session))
end

-- Notebook: série gravada no item na primeira vez que liga.
local function openLaptop(playerId, character, slot)
	local inventory = inventoryOf(character)
	local item = call('coe_inventory', 'GetSlot', inventory, slot)
	if type(item) ~= 'table' or item.name ~= config.Items.Laptop then
		return
	end
	local serial = type(item.metadata) == 'table' and item.metadata.serial
	if not DeepwebRules.IsSerial(serial) then
		serial = DeepwebRules.Serial(KIND_PREFIX.laptop, math.random)
		if not call('coe_inventory', 'SetItemMetadata', inventory, slot, { serial = serial }) then
			notify(playerId, 'error', _t('laptop_start_failed'))
			return
		end
	end
	openComputer(playerId, { kind = 'laptop', serial = serial, key = DeepwebRules.DeviceKey('laptop', serial), character = character })
end

-- Espaço de imóvel em que o jogador está: { propertyId, owner } ou nil.
local function currentSpace(playerId)
	local space = call('coe_housing', 'CurrentSpace', playerId)
	if type(space) ~= 'table' or type(space.propertyId) ~= 'string' or type(space.owner) ~= 'string' then
		return nil
	end
	return space
end

-- Desktop ou servidor: usar o item dentro de um imóvel instala a máquina ali, na posição do jogador.
local function installRig(playerId, character, slot, kind)
	local space = currentSpace(playerId)
	if not space then
		notify(playerId, 'error', _t('install_property_required'))
		return
	end
	local result = withLock('space:' .. space.propertyId .. ':' .. space.owner, function()
		local existing = DeepwebPersistence.RigsInSpace(space.propertyId, space.owner)
		if not existing then
			return { ok = false, error = 'database_error' }
		end
		if #existing >= config.Install.MaxPerSpace then
			return { ok = false, error = 'space_full' }
		end
		local inventory = inventoryOf(character)
		local item = call('coe_inventory', 'GetSlot', inventory, slot)
		if type(item) ~= 'table' or item.name ~= KIND_ITEM[kind] then
			return { ok = false, error = 'no_item' }
		end
		local serial = type(item.metadata) == 'table' and item.metadata.serial
		if not DeepwebRules.IsSerial(serial) then
			serial = DeepwebRules.Serial(KIND_PREFIX[kind], math.random)
		end
		local coords = playerCoords(playerId)
		if not coords then
			return { ok = false, error = 'no_position' }
		end
		if not call('coe_inventory', 'RemoveItem', inventory, slot, 1) then
			return { ok = false, error = 'no_item' }
		end
		local id = DeepwebPersistence.InsertRig({
			kind = kind, serial = serial, propertyId = space.propertyId, owner = space.owner,
			x = coords.x, y = coords.y, z = coords.z, heading = coords.heading, installedBy = character
		}, os.time())
		if not id then
			call('coe_inventory', 'AddItem', inventory, KIND_ITEM[kind], 1, { serial = serial })
			return { ok = false, error = 'database_error' }
		end
		DeepwebPersistence.EnsureDevice(DeepwebRules.DeviceKey(kind, serial), kind, os.time())
		audit('deepweb_rig_installed', { character_id = character, item = KIND_ITEM[kind], target = space.propertyId })
		return { ok = true }
	end)
	if result.ok then
		notify(playerId, 'success', _t('rig_installed', { tier = config.Tiers[kind].label, command = config.Install.Command }))
	elseif result.error == 'space_full' then
		notify(playerId, 'error', _t('space_full'))
	else
		notify(playerId, 'error', _t('install_failed'))
	end
end

-- O jogador continua com o computador? Notebook no inventário; máquina instalada ao alcance, no mesmo espaço.
local function stillHolds(playerId, session)
	local character = characterOf(playerId)
	if not character or character ~= session.character then
		return false
	end
	if session.kind == 'laptop' then
		local count = call('coe_inventory', 'GetItemCount', inventoryOf(character), config.Items.Laptop, { serial = session.serial }, false)
		return type(count) == 'number' and count > 0
	end
	local rig = DeepwebPersistence.RigById(session.rigId)
	local space = currentSpace(playerId)
	local coords = playerCoords(playerId)
	if not rig or not space or not coords or rig.propertyId ~= space.propertyId or rig.owner ~= space.owner then
		return false
	end
	return DeepwebRules.Nearest({ rig }, coords.x, coords.y, coords.z, config.Install.UseDistance + 1.5) ~= nil
end

-- /computador: abre a máquina instalada mais próxima no espaço em que o jogador está.
RegisterNetEvent('coe_deepweb:computer:nearby', function()
	local playerId = source
	local character = characterOf(playerId)
	if not ready or not character then
		return
	end
	local space = currentSpace(playerId)
	local coords = playerCoords(playerId)
	if not space or not coords then
		notify(playerId, 'info', _t('no_computer_nearby'))
		return
	end
	local list = DeepwebPersistence.RigsInSpace(space.propertyId, space.owner)
	local rig = list and DeepwebRules.Nearest(list, coords.x, coords.y, coords.z, config.Install.UseDistance)
	if not rig then
		notify(playerId, 'info', _t('no_computer_nearby'))
		return
	end
	openComputer(playerId, {
		kind = rig.kind, serial = rig.serial, key = DeepwebRules.DeviceKey(rig.kind, rig.serial), rigId = rig.id, character = character
	})
end)

RegisterNetEvent('coe_deepweb:computer:close', function()
	computers[source] = nil
end)

-- Aplicativo onion --------------------------------------------------------------------------------------

local function publicHandle(entry)
	return entry and { name = entry.handle, reputation = entry.reputation, createdAt = entry.createdAt } or nil
end

local function rigView(context)
	if not context.rigId then
		return nil
	end
	local rig = DeepwebPersistence.RigById(context.rigId)
	if not rig then
		return nil
	end
	return {
		kind = rig.kind, serial = rig.serial, mining = rig.mining, payout = rig.payout, hash = DeepwebRules.Hash(config, rig.kind),
		powerCost = DeepwebRules.PowerCost(config, rig.kind), minedTotal = rig.minedTotal, lastPayout = rig.lastPayout,
		lastStatus = rig.lastStatus, lastTickAt = rig.lastTickAt, tickMinutes = config.Mining.TickMinutes,
		mine = rig.installedBy == context.character,
		minedText = call('coe_crypto', 'Format', rig.minedTotal), lastPayoutText = call('coe_crypto', 'Format', rig.lastPayout)
	}
end

function App.state(context)
	local session = DeepwebPersistence.Session(context.key)
	local owned = DeepwebPersistence.HandlesOf(context.character)
	if session == nil or not owned then
		return { ok = false, error = 'database_error' }
	end
	local tier = config.Tiers[context.kind]
	local device = context.computer and DeepwebPersistence.Device(context.key) or nil
	return {
		ok = true,
		tier = { kind = context.kind, label = tier.label, level = tier.level, max = 5 },
		tiers = (function()
			local list = {}
			for kind, entry in pairs(config.Tiers) do
				list[#list + 1] = { kind = kind, label = entry.label, level = entry.level }
			end
			table.sort(list, function(a, b) return a.level < b.level end)
			return list
		end)(),
		features = DeepwebRules.Features(config, tier.level),
		handle = publicHandle(session or nil),
		owned = #owned,
		ownedNames = (function()
			local names = {}
			for _, entry in ipairs(owned) do
				names[#names + 1] = entry.handle
			end
			return names
		end)(),
		canCreate = #owned < config.Handles.MaxPerCharacter,
		limits = { Min = config.Handles.Min, Max = config.Handles.Max, PasswordMin = config.Handles.PasswordMin, MaxPerCharacter = config.Handles.MaxPerCharacter },
		computer = context.computer and {
			serial = context.serial, hasPassword = device and device.hash ~= '' or false,
			face = device and device.hash ~= '' and device.face ~= '' or false,
			faceMine = device and device.face ~= '' and device.face == context.character or false
		} or nil,
		rig = rigView(context),
		browser = { home = config.Browser.Home, maxTabs = config.Browser.MaxTabs, device = context.computer and 'computer' or context.kind }
	}
end

local function requireFeature(context, feature)
	if not DeepwebRules.Allows(config, config.Tiers[context.kind].level, feature) then
		return 'tier_too_low'
	end
	return nil
end

function App.handleCreate(context, payload)
	local denied = requireFeature(context, 'identity')
	if denied then
		return { ok = false, error = denied }
	end
	local name, errorCode = DeepwebRules.Handle(config, payload.name)
	if not name then
		return { ok = false, error = errorCode }
	end
	local password
	password, errorCode = DeepwebRules.Password(config.Handles.PasswordMin, config.Handles.PasswordMax, payload.password)
	if not password then
		return { ok = false, error = errorCode }
	end
	return withLock('character:' .. context.character, function()
		local owned = DeepwebPersistence.HandlesOf(context.character)
		if not owned then
			return { ok = false, error = 'database_error' }
		end
		if #owned >= config.Handles.MaxPerCharacter then
			return { ok = false, error = 'handle_limit' }
		end
		local digest = hash(password)
		if not digest then
			return { ok = false, error = 'database_error' }
		end
		local now = os.time()
		local id
		id, errorCode = DeepwebPersistence.InsertHandle(name, digest, context.character, now)
		if not id then
			return { ok = false, error = errorCode == 'handle_taken' and errorCode or 'database_error' }
		end
		DeepwebPersistence.SetSession(context.key, id, now)
		log('info', 'gameplay', 'deepweb_handle_created', { character_id = context.character })
		return { ok = true }
	end)
end

function App.handleLogin(context, payload)
	local name = DeepwebRules.Handle(config, payload.name)
	if not name or type(payload.password) ~= 'string' or #payload.password > 64 then
		return { ok = false, error = 'wrong_credentials' }
	end
	local now = os.time()
	if DeepwebRules.Locked(loginFails[name], now) then
		return { ok = false, error = 'login_locked', seconds = loginFails[name].lockedUntil - now }
	end
	return withLock('device:' .. context.key, function()
		local entry = DeepwebPersistence.HandleByName(name)
		if entry == nil then
			return { ok = false, error = 'database_error' }
		end
		if not entry or not verify(payload.password, entry.hash) then
			loginFails[name] = DeepwebRules.Fail(config.Handles.LoginFailures, config.Handles.LockSeconds, loginFails[name], now)
			if entry and DeepwebRules.Locked(loginFails[name], now) then
				log('warn', 'security', 'deepweb_login_locked', { character_id = context.character })
			end
			return { ok = false, error = 'wrong_credentials' }
		end
		loginFails[name] = nil
		if not CoeHash.IsCurrent(entry.hash) then
			DeepwebPersistence.UpdateHandlePassword(entry.id, hash(payload.password))
		end
		if not DeepwebPersistence.SetSession(context.key, entry.id, now) then
			return { ok = false, error = 'database_error' }
		end
		DeepwebPersistence.TouchHandle(entry.id, now)
		return { ok = true }
	end)
end

-- Esqueci a senha: quem criou o apelido define outra. Os outros aparelhos saem e este entra.
function App.handleReset(context, payload)
	local name = DeepwebRules.Handle(config, payload.name)
	if not name then
		return { ok = false, error = 'invalid_handle' }
	end
	local password, errorCode = DeepwebRules.Password(config.Handles.PasswordMin, config.Handles.PasswordMax, payload.password)
	if not password then
		return { ok = false, error = errorCode }
	end
	return withLock('handle:' .. name, function()
		local entry = DeepwebPersistence.HandleByName(name)
		if entry == nil then
			return { ok = false, error = 'database_error' }
		end
		if not entry or entry.owner ~= context.character then
			return { ok = false, error = 'not_owner' }
		end
		local digest = hash(password)
		if not digest or not DeepwebPersistence.UpdateHandlePassword(entry.id, digest) then
			return { ok = false, error = 'database_error' }
		end
		local now = os.time()
		DeepwebPersistence.ClearOtherSessions(entry.id, context.key)
		DeepwebPersistence.SetSession(context.key, entry.id, now)
		loginFails[name] = nil
		audit('deepweb_handle_reset', { character_id = context.character })
		return { ok = true }
	end)
end

function App.handleLogout(context)
	if not DeepwebPersistence.ClearSession(context.key) then
		return { ok = false, error = 'database_error' }
	end
	return { ok = true }
end

function App.handlePassword(context, payload)
	local session = DeepwebPersistence.Session(context.key)
	if session == nil then
		return { ok = false, error = 'database_error' }
	end
	if not session then
		return { ok = false, error = 'not_signed_in' }
	end
	local password, errorCode = DeepwebRules.Password(config.Handles.PasswordMin, config.Handles.PasswordMax, payload.new)
	if not password then
		return { ok = false, error = errorCode }
	end
	return withLock('handle:' .. session.id, function()
		if not verify(payload.current, session.hash) then
			return { ok = false, error = 'wrong_password' }
		end
		local digest = hash(password)
		if not digest or not DeepwebPersistence.UpdateHandlePassword(session.id, digest) then
			return { ok = false, error = 'database_error' }
		end
		DeepwebPersistence.ClearOtherSessions(session.id, context.key)
		return { ok = true }
	end)
end

-- Senha do computador: define, troca ou remove (new vazio). Exige a atual quando já existe.
function App.devicePassword(context, payload)
	if not context.computer then
		return { ok = false, error = 'unknown_action' }
	end
	return withLock('device:' .. context.key, function()
		local device = DeepwebPersistence.Device(context.key)
		if not device then
			return { ok = false, error = 'database_error' }
		end
		if device.hash ~= '' and not verify(payload.current, device.hash) then
			return { ok = false, error = 'wrong_password' }
		end
		local digest = ''
		if type(payload.new) == 'string' and payload.new ~= '' then
			local password, errorCode = DeepwebRules.Password(config.Device.PasswordMin, config.Device.PasswordMax, payload.new)
			if not password then
				return { ok = false, error = errorCode }
			end
			digest = hash(password)
			if not digest then
				return { ok = false, error = 'database_error' }
			end
		end
		if not DeepwebPersistence.SetDevicePassword(context.key, digest) then
			return { ok = false, error = 'database_error' }
		end
		if digest == '' then
			DeepwebPersistence.SetDeviceFace(context.key, nil)
		end
		return { ok = true, hasPassword = digest ~= '' }
	end)
end

-- Reconhecimento facial do computador: liga com o rosto de quem está usando (exige senha definida) ou desliga.
-- Como no celular: o rosto cadastrado abre sem senha; outra pessoa só entra pela senha.
function App.deviceFace(context, payload)
	if not context.computer then
		return { ok = false, error = 'unknown_action' }
	end
	return withLock('device:' .. context.key, function()
		local device = DeepwebPersistence.Device(context.key)
		if not device then
			return { ok = false, error = 'database_error' }
		end
		if device.hash == '' then
			return { ok = false, error = 'password_required' }
		end
		local enabled = payload.enabled == true
		if not DeepwebPersistence.SetDeviceFace(context.key, enabled and context.character or nil) then
			return { ok = false, error = 'database_error' }
		end
		return { ok = true, face = enabled }
	end)
end

-- Mineração: liga/desliga e escolhe a carteira que recebe (qualquer endereço existente na rede).
function App.mining(context, payload)
	if not context.rigId then
		return { ok = false, error = 'unknown_action' }
	end
	local denied = requireFeature(context, 'mining')
	if denied then
		return { ok = false, error = denied }
	end
	if GetResourceState('coe_crypto') ~= 'started' then
		return { ok = false, error = 'crypto_unavailable' }
	end
	local enabled = payload.enabled == true
	local address = type(payload.address) == 'string' and payload.address:gsub('^%s+', ''):gsub('%s+$', '') or ''
	if address ~= '' then
		if call('coe_crypto', 'IsAddress', address) ~= true then
			return { ok = false, error = 'invalid_address' }
		end
		if call('coe_crypto', 'Balance', address) == nil then
			return { ok = false, error = 'unknown_address' }
		end
	elseif enabled then
		return { ok = false, error = 'no_payout' }
	end
	if not DeepwebPersistence.SetMining(context.rigId, address, enabled) then
		return { ok = false, error = 'database_error' }
	end
	log('info', 'gameplay', 'deepweb_mining_set', { character_id = context.character, result = enabled and 'on' or 'off' })
	return { ok = true }
end

-- Desmonta a máquina e devolve o item (com a série: senha, carteiras e apelido conectado vão junto).
function App.uninstall(context)
	if not context.rigId then
		return { ok = false, error = 'unknown_action' }
	end
	return withLock('rig:' .. context.rigId, function()
		local rig = DeepwebPersistence.RigById(context.rigId)
		if not rig then
			return { ok = false, error = 'not_found' }
		end
		local inventory = inventoryOf(context.character)
		if not call('coe_inventory', 'AddItem', inventory, KIND_ITEM[rig.kind], 1, { serial = rig.serial }) then
			return { ok = false, error = 'inventory_full' }
		end
		local deleted = DeepwebPersistence.DeleteRig(rig.id)
		if not deleted then
			call('coe_inventory', 'RemoveItemByName', inventory, KIND_ITEM[rig.kind], 1)
			return { ok = false, error = deleted == false and 'not_found' or 'database_error' }
		end
		audit('deepweb_rig_removed', { character_id = context.character, item = KIND_ITEM[rig.kind], target = rig.propertyId })
		return { ok = true, closed = true }
	end)
end

-- Bancada do computador (coe_crafting) ------------------------------------------------------------------

-- A máquina ainda existe, no espaço em que o jogador está e ao alcance?
local function rigReachable(playerId, rigId)
	local rig = DeepwebPersistence.RigById(rigId)
	local space = currentSpace(playerId)
	local coords = playerCoords(playerId)
	if not rig or not space or not coords or rig.propertyId ~= space.propertyId or rig.owner ~= space.owner then
		return nil
	end
	if not DeepwebRules.Nearest({ rig }, coords.x, coords.y, coords.z, config.Install.UseDistance + 1.5) then
		return nil
	end
	return rig
end

-- Abre a bancada no lugar do computador. Posição e acesso são conferidos de novo a cada produção.
function App.workbench(context)
	if not context.rigId then
		return { ok = false, error = 'unknown_action' }
	end
	local rig = DeepwebPersistence.RigById(context.rigId)
	if not rig or not config.Craft.Kinds[rig.kind] then
		return { ok = false, error = 'tier_too_low' }
	end
	if GetResourceState('coe_crafting') ~= 'started' then
		return { ok = false, error = 'craft_unavailable' }
	end
	return { ok = true, closed = true, bench = rig.id }
end

local function openWorkbench(playerId, rigId)
	local rig = rigReachable(playerId, rigId)
	if not rig then
		return
	end
	local result = call('coe_crafting', 'Open', playerId, config.Craft.Bench, {
		label = ('%s · %s'):format(config.Craft.Label, rig.serial),
		position = { x = rig.x, y = rig.y, z = rig.z, radius = config.Install.UseDistance + 1.0 },
		access = function(pid)
			return rigReachable(pid, rigId) ~= nil
		end
	})
	if type(result) == 'table' and result.error then
		notify(playerId, 'error', _t('bench_unavailable'))
	end
end

-- Bancada e receitas vivem no coe_crafting; registra de novo se ele reiniciar.
local function registerCraft()
	if GetResourceState('coe_crafting') ~= 'started' then
		return
	end
	pcall(function()
		exports.coe_crafting:RegisterBench(config.Craft.Bench, {
			label = config.Craft.Label, categories = { 'hacking' }, source = 'player', output = 'player',
			animation = config.Craft.Animation
		})
		for _, recipe in ipairs(config.Craft.Recipes) do
			exports.coe_crafting:RegisterRecipe(recipe)
		end
	end)
end

AddEventHandler('coe_crafting:ready', registerCraft)
CreateThread(registerCraft)

-- Ferramentas compartilhadas com os módulos do navegador.
DeepwebServer = {
	Log = log, Audit = audit, Notify = notify, Call = call, WithLock = withLock, InventoryOf = inventoryOf,
	PlayerCoords = playerCoords, RequireFeature = requireFeature, CharacterOf = characterOf, T = _t,
	IsReady = function() return ready end,
	-- Roda depois das migrações (sementes de sites, comunidades e fornecedores).
	OnReady = function(fn) readyHooks[#readyHooks + 1] = fn end,
	-- Ação só de leitura (sem intervalo mínimo entre chamadas).
	ReadOnly = function(action) readActions[action] = true end,
	-- Personagem online -> playerId (avisos de pedidos).
	PlayerOfCharacter = function(characterId)
		for _, value in ipairs(GetPlayers()) do
			local playerId = tonumber(value)
			if characterOf(playerId) == tostring(characterId) then
				return playerId
			end
		end
		return nil
	end
}

-- Aviso no aparelho de quem usa o apelido, se estiver online (sem revelar a outra parte).
function DeepwebServer.NotifyHandle(handleId, message)
	if not handleId then
		return
	end
	local entry = DeepwebPersistence.HandleById(handleId)
	if not entry then
		return
	end
	local playerId = DeepwebServer.PlayerOfCharacter(entry.owner)
	if playerId then
		notify(playerId, 'info', message)
	end
end

local function dispatch(context, action, payload)
	local handler = type(action) == 'string' and rawget(App, action)
	if type(handler) ~= 'function' then
		return { ok = false, error = 'unknown_action' }
	end
	local now = GetGameTimer()
	if not readActions[action] then
		if lastCall[context.playerId] and now - lastCall[context.playerId] < config.CallCooldownMs then
			return { ok = false, error = 'rate_limited' }
		end
		lastCall[context.playerId] = now
	end
	return handler(context, type(payload) == 'table' and payload or {})
end

-- Smartphone e tablet -----------------------------------------------------------------------------------

exports('TabletVisible', function(playerId, appId)
	local device = config.Hosts[GetInvokingResource() or '']
	if not device or not ready or appId ~= 'onion' then
		return false
	end
	local character = characterOf(playerId)
	local key = character and handheldKey(playerId, device, character)
	return key ~= nil and browserInstalled(key)
end)

exports('TabletCall', function(playerId, appId, action, payload)
	local device = config.Hosts[GetInvokingResource() or '']
	if not device then
		return { ok = false, error = 'forbidden' }
	end
	if not ready then
		return { ok = false, error = 'not_ready' }
	end
	local character = characterOf(playerId)
	if not character then
		return { ok = false, error = 'no_character' }
	end
	if appId ~= 'onion' then
		return { ok = false, error = 'unknown_action' }
	end
	local key = handheldKey(playerId, device, character)
	if not key then
		return { ok = false, error = 'no_device' }
	end
	if not browserInstalled(key) then
		return { ok = false, error = 'not_installed' }
	end
	return dispatch({ playerId = playerId, character = character, kind = device, key = key }, action, payload)
end)

-- Computador (NUI própria) ------------------------------------------------------------------------------

local function reply(playerId, requestId, result)
	TriggerClientEvent('coe_deepweb:computer:result', playerId, requestId, result)
end

-- Desbloqueio com a senha do computador.
local function unlock(playerId, session, payload)
	local now = os.time()
	if DeepwebRules.Locked(deviceFails[session.key], now) then
		return { ok = false, error = 'login_locked', seconds = deviceFails[session.key].lockedUntil - now }
	end
	local device = DeepwebPersistence.Device(session.key)
	if not device then
		return { ok = false, error = 'database_error' }
	end
	if payload.face == true then
		if device.hash ~= '' and device.face ~= '' and device.face == session.character then
			session.unlocked = true
			return { ok = true }
		end
		return { ok = false, error = 'face_not_recognized' }
	end
	if device.hash ~= '' and not verify(payload.password, device.hash) then
		deviceFails[session.key] = DeepwebRules.Fail(config.Device.Failures, config.Device.LockSeconds, deviceFails[session.key], now)
		return { ok = false, error = 'wrong_password' }
	end
	if device.hash ~= '' and not CoeHash.IsCurrent(device.hash) then
		DeepwebPersistence.SetDevicePassword(session.key, hash(payload.password))
	end
	deviceFails[session.key] = nil
	session.unlocked = true
	return { ok = true }
end

RegisterNetEvent('coe_deepweb:computer:call', function(requestId, appId, action, payload)
	local playerId = source
	if type(requestId) ~= 'number' or requestId % 1 ~= 0 then
		return
	end
	if type(appId) ~= 'string' or type(action) ~= 'string' or #appId > 32 or #action > 32 then
		reply(playerId, requestId, { ok = false, error = 'invalid_request' })
		return
	end
	if payload ~= nil and (type(payload) ~= 'table' or #json.encode(payload) > config.MaxPayloadBytes) then
		reply(playerId, requestId, { ok = false, error = 'invalid_payload' })
		return
	end
	local session = computers[playerId]
	if not session or not ready then
		reply(playerId, requestId, { ok = false, error = 'closed' })
		return
	end
	session.character = session.character or characterOf(playerId)
	if not stillHolds(playerId, session) then
		computers[playerId] = nil
		TriggerClientEvent('coe_deepweb:computer:close', playerId)
		reply(playerId, requestId, { ok = false, error = 'device_gone' })
		return
	end
	payload = payload or {}
	if appId == 'system' and action == 'unlock' then
		reply(playerId, requestId, unlock(playerId, session, payload))
		return
	end
	if not session.unlocked then
		reply(playerId, requestId, { ok = false, error = 'locked' })
		return
	end
	local result
	if appId == 'onion' then
		result = dispatch({
			playerId = playerId, character = session.character, kind = session.kind, key = session.key, serial = session.serial,
			computer = true, rigId = session.rigId
		}, action, payload)
		if result.ok and result.closed then
			computers[playerId] = nil
			TriggerClientEvent('coe_deepweb:computer:close', playerId)
			if result.bench then
				openWorkbench(playerId, result.bench)
			end
		end
	elseif appId == 'crypto' then
		result = call('coe_crypto', 'ComputerCall', playerId, session.key, action, payload) or { ok = false, error = 'app_unavailable' }
	else
		result = { ok = false, error = 'app_unavailable' }
	end
	reply(playerId, requestId, type(result) == 'table' and result or { ok = false, error = 'app_error' })
end)

-- Itens -------------------------------------------------------------------------------------------------

local function playerOfCharacter(characterId)
	for _, value in ipairs(GetPlayers()) do
		local playerId = tonumber(value)
		if characterOf(playerId) == characterId then
			return playerId
		end
	end
	return nil
end

Core.Events.On('inventory.itemUsed', function(inventoryId, slot, item)
	local characterId = type(inventoryId) == 'string' and inventoryId:match('^character:(.+)$')
	local name = type(item) == 'table' and item.name
	if not characterId or not name or (not ITEM_KIND[name] and name ~= config.Items.Browser) then
		return
	end
	CreateThread(function()
		local playerId = playerOfCharacter(characterId)
		if not playerId or not ready then
			return
		end
		if name == config.Items.Browser then
			installBrowser(playerId, characterId, slot)
		elseif ITEM_KIND[name] == 'laptop' then
			openLaptop(playerId, characterId, slot)
		else
			installRig(playerId, characterId, slot, ITEM_KIND[name])
		end
	end)
end)

-- Contato NPC do mercado negro --------------------------------------------------------------------------

local dealer = { rotation = nil, stock = {}, last = {} }

local function dealerSpot()
	if not config.Dealer.Enabled then
		return nil
	end
	local index, rotation = DeepwebRules.DealerRotation(config, os.time())
	if not index then
		return nil
	end
	if rotation ~= dealer.rotation then
		dealer.rotation = rotation
		dealer.stock = {}
		for i, entry in ipairs(config.Dealer.Stock) do
			dealer.stock[i] = entry.perRotation
		end
	end
	return config.Dealer.Spots[index], index
end

local function spotPayload()
	local spot, index = dealerSpot()
	return spot and { index = index, x = spot.x, y = spot.y, z = spot.z, heading = spot.heading } or false
end

RegisterNetEvent('coe_deepweb:dealer:where', function()
	TriggerClientEvent('coe_deepweb:dealer:spot', source, spotPayload())
end)

-- Avisa todo mundo quando o contato troca de lugar.
CreateThread(function()
	local announced
	while true do
		local spot = spotPayload()
		local key = spot and (dealer.rotation .. ':' .. spot.index) or 'off'
		if key ~= announced then
			announced = key
			TriggerClientEvent('coe_deepweb:dealer:spot', -1, spot)
		end
		Wait(30000)
	end
end)

local function dealerAlert(spot)
	local alert = config.Dealer.Alert
	if not alert or (alert.Chance or 0) <= 0 or math.random() >= alert.Chance then
		return
	end
	call('coe_dispatch', 'Alert', alert.Code, spot.x, spot.y, spot.z)
end

RegisterNetEvent('coe_deepweb:dealer:buy', function(index)
	local playerId = source
	local character = characterOf(playerId)
	local entry = type(index) == 'number' and config.Dealer.Stock[index]
	if not ready or not character or not entry then
		return
	end
	local now = os.time()
	if dealer.last[playerId] and now - dealer.last[playerId] < config.Dealer.CooldownSeconds then
		notify(playerId, 'error', _t('dealer_cooldown'))
		return
	end
	local spot = dealerSpot()
	local coords = playerCoords(playerId)
	if not spot or not coords or not DeepwebRules.Nearest({ spot }, coords.x, coords.y, coords.z, config.Dealer.UseDistance + 1.0) then
		return
	end
	dealer.last[playerId] = now
	local result = withLock('dealer', function()
		if (dealer.stock[index] or 0) <= 0 then
			return { ok = false, error = 'sold_out' }
		end
		local inventory = inventoryOf(character)
		local counts = {}
		for _, item in ipairs(config.Dealer.Payment) do
			counts[item] = call('coe_inventory', 'GetItemCount', inventory, item) or 0
		end
		local payment = DeepwebRules.PickPayment(config.Dealer.Payment, counts, entry.price)
		if not payment then
			return { ok = false, error = 'no_cash' }
		end
		if call('coe_inventory', 'RemoveItemByName', inventory, payment, entry.price) ~= true then
			return { ok = false, error = 'no_cash' }
		end
		if call('coe_inventory', 'AddItem', inventory, entry.item, 1) ~= true then
			call('coe_inventory', 'AddItem', inventory, payment, entry.price)
			return { ok = false, error = 'inventory_full' }
		end
		dealer.stock[index] = dealer.stock[index] - 1
		audit('deepweb_dealer_sale', { character_id = character, item = entry.item, count = entry.price })
		return { ok = true }
	end)
	if result.ok then
		notify(playerId, 'success', _t('dealer_bought', { item = entry.label }))
		dealerAlert(spot)
	elseif result.error == 'sold_out' then
		notify(playerId, 'info', _t('dealer_sold_out'))
	elseif result.error == 'no_cash' then
		notify(playerId, 'error', _t('dealer_no_cash', { price = entry.price }))
	elseif result.error == 'inventory_full' then
		notify(playerId, 'error', _t('dealer_inventory_full'))
	end
end)

-- Staff: onde está o contato agora (ACE command.coe_deepweb_dealer).
RegisterCommand('coe_deepweb_dealer', function(playerId)
	local spot, index = dealerSpot()
	local text = spot and _t('dealer_info', { spot = spot.label, index = index, stock = json.encode(dealer.stock) }) or _t('dealer_off')
	if playerId == 0 then
		print(text)
	else
		notify(playerId, 'info', text)
	end
end, true)

AddEventHandler('playerDropped', function()
	dealer.last[source] = nil
end)

-- Mineração ---------------------------------------------------------------------------------------------

local function miningTick()
	if GetResourceState('coe_crypto') ~= 'started' or call('coe_crypto', 'IsReady') ~= true then
		return
	end
	local rigs = DeepwebPersistence.MiningRigs()
	if not rigs then
		return
	end
	local now = os.time()
	local charged, entries, hashByAddress = {}, {}, {}
	for _, rig in ipairs(rigs) do
		local active = call('coe_housing', 'AddressActive', rig.propertyId, rig.owner) == true
		local canMine, reason = DeepwebRules.CanMine(config, rig, active)
		if canMine then
			local cost = DeepwebRules.PowerCost(config, rig.kind)
			if cost > 0 and call('coe_economy', 'Debit', rig.installedBy, cost, 'deepweb_power', 'rig:' .. rig.id) ~= true then
				canMine, reason = false, 'no_power'
			end
		end
		if canMine then
			local power = DeepwebRules.Hash(config, rig.kind)
			charged[#charged + 1] = rig
			entries[#entries + 1] = { address = rig.payout, hash = power }
			hashByAddress[rig.payout] = (hashByAddress[rig.payout] or 0) + power
		else
			DeepwebPersistence.RecordTick(rig.id, reason, 0, now)
		end
	end
	if #entries == 0 then
		return
	end
	local result = call('coe_crypto', 'MintMining', entries)
	if type(result) ~= 'table' or not result.ok then
		-- A rede recusou a rodada: devolve a energia cobrada.
		for _, rig in ipairs(charged) do
			call('coe_economy', 'Credit', rig.installedBy, DeepwebRules.PowerCost(config, rig.kind), 'deepweb_power_refund', 'rig:' .. rig.id)
			DeepwebPersistence.RecordTick(rig.id, 'network', 0, now)
		end
		log('warn', 'gameplay', 'deepweb_mining_rejected', { error_code = type(result) == 'table' and tostring(result.error) or 'no_reply' })
		return
	end
	for _, rig in ipairs(charged) do
		local total = result.payouts and result.payouts[rig.payout] or 0
		local share = hashByAddress[rig.payout] > 0 and (total * DeepwebRules.Hash(config, rig.kind) // hashByAddress[rig.payout]) or 0
		DeepwebPersistence.RecordTick(rig.id, 'ok', share, now)
	end
	log('info', 'gameplay', 'deepweb_mining_tick', { count = #charged })
end

AddEventHandler('playerDropped', function()
	computers[source] = nil
	lastCall[source] = nil
end)

CreateThread(function()
	math.randomseed(os.time() + GetGameTimer())
	local waitingLogged = false
	while true do
		local initialized, errorCode = DeepwebPersistence.Initialize()
		if initialized then
			break
		end
		if errorCode == 'database_not_ready' or errorCode == 'database_unavailable' then
			if not waitingLogged then
				log('info', 'persistence', 'database_waiting', {})
				waitingLogged = true
			end
			Wait(1000)
		else
			log('error', 'persistence', 'migrations_failed', { error_code = tostring(errorCode) })
			return
		end
	end
	for _, hook in ipairs(readyHooks) do
		local ok, failure = pcall(hook)
		if not ok then
			log('error', 'persistence', 'deepweb_seed_failed', { error_code = tostring(failure):sub(1, 120) })
		end
	end
	ready = true
	log('info', 'system', 'deepweb_ready', {})
	while true do
		Wait(config.Mining.TickMinutes * 60000)
		local ok, failure = pcall(miningTick)
		if not ok then
			log('error', 'gameplay', 'deepweb_mining_failed', { error_code = tostring(failure):sub(1, 120) })
		end
	end
end)
