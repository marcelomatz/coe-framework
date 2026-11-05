-- Factions Administration
local Admin = Admin
local log = function(...) return Admin.log(...) end
local sendResult = function(...) return Admin.sendResult(...) end
local allowAction = function(...) return Admin.allowAction(...) end
local getPermissions = function(...) return Admin.getPermissions(...) end
local refreshPanel = function(...) return Admin.refreshPanel(...) end
local exportError = function(...) return Admin.exportError(...) end

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
