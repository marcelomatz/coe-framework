-- News & Media Administration
local Admin = Admin
local log = function(...) return Admin.log(...) end
local sendResult = function(...) return Admin.sendResult(...) end
local allowAction = function(...) return Admin.allowAction(...) end
local getPermissions = function(...) return Admin.getPermissions(...) end
local refreshPanel = function(...) return Admin.refreshPanel(...) end
local exportError = function(...) return Admin.exportError(...) end
local staffDeps = Admin.staffDeps

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
