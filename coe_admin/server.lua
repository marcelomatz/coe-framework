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

local function businessGate(playerId, action, requestId)
	if type(requestId) ~= 'number' or requestId % 1 ~= 0 then
		return false
	end
	if not allowAction(playerId) then
		sendResult(playerId, action, requestId, false, 'Aguarde antes de executar outra ação.')
		return false
	end
	if not getPermissions(playerId).manageBusinesses then
		log('warn', 'security', 'business_change_denied', { action = action, source = playerId })
		sendResult(playerId, action, requestId, false, 'Sem permissão para gerenciar negócios.')
		return false
	end
	if GetResourceState('coe_businesses') ~= 'started' then
		sendResult(playerId, action, requestId, false, 'O resource coe_businesses não está iniciado.')
		return false
	end
	return true
end

-- Busca de personagens por nome ou ID (donos e equipe). Só quem gerencia negócios, grupos ou equipe; com intervalo mínimo por admin.
local lastSearch = {}
local lastProfile = {}
RegisterNetEvent('coe_admin:searchCharacters', function(requestId, term)
	local playerId = source
	local permissions = getPermissions(playerId)
	if not (permissions.manageBusinesses or permissions.manageGroups or permissions.manageStaff or permissions.manageBanking or permissions.manageNews) then
		return
	end
	local now = GetGameTimer()
	if lastSearch[playerId] and now - lastSearch[playerId] < 250 then
		return
	end
	lastSearch[playerId] = now
	if type(term) ~= 'string' or #term > 64 then
		TriggerClientEvent('coe_admin:characterResults', playerId, requestId, {}, 'term_too_short')
		return
	end
	local results, searchError = characterDirectory.Search(term)
	TriggerClientEvent('coe_admin:characterResults', playerId, requestId, results or {}, searchError)
end)

AddEventHandler('playerDropped', function()
	lastSearch[source] = nil
	lastProfile[source] = nil
end)

-- Perfil completo (somente leitura) de um personagem, online ou não. Cada abertura é auditada.
RegisterNetEvent('coe_admin:getProfile', function(requestId, characterId)
	local playerId = source
	if type(requestId) ~= 'number' or requestId % 1 ~= 0 then
		return
	end
	if not getPermissions(playerId).viewPlayers then
		log('warn', 'security', 'admin_profile_denied', { source = playerId })
		TriggerClientEvent('coe_admin:profileResult', playerId, requestId, nil, 'forbidden')
		return
	end
	local now = GetGameTimer()
	if lastProfile[playerId] and now - lastProfile[playerId] < 500 then
		TriggerClientEvent('coe_admin:profileResult', playerId, requestId, nil, 'rate_limited')
		return
	end
	lastProfile[playerId] = now
	if type(characterId) ~= 'string' or not characterId:match('^%d+$') or #characterId > 20 then
		TriggerClientEvent('coe_admin:profileResult', playerId, requestId, nil, 'invalid_character')
		return
	end
	local profile, profileError = AdminProfile.Load({
		query = AdminPersistence.Query,
		inventory = function(id)
			if GetResourceState('coe_inventory') ~= 'started' then
				return nil
			end
			return exports.coe_inventory:GetInventory('character:' .. id)
		end,
		itemLabel = function(name)
			local item = exports.coe_inventory:Items(name)
			return item and item.label or name
		end,
		factions = function(id)
			if GetResourceState('coe_factions') ~= 'started' then
				return nil
			end
			return exports.coe_factions:Memberships(id)
		end,
		businesses = function()
			return GetResourceState('coe_businesses') == 'started' and exports.coe_businesses:List() or {}
		end,
		properties = function()
			return GetResourceState('coe_housing') == 'started' and exports.coe_housing:ListProperties() or {}
		end,
		garages = function()
			return garagesList()
		end,
		online = function(id)
			for _, player in ipairs(GetPlayers()) do
				local character = activeCharacter(tonumber(player))
				if character and character.characterId == id then
					return { serverId = tonumber(player), ping = GetPlayerPing(player) }
				end
			end
		end
	}, characterId)
	if profile then
		log('info', 'audit', 'admin_profile_viewed', { admin = playerId, characterId = characterId })
	end
	TriggerClientEvent('coe_admin:profileResult', playerId, requestId, profile, profileError)
end)

local staffDeps = {
	isValidStateId = function(stateId)
		return Core.Identity.IsValidStateId(stateId)
	end,
	find = function(stateId)
		return AdminPersistence.FindCharacterByStateId(stateId)
	end
}

RegisterNetEvent('coe_admin:saveBusiness', function(requestId, raw)
	local playerId = source
	if not businessGate(playerId, 'businessSave', requestId) then
		return
	end
	if type(raw) ~= 'table' then
		sendResult(playerId, 'businessSave', requestId, false, businessErrors.invalid_business)
		return
	end
	local existing = type(raw.id) == 'string' and exports.coe_businesses:Get(raw.id) or nil
	local ownerStateId = raw.ownerStateId
	local clearOwner = raw.clearOwner == true
	raw.ownerStateId, raw.ownerPlayerId, raw.clearOwner = nil, nil, nil
	raw.owner = existing and existing.owner or nil
	-- Sócios entram só pelo convite do dono no tablet; o painel os preserva.
	raw.partners = existing and existing.partners or nil
	if clearOwner then
		raw.owner = nil
	elseif ownerStateId ~= nil then
		if type(ownerStateId) ~= 'string' or not Core.Identity.IsValidStateId(ownerStateId:upper()) then
			sendResult(playerId, 'businessSave', requestId, false, businessErrors.invalid_state_id)
			return
		end
		local found, findError = AdminPersistence.FindCharacterByStateId(ownerStateId:upper())
		if not found then
			sendResult(playerId, 'businessSave', requestId, false,
				findError == 'character_not_found' and businessErrors.owner_not_found or businessErrors.database_error)
			return
		end
		raw.owner = found
	end
	local ownerChanged = (existing and existing.owner and existing.owner.characterId) ~= (raw.owner and raw.owner.characterId)
	-- Sócios aceitaram o convite de um dono específico; com novo dono (ou sem dono), a sociedade se desfaz.
	if ownerChanged then
		raw.partners = nil
	end
	local dismissAll = ownerChanged and raw.staffOnOwnerChange == 'dismiss'
	raw.staffOnOwnerChange = nil
	-- Equipe: só se removem membros existentes; novos entram por ID de personagem validado
	local staffAdd, staffAddGrades = raw.staffAddStateIds, raw.staffAddGrades
	raw.staffAddStateIds, raw.staffAddStateId, raw.staffAddGrades = nil, nil, nil
	local kept, staffError = AdminStaff.Merge(existing and existing.staff or {}, raw.staff, dismissAll, staffAdd, staffAddGrades, staffDeps)
	if not kept then
		sendResult(playerId, 'businessSave', requestId, false, businessErrors[staffError])
		return
	end
	raw.staff = kept
	local ok, saved = pcall(function()
		return exports.coe_businesses:Save(raw, 'admin:' .. playerId)
	end)
	local saveError = not ok and 'not_ready' or (type(saved) ~= 'table' and 'not_ready') or saved.error
	if saveError then
		sendResult(playerId, 'businessSave', requestId, false,
			businessErrors[saveError] or 'Não foi possível salvar o negócio.')
		return
	end
	sendResult(playerId, 'businessSave', requestId, true, 'Negócio salvo.')
	refreshPanel(playerId)
end)

RegisterNetEvent('coe_admin:deleteBusiness', function(requestId, id)
	local playerId = source
	if not businessGate(playerId, 'businessDelete', requestId) then
		return
	end
	if type(id) ~= 'string' or #id > 32 then
		sendResult(playerId, 'businessDelete', requestId, false, businessErrors.invalid_id)
		return
	end
	local ok, deleted = pcall(function()
		return exports.coe_businesses:Delete(id, 'admin:' .. playerId)
	end)
	local deleteError = not ok and 'not_ready' or (deleted ~= true and (type(deleted) == 'table' and deleted.error or 'not_ready')) or nil
	if deleteError then
		sendResult(playerId, 'businessDelete', requestId, false,
			businessErrors[deleteError] or 'Não foi possível remover o negócio.')
		return
	end
	sendResult(playerId, 'businessDelete', requestId, true, 'Negócio removido.')
	refreshPanel(playerId)
end)

