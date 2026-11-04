local staffMembers
local lastActions = {}
local GarageKinds = { public = 'Pública', business = 'Negócio', job = 'Corporação' }

local function garageBackend()
	if GetResourceState('coe_garages') == 'started' then
		return 'coe_garages'
	end
	return nil
end

local function garagesList()
	if garageBackend() == 'coe_garages' then
		return exports.coe_garages:ListGarages() or {}
	end
	return {}
end

local function garageSaveRaw(raw)
	if garageBackend() == 'coe_garages' then
		return exports.coe_garages:SaveGarage(raw)
	end
	return { error = 'not_ready' }
end

local function garageDeleteRaw(garageId)
	if garageBackend() == 'coe_garages' then
		return exports.coe_garages:DeleteGarage(garageId)
	end
	return { error = 'not_ready' }
end
local HousingKinds = { apartment = 'Apartamentos', hotel = 'Hotéis', house = 'Casas', commercial = 'Comerciais' }

local log = CoeLogger.Create('coe_admin').log

local function getLicense(playerId)
	for _, identifier in ipairs(GetPlayerIdentifiers(playerId)) do
		if identifier:sub(1, 8) == 'license:' then
			return identifier
		end
	end
end

local function getStaffMembers()
	if staffMembers then
		return staffMembers
	end

	local loaded, errorCode = AdminPersistence.Load()
	if not loaded then
		log('error', 'persistence', 'staff_roles_load_failed', {
			error_code = errorCode or 'database_error'
		})
		return {}
	end
	staffMembers = loaded
	return staffMembers
end

local function getPermissions(playerId)
	local permissions = {}
	for permission, ace in pairs(Config.Permissions) do
		permissions[permission] = IsPlayerAceAllowed(playerId, ace)
	end
	if permissions.root then
		permissions.open = true
		permissions.giveItems = true
		permissions.manageStaff = true
		permissions.manageGroups = true
		permissions.manageResources = true
		permissions.manageTheme = true
		permissions.manageBusinesses = true
		permissions.viewPlayers = true
		permissions.manageBanking = true
		permissions.manageCrypto = true
		permissions.manageNews = true
		permissions.manageDeepweb = true
	end
	if permissions.manageBanking or permissions.manageBusinesses then
		permissions.manageCrypto = true
	end

	local license = getLicense(playerId)
	local member = license and getStaffMembers()[license]
	local role = member and Config.Roles[member.role]
	if role then
		for permission, allowed in pairs(role.permissions) do
			-- Banco nunca vem de cargo: só root ou ACE explícita.
			if allowed and permission ~= 'manageBanking' then
				permissions[permission] = true
			end
		end
	end
	if permissions.manageBanking or permissions.manageBusinesses then
		permissions.manageCrypto = true
	end

	return permissions
end

local function canAssignRole(playerId, roleName)
	local permissions = getPermissions(playerId)
	if not permissions.manageStaff then
		return false
	end
	if permissions.root then
		return true
	end

	local targetRole = Config.Roles[roleName]
	for permission, allowed in pairs(targetRole.permissions) do
		if allowed and not permissions[permission] then
			return false
		end
	end
	return true
end

local function canManageMember(playerId, license)
	local permissions = getPermissions(playerId)
	if permissions.root then
		return true
	end

	if not permissions.manageStaff then
		return false
	end

	local member = getStaffMembers()[license]
	local role = member and Config.Roles[member.role]
	if not role then
		return true
	end

	for permission, allowed in pairs(role.permissions) do
		if allowed and not permissions[permission] then
			return false
		end
	end
	return true
end

local function sendResult(playerId, action, requestId, success, message)
	TriggerClientEvent('coe_admin:result', playerId, action, requestId, success, message)
end

local function allowAction(playerId)
	local now = GetGameTimer()
	local previous = lastActions[playerId]
	if previous and now - previous < 200 then
		return false
	end

	lastActions[playerId] = now
	return true
end

-- Personagem ativo de um jogador online, direto da memória do coe_core (sem banco).
local function activeCharacter(serverId)
	local ok, character = pcall(function()
		return exports.coe_core:GetActiveCharacter(serverId)
	end)
	if not ok or type(character) ~= 'table' then
		return nil
	end
	local name = ('%s %s'):format(character.firstName or '', character.lastName or ''):gsub('^%s+', ''):gsub('%s+$', '')
	if name == '' then
		return nil
	end
	return { characterId = tostring(character.characterId), stateId = character.stateId, name = name:sub(1, 48) }
