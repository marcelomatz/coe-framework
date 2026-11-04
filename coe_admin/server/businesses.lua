-- Businesses & Character Search Administration
local Admin = Admin
local log = function(...) return Admin.log(...) end
local sendResult = function(...) return Admin.sendResult(...) end
local allowAction = function(...) return Admin.allowAction(...) end
local getPermissions = function(...) return Admin.getPermissions(...) end
local refreshPanel = function(...) return Admin.refreshPanel(...) end
local businessGate = function(...) return Admin.businessGate(...) end
local characterDirectory = Admin.characterDirectory
local activeCharacter = function(...) return Admin.activeCharacter(...) end
local garagesList = function(...) return Admin.garagesList(...) end

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