local craftErrors = {
	not_ready = 'O serviço de produção ainda está iniciando.', forbidden = 'Ação não permitida.',
	database_error = 'Falha ao gravar no banco.', id_conflict = 'Esse ID já pertence a outro sistema.',
	reserved_recipe = 'Receitas padrão do servidor não podem ser editadas aqui.',
	invalid_recipe_id = 'ID inválido: use letras, números e _ (2 a 48).',
	invalid_recipe_label = 'Nome inválido (1 a 48 caracteres, sem < >).',
	invalid_recipe_category = 'Escolha a bancada da receita.', invalid_recipe_time = 'Tempo inválido (0,5 a 120 segundos).',
	invalid_recipe_inputs = 'Ingredientes inválidos: de 1 a 8, com quantidade de 1 a 1000.',
	invalid_recipe_outputs = 'Resultado inválido: de 1 a 4 itens, com quantidade de 1 a 1000.',
	unknown_item = 'Um dos itens não existe no inventário.', recipe_limit = 'Limite de receitas atingido.',
	unknown_recipe = 'Receita inexistente ou padrão do servidor.',
	invalid_menu_id = 'ID inválido: use letras, números e _ (2 a 32).',
	invalid_menu_label = 'Nome inválido (1 a 48 caracteres, sem < >).',
	invalid_menu_category = 'Essa categoria de negócio não tem bancada.',
	invalid_menu_recipes = 'Receitas inválidas: escolha só receitas desta bancada (até 60).',
	unknown_menu = 'Tipo de cardápio inexistente para esta categoria.', menu_limit = 'Limite de tipos de cardápio atingido.',
	invalid_bench_id = 'ID inválido: use letras, números e _ (2 a 32).',
	invalid_bench_label = 'Nome inválido (1 a 48 caracteres, sem < >).',
	invalid_bench_coords = 'Posição ou raio da bancada inválido: marque o ponto no mundo (raio de 0,5 a 10 m).',
	invalid_bench_recipes = 'Receitas inválidas: escolha apenas receitas da bancada clandestina.',
	bench_limit = 'Limite de bancadas ilegais atingido.', unknown_bench = 'Bancada ilegal inexistente.',
	unknown_business = 'Negócio inexistente ou sem bancada.', invalid_assignment = 'Cardápio inválido.'
}

local craftOps = {
	saveRecipe = { export = 'AdminSaveRecipe', done = 'Receita salva.' },
	deleteRecipe = { export = 'AdminDeleteRecipe', done = 'Receita removida.' },
	saveMenu = { export = 'AdminSaveMenu', done = 'Tipo de cardápio salvo.' },
	deleteMenu = { export = 'AdminDeleteMenu', done = 'Tipo de cardápio removido.' },
	saveBench = { export = 'AdminSaveBench', done = 'Bancada ilegal salva.' },
	deleteBench = { export = 'AdminDeleteBench', done = 'Bancada ilegal removida.' },
	setBusinessMenu = { export = 'AdminSetBusinessMenu', done = 'Cardápio do negócio salvo.' }
}

RegisterNetEvent('coe_admin:craftCatalog', function(requestId, op, payload)
	local playerId = source
	if not businessGate(playerId, 'craftCatalog', requestId) then
		return
	end
	local spec = type(op) == 'string' and craftOps[op] or nil
	if not spec or GetResourceState('coe_crafting') ~= 'started' then
		sendResult(playerId, 'craftCatalog', requestId, false, 'O resource coe_crafting não está iniciado.')
		return
	end
	local ok, result = pcall(function()
		local exportsTable = exports.coe_crafting
		if op == 'setBusinessMenu' then
			local data = type(payload) == 'table' and payload or {}
			return exportsTable[spec.export](exportsTable, data.businessId, { menu = data.menu, recipes = data.recipes })
		end
		return exportsTable[spec.export](exportsTable, payload)
	end)
	local errorCode = not ok and 'not_ready' or (type(result) ~= 'table' and 'not_ready') or result.error
	if errorCode then
		sendResult(playerId, 'craftCatalog', requestId, false, craftErrors[errorCode] or 'Não foi possível salvar.')
		return
	end
	sendResult(playerId, 'craftCatalog', requestId, true, spec.done)
	refreshPanel(playerId)
end)

local amzgErrors = {
	not_ready = 'A loja Amzg ainda está iniciando.', forbidden = 'Ação não permitida.',
	database_error = 'Falha ao gravar no banco.', unknown_item = 'Esse item não existe no inventário.',
	unknown_product = 'Produto inexistente.', product_limit = 'Limite de produtos do catálogo atingido.',
	invalid_item = 'Informe o item do inventário.', invalid_label = 'Nome inválido (até 48 caracteres).',
	invalid_category = 'Escolha uma categoria.', invalid_price = 'Preço inválido.',
	invalid_sort = 'Ordem inválida (0 a 9999).', invalid_product = 'Produto inválido.',
	invalid_promo_price = 'Preço promocional inválido: precisa ser menor que o preço normal (0 = sem promoção).',
	invalid_promo_until = 'O fim da promoção precisa ser uma data no futuro (ou vazio = sem prazo).',
	invalid_banner_text = 'Selo do banner muito longo.'
}

local amzgOps = {
	save = { export = 'AdminSaveProduct', done = 'Produto salvo.' },
	delete = { export = 'AdminDeleteProduct', done = 'Produto removido.' }
}

RegisterNetEvent('coe_admin:amzgCatalog', function(requestId, op, payload)
	local playerId = source
	if not businessGate(playerId, 'amzgCatalog', requestId) then
		return
	end
	local spec = type(op) == 'string' and amzgOps[op] or nil
	if not spec or GetResourceState('coe_amzg') ~= 'started' then
		sendResult(playerId, 'amzgCatalog', requestId, false, 'O resource coe_amzg não está iniciado.')
		return
	end
	local ok, result = pcall(function()
		local exportsTable = exports.coe_amzg
		return exportsTable[spec.export](exportsTable, type(payload) == 'table' and payload or {})
	end)
	local errorCode = not ok and 'not_ready' or (type(result) ~= 'table' and 'not_ready') or result.error
	if errorCode then
		sendResult(playerId, 'amzgCatalog', requestId, false, amzgErrors[errorCode] or 'Não foi possível salvar.')
		return
	end
	sendResult(playerId, 'amzgCatalog', requestId, true, spec.done)
	refreshPanel(playerId)
end)

-- DeepWeb (coe_deepweb): permissão própria (manageDeepweb). Os exports Admin* validam tudo de novo.
local deepwebErrors = {
	not_ready = 'A DeepWeb ainda está iniciando.', forbidden = 'Ação não permitida.', database_error = 'Falha ao gravar no banco.',
	invalid_domain = 'Endereço inválido: 3 a 24 letras minúsculas, números ou hífen (.onion).', domain_reserved = 'Esse endereço é reservado.',
	domain_taken = 'Esse endereço já pertence a outra pessoa.', invalid_title = 'Título inválido.', invalid_description = 'Descrição ou palavras-chave longas demais.',
	invalid_blocks = 'Blocos demais.', invalid_block = 'Algum bloco está vazio ou inválido.', not_found = 'Não encontrado.',
	invalid_listing = 'Anúncio inválido.', invalid_category = 'Escolha uma categoria.', invalid_price = 'Preço inválido.',
	invalid_stock = 'Estoque inválido.', invalid_item = 'Informe o item do inventário.', invalid_count = 'Quantidade por unidade inválida.',
	unknown_item = 'Esse item não existe no inventário.', invalid_vendor = 'Informe o nome do fornecedor (até 32 caracteres).',
	invalid_order = 'Pedido inválido.', invalid_status = 'O pedido já mudou de estado.',
	invalid_reply = 'Escreva a resposta (até 1000 caracteres).', contact_closed = 'Essa mensagem já foi arquivada.'
}

local deepwebOps = {
	saveSite = { export = 'AdminSaveSite', done = 'Site salvo.' },
	deleteSite = { export = 'AdminDeleteSite', done = 'Site apagado.' },
	saveVendor = { export = 'AdminSaveVendor', done = 'Fornecedor salvo.' },
	deleteVendor = { export = 'AdminDeleteVendor', done = 'Anúncio removido.' },
	resolveOrder = { export = 'AdminResolveOrder', done = 'Pedido decidido.' },
	removePost = { export = 'AdminRemovePost', done = 'Post removido.' },
	replyContact = { export = 'AdminReplyContact', done = 'Resposta enviada.' },
	closeContact = { export = 'AdminCloseContact', done = 'Mensagem arquivada.' }
}