end

local function onlineCharacters()
	local list = {}
	for _, player in ipairs(GetPlayers()) do
		local character = activeCharacter(tonumber(player))
		if character then
			list[#list + 1] = character
		end
	end
	return list
end

-- Totais que exigem banco (personagens e economia): cache de 60 s com atualização em segundo plano.
local slowStats = AdminAnalytics.Cache({
	now = GetGameTimer,
	load = function()
		local stats = { database = {} }
		local rows = AdminPersistence.Query('SELECT COUNT(*) AS total FROM coe_characters WHERE archived_at IS NULL', {})
		if rows and rows[1] then
			stats.database.characters = tonumber(rows[1].total)
		end
		if GetResourceState('coe_economy') == 'started' then
			local ok, summary = pcall(function()
				return exports.coe_economy:Summary()
			end)
			stats.economy = ok and summary or nil
		end
		return stats
	end,
	async = function(task)
		CreateThread(task)
	end
}, 60000)

local characterDirectory = AdminDirectory.New({
	query = AdminPersistence.Query,
	online = onlineCharacters,
	now = GetGameTimer,
	isStateId = function(text)
		return Core.Identity.IsValidStateId(text)
	end
})

-- Aba Imprensa: veículos do coe_news com o negócio, as garagens de frota e quem da equipe está online/de ponto.
local function buildNewsData()
	if GetResourceState('coe_news') ~= 'started' then
		return { available = false, reason = 'not_started' }
	end
	local ok, overview = pcall(function()
		return exports.coe_news:AdminOverview()
	end)
	if not ok or type(overview) ~= 'table' or not overview.available then
		return { available = false, reason = type(overview) == 'table' and overview.error or 'not_ready' }
	end
	local businessesReady = GetResourceState('coe_businesses') == 'started'
	local online = {}
	for _, character in ipairs(onlineCharacters()) do
		online[character.characterId] = true
	end
	overview.online = online
	overview.businesses, overview.garages, overview.duty = {}, {}, {}
	overview.permissions = {}
	if businessesReady then
		pcall(function()
			overview.permissions = exports.coe_businesses:Permissions() or {}
			local summary = exports.coe_businesses:DutySummary()
			overview.duty = type(summary) == 'table' and summary.byBusiness or {}
		end)
	end
	local wanted = {}
	for _, outlet in ipairs(overview.outlets or {}) do
		wanted[outlet.business] = true
		if businessesReady then
			local found, record = pcall(function()
				return exports.coe_businesses:Get(outlet.business)
			end)
			overview.businesses[outlet.business] = found and type(record) == 'table' and record or nil
		end
		overview.garages[outlet.business] = {}
	end
	local hasFleet = false
	if GetResourceState('coe_garages') == 'started' then
		pcall(function()
			for _, garage in ipairs(exports.coe_garages:ListGarages() or {}) do
				if garage.kind == 'business' and wanted[garage.business] then
					local list = overview.garages[garage.business]
					list[#list + 1] = { id = garage.id, label = garage.label, fleet = exports.coe_garages:ListFleet(garage.id) or {} }
					hasFleet = true
				end
			end
		end)
	end
	overview.vehicleCatalog = {}
	if hasFleet and GetResourceState('coe_vehicle_catalog') == 'started' then
		pcall(function()
			local offset, page = 0, nil
			repeat
				page = exports.coe_vehicle_catalog:ListVehiclesPage({ limit = 500, offset = offset })
				for _, info in ipairs(page.vehicles) do
					overview.vehicleCatalog[#overview.vehicleCatalog + 1] = { model = info.model, name = info.name, brand = info.brand, type = info.type }
				end
				offset = offset + page.limit
			until offset >= page.total or #page.vehicles == 0
			overview.vehicleCatalogTotal = page.total
		end)
	end
	return overview
end

local function getPanelData(playerId)
	local permissions = getPermissions(playerId)
	if not permissions.open and not permissions.giveItems and not permissions.manageStaff
		and not permissions.manageGroups and not permissions.manageResources and not permissions.manageTheme
		and not permissions.manageBusinesses and not permissions.manageBanking and not permissions.manageCrypto
		and not permissions.manageNews and not permissions.manageDeepweb then
		return nil, 'Sem permissão para acessar o painel.'
	end

	local players = {}
	if permissions.giveItems or permissions.manageStaff or permissions.manageBusinesses or permissions.viewPlayers then
		for _, player in ipairs(GetPlayers()) do
			local serverId = tonumber(player)
			if serverId then
				local account = GetPlayerName(serverId) or 'Desconhecido'
				local character = activeCharacter(serverId)
				local entry = {
					id = serverId,
					-- O painel mostra o personagem; o nome da conta fica como referência.
					name = character and character.name or account,
					account = account,
					stateId = character and character.stateId or nil,
					characterId = character and character.characterId or nil,
					hasCharacter = character ~= nil,
					ping = GetPlayerPing(serverId)
				}
				players[#players + 1] = entry
			end
		end
		table.sort(players, function(first, second)
			return first.id < second.id
		end)
	end

	local staff = {}
	if permissions.manageStaff then
		local onlineByLicense = {}
		for _, player in ipairs(GetPlayers()) do
			local serverId = tonumber(player)
			local license = serverId and getLicense(serverId)
			if license then onlineByLicense[license] = serverId end
		end
		for license, member in pairs(getStaffMembers()) do
			local role = Config.Roles[member.role]
			local entry = {
				license = license,
				role = member.role,
				roleLabel = role and role.label or member.role,
				name = 'Offline',
				id = nil
			}
			local serverId = onlineByLicense[license]
			if serverId then
				entry.id = serverId
				entry.name = GetPlayerName(serverId) or 'Desconhecido'
			end
			staff[#staff + 1] = entry
		end
		 table.sort(staff, function(first, second)
			return first.name:lower() < second.name:lower()
		end)
	end

	local factions = { available = false, categories = {}, list = {}, recipes = {} }
	if permissions.manageGroups and GetResourceState('coe_factions') == 'started' then
		local ok = pcall(function()
			factions.categories = exports.coe_factions:Categories()
			factions.list = exports.coe_factions:List()
			factions.available = true
		end)
		if not ok then
			factions.list = {}
		end
		if factions.available and GetResourceState('coe_crafting') == 'started' then
			pcall(function()
				factions.recipes = exports.coe_crafting:ListRecipes() or {}
			end)
		end
	end
	local resources = {}
	local supervisorAvailable = false
	if permissions.manageResources then
		local ok, list = pcall(function()
			return exports.coe_supervisor:List()
		end)
		if ok and type(list) == 'table' then
			resources = list
			supervisorAvailable = true
		end
	end

	local theme = { current = nil, options = {} }
	if permissions.manageTheme then
		local ok, data = pcall(function()
			return exports.coe_ui:GetThemes()
		end)
		if ok and type(data) == 'table' then
			theme = data
		end
	end

	local businesses = { available = false, categories = {}, rules = {}, list = {} }
	if permissions.manageBusinesses and GetResourceState('coe_businesses') == 'started' then
		local ok, categories, rules, list, permissionCatalog = pcall(function()
			return exports.coe_businesses:Categories(), exports.coe_businesses:RuleSchema(), exports.coe_businesses:List(),
				exports.coe_businesses:Permissions()
		end)
		if ok and type(categories) == 'table' then
			businesses = {
				available = true, categories = categories, rules = rules, list = list,
				permissions = type(permissionCatalog) == 'table' and permissionCatalog or {}
			}
			if GetResourceState('coe_crafting') == 'started' then
				local craftOk, crafting = pcall(function()
					return exports.coe_crafting:AdminCatalog()
				end)
				businesses.crafting = craftOk and type(crafting) == 'table' and crafting or nil
			end
		end
	end

	local garages = { available = false, kinds = {}, list = {}, fleets = {}, vehicleCatalog = {} }
	local garageSource = garageBackend()
	if permissions.manageBusinesses and garageSource then
		local ok = pcall(function()
			garages.list = garagesList()
			garages.kinds = GarageKinds
			garages.source = garageSource
			if garageSource == 'coe_garages' then
				for _, garage in ipairs(garages.list) do
					if garage.kind ~= 'public' then
						garages.fleets[garage.id] = exports.coe_garages:ListFleet(garage.id)
					end
				end
			end
			garages.available = true
		end)
		if ok and next(garages.fleets) and GetResourceState('coe_vehicle_catalog') == 'started' then
			pcall(function()
				local offset, page = 0, nil
				repeat
					page = exports.coe_vehicle_catalog:ListVehiclesPage({ limit = 500, offset = offset })
					for _, info in ipairs(page.vehicles) do
						garages.vehicleCatalog[#garages.vehicleCatalog + 1] = { model = info.model, name = info.name, brand = info.brand, type = info.type }
					end
					offset = offset + page.limit
				until offset >= page.total or #page.vehicles == 0
			end)
		end
	end

	local housing = { available = false, kinds = HousingKinds, list = {}, interiors = { categories = {}, list = {} } }
	if permissions.manageBusinesses and GetResourceState('coe_housing') == 'started' then
		local ok = pcall(function()
			housing.list = exports.coe_housing:ListProperties()
			housing.interiors = exports.coe_housing:Interiors()
			housing.available = true
		end)
		if not ok then
			housing.list = {}
		end
	end

	local doors = { available = false, list = {}, factions = {} }
	if permissions.manageBusinesses and GetResourceState('coe_doors') == 'started' then
		local ok, list = pcall(function()
			return exports.coe_doors:List()
		end)
		if ok and type(list) == 'table' and not list.error then
			doors.list = list
			doors.available = true
		end
		if doors.available and GetResourceState('coe_factions') == 'started' then
			pcall(function()
				for _, faction in ipairs(exports.coe_factions:List() or {}) do
					doors.factions[#doors.factions + 1] = { id = faction.id, label = faction.label }
				end
			end)
		end
	end

	local banking = { available = false }
	if permissions.manageBanking and GetResourceState('coe_banking') == 'started' then
		local ok, result = pcall(function()
			return exports.coe_banking:AdminTiers()
		end)
		if ok and type(result) == 'table' and not result.error then
			banking = { available = true, tiers = result.tiers, limits = result.limits }
		end
	end

	local crypto = { available = false }
	if permissions.manageCrypto and GetResourceState('coe_crypto') == 'started' then
		local ok, result = pcall(function()
			return exports.coe_crypto:AdminOverview()
		end)
		if ok and type(result) == 'table' and result.available then
			crypto = result
			local ids, seen = {}, {}
			for _, w in ipairs(crypto.topWallets or {}) do
				local cid = w.createdBy and tostring(w.createdBy)
				if cid and not seen[cid] then seen[cid] = true; ids[#ids + 1] = cid end
			end
			for _, tx in ipairs(crypto.recentTx or {}) do
				local cid = tx.characterId and tostring(tx.characterId)
				if cid and not seen[cid] then seen[cid] = true; ids[#ids + 1] = cid end
			end
			if #ids > 0 then
				local marks = {}
				for index = 1, #ids do marks[index] = '?' end
				local rows = AdminPersistence.Query(('SELECT character_id, state_id, first_name, last_name FROM coe_characters WHERE character_id IN (%s)'):format(table.concat(marks, ',')), ids)
				local names = {}
				for _, row in ipairs(rows or {}) do
					local full = ('%s %s'):format(row.first_name or '', row.last_name or ''):gsub('^%s+', ''):gsub('%s+$', '')
					names[tostring(row.character_id)] = { name = full:sub(1, 48), stateId = row.state_id }
				end
				for _, w in ipairs(crypto.topWallets or {}) do
					local person = w.createdBy and names[tostring(w.createdBy)]
					if person then w.characterName, w.stateId = person.name, person.stateId end
				end
				for _, tx in ipairs(crypto.recentTx or {}) do
					local person = tx.characterId and names[tostring(tx.characterId)]
					if person then tx.characterName, tx.stateId = person.name, person.stateId end
				end
			end
		end
	end

	local amzg = nil
	if permissions.manageBusinesses and GetResourceState('coe_amzg') == 'started' then
		local ok, result = pcall(function()
			return exports.coe_amzg:AdminCatalog()
		end)
		if ok and type(result) == 'table' and result.available then
			amzg = result
		end
	end

	local deepweb = nil
	if permissions.manageDeepweb and GetResourceState('coe_deepweb') == 'started' then
		local ok, result = pcall(function()
			return exports.coe_deepweb:AdminOverview()
		end)
		if ok and type(result) == 'table' and result.available then
			deepweb = result
		end
	end

	local news = nil
	if permissions.manageNews then
		news = buildNewsData()
	end

	local duty = { total = 0, byBusiness = {} }
	if businesses.available then
		local ok, summary = pcall(function()
			return exports.coe_businesses:DutySummary()
		end)
		if ok and type(summary) == 'table' then
			duty = summary
		end
	end
	-- Aluguel de veículos (coe_rentals do framework): estações com atendente, retirada e devolução.
	local rentals = { available = false, list = {}, catalog = {} }
	if permissions.manageBusinesses and GetResourceState('coe_rentals') == 'started' then
		local ok = pcall(function()
			rentals.list = exports.coe_rentals:ListStations() or {}
			rentals.catalog = exports.coe_rentals:Catalog() or {}
		end)
		rentals.available = ok
	end

	local slow = slowStats.Get() or {}
	local analytics = AdminAnalytics.Build({
		players = players,
		businesses = businesses,
		garages = garages,
		fleets = garages.fleets,
		housing = housing,
		duty = duty,
		resources = resources,
		database = slow.database,
		economy = permissions.manageBusinesses and slow.economy or nil
	})
	if not permissions.manageBusinesses then
		analytics.economy = { available = false }
	end

	return {
		theme = theme,
		analytics = analytics,
		businesses = businesses,
		garages = garages,
		rentals = rentals,
		housing = housing,
		doors = doors,
		banking = banking,
		crypto = crypto,
		amzg = amzg,
		deepweb = deepweb,
		news = news,
		actor = {
			id = playerId,
			name = GetPlayerName(playerId) or 'Administrador'
		},
		permissions = permissions,
		players = players,
		items = permissions.giveItems and exports.coe_inventory:Items() or {},
		staff = staff,
		factions = factions,
		resources = resources,
		supervisorAvailable = supervisorAvailable,
		roles = Config.Roles
	}
end

local function refreshPanel(playerId)
	local data, errorMessage = getPanelData(playerId)
	if data then
		TriggerClientEvent('coe_admin:panelData', playerId, data)
	else
		TriggerClientEvent('coe_admin:openResult', playerId, false, errorMessage)
	end
end

local function getOrCreatePlayerInventory(playerId)
	local inventoryId, inventoryError = exports.coe_inventory:GetPlayerInventory(playerId)
	if not inventoryId then
		return nil, inventoryError or 'O jogador precisa selecionar um personagem.'
	end
	return inventoryId
end

RegisterNetEvent('coe_admin:requestOpen', function(silent)
	local playerId = source
	local data, errorMessage = getPanelData(playerId)
	if not data then
		-- Quem só tem as ferramentas da staff (ex.: as ACEs coe.staff.* do painel básico) abre direto nelas.
		if AdminToolsHasAny(playerId) then
			TriggerClientEvent('coe_admin:openResult', playerId, false, nil)
			AdminToolsOpenFor(playerId, true)
			return
		end
		-- O atalho de teclado é pressionado por todos: negação silenciosa, sem log nem aviso.
		if silent == true then
			TriggerClientEvent('coe_admin:openResult', playerId, false, nil)
			return
		end
		log('warn', 'security', 'admin_panel_access_denied', {
			action = 'open',
			source = playerId
		})
		TriggerClientEvent('coe_admin:openResult', playerId, false, errorMessage)
		return
	end

	data.tools = AdminToolsHasAny(playerId)
	TriggerClientEvent('coe_admin:openResult', playerId, true, data)
end)

RegisterNetEvent('coe_admin:setTheme', function(requestId, themeName)
	local playerId = source
	if type(requestId) ~= 'number' or requestId % 1 ~= 0 then
		return
	end
	if not allowAction(playerId) then
		sendResult(playerId, 'themeChange', requestId, false, 'Aguarde antes de executar outra ação.')
		return
	end
	if type(themeName) ~= 'string' or #themeName > 24 then
		sendResult(playerId, 'themeChange', requestId, false, 'Tema inválido.')
		return
	end
	if not getPermissions(playerId).manageTheme then
		log('warn', 'security', 'theme_change_denied', {
			action = 'set_theme',
			theme = themeName,
			source = playerId
		})
		sendResult(playerId, 'themeChange', requestId, false, 'Sem permissão para alterar o tema.')
		return
	end

	local ok, result = pcall(function()
		return exports.coe_ui:SetTheme(themeName)
	end)
	if not ok then
		result = 'ui_unavailable'
	end
	if result ~= true then
		log('error', 'audit', 'theme_change_failed', {
			error_code = tostring(result),
			theme = themeName,
			source = playerId
		})
		local messages = {
			invalid_theme = 'Tema inexistente.',
			ui_unavailable = 'O coe_ui não está iniciado.'
		}
		sendResult(playerId, 'themeChange', requestId, false, messages[result] or 'Não foi possível alterar o tema.')
		return
	end

	log('info', 'audit', 'theme_changed', {
		theme = themeName,
		source = playerId
	})
	sendResult(playerId, 'themeChange', requestId, true, 'Tema aplicado a todos os jogadores.')
	refreshPanel(playerId)
end)

RegisterNetEvent('coe_admin:restartResource', function(requestId, resourceName)
	local playerId = source
	if type(requestId) ~= 'number' or requestId % 1 ~= 0 then
		return
	end
	if not allowAction(playerId) then
		sendResult(playerId, 'resourceRestart', requestId, false, 'Aguarde antes de executar outra ação.')
		return
	end
	if type(resourceName) ~= 'string' or #resourceName > 64 then
		sendResult(playerId, 'resourceRestart', requestId, false, 'Resource inválido.')
		return
	end
	if not getPermissions(playerId).manageResources then
		log('warn', 'security', 'resource_restart_denied', {
			action = 'restart_resource',
			resource = resourceName,
			source = playerId
		})
		sendResult(playerId, 'resourceRestart', requestId, false, 'Sem permissão para reiniciar resources.')
		return
	end

	local ok, result = pcall(function()
		return exports.coe_supervisor:Restart(resourceName, playerId)
	end)
	if not ok then
		result = 'supervisor_unavailable'
	end
	if result ~= true then
		log('error', 'audit', 'resource_restart_failed', {
			error_code = tostring(result),
			resource = resourceName,
			source = playerId
		})
		local messages = {
			restart_in_progress = 'Já existe um reinício em andamento.',
			resource_not_managed = 'Resource não gerenciado.',
			dependency_cycle = 'Dependências circulares impedem o reinício.',
			supervisor_unavailable = 'O coe_supervisor não está iniciado.'
		}
		sendResult(playerId, 'resourceRestart', requestId, false, messages[result] or 'Não foi possível reiniciar o resource.')
		return
	end

	log('info', 'audit', 'resource_restart_requested', {
		resource = resourceName,
		source = playerId
	})
	sendResult(playerId, 'resourceRestart', requestId, true, 'Reinício iniciado. O painel fecha durante o processo.')
end)

RegisterNetEvent('coe_admin:refresh', function()
	local playerId = source
	local data, errorMessage = getPanelData(playerId)
	if data then
		TriggerClientEvent('coe_admin:panelData', playerId, data)
	else
		TriggerClientEvent('coe_admin:openResult', playerId, false, errorMessage)
	end
end)

RegisterNetEvent('coe_admin:giveItem', function(requestId, targetId, itemName, count, metadata)
	local playerId = source
	if type(requestId) ~= 'number' or requestId % 1 ~= 0 then
		return
	end
	if not getPermissions(playerId).giveItems then
		log('warn', 'security', 'admin_item_grant_denied', {
			action = 'give_item',
			source = playerId
		})
		sendResult(playerId, 'giveItem', requestId, false, 'Sem permissão para conceder itens.')
		return
	end
	if not allowAction(playerId) then
		sendResult(playerId, 'giveItem', requestId, false, 'Aguarde antes de executar outra ação.')
		return
	end
	if type(targetId) ~= 'number' or targetId % 1 ~= 0 or not GetPlayerName(targetId) then
		sendResult(playerId, 'giveItem', requestId, false, 'ID de jogador inválido ou offline.')
		return
	end
	if type(itemName) ~= 'string' or not exports.coe_inventory:Items(itemName) then
		sendResult(playerId, 'giveItem', requestId, false, 'Item não encontrado no catálogo.')
		return
	end
	if type(count) ~= 'number' or count % 1 ~= 0 or count < 1 or count > 999 then
		sendResult(playerId, 'giveItem', requestId, false, 'Quantidade inválida (1–999).')
		return
	end
	if metadata ~= nil and type(metadata) ~= 'table' then
		sendResult(playerId, 'giveItem', requestId, false, 'Metadata inválida.')
		return
	end

	local inventoryId, inventoryError = getOrCreatePlayerInventory(targetId)
	if not inventoryId then
		sendResult(playerId, 'giveItem', requestId, false, inventoryError)
		return
	end

	local success, result = exports.coe_inventory:AddItem(inventoryId, itemName, count, metadata)
	if not success then
		log('error', 'audit', 'admin_item_grant_failed', {
			count = count,
			error_code = result or 'inventory_error',
			item = itemName,
			source = playerId,
			target = targetId
		})
		sendResult(playerId, 'giveItem', requestId, false, result or 'Não foi possível adicionar o item.')
		return
	end

	log('info', 'audit', 'admin_item_granted', {
		count = count,
		item = itemName,
		source = playerId,
		target = targetId
	})
	sendResult(playerId, 'giveItem', requestId, true, ('%dx %s enviado para [%d] %s.'):format(
		count,
		exports.coe_inventory:Items(itemName).label,
		targetId,
		GetPlayerName(targetId)
	))
	refreshPanel(playerId)
end)

RegisterNetEvent('coe_admin:setStaffRole', function(requestId, targetId, roleName)
	local playerId = source
	if type(requestId) ~= 'number' or requestId % 1 ~= 0 then
		return
	end
	if not allowAction(playerId) then
		sendResult(playerId, 'staffRole', requestId, false, 'Aguarde antes de executar outra ação.')
		return
	end
	if type(targetId) ~= 'number' or targetId % 1 ~= 0 or not GetPlayerName(targetId) then
		sendResult(playerId, 'staffRole', requestId, false, 'ID de jogador inválido ou offline.')
		return
	end
	local license = getLicense(targetId)
	if not license then
		sendResult(playerId, 'staffRole', requestId, false, 'O jogador não possui um identificador license.')
		return
	end
	if type(roleName) ~= 'string' or not Config.Roles[roleName] then
		sendResult(playerId, 'staffRole', requestId, false, 'Cargo inválido.')
		return
	end
	if not canAssignRole(playerId, roleName) then
		log('warn', 'security', 'staff_role_assignment_denied', {
			action = 'assign_staff_role',
			role = roleName,
			source = playerId,
			target = targetId
		})
		sendResult(playerId, 'staffRole', requestId, false, 'Sem permissão para atribuir esse cargo.')
		return
	end

	local members = getStaffMembers()
	local saved, saveError = AdminPersistence.SetRole(license, roleName)
	if not saved then
		log('error', 'audit', 'staff_role_assignment_failed', {
			error_code = saveError or 'database_error',
			role = roleName,
			source = playerId,
			target = targetId
		})
		sendResult(playerId, 'staffRole', requestId, false, saveError or 'Não foi possível salvar a equipe.')
		return
	end
	members[license] = { role = roleName }
	log('info', 'audit', 'staff_role_assigned', {
		role = roleName,
		source = playerId,
		target = targetId
	})

	sendResult(playerId, 'staffRole', requestId, true, 'Cargo atualizado.')
	refreshPanel(playerId)
end)

RegisterNetEvent('coe_admin:removeStaff', function(requestId, license)
	local playerId = source
	if type(requestId) ~= 'number' or requestId % 1 ~= 0 then
		return
	end
	if not allowAction(playerId) then
		sendResult(playerId, 'removeStaff', requestId, false, 'Aguarde antes de executar outra ação.')
		return
	end
	if type(license) ~= 'string' or not license:match('^license:[%w]+$') then
		sendResult(playerId, 'removeStaff', requestId, false, 'License inválida.')
		return
	end
	if not canManageMember(playerId, license) then
		log('warn', 'security', 'staff_role_removal_denied', {
			action = 'remove_staff_role',
			source = playerId
		})
		sendResult(playerId, 'removeStaff', requestId, false, 'Sem permissão para gerenciar a equipe.')
		return
	end

	local members = getStaffMembers()
	local previous = members[license]
	if not previous then
		sendResult(playerId, 'removeStaff', requestId, false, 'Membro não encontrado.')
		return
	end
	local removed, removeError = AdminPersistence.RemoveRole(license)
	if not removed then
		log('error', 'audit', 'staff_role_removal_failed', {
			error_code = removeError or 'database_error',
			source = playerId
		})
		sendResult(playerId, 'removeStaff', requestId, false, removeError or 'Não foi possível salvar a equipe.')
		return
	end
	members[license] = nil
	log('info', 'audit', 'staff_role_removed', {
		source = playerId
	})

	sendResult(playerId, 'removeStaff', requestId, true, 'Acesso removido.')
	refreshPanel(playerId)
end)

local businessErrors = {
	invalid_business = 'Dados do negócio inválidos.', invalid_id = 'ID inválido: use letras minúsculas, números e _ (2 a 32).',
	invalid_category = 'Categoria inválida.', invalid_label = 'Nome inválido (1 a 48 caracteres, sem < >).',
	invalid_area = 'Área inválida: confira raio/pontos e coordenadas.', invalid_station = 'Baú, mesa ou showroom inválido.',
	duplicate_station = 'Há dois pontos com o mesmo ID na mesma lista.', invalid_rule = 'Alguma regra tem valor inválido.',
	category_locked = 'A categoria de um negócio existente não pode mudar.', limit_reached = 'Limite de negócios atingido.',
	unknown_business = 'Negócio inexistente.', not_ready = 'O registro de negócios ainda está iniciando.',
	database_error = 'Falha ao gravar no banco.', invalid_owner = 'Dono inválido.', invalid_staff = 'Equipe inválida (limite ou personagem repetido).',
	owner_not_found = 'Nenhum personagem encontrado com esse ID.',
	invalid_grades = 'Cargos inválidos: confira ID, nome, nível, salário e permissões (sem repetir ID ou nível).',
	invalid_staff_grade = 'Algum funcionário está com um cargo que não existe neste negócio.',
	multiple_jobs = 'Dedicação exclusiva: alguém da equipe já trabalha em outro negócio.',
	invalid_state_id = 'ID inválido: são 8 caracteres (use o comando /id no jogo).'
}


local function exportError(ok, result)
	if not ok or not result then
		return "not_ready"
	end
	if type(result) == "table" and result.error then
		return result.error
	end
	return nil
end

local function businessGate(playerId, action, requestId)
	if type(requestId) ~= "number" or requestId % 1 ~= 0 then
		return false
	end
	if not allowAction(playerId) then
		sendResult(playerId, action, requestId, false, "Aguarde antes de executar outra ação.")
		return false
	end
	if not getPermissions(playerId).manageBusinesses then
		log("warn", "security", "business_change_denied", { action = action, source = playerId })
		sendResult(playerId, action, requestId, false, "Sem permissão para gerenciar negócios.")
		return false
	end
	if GetResourceState("coe_businesses") ~= "started" then
		sendResult(playerId, action, requestId, false, "O resource coe_businesses não está iniciado.")
		return false
	end
	return true
end

local staffDeps = {
	isValidStateId = function(stateId)
		return Core.Identity.IsValidStateId(stateId)
	end,
	find = function(stateId)
		return AdminPersistence.FindCharacterByStateId(stateId)
	end
}

Admin = {
	log = log,
	allowAction = allowAction,
	sendResult = sendResult,
	refreshPanel = refreshPanel,
	getPermissions = getPermissions,
	getLicense = getLicense,
	getStaffMembers = getStaffMembers,
	businessGate = businessGate,
	garageBackend = garageBackend,
	garagesList = garagesList,
	garageSaveRaw = garageSaveRaw,
	garageDeleteRaw = garageDeleteRaw,
	activeCharacter = activeCharacter,
	characterDirectory = characterDirectory,
	exportError = exportError,
	staffDeps = staffDeps
}

-- Submodules loaded in offline test harness when not managed by FXServer manifest
local function _loadSub(relPath)
	local f = io.open(relPath, "r")
	if f then f:close() return dofile(relPath) end
	local f2 = io.open("coe_admin/" .. relPath, "r")
	if f2 then f2:close() return dofile("coe_admin/" .. relPath) end
end

if not IsDuplicityVersion or not IsDuplicityVersion() then
	_loadSub("server/businesses.lua")
	_loadSub("server/economy_crypto.lua")
	_loadSub("server/news.lua")
	_loadSub("server/world.lua")
	_loadSub("server/factions.lua")
end

AddEventHandler('playerDropped', function()
	lastActions[source] = nil
end)

CreateThread(function()
	local waitingLogged = false
	while true do
		local initialized, errorCode = AdminPersistence.Initialize()
		if initialized then
			staffMembers = nil
			return
		end
		-- Banco ainda subindo é esperado na inicialização: não é erro.
		if errorCode == 'database_not_ready' then
			if not waitingLogged then
				log('info', 'persistence', 'database_waiting', {})
				waitingLogged = true
			end
			Wait(1000)
		else
			log('error', 'persistence', 'database_initialization_failed', {
				error_code = errorCode or 'database_error',
				retry_ms = 5000
			})
			Wait(5000)
		end
	end
end)
