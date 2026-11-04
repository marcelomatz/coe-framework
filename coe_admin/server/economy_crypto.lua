-- Economy, Catalog & Crypto Administration
local Admin = Admin
local log = function(...) return Admin.log(...) end
local sendResult = function(...) return Admin.sendResult(...) end
local allowAction = function(...) return Admin.allowAction(...) end
local getPermissions = function(...) return Admin.getPermissions(...) end
local refreshPanel = function(...) return Admin.refreshPanel(...) end
local businessGate = function(...) return Admin.businessGate(...) end
local exportError = function(...) return Admin.exportError(...) end

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