RegisterNetEvent('coe_admin:deepweb', function(requestId, op, payload)
	local playerId = source
	if type(requestId) ~= 'number' or requestId % 1 ~= 0 then
		return
	end
	if not allowAction(playerId) then
		sendResult(playerId, 'deepweb', requestId, false, 'Aguarde antes de executar outra ação.')
		return
	end
	if not getPermissions(playerId).manageDeepweb then
		log('warn', 'security', 'deepweb_change_denied', { action = tostring(op), source = playerId })
		sendResult(playerId, 'deepweb', requestId, false, 'Sem permissão para gerenciar a DeepWeb.')
		return
	end
	local spec = type(op) == 'string' and deepwebOps[op] or nil
	if not spec or GetResourceState('coe_deepweb') ~= 'started' then
		sendResult(playerId, 'deepweb', requestId, false, 'O resource coe_deepweb não está iniciado.')
		return
	end
	local ok, result = pcall(function()
		local exportsTable = exports.coe_deepweb
		return exportsTable[spec.export](exportsTable, type(payload) == 'table' and payload or {})
	end)
	local errorCode = not ok and 'not_ready' or (type(result) ~= 'table' and 'not_ready') or result.error
	if errorCode then
		local message = deepwebErrors[errorCode] or 'Não foi possível salvar.'
		if errorCode == 'invalid_block' and result.index then
			message = ('Bloco %d vazio ou inválido.'):format(result.index)
		end
		sendResult(playerId, 'deepweb', requestId, false, message)
		return
	end
	sendResult(playerId, 'deepweb', requestId, true, spec.done)
	refreshPanel(playerId)
end)

local garageErrors = {
	no_fleet_garage = 'Só garagens de negócio ou corporação têm frota.', unknown_model = 'Modelo fora do catálogo.',
	fleet_full = 'A frota da garagem está cheia.', not_in_fleet = 'Veículo não pertence à frota.',
	not_stored = 'O veículo precisa estar guardado para sair da frota.', not_ready = 'O serviço de garagens ainda está iniciando.',
	forbidden = 'Ação não permitida.', database_error = 'Falha ao gravar no banco.',
	invalid_garage = 'Dados da garagem inválidos.', invalid_id = 'ID inválido: use letras minúsculas, números e _ (2 a 32).',
	invalid_kind = 'Tipo de garagem inválido.', invalid_label = 'Nome inválido (1 a 48 caracteres, sem < >).',
	invalid_spots = 'Vagas inválidas: de 1 a 8, com ID único e coordenadas válidas.',
	invalid_business = 'Escolha o negócio da garagem.', invalid_jobs = 'Informe de 1 a 5 empregos (letras minúsculas, números e _).',
	invalid_blip = 'Blip inválido.', garage_limit = 'Limite de garagens atingido.', unknown_business = 'Negócio inexistente.',
	kind_has_fleet = 'Remova a frota antes de mudar o tipo da garagem.', has_fleet = 'Remova a frota antes de apagar a garagem.',
	unknown_garage = 'Garagem inexistente.'
}

local function exportError(ok, result)
	if not ok or not result then
		return 'not_ready'
	end
	if type(result) == 'table' and result.error then
		return result.error
	end
	return nil
end

-- Imprensa (coe_news) ---------------------------------------------------------------------------------------
-- Permissão própria (manageNews). Conteúdo, anúncios, linha editorial e estoque passam pelos exports Admin* do
-- coe_news; equipe/cargos e frota são gravados aqui, restritos aos negócios da categoria `media`.

local newsErrors = {
	not_ready = 'O coe_news ainda está iniciando.', forbidden = 'Ação não permitida.', database_error = 'Falha ao gravar no banco.',
	busy = 'Outra ação está em andamento. Tente de novo.', conflict = 'O item mudou enquanto você agia. Atualize a lista.',
	not_found = 'Item não encontrado.', invalid_action = 'Ação inválida.', invalid_query = 'Consulta inválida.',
	invalid_sections = 'Escolha ao menos uma editoria.', invalid_price = 'Preço por dia fora da faixa permitida.',
	invalid_editorial = 'Linha editorial inválida.', ad_decided = 'O anúncio já foi decidido.', ad_not_active = 'O anúncio não está no ar.',
	ad_slots_full = 'O veículo já tem o máximo de anúncios no ar.', payment_failed = 'Não foi possível mover o dinheiro.',
	refund_failed = 'Não foi possível devolver o valor; nada foi alterado.',
	outlet_insufficient_funds = 'O caixa do veículo não tem saldo para o estorno.',
	invalid_status = 'A matéria não está no status esperado.', unknown_equipment = 'Equipamento desconhecido.',
	invalid_count = 'Quantidade inválida.', invalid_stock = 'Operação de estoque inválida.',
	no_stash = 'O negócio não tem baú cadastrado (aba Negócios > Pontos).', stash_unavailable = 'O baú do veículo não está disponível.',
	stash_full = 'O baú não tem espaço para essa quantidade.', insufficient_items = 'O baú não tem essa quantidade.',
	not_media = 'Esse negócio não é um veículo de imprensa.', unknown_garage = 'Garagem de frota inexistente.',
	invalid_state_id = 'ID inválido: são 8 caracteres (use o comando /id no jogo).',
	owner_not_found = 'Personagem não encontrado.', team_failed = 'Não foi possível salvar a equipe. Confira cargos (IDs únicos, nível 0 a 99) e se alguém ficou num cargo removido.',
	unknown_model = 'Modelo fora do catálogo.', fleet_full = 'A frota da garagem está cheia.', not_in_fleet = 'Veículo não pertence à frota.',
	not_stored = 'O veículo precisa estar guardado para sair da frota.'
}

local newsDone = {
	editorial = 'Linha editorial salva.', adApprove = 'Anúncio aprovado.', adReject = 'Anúncio recusado e valor devolvido.',
	adTakedown = 'Anúncio retirado do ar.', articleUnpublish = 'Matéria tirada do ar.', articleRepublish = 'Matéria publicada de novo.',
	articleDelete = 'Matéria apagada.', stock = 'Estoque atualizado.', team = 'Equipe e cargos salvos.',
	fleetAdd = 'Veículo adicionado à frota.', fleetRemove = 'Veículo removido da frota.'
}

-- Ações que mudam o snapshot do painel (o resto é recarregado pela própria aba).
local newsRefresh = { editorial = true, team = true, fleetAdd = true, fleetRemove = true, adApprove = true, adTakedown = true }

-- Consultas têm intervalo próprio (a aba recarrega a lista logo depois de cada ação); ações usam o geral.
local lastNewsQuery = {}

AddEventHandler('playerDropped', function()
	lastNewsQuery[source] = nil
end)

local function newsGate(playerId, requestId, isQuery)
	if type(requestId) ~= 'number' or requestId % 1 ~= 0 then
		return false
	end
	if not getPermissions(playerId).manageNews then
		log('warn', 'security', 'news_admin_denied', { source = playerId })
		return false, 'forbidden'
	end
	if isQuery then
		local now = GetGameTimer()
		if lastNewsQuery[playerId] and now - lastNewsQuery[playerId] < 100 then
			return false, 'busy'
		end
		lastNewsQuery[playerId] = now
	elseif not allowAction(playerId) then
		return false, 'busy'
	end
	if GetResourceState('coe_news') ~= 'started' then
		return false, 'not_ready'
	end
	return true
end

-- Negócio de imprensa (categoria media) ou nil.
local function mediaBusiness(id)
	if type(id) ~= 'string' or #id > 32 or GetResourceState('coe_businesses') ~= 'started' then
		return nil
	end
	local ok, record = pcall(function()
		return exports.coe_businesses:Get(id)
	end)
	return ok and type(record) == 'table' and record.category == 'media' and record or nil
end

