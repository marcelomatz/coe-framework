local startTime = os.time()

-- Facção no dossiê: provedores registrados por outros resources (ACE coe.pausemenu.profile no server.cfg). Cada um
-- informa o export que recebe o characterId e devolve { label, grade } ou nil. O registro some quando o resource para.
local factionProviders = {}

exports('RegisterFactionProvider', function(exportName)
	local resource = GetInvokingResource()
	if not CoeAccess.Allowed(resource, 'coe.pausemenu.profile') then
		return { error = 'forbidden' }
	end
	if type(exportName) ~= 'string' or #exportName > 64 or not exportName:match('^[%a_][%w_]*$') then
		return { error = 'invalid_provider' }
	end
	factionProviders[resource] = exportName
	return true
end)

AddEventHandler('onResourceStop', function(resource)
	factionProviders[resource] = nil
end)

local function getCharacterData(source)
	local char = nil
	pcall(function()
		if exports.coe_core and exports.coe_core.GetActiveCharacter then
			char = exports.coe_core:GetActiveCharacter(source)
		end
	end)

	local fullName = 'Cidadão'
	local stateId = 'COE' .. tostring(source)
	local birthDate = '1998-05-15'
	local gender = 'male'
	local createdAt = 'Recente'
	local charId = nil

	if char and type(char) == 'table' then
		charId = char.characterId
		stateId = char.stateId or stateId
		birthDate = char.birthDate or birthDate
		gender = char.gender or gender
		createdAt = char.createdAt or createdAt
		local fName = ('%s %s'):format(char.firstName or '', char.lastName or ''):gsub('^%s*(.-)%s*$', '%1')
		if fName ~= '' then fullName = fName end
	else
		local playerName = GetPlayerName(source)
		if playerName and playerName ~= '' then
			fullName = playerName
		end
	end

	-- 1. Saldo Bancário via coe_economy
	local bankBalance = 0
	pcall(function()
		if exports.coe_economy and exports.coe_economy.GetBalance and charId then
			local bal = exports.coe_economy:GetBalance(charId)
			if bal and type(bal) == 'number' then
				bankBalance = bal
			end
		end
	end)

	-- 2. Emprego e Cargo
	local jobTitle = 'Civil / Desempregado'
	local jobGrade = 'N/A'

	-- Consulta coe_core groups
	pcall(function()
		if exports.coe_core and exports.coe_core.GetPlayerGroups then
			local groups = exports.coe_core:GetPlayerGroups(source)
			if groups and groups.job then
				jobTitle = groups.job.name
				jobGrade = tostring(groups.job.grade or '1')
			end
		end
	end)

	-- Consulta coe_jobs se disponível
	pcall(function()
		if exports.coe_jobs and exports.coe_jobs.GetCareer and charId then
			local career = exports.coe_jobs:GetCareer(charId)
			if career and career.currentJob then
				jobTitle = career.currentJob.label or career.currentJob.name or jobTitle
				jobGrade = career.currentJob.gradeLabel or tostring(career.currentJob.grade or jobGrade)
			end
		end
	end)

	-- 3. Facção / Organização
	local factionTitle = 'Nenhuma'
	local factionGrade = 'N/A'

	-- Consulta coe_core groups
	pcall(function()
		if exports.coe_core and exports.coe_core.GetPlayerGroups then
			local groups = exports.coe_core:GetPlayerGroups(source)
			if groups and groups.faction then
				factionTitle = groups.faction.name
				factionGrade = tostring(groups.faction.grade or '1')
			end
		end
	end)

	-- Provedores registrados (o primeiro que responder vale)
	for resource, exportName in pairs(charId and factionProviders or {}) do
		local ok, info = pcall(function()
			local target = exports[resource]
			return target[exportName](target, charId)
		end)
		if ok and type(info) == 'table' and type(info.label) == 'string' then
			factionTitle = info.label
			factionGrade = tostring(info.grade or factionGrade)
			break
		end
	end

	return {
		name = fullName,
		stateId = stateId,
		job = jobTitle,
		jobGrade = jobGrade,
		faction = factionTitle,
		factionGrade = factionGrade,
		bank = bankBalance,
		birthDate = birthDate,
		gender = gender,
		createdAt = createdAt
	}
end

RegisterNetEvent('coe_pausemenu:server:requestData', function()
	local src = source
	local charData = getCharacterData(src)
	local uptimeSeconds = os.time() - startTime
	local onlineCount = #GetPlayers()
	local maxClients = GetConvarInt('sv_maxclients', 128)
	local ping = GetPlayerPing(src) or 0

	local serverInfo = {
		onlinePlayers = onlineCount,
		maxPlayers = maxClients,
		ping = ping,
		uptime = uptimeSeconds
	}

	local payload = Rules.BuildPayload(charData, serverInfo)
	TriggerClientEvent('coe_pausemenu:client:receiveData', src, payload)
end)

RegisterNetEvent('coe_pausemenu:server:disconnect', function()
	local src = source
	DropPlayer(src, 'Você se desconectou do servidor pelo Menu de Pausa.')
end)
