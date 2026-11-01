local config = CraftingConfig

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

local registry = CraftingRegistry.New(config)
local service = CraftingService.New({
	registry = registry,
	audit = audit,
	inventory = {
		count = function(id, item)
			local ok, count = pcall(function()
				return exports.coe_inventory:GetItemCount(id, item)
			end)
			return ok and tonumber(count) or 0
		end,
		remove = function(id, item, count)
			local ok, removed, removeError = pcall(function()
				return exports.coe_inventory:RemoveItemByName(id, item, count)
			end)
			if not ok then
				return false, 'inventory_unavailable'
			end
			return removed == true, removeError
		end,
		add = function(id, item, count)
			local ok, added, addError = pcall(function()
				return exports.coe_inventory:AddItem(id, item, count)
			end)
			if not ok then
				return false, 'inventory_unavailable'
			end
			return added == true, addError
		end
	}
})

-- Vários retornos se perdem entre resources: devolvemos um valor só, ou { error = codigo }.
local function packResult(result, errorCode)
	if result == nil then
		return { error = errorCode or 'unknown' }
	end
	return result
end

local function allowed()
	local resource = GetInvokingResource()
	if resource == nil then
		return true
	end
	return config.AllowedResources[resource] == true
end

local function guarded(fn)
	return function(...)
		if not allowed() then
			log('warn', 'security', 'craft_caller_denied', { resource = GetInvokingResource() })
			return { error = 'forbidden' }
		end
		return fn(...)
	end
end

-- O dono do registro é o resource que chamou; ninguém sobrescreve receita ou bancada de outro.
exports('RegisterBench', guarded(function(benchType, def)
	return packResult(registry.AddBench(benchType, def, GetInvokingResource() or GetCurrentResourceName()))
end))

exports('RegisterRecipe', guarded(function(recipe)
	return packResult(registry.AddRecipe(recipe, GetInvokingResource() or GetCurrentResourceName()))
end))

exports('RemoveRecipe', guarded(function(id)
	return registry.RemoveRecipe(id, GetInvokingResource() or GetCurrentResourceName())
end))