local function saveNewsTeam(playerId, payload)
	local business = mediaBusiness(payload.business)
	if not business then
		return 'not_media'
	end
	if type(payload.grades) == 'table' then
		local grades = {}
		for index, grade in ipairs(payload.grades) do
			if index > 20 or type(grade) ~= 'table' then
				return 'team_failed'
			end
			grades[index] = {
				id = type(grade.id) == 'string' and grade.id:sub(1, 24) or '', label = type(grade.label) == 'string' and grade.label:sub(1, 32) or '',
				level = tonumber(grade.level), salary = tonumber(grade.salary),
				permissions = type(grade.permissions) == 'table' and grade.permissions or {}
			}
		end
		business.grades = grades
	end
	local kept, staffError = AdminStaff.Merge(business.staff or {}, payload.staff, false, payload.staffAddStateIds, payload.staffAddGrades, staffDeps)
	if not kept then
		return staffError
	end
	business.staff = kept
	local ok, saved = pcall(function()
		return exports.coe_businesses:Save(business, 'admin:' .. playerId)
	end)
	if exportError(ok, saved) then
		return 'team_failed'
	end
	log('info', 'audit', 'news_team_saved', { source = playerId, target = business.id, count = #kept })
	return nil
end

local function newsFleet(op, payload)
	if GetResourceState('coe_garages') ~= 'started' or type(payload.garage) ~= 'string' or #payload.garage > 32 then
		return 'unknown_garage'
	end
	local garage
	pcall(function()
		for _, entry in ipairs(exports.coe_garages:ListGarages() or {}) do
			if entry.id == payload.garage then
				garage = entry
			end
		end
	end)
	if not garage or garage.kind ~= 'business' or not mediaBusiness(garage.business) then
		return 'unknown_garage'
	end
	local ok, result = pcall(function()
		if op == 'fleetAdd' then
			return exports.coe_garages:AddFleetVehicle(garage.id, type(payload.model) == 'string' and payload.model:lower() or nil)
		end
		return exports.coe_garages:RemoveFleetVehicle(garage.id, tostring(payload.vehicleId))
	end)
	return exportError(ok, result)
end

local NEWS_LOCAL = { team = saveNewsTeam, fleetAdd = function(_, payload) return newsFleet('fleetAdd', payload) end,
	fleetRemove = function(_, payload) return newsFleet('fleetRemove', payload) end }

RegisterNetEvent('coe_admin:newsQuery', function(requestId, kind, payload)
	local playerId = source
	local allowed, gateError = newsGate(playerId, requestId, true)
	if not allowed then
		if gateError then
			TriggerClientEvent('coe_admin:newsData', playerId, requestId, kind, nil, gateError)
		end
		return
	end
	local ok, result = pcall(function()
		return exports.coe_news:AdminQuery(kind, type(payload) == 'table' and payload or {})
	end)
	local failure = exportError(ok, result)
	TriggerClientEvent('coe_admin:newsData', playerId, requestId, kind, not failure and result or nil, failure)
end)

RegisterNetEvent('coe_admin:newsAction', function(requestId, op, payload)
	local playerId = source
	local allowed, gateError = newsGate(playerId, requestId)
	if not allowed then
		if gateError then
			sendResult(playerId, 'news', requestId, false, newsErrors[gateError])
		end
		return
	end
	if type(op) ~= 'string' or not newsDone[op] or type(payload) ~= 'table' then
		sendResult(playerId, 'news', requestId, false, newsErrors.invalid_action)
		return
	end
	local failure
	if NEWS_LOCAL[op] then
		failure = NEWS_LOCAL[op](playerId, payload)
	else
		payload.admin = playerId
		local ok, result = pcall(function()
			return exports.coe_news:AdminAction(op, payload)
		end)
		failure = exportError(ok, result)
	end
	if failure then
		sendResult(playerId, 'news', requestId, false, newsErrors[failure] or 'Não foi possível concluir a ação.')
		return
	end
	sendResult(playerId, 'news', requestId, true, newsDone[op])
	if newsRefresh[op] then
		refreshPanel(playerId)
	end
end)


local function fleetGate(playerId, action, requestId, garageId)
	if not businessGate(playerId, action, requestId) then
		return false
	end
	if not garageBackend() then
		sendResult(playerId, action, requestId, false, 'Nenhum resource de garagens (coe_garages ou coe_garage) está iniciado.')
		return false
	end
	if type(garageId) ~= 'string' or #garageId > 32 then
		sendResult(playerId, action, requestId, false, garageErrors.invalid_id)
		return false
	end
	return true
end

RegisterNetEvent('coe_admin:saveGarage', function(requestId, raw)
	local playerId = source
	if not fleetGate(playerId, 'garageSave', requestId, type(raw) == 'table' and raw.id or nil) then
		return
	end
	local ok, saved = pcall(function()
		return garageSaveRaw(raw)
	end)
	local failure = exportError(ok, saved)
	if failure then
		sendResult(playerId, 'garageSave', requestId, false, garageErrors[failure] or 'Não foi possível salvar a garagem.')
		return
	end
	sendResult(playerId, 'garageSave', requestId, true, 'Garagem salva.')
	refreshPanel(playerId)
end)

local rentalErrors = {
	not_ready = 'O aluguel ainda está iniciando.', forbidden = 'Ação não permitida.', database_error = 'Falha ao gravar no banco.',
	invalid_station = 'Dados da estação inválidos.', invalid_id = 'ID inválido: use letras minúsculas, números e _ (2 a 32).',
	invalid_label = 'Nome inválido (1 a 48 caracteres, sem < >).', invalid_ped = 'Marque a posição do atendente (modelo: letras, números e _).',
	invalid_spawns = 'Marque de 1 a 8 pontos de retirada.', invalid_return = 'Marque a zona de devolução (raio de 1 a 30 m).',
	invalid_vehicles = 'Modelos inválidos ou fora do catálogo do aluguel.', invalid_blip = 'Blip inválido.',
	unknown_station = 'Estação inexistente.'
}

local function rentalGate(playerId, action, requestId)
	if not businessGate(playerId, action, requestId) then
		return false
	end
	if GetResourceState('coe_rentals') ~= 'started' then
		sendResult(playerId, action, requestId, false, 'O resource coe_rentals não está iniciado.')
		return false
	end
	return true
end

RegisterNetEvent('coe_admin:saveRental', function(requestId, raw)
	local playerId = source
	if not rentalGate(playerId, 'rentalSave', requestId) then
		return
	end
	local ok, saved = pcall(function()
		return exports.coe_rentals:SaveStation(raw)
	end)
	local failure = exportError(ok, saved)
	if failure then
		sendResult(playerId, 'rentalSave', requestId, false, rentalErrors[failure] or 'Não foi possível salvar a estação.')
		return
	end
	sendResult(playerId, 'rentalSave', requestId, true, 'Estação salva.')
	refreshPanel(playerId)
end)

RegisterNetEvent('coe_admin:deleteRental', function(requestId, stationId)
	local playerId = source
	if not rentalGate(playerId, 'rentalDelete', requestId) or type(stationId) ~= 'string' or #stationId > 32 then
		return
	end
	local ok, deleted = pcall(function()
		return exports.coe_rentals:DeleteStation(stationId)
	end)
	local failure = exportError(ok, deleted)
	if failure then
		sendResult(playerId, 'rentalDelete', requestId, false, rentalErrors[failure] or 'Não foi possível remover a estação.')
		return
	end
	sendResult(playerId, 'rentalDelete', requestId, true, 'Estação removida.')
	refreshPanel(playerId)
end)

RegisterNetEvent('coe_admin:deleteGarage', function(requestId, garageId)
	local playerId = source
	if not fleetGate(playerId, 'garageDelete', requestId, garageId) then
		return
	end
	local ok, deleted = pcall(function()
		return garageDeleteRaw(garageId)
	end)
	local failure = exportError(ok, deleted)
	if failure then
		sendResult(playerId, 'garageDelete', requestId, false, garageErrors[failure] or 'Não foi possível remover a garagem.')
		return
	end
	sendResult(playerId, 'garageDelete', requestId, true, 'Garagem removida.')
	refreshPanel(playerId)
end)

local doorErrors = {
	not_ready = 'O serviço de portas ainda está iniciando.', forbidden = 'Ação não permitida.', database_error = 'Falha ao gravar no banco.',
	invalid_door = 'Dados do local inválidos.', invalid_id = 'ID inválido: use letras minúsculas, números e _ (2 a 32).',
	invalid_label = 'Nome inválido (1 a 48 caracteres, sem < >).',
	invalid_doors = 'Cada porta precisa das folhas marcadas: simples 1, dupla 2, garagem/portão 1 ou 2 (folhas próximas).',
	invalid_entry = 'Porta inválida: confira o tipo.', duplicate_entry = 'Há portas repetidas no local.',
	entry_limit = 'Limite de portas por local atingido (12).',
	invalid_distance = 'Distância de interação inválida (até 6 m; garagem/portão até 12 m).', invalid_autolock = 'Tempo de trancamento automático inválido.',
	invalid_access = 'Regras de acesso inválidas (duplicadas ou acima do limite).', invalid_pin = 'A senha deve ter de 4 a 8 dígitos.',
	invalid_owner = 'Dono inválido.',
	duplicate_id = 'Já existe um local com esse ID.', door_limit = 'Limite de locais atingido.', unknown_door = 'Local inexistente.'
}

local function doorGate(playerId, action, requestId, doorId)
	if not businessGate(playerId, action, requestId) then
		return false
	end
	if GetResourceState('coe_doors') ~= 'started' then
		sendResult(playerId, action, requestId, false, 'O resource coe_doors não está iniciado.')
		return false
	end
	if type(doorId) ~= 'string' or #doorId > 32 then
		sendResult(playerId, action, requestId, false, doorErrors.invalid_id)
		return false
	end
	return true
end

RegisterNetEvent('coe_admin:saveDoor', function(requestId, raw)
	local playerId = source
	if not doorGate(playerId, 'doorSave', requestId, type(raw) == 'table' and raw.id or nil) then
		return
	end
	local ok, saved = pcall(function()
		return exports.coe_doors:Save(raw)
	end)
	local failure = exportError(ok, saved)
	if failure then
		sendResult(playerId, 'doorSave', requestId, false, doorErrors[failure] or 'Não foi possível salvar a porta.')
		return
	end
	sendResult(playerId, 'doorSave', requestId, true, 'Local salvo.')
	refreshPanel(playerId)
end)

RegisterNetEvent('coe_admin:deleteDoor', function(requestId, doorId)
	local playerId = source
	if not doorGate(playerId, 'doorDelete', requestId, doorId) then
		return
	end
	local ok, deleted = pcall(function()
		return exports.coe_doors:Delete(doorId)
	end)
	local failure = exportError(ok, deleted)
	if failure then
		sendResult(playerId, 'doorDelete', requestId, false, doorErrors[failure] or 'Não foi possível remover a porta.')
		return
	end
	sendResult(playerId, 'doorDelete', requestId, true, 'Local removido.')
	refreshPanel(playerId)
end)

local housingErrors = {
	not_ready = 'O serviço de imóveis ainda está iniciando.', forbidden = 'Ação não permitida.', database_error = 'Falha ao gravar no banco.',
	invalid_property = 'Dados do imóvel inválidos.', invalid_id = 'ID inválido: use letras minúsculas, números e _ (2 a 32).',
	invalid_kind = 'Tipo de imóvel inválido.', invalid_label = 'Nome inválido (1 a 48 caracteres, sem < >).',
	invalid_door = 'Marque a porta de entrada.', invalid_stash = 'Baú inválido: marque-o dentro do interior (até 80 m do ponto interior) e confira slots e peso.', invalid_interior = 'Marque o ponto interior (entrada e saída).',
	invalid_units = 'Unidades inválidas (1 a 500).', invalid_rent = 'Aluguel inválido: diária positiva, ao menos um ciclo; imóvel inicial não aluga.',
	invalid_blip = 'Blip inválido.', property_limit = 'Limite de imóveis atingido.',
	units_in_use = 'Há moradores ou contratos que impedem a mudança (unidades, tipo ou vínculo).', has_tenants = 'Há moradores ou contratos: o imóvel não pode ser apagado.',
	invalid_business = 'Negócio vinculado inválido.', unknown_business = 'Negócio vinculado inexistente.',
	invalid_starter = 'Imóvel comercial ou ilegal não pode ser inicial.', already_leased = 'O negócio já ocupa este imóvel.',
	invalid_owner = 'Dono inválido.', invalid_members = 'Pessoas com acesso inválidas (até 10, sem repetir).',
	invalid_interior_id = 'Interior do catálogo inexistente.',
	no_vacancy = 'Sem unidade livre para o negócio vinculado.',
	unknown_property = 'Imóvel inexistente.', unknown_contract = 'Contrato inexistente (talvez já encerrado).',
	starter_locked = 'O contrato do imóvel inicial não é encerrado pela imobiliária.',
	granted_locked = 'Contrato cedido: remova o negócio vinculado no cadastro do imóvel.'
}

local function housingGate(playerId, action, requestId)
	if not businessGate(playerId, action, requestId) then
		return false
	end
	if GetResourceState('coe_housing') ~= 'started' then
		sendResult(playerId, action, requestId, false, 'O resource coe_housing não está iniciado.')
		return false
	end
	return true
end

RegisterNetEvent('coe_admin:saveProperty', function(requestId, raw)
	local playerId = source
	if not housingGate(playerId, 'propertySave', requestId) then
		return
	end
	local ok, saved = pcall(function()
		return exports.coe_housing:SaveProperty(raw)
	end)
	local failure = exportError(ok, saved)
	if failure then
		sendResult(playerId, 'propertySave', requestId, false, housingErrors[failure] or 'Não foi possível salvar o imóvel.')
		return
	end
	sendResult(playerId, 'propertySave', requestId, true, 'Imóvel salvo.')
	refreshPanel(playerId)
end)

RegisterNetEvent('coe_admin:deleteProperty', function(requestId, propertyId)
	local playerId = source
	if not housingGate(playerId, 'propertyDelete', requestId) then
		return
	end
	local ok, deleted = pcall(function()
		return exports.coe_housing:DeleteProperty(propertyId)
	end)
	local failure = exportError(ok, deleted)
	if failure then
		sendResult(playerId, 'propertyDelete', requestId, false, housingErrors[failure] or 'Não foi possível remover o imóvel.')
		return
	end
	sendResult(playerId, 'propertyDelete', requestId, true, 'Imóvel removido.')
	refreshPanel(playerId)
end)

local function housingAllowed(playerId)
	return getPermissions(playerId).manageBusinesses == true and GetResourceState('coe_housing') == 'started'
end

-- Imobiliária: contratos de um imóvel (com nomes dos moradores) e encerramento pelo admin -------------
local function characterNames(ids)
	local names = {}
	if #ids == 0 then
		return names
	end
	local marks = {}
	for index = 1, #ids do
		marks[index] = '?'
	end
	local rows = AdminPersistence.Query(('SELECT character_id, state_id, first_name, last_name FROM coe_characters WHERE character_id IN (%s)'):format(table.concat(marks, ',')), ids)
	for _, row in ipairs(rows or {}) do
		local name = ('%s %s'):format(row.first_name or '', row.last_name or ''):gsub('^%s+', ''):gsub('%s+$', '')
		names[tostring(row.character_id)] = { name = name:sub(1, 48), stateId = row.state_id }
	end
	return names
end

RegisterNetEvent('coe_admin:housingContracts', function(requestId, propertyId)
	local playerId = source
	if type(requestId) ~= 'number' or type(propertyId) ~= 'string' or not allowAction(playerId) then
		return
	end
	if not housingAllowed(playerId) then
		TriggerClientEvent('coe_admin:housingContractsResult', playerId, requestId, propertyId, nil, 'forbidden')
		return
	end
	local ok, result = pcall(function()
		return exports.coe_housing:PropertyContracts(propertyId)
	end)
	local failure = exportError(ok, result)
	if failure then
		TriggerClientEvent('coe_admin:housingContractsResult', playerId, requestId, propertyId, nil, failure)
		return
	end
	local ids, seen = {}, {}
	for _, contract in ipairs(result) do
		if contract.characterId and not seen[contract.characterId] then
			seen[contract.characterId] = true
			ids[#ids + 1] = contract.characterId
		end
	end
	local names = characterNames(ids)
	for _, contract in ipairs(result) do
		local person = contract.characterId and names[contract.characterId]
		if person then
			contract.name, contract.stateId = person.name, person.stateId
		end
	end
	TriggerClientEvent('coe_admin:housingContractsResult', playerId, requestId, propertyId, result, nil)
end)

RegisterNetEvent('coe_admin:housingEndContract', function(requestId, kind, contractId)
	local playerId = source
	if not housingGate(playerId, 'contractEnd', requestId) then
		return
	end
	local ok, ended = pcall(function()
		return exports.coe_housing:EndContract(kind, contractId)
	end)
	local failure = exportError(ok, ended)
	if failure then
		sendResult(playerId, 'contractEnd', requestId, false, housingErrors[failure] or 'Não foi possível encerrar o contrato.')
		return
	end
	log('info', 'housing', 'contract_ended_by_admin', { source = playerId, action = tostring(kind), target = tostring(contractId) })
	sendResult(playerId, 'contractEnd', requestId, true, 'Contrato encerrado.')
	refreshPanel(playerId)
end)

-- Catálogo de interiores: miniaturas e prévia (mundo próprio do admin) ---------------------------------

RegisterNetEvent('coe_admin:housingThumbs', function(requestId)
	local playerId = source
	if type(requestId) ~= 'number' or not housingAllowed(playerId) then
		return
	end
	local ok, result = pcall(function()
		return exports.coe_housing:InteriorThumbs()
	end)
	local failure = exportError(ok, result)
	TriggerLatentClientEvent('coe_admin:housingThumbsResult', playerId, 500000, requestId, not failure and result or nil, failure)
end)

RegisterNetEvent('coe_admin:housingThumb', function(interiorId, image)
	local playerId = source
	if not housingAllowed(playerId) then
		return
	end
	local ok, result = pcall(function()
		return exports.coe_housing:SaveInteriorThumb(interiorId, image)
	end)
	local failure = exportError(ok, result)
	if failure then
		log('warn', 'housing', 'interior_thumb_failed', { source = playerId, error_code = failure })
	end
	TriggerClientEvent('coe_admin:housingThumbSaved', playerId, type(interiorId) == 'string' and interiorId or '', failure)
end)

RegisterNetEvent('coe_admin:housingPreview', function(active)
	local playerId = source
	if active == true and not housingAllowed(playerId) then
		TriggerClientEvent('coe_admin:housingPreviewResult', playerId, false, 'forbidden')
		return
	end
	if GetResourceState('coe_housing') ~= 'started' then
		TriggerClientEvent('coe_admin:housingPreviewResult', playerId, false, 'not_ready')
		return
	end
	local ok, result = pcall(function()
		if active == true then
			return exports.coe_housing:BeginPreview(playerId)
		end
		return exports.coe_housing:EndPreview(playerId)
	end)
	local failure = exportError(ok, result)
	TriggerClientEvent('coe_admin:housingPreviewResult', playerId, not failure, failure)
end)

-- Banco (alto nível: manageBanking) -----------------------------------------------------------------

local bankingErrors = {
	forbidden = 'Ação não permitida.', not_ready = 'O banco ainda está iniciando.', database_error = 'Falha ao gravar no banco.',
	busy = 'Conta em uso por outra operação. Tente de novo.', conflict = 'A conta mudou durante a operação. Tente de novo.',
	character_not_found = 'Personagem sem conta bancária.', card_not_found = 'Cartão não encontrado.',
	card_blocked = 'Ação não se aplica a este cartão (substituído ou já no estado pedido).', no_credit = 'O cliente não tem conta de crédito.',
	invalid_tier = 'Nível inválido.', invalid_amount = 'Valor inválido.', invalid_tiers = 'Lista de níveis inválida.',
	invalid_tier_label = 'Nome de nível inválido (1 a 24 caracteres, sem < >).',
	invalid_tier_values = 'Valores inválidos: inteiros, pontos de 0 a 100 por $100, pontuação até 1000.',
	invalid_tier_order = 'A pontuação mínima deve crescer e o limite não pode diminuir de um nível para o próximo.',
	invalid_loan = 'Empréstimo inválido: confira valor, juros e parcelas dentro dos tetos.',
	loan_active = 'O cliente já tem um empréstimo ativo.', loan_not_found = 'Empréstimo não encontrado ou já encerrado.',
	economy_unavailable = 'Economia indisponível: o valor não foi creditado.',
	request_not_found = 'Pedido não encontrado ou já decidido.', business_not_found = 'Negócio não encontrado ou sem proprietário.',
	business_loan_active = 'O negócio já tem um empréstimo ativo.',
	owner_changed = 'O negócio mudou de dono depois do pedido. Recuse e peça ao novo dono um novo pedido.',
	balance_limit = 'Limite de saldo atingido na conta ou no caixa do negócio.',
	unknown_business = 'Negócio não encontrado.',
	account_not_found = 'Conta ou caixa do negócio não encontrado.',
	transaction_failed = 'Erro na transação bancária. Tente novamente.',
	invalid_parameters = 'Parâmetros inválidos na operação bancária.',
	invalid_transaction = 'Transação inválida no banco de dados.',
	invalid_limit = 'Limite diário inválido.', insufficient_funds = 'Saldo insuficiente no caixa da empresa.'
}

local bankingSuccess = {
	saveTiers = 'Níveis salvos.', setCredit = 'Crédito atualizado.', points = 'Pontos ajustados.',
	card = 'Cartão atualizado.', grantLoan = 'Empréstimo concedido e creditado na conta.', forgiveLoan = 'Saldo do empréstimo perdoado.',
	decideRequest = 'Pedido decidido.', businessAdjust = 'Caixa da empresa ajustado.', businessCardLimit = 'Limite do cartão empresarial salvo.'
}

local BANKING_CALLS = {
	saveTiers = function(payload)
		return exports.coe_banking:AdminSaveTiers(payload.tiers)
	end,
	setCredit = function(payload)
		return exports.coe_banking:AdminSetCredit(payload.characterId,
			{ tier = payload.tier, customLimit = payload.customLimit or false, tierLocked = payload.tierLocked == true })
	end,
	points = function(payload)
		return exports.coe_banking:AdminPoints(payload.characterId, payload.delta)
	end,
	card = function(payload)
		return exports.coe_banking:AdminCard(payload.cardId, payload.op)
	end,
	grantLoan = function(payload)
		return exports.coe_banking:AdminGrantLoan(payload.characterId,
			{ principal = payload.principal, rate = payload.rate, installments = payload.installments, note = payload.note })
	end,
	forgiveLoan = function(payload)
		return exports.coe_banking:AdminForgiveLoan(payload.loanId)
	end,
	businessAdjust = function(payload)
		return exports.coe_banking:AdminBusinessAdjust(payload.businessId, payload.delta, type(payload.note) == 'string' and payload.note:sub(1, 64) or '')
	end,
	businessCardLimit = function(payload)
		return exports.coe_banking:AdminBusinessCardLimit(payload.cardId, payload.dailyLimit)
	end,
	decideRequest = function(payload)
		return exports.coe_banking:AdminDecideRequest(payload.requestId, {
			approve = payload.approve == true, rate = payload.rate, installments = payload.installments,
			reason = type(payload.reason) == 'string' and payload.reason:sub(1, 64) or ''
		})
	end
}

local function bankingGate(playerId)
	if not getPermissions(playerId).manageBanking then
		log('warn', 'security', 'admin_banking_denied', { source = playerId })
		return false, 'forbidden'
	end
	if GetResourceState('coe_banking') ~= 'started' then
		return false, 'not_ready'
	end
	return true
end

RegisterNetEvent('coe_admin:bankingAccount', function(requestId, characterId)
	local playerId = source
	if type(requestId) ~= 'number' or requestId % 1 ~= 0 then
		return
	end
	local allowed, gateError = bankingGate(playerId)
	if not allowed or not allowAction(playerId) then
		TriggerClientEvent('coe_admin:bankingAccountResult', playerId, requestId, nil, gateError or 'busy')
		return
	end
	if type(characterId) ~= 'string' or not characterId:match('^%d+$') or #characterId > 20 then
		TriggerClientEvent('coe_admin:bankingAccountResult', playerId, requestId, nil, 'character_not_found')
		return
	end
	local ok, account = pcall(function()
		return exports.coe_banking:AdminAccount(characterId)
	end)
	local failure = exportError(ok, account)
	if failure then
		TriggerClientEvent('coe_admin:bankingAccountResult', playerId, requestId, nil, failure)
		return
	end
	log('info', 'audit', 'bank_admin_view', { admin = playerId, characterId = characterId })
	TriggerClientEvent('coe_admin:bankingAccountResult', playerId, requestId, account, nil)
end)

RegisterNetEvent('coe_admin:bankingRequests', function(requestId)
	local playerId = source
	if type(requestId) ~= 'number' or requestId % 1 ~= 0 then
		return
	end
	local allowed, gateError = bankingGate(playerId)
	if not allowed or not allowAction(playerId) then
		TriggerClientEvent('coe_admin:bankingRequestsResult', playerId, requestId, nil, gateError or 'busy')
		return
	end
	local ok, result = pcall(function()
		return exports.coe_banking:AdminLoanRequests()
	end)
	local failure = exportError(ok, result)
	TriggerClientEvent('coe_admin:bankingRequestsResult', playerId, requestId, not failure and result or nil, failure)
end)

RegisterNetEvent('coe_admin:bankingBusiness', function(requestId, op, businessId, filter)
	local playerId = source
	if type(requestId) ~= 'number' or requestId % 1 ~= 0 then
		return
	end
	local allowed, gateError = bankingGate(playerId)
	if not allowed or not allowAction(playerId) then
		TriggerClientEvent('coe_admin:bankingBusinessResult', playerId, requestId, nil, gateError or 'busy')
		return
	end
	local ok, result = pcall(function()
		if op == 'account' then
			return exports.coe_banking:AdminBusinessAccount(businessId, type(filter) == 'table' and filter or {})
		end
		return exports.coe_banking:AdminBusinessAccounts()
	end)
	local failure = exportError(ok, result)
	if not failure and op == 'account' then
		log('info', 'audit', 'bank_admin_business_view', { admin = playerId, op = tostring(businessId) })
	end
	TriggerClientEvent('coe_admin:bankingBusinessResult', playerId, requestId, not failure and result or nil, failure)
end)

RegisterNetEvent('coe_admin:bankingAction', function(requestId, action, payload)
	local playerId = source
	local call = type(action) == 'string' and BANKING_CALLS[action] or nil
	if not call or type(payload) ~= 'table' then
		return
	end
	local allowed, gateError = bankingGate(playerId)
	if not allowed then
		sendResult(playerId, 'banking', requestId, false, bankingErrors[gateError])
		return
	end
	if not allowAction(playerId) then
		return
	end
	local ok, result = pcall(call, payload)
	local failure = exportError(ok, result)
	if failure then
		log('warn', 'banking', 'admin_banking_action_failed', { source = playerId, action = tostring(action), error_code = tostring(failure) })
		sendResult(playerId, 'banking', requestId, false, bankingErrors[failure] or 'Não foi possível concluir a operação bancária.')
		return
	end
	log('info', 'audit', 'bank_admin_' .. action:gsub('%u', function(letter) return '_' .. letter:lower() end), {
		admin = playerId, characterId = type(payload.characterId) == 'string' and payload.characterId or nil,
		cardId = tonumber(payload.cardId), loanId = tonumber(payload.loanId),
		op = type(payload.op) == 'string' and payload.op or (type(payload.businessId) == 'string' and payload.businessId or nil),
		loanRequestId = tonumber(payload.requestId), approve = action == 'decideRequest' and payload.approve == true or nil,
		rate = tonumber(payload.rate),
		tier = type(payload.tier) == 'string' and payload.tier or nil, amount = tonumber(payload.principal or payload.delta or payload.customLimit)
	})
	sendResult(playerId, 'banking', requestId, true, bankingSuccess[action])
	if action == 'saveTiers' then
		refreshPanel(playerId)
	end
end)

-- Criptomoeda (manageCrypto) ------------------------------------------------------------------------

local cryptoErrors = {
	forbidden = 'Sem permissão para gerenciar a criptomoeda.',
	not_ready = 'O coe_crypto ainda está iniciando.',
	database_error = 'Falha ao gravar no banco.',
	invalid_settings = 'Configurações inválidas.',
	invalid_coin = 'Identidade da moeda inválida: nome de 1 a 24 caracteres e símbolo de 2 a 6 letras/números.',
	invalid_wallets = 'Parâmetros de carteiras inválidos: confira limites por aparelho, por dia, rótulo e bloqueio.',
	invalid_transfer = 'Parâmetros de transferência inválidos: confira taxa, quantia mínima/máxima, memo e intervalo.',
	invalid_exchange = 'Parâmetros da corretora inválidos: confira nome, intervalos, volatilidade, reversão, impacto e spread.',
	invalid_exchange_prices = 'Cotações da corretora inválidas: piso <= âncora e inicial <= teto.',
	invalid_exchange_orders = 'Limites de ordens inválidos: mínimo <= máximo e limites diários >= mínimo.',
	invalid_mining = 'Parâmetros de mineração inválidos: confira intervalo, emissão por rodada, hash de referência e teto.',
	invalid_network = 'Parâmetros de rede inválidos: confira tamanho de página (5 a 100) e cooldown (50 a 5000 ms).',
	invalid_price = 'Cotação inválida: informe um valor inteiro em $ entre o piso e o teto da corretora.'
}

local cryptoSuccess = {
	save = 'Configurações da criptomoeda salvas e aplicadas.',
	reset = 'Configurações restauradas para o padrão do config.lua.',
	setPrice = 'Cotação atualizada.'
}

local CRYPTO_CALLS = {
	save = function(payload)
		return exports.coe_crypto:AdminSaveSettings(payload.settings)
	end,
	reset = function()
		return exports.coe_crypto:AdminResetSettings()
	end,
	setPrice = function(payload)
		return exports.coe_crypto:AdminSetPrice(payload.price)
	end
}

local function cryptoGate(playerId)
	if not getPermissions(playerId).manageCrypto then
		log('warn', 'security', 'admin_crypto_denied', { source = playerId })
		return false, 'forbidden'
	end
	if GetResourceState('coe_crypto') ~= 'started' then
		return false, 'not_ready'
	end
	return true
end

RegisterNetEvent('coe_admin:cryptoAction', function(requestId, action, payload)
	local playerId = source
	if type(requestId) ~= 'number' or requestId % 1 ~= 0 then
		return
	end
	local call = type(action) == 'string' and CRYPTO_CALLS[action] or nil
	if not call or type(payload) ~= 'table' then
		return
	end
	local allowed, gateError = cryptoGate(playerId)
	if not allowed then
		sendResult(playerId, 'crypto', requestId, false, cryptoErrors[gateError])
		return
	end
	if not allowAction(playerId) then
		sendResult(playerId, 'crypto', requestId, false, 'Aguarde antes de executar outra ação.')
		return
	end
	local ok, result = pcall(call, payload)
	local failure = exportError(ok, result)
	if failure then
		sendResult(playerId, 'crypto', requestId, false, cryptoErrors[failure] or 'Não foi possível concluir a ação.')
		return
	end
	log('info', 'audit', 'crypto_admin_' .. action:gsub('%u', function(letter) return '_' .. letter:lower() end), {
		admin = playerId,
		price = tonumber(payload.price)
	})
	sendResult(playerId, 'crypto', requestId, true, cryptoSuccess[action])
	refreshPanel(playerId)
end)

RegisterNetEvent('coe_admin:cryptoInspect', function(requestId, address)
	local playerId = source
	if type(requestId) ~= 'number' or requestId % 1 ~= 0 or type(address) ~= 'string' then
		return
	end
	local allowed, gateError = cryptoGate(playerId)
	if not allowed or not allowAction(playerId) then
		TriggerClientEvent('coe_admin:cryptoInspectResult', playerId, requestId, nil, gateError or 'busy')
		return
	end
	local ok, result = pcall(function()
		return exports.coe_crypto:AdminInspect(address:sub(1, 64))
	end)
	local failure = exportError(ok, result)
	if failure then
		TriggerClientEvent('coe_admin:cryptoInspectResult', playerId, requestId, nil, failure)
		return
	end
	local ids, seen = {}, {}
	if result.wallet and result.wallet.createdBy then
		local cid = tostring(result.wallet.createdBy)
		seen[cid] = true
		ids[#ids + 1] = cid
	end
	for _, tx in ipairs(result.history or {}) do
		local cid = tx.characterId and tostring(tx.characterId)
		if cid and not seen[cid] then seen[cid] = true; ids[#ids + 1] = cid end
	end
	local names = characterNames(ids)
	if result.wallet and result.wallet.createdBy then
		local person = names[tostring(result.wallet.createdBy)]
		if person then result.wallet.characterName, result.wallet.stateId = person.name, person.stateId end
	end
	for _, tx in ipairs(result.history or {}) do
		local person = tx.characterId and names[tostring(tx.characterId)]
		if person then tx.characterName, tx.stateId = person.name, person.stateId end
	end
	TriggerClientEvent('coe_admin:cryptoInspectResult', playerId, requestId, result, nil)
end)

RegisterNetEvent('coe_admin:fleetAdd', function(requestId, garageId, model)
	local playerId = source
	if not fleetGate(playerId, 'fleetAdd', requestId, garageId) then
		return
	end
	if garageBackend() ~= 'coe_garages' then
		sendResult(playerId, 'fleetAdd', requestId, false, garageErrors.no_fleet_garage)
		return
	end
	local ok, record = pcall(function()
		return exports.coe_garages:AddFleetVehicle(garageId, type(model) == 'string' and model:lower() or nil)
	end)
	local failure = exportError(ok, record)
	if failure then
		sendResult(playerId, 'fleetAdd', requestId, false, garageErrors[failure] or 'Não foi possível adicionar o veículo.')
		return
	end
	sendResult(playerId, 'fleetAdd', requestId, true, 'Veículo adicionado à frota.')
	refreshPanel(playerId)
end)

RegisterNetEvent('coe_admin:fleetRemove', function(requestId, garageId, vehicleId)
	local playerId = source
	if not fleetGate(playerId, 'fleetRemove', requestId, garageId) then
		return
	end
	if garageBackend() ~= 'coe_garages' then
		sendResult(playerId, 'fleetRemove', requestId, false, garageErrors.no_fleet_garage)
		return
	end
	local ok, removed = pcall(function()
		return exports.coe_garages:RemoveFleetVehicle(garageId, tostring(vehicleId))
	end)
	local failure = exportError(ok, removed)
	if failure then
		sendResult(playerId, 'fleetRemove', requestId, false, garageErrors[failure] or 'Não foi possível remover o veículo.')
		return
	end
	sendResult(playerId, 'fleetRemove', requestId, true, 'Veículo removido da frota.')
	refreshPanel(playerId)
end)

local factionErrors = {
	not_ready = 'O serviço de facções ainda está iniciando.', forbidden = 'Ação não permitida.',
	database_error = 'Falha ao gravar no banco.', invalid_faction = 'Dados da facção inválidos.',
	invalid_id = 'ID inválido: use letras minúsculas, números e _ (2 a 32).', invalid_category = 'Categoria inválida.',
	invalid_label = 'Nome inválido (1 a 48 caracteres, sem < >).',
	invalid_grades = 'Graus inválidos: de 1 a 10, números de 0 a 9 sem repetição e com nome.',
	invalid_crafts = 'Crafts inválidos: receita repetida ou grau mínimo inexistente.',
	invalid_station = 'Mesa de craft ou baú inválido: confira ID, nome, posição, raio, slots e peso.',
	duplicate_station = 'Há dois pontos com o mesmo ID na mesma lista.',
	faction_limit = 'Limite de facções atingido.', unknown_faction = 'Facção inexistente.',
	grade_in_use = 'Há membros em um grau que você removeu. Mova esses membros antes.',
	invalid_character = 'Personagem inválido.', character_not_found = 'Personagem não encontrado.',
	invalid_grade = 'Grau inválido para a facção.', member_limit = 'Limite de membros da facção atingido.'
}

local function factionGate(playerId, action, requestId)
	if type(requestId) ~= 'number' or requestId % 1 ~= 0 then
		return false
	end
	if not allowAction(playerId) then
		sendResult(playerId, action, requestId, false, 'Aguarde antes de executar outra ação.')
		return false
	end
	if not getPermissions(playerId).manageGroups then
		log('warn', 'security', 'faction_change_denied', { action = action, source = playerId })
		sendResult(playerId, action, requestId, false, 'Sem permissão para gerenciar facções.')
		return false
	end
	if GetResourceState('coe_factions') ~= 'started' then
		sendResult(playerId, action, requestId, false, 'O resource coe_factions não está iniciado.')
		return false
	end
	return true
end

local function factionCall(playerId, action, requestId, failureMessage, call)
	local ok, result = pcall(call)
	local failure = exportError(ok, result)
	if failure then
		sendResult(playerId, action, requestId, false, factionErrors[failure] or failureMessage)
		return nil
	end
	return result
end

RegisterNetEvent('coe_admin:saveFaction', function(requestId, raw)
	local playerId = source
	if not factionGate(playerId, 'factionSave', requestId) then
		return
	end
	if type(raw) ~= 'table' then
		sendResult(playerId, 'factionSave', requestId, false, factionErrors.invalid_faction)
		return
	end
	if not factionCall(playerId, 'factionSave', requestId, 'Não foi possível salvar a facção.', function()
		return exports.coe_factions:Save(raw)
	end) then
		return
	end
	log('info', 'audit', 'faction_saved', { admin = playerId, faction = raw.id })
	sendResult(playerId, 'factionSave', requestId, true, 'Facção salva.')
	refreshPanel(playerId)
end)

RegisterNetEvent('coe_admin:deleteFaction', function(requestId, factionId)
	local playerId = source
	if not factionGate(playerId, 'factionDelete', requestId) then
		return
	end
	if type(factionId) ~= 'string' or #factionId > 32 then
		sendResult(playerId, 'factionDelete', requestId, false, factionErrors.invalid_id)
		return
	end
	if not factionCall(playerId, 'factionDelete', requestId, 'Não foi possível remover a facção.', function()
		return exports.coe_factions:Delete(factionId)
	end) then
		return
	end
	log('info', 'audit', 'faction_deleted', { admin = playerId, faction = factionId })
	sendResult(playerId, 'factionDelete', requestId, true, 'Facção removida.')
	refreshPanel(playerId)
end)

-- Lista os membros (online ou não) de uma facção; só leitura, com intervalo mínimo por admin.
RegisterNetEvent('coe_admin:getFactionMembers', function(requestId, factionId)
	local playerId = source
	if type(requestId) ~= 'number' or requestId % 1 ~= 0 or type(factionId) ~= 'string' or #factionId > 32 then
		return
	end
	if not getPermissions(playerId).manageGroups or GetResourceState('coe_factions') ~= 'started' then
		TriggerClientEvent('coe_admin:factionMembersResult', playerId, requestId, factionId, nil, 'forbidden')
		return
	end
	if not allowAction(playerId) then
		TriggerClientEvent('coe_admin:factionMembersResult', playerId, requestId, factionId, nil, 'rate_limited')
		return
	end
	local ok, members = pcall(function()
		return exports.coe_factions:Members(factionId)
	end)
	if not ok or type(members) ~= 'table' then
		TriggerClientEvent('coe_admin:factionMembersResult', playerId, requestId, factionId, nil, 'not_ready')
		return
	end
	TriggerClientEvent('coe_admin:factionMembersResult', playerId, requestId, factionId, members, nil)
end)

RegisterNetEvent('coe_admin:setFactionMember', function(requestId, factionId, characterId, grade)
	local playerId = source
	if not factionGate(playerId, 'factionMember', requestId) then
		return
	end
	if type(factionId) ~= 'string' or #factionId > 32 or type(characterId) ~= 'string'
		or type(grade) ~= 'number' or grade % 1 ~= 0 then
		sendResult(playerId, 'factionMember', requestId, false, factionErrors.invalid_character)
		return
	end
	if not factionCall(playerId, 'factionMember', requestId, 'Não foi possível atualizar o membro.', function()
		return exports.coe_factions:SetMember(factionId, characterId, grade)
	end) then
		return
	end
	log('info', 'audit', 'faction_member_set', { admin = playerId, faction = factionId, characterId = characterId, grade = grade })
	sendResult(playerId, 'factionMember', requestId, true, 'Membro atualizado.')
end)

RegisterNetEvent('coe_admin:removeFactionMember', function(requestId, factionId, characterId)
	local playerId = source
	if not factionGate(playerId, 'factionMember', requestId) then
		return
	end
	if type(factionId) ~= 'string' or #factionId > 32 or type(characterId) ~= 'string' then
		sendResult(playerId, 'factionMember', requestId, false, factionErrors.invalid_character)
		return
	end
	if not factionCall(playerId, 'factionMember', requestId, 'Não foi possível remover o membro.', function()
		return exports.coe_factions:RemoveMember(factionId, characterId)
	end) then
		return
	end
	log('info', 'audit', 'faction_member_removed', { admin = playerId, faction = factionId, characterId = characterId })
	sendResult(playerId, 'factionMember', requestId, true, 'Membro removido.')
end)

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
