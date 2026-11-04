-- World, Garages, Rentals, Doors & Housing Administration
local Admin = Admin
local log = function(...) return Admin.log(...) end
local sendResult = function(...) return Admin.sendResult(...) end
local allowAction = function(...) return Admin.allowAction(...) end
local getPermissions = function(...) return Admin.getPermissions(...) end
local refreshPanel = function(...) return Admin.refreshPanel(...) end
local exportError = function(...) return Admin.exportError(...) end
local garageBackend = function(...) return Admin.garageBackend(...) end
local garagesList = function(...) return Admin.garagesList(...) end
local garageSaveRaw = function(...) return Admin.garageSaveRaw(...) end
local garageDeleteRaw = function(...) return Admin.garageDeleteRaw(...) end

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