-- Catálogo para o painel: só id, nome e categoria de cada receita.
exports('ListRecipes', function()
	if GetInvokingResource() ~= 'coe_admin' then
		return {}
	end
	local list = {}
	for _, recipe in ipairs(registry.All()) do
		list[#list + 1] = { id = recipe.id, label = recipe.label, category = recipe.category }
	end
	return list
end)

exports('List', guarded(function(playerId, benchType, context)
	return packResult(service.List(playerId, benchType, context))
end))

exports('Begin', guarded(function(playerId, benchType, recipeId, context)
	return packResult(service.Begin(playerId, benchType, recipeId, context))
end))

exports('Complete', guarded(function(playerId)
	return packResult(service.Complete(playerId))
end))

exports('Cancel', guarded(function(playerId)
	service.Cancel(playerId)
	return true
end))

exports('Busy', guarded(function(playerId)
	return service.Busy(playerId)
end))

local COOLDOWN_MS = 400
local sessions, tokens, lastAction = {}, {}, {}

local MESSAGES = {
	forbidden = 'Você não pode usar esta bancada agora.', missing_items = 'Faltam materiais.',
	craft_busy = 'Você já está produzindo algo.', inventory_full = 'Sem espaço na mochila.',
	inventory_unavailable = 'Inventário indisponível.', recipe_not_found = 'Receita não encontrada.',
	off_duty = 'Bata o ponto neste negócio para usar a bancada.', not_staff = 'Só a equipe deste negócio usa esta bancada.',
	not_member = 'Só membros deste grupo usam esta bancada.', grade_too_low = 'Seu cargo no grupo não libera esta receita.',
	too_far = 'Chegue mais perto da bancada.', unavailable = 'Negócios indisponíveis no momento. Tente de novo.'
}

local function notify(playerId, kind, message)
	pcall(function()
		exports.coe_notify:Notify(playerId, kind, message)
	end)
end

local function throttled(playerId)
	local now = GetGameTimer()
	if lastAction[playerId] and now - lastAction[playerId] < COOLDOWN_MS then
		return true
	end
	lastAction[playerId] = now
	return false
end

local function playerInventory(playerId)
	local ok, id = pcall(function()
		return exports.coe_inventory:GetPlayerInventory(playerId)
	end)
	return ok and id or nil
end

local function nearby(playerId, position)
	local ped = GetPlayerPed(playerId)
	if not ped or ped == 0 then
		return false
	end
	return #(GetEntityCoords(ped) - vector3(position.x, position.y, position.z)) <= (position.radius or 2.0) + 1.0
end

-- Receitas com o nome de cada insumo e saída, para a interface.
local function panel(playerId)
	local session = sessions[playerId]
	if not session then
		return nil, 'no_session'
	end
	local recipes, errorCode = service.List(playerId, session.bench, session.context)
	if not recipes then
		return nil, errorCode
	end
	local function label(item)
		local ok, found = pcall(function()
			return exports.coe_inventory:GetItem(session.context.inventoryId, item)
		end)
		return ok and type(found) == 'table' and found.label or item
	end
	for _, recipe in ipairs(recipes) do
		for _, input in ipairs(recipe.inputs) do
			input.label = label(input.item)
		end
		for _, output in ipairs(recipe.outputs) do
			output.label = label(output.item)
		end
	end
	return recipes
end

local DENIALS = { forbidden = true, off_duty = true, not_staff = true, not_member = true, grade_too_low = true, too_far = true, unavailable = true }

local function fail(playerId, errorCode)
	if DENIALS[errorCode] then
		log('info', 'gameplay', 'craft_denied', { player_id = playerId, reason = errorCode })
	end
	TriggerClientEvent('coe_crafting:failed', playerId, errorCode)
	if MESSAGES[errorCode] then
		notify(playerId, 'error', MESSAGES[errorCode])
	end
end

local function closeSession(playerId, tellClient)
	tokens[playerId] = (tokens[playerId] or 0) + 1
	service.Cancel(playerId)
	if sessions[playerId] and tellClient then
		TriggerClientEvent('coe_crafting:close', playerId)
	end
	sessions[playerId] = nil
end

-- opts: { label, stashId, recipes = { ids } | function(playerId) -> { ids } (opcional: restringe as receitas),
-- position = { x, y, z, radius }, access = function(playerId, recipeId) -> bool, motivo }.
local function openBench(playerId, benchType, opts)
	if type(playerId) ~= 'number' or type(opts) ~= 'table' then
		return { error = 'invalid_context' }
	end
	local bench = registry.Bench(benchType)
	if not bench then
		return { error = 'bench_not_found' }
	end
	local inventoryId = playerInventory(playerId)
	if not inventoryId then
		return { error = 'inventory_unavailable' }
	end
	local position, access = opts.position, opts.access
	local recipeSet
	if type(opts.recipes) == 'table' then
		recipeSet = {}
		for _, id in ipairs(opts.recipes) do
			if type(id) == 'string' then
				recipeSet[id] = true
			end
		end
	elseif type(opts.recipes) == 'function' then
		recipeSet = opts.recipes
	end
	local context = {
		inventoryId = inventoryId,
		recipes = recipeSet,
		stashId = type(opts.stashId) == 'string' and opts.stashId or nil,
		access = function(pid, recipeId)
			if type(position) == 'table' and not nearby(pid, position) then
				return false, 'too_far'
			end
			if access then
				local ok, allowed, reason = pcall(access, pid, recipeId)
				if not ok then
					return false, 'unavailable'
				end
				return allowed == true, allowed ~= true and (reason or 'forbidden') or nil
			end
			return true
		end
	}
	local allowed, reason = context.access(playerId)
	if not allowed then
		return { error = reason or 'forbidden' }
	end
	closeSession(playerId, false)
	sessions[playerId] = { bench = benchType, context = context }
	local recipes, errorCode = panel(playerId)
	if not recipes then
		sessions[playerId] = nil
		return { error = errorCode }
	end
	TriggerClientEvent('coe_crafting:open', playerId, {
		label = type(opts.label) == 'string' and opts.label or bench.label,
		recipes = recipes,
		animation = bench.animation
	})
	return { ok = true }
end

exports('Open', guarded(openBench))

Crafting = { Open = openBench, registry = registry, throttled = throttled, messages = MESSAGES }

exports('Close', guarded(function(playerId)
	closeSession(playerId, true)
	return true
end))

RegisterNetEvent('coe_crafting:refresh', function()
	local playerId = source
	if not sessions[playerId] or throttled(playerId) then
		return
	end
	local recipes, errorCode = panel(playerId)
	if not recipes then
		fail(playerId, errorCode)
		return
	end
	TriggerClientEvent('coe_crafting:recipes', playerId, recipes)
end)

RegisterNetEvent('coe_crafting:craft', function(recipeId)
	local playerId = source
	local session = sessions[playerId]
	if not session or type(recipeId) ~= 'string' or throttled(playerId) then
		return
	end
	local recipe, errorCode = service.Begin(playerId, session.bench, recipeId, session.context)
	if not recipe then
		fail(playerId, errorCode)
		return
	end
	local token = (tokens[playerId] or 0) + 1
	tokens[playerId] = token
	TriggerClientEvent('coe_crafting:started', playerId, recipe.label, recipe.timeMs)
	SetTimeout(recipe.timeMs, function()
		if tokens[playerId] ~= token then
			return
		end
		local done, completeError = service.Complete(playerId)
		if not done then
			fail(playerId, completeError)
			return
		end
		notify(playerId, 'success', ('%s produzido.'):format(done.label))
		TriggerClientEvent('coe_crafting:done', playerId, (panel(playerId)))
	end)
end)

-- Catálogo do painel (receitas próprias e cardápios), persistido no banco.
local catalog = CraftingCatalog.New({
	config = config,
	registry = registry,
	owner = GetCurrentResourceName(),
	store = { save = CraftingPersistence.Save, delete = CraftingPersistence.Delete },
	itemExists = function(name)
		local ok, item = pcall(function()
			return exports.coe_inventory:Items(name)
		end)
		return ok and type(item) == 'table'
	end
})
local catalogReady = false
Crafting.catalog = catalog
Crafting.catalogReady = function()
	return catalogReady
end

local function loadCatalog()
	while true do
		local initialized, errorCode = CraftingPersistence.Initialize()
		if initialized then
			break
		end
		if errorCode == 'database_not_ready' or errorCode == 'database_unavailable' then
			log('info', 'persistence', 'database_waiting', {})
		else
			log('error', 'persistence', 'database_initialization_failed', { error_code = errorCode or 'database_error', retry_ms = 5000 })
		end
		Wait(5000)
	end
	local rows, errorCode = CraftingPersistence.List()
	while not rows do
		log('error', 'persistence', 'catalog_load_failed', { error_code = errorCode or 'database_error', retry_ms = 5000 })
		Wait(5000)
		rows, errorCode = CraftingPersistence.List()
	end
	for _, skipped in ipairs(catalog.Load(rows)) do
		log('warn', 'persistence', 'catalog_entry_skipped', { kind = skipped.kind, item = skipped.id, error_code = tostring(skipped.error) })
	end
	catalogReady = true
	TriggerEvent('coe_crafting:catalogChanged')
	log('info', 'persistence', 'catalog_loaded', { count = #rows })
end

-- Só o painel admin edita o catálogo. Retorno: { ok = true } ou { error = codigo }.
local function adminCall(fn)
	return function(...)
		if GetInvokingResource() ~= 'coe_admin' then
			return { error = 'forbidden' }
		end
		if not catalogReady then
			return { error = 'not_ready' }
		end
		local result, errorCode = fn(...)
		if not result then
			return { error = errorCode or 'unknown' }
		end
		return { ok = true }
	end
end

exports('AdminCatalog', function()
	if GetInvokingResource() ~= 'coe_admin' or not catalogReady then
		return nil
	end
	return catalog.Admin()
end)

exports('AdminSaveRecipe', adminCall(function(raw)
	return catalog.SaveRecipe(raw)
end))

exports('AdminDeleteRecipe', adminCall(function(id)
	return catalog.DeleteRecipe(id)
end))

exports('AdminSaveMenu', adminCall(function(raw)
	return catalog.SaveMenu(raw)
end))

exports('AdminDeleteMenu', adminCall(function(id)
	return catalog.DeleteMenu(id)
end))

exports('AdminSaveBench', adminCall(function(raw)
	local saved, errorCode = catalog.SaveBench(raw)
	if saved then
		TriggerEvent('coe_crafting:catalogChanged')
	end
	return saved, errorCode
end))

exports('AdminDeleteBench', adminCall(function(id)
	local deleted, errorCode = catalog.DeleteBench(id)
	if deleted then
		TriggerEvent('coe_crafting:catalogChanged')
	end
	return deleted, errorCode
end))

exports('AdminSetBusinessMenu', adminCall(function(businessId, raw)
	if type(businessId) ~= 'string' then
		return nil, 'unknown_business'
	end
	local ok, business = pcall(function()
		return exports.coe_businesses:Get(businessId)
	end)
	return catalog.SetBusinessMenu(ok and business or nil, raw)
end))

RegisterNetEvent('coe_crafting:close', function()
	closeSession(source, false)
end)

AddEventHandler('playerDropped', function()
	local playerId = source
	closeSession(playerId, false)
	sessions[playerId], tokens[playerId], lastAction[playerId] = nil, nil, nil
	service.Drop(playerId)
end)

CreateThread(function()
	for _, recipe in ipairs(config.Recipes) do
		local _, errorCode = registry.AddRecipe(recipe, GetCurrentResourceName())
		if errorCode then
			log('error', 'system', 'recipe_invalid', { error_code = errorCode, item = tostring(recipe.id) })
		end
	end
	-- Quem registra bancadas escuta este evento para registrar de novo após um restart.
	TriggerEvent('coe_crafting:ready')
	log('info', 'system', 'started', { count = #config.Recipes })
	loadCatalog()
end)
