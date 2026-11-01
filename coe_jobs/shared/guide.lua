-- Guia de cada emprego (puro, testável): o "como funciona" mostrado no NPC e no app Carreira, montado a partir da
-- definição validada. Assim todo emprego novo em jobs/ já ganha o guia sem texto extra; `tips` acrescenta dicas.
JobGuide = {}

local KIND_LABELS = {
	gather = 'Coleta e venda',
	fishing = 'Pesca livre',
	haul = 'Corte, transporte e beneficiamento',
	deliver = 'Rota de entregas',
	collect = 'Rota de coleta',
	passenger = 'Corridas com passageiros',
	zone = 'Coleta por áreas'
}

-- Texto de cada bônus de habilidade por nível (mesmos perks de Career.skills).
local PERK_TEXT = {
	pay = '+%d%% de pagamento',
	speed = '-%d%% no tempo das ações',
	capacity = '+%d%% de carga',
	deposit = '-%d%% no depósito do veículo'
}

local function percent(value)
	return math.floor((value or 0) * 100 + 0.5)
end

local function money(value)
	local textValue = tostring(math.floor(value or 0))
	return '$' .. textValue:reverse():gsub('(%d%d%d)', '%1.'):reverse():gsub('^%.', '')
end

local function duration(seconds)
	if seconds >= 60 then
		local minutes = seconds / 60
		return minutes == math.floor(minutes) and ('%d min'):format(minutes) or ('%.1f min'):format(minutes):gsub('%.', ',')
	end
	return ('%d s'):format(math.floor(seconds + 0.5))
end

function JobGuide.KindLabel(job)
	return KIND_LABELS[job.gather and (job.gather.haul and 'haul' or job.gather.fishing and 'fishing' or 'gather') or job.route.mode or 'deliver']
end

function JobGuide.PerkText(perk, value)
	local pattern = PERK_TEXT[perk]
	return pattern and pattern:format(percent(value)) or perk
end

local function yieldText(yield, item)
	local amount = yield[1] == yield[2] and tostring(yield[1]) or ('%d a %d'):format(yield[1], yield[2])
	return ('%s %s'):format(amount, yield[2] == 1 and item.unit or item.units)
end

-- Produtos em ordem de exibição (o primeiro é o padrão).
local function productList(g)
	local list = {}
	for _, id in ipairs(g.productOrder or {}) do
		list[#list + 1] = g.products[id]
	end
	return list
end

local function gatherSteps(job)
	local g = job.gather
	local products = productList(g)
	local steps = { 'Fale com o responsável aqui e escolha "Começar".' }
	if g.haul then
		local raw = g.products[g.haul.product]
		local output = g.process and g.products[g.process.product]
		if job.vehicle then
			steps[#steps + 1] = job.vehicle.deposit > 0
				and ('A pickup da empresa sai na vaga ao lado, com depósito de %s devolvido quando você a traz de volta e encerra.'):format(money(job.vehicle.deposit))
				or 'A pickup da empresa sai na vaga ao lado.'
		end
		local place = g.world[1] and g.world[1].label or 'a área marcada'
		steps[#steps + 1] = ('Leve a pickup até %s (o círculo no mapa). Qualquer árvore de lá serve: use "%s" (cerca de %s); ela tomba e deixa %s no chão.'):format(
			place, raw.actionLabel, duration(raw.seconds), yieldText(raw.yield, raw))
		steps[#steps + 1] = ('Use "%s" em cada tora e "%s" na pickup. Cabem %d %s na caçamba.'):format(g.haul.takeLabel, g.haul.loadLabel, g.haul.capacity, raw.units)
		if output then
			steps[#steps + 1] = ('Volte à madeireira com a pickup e use "%s" na serra: cada %s vira %d %s.'):format(g.process.label, raw.unit, g.process.ratio, output.units)
			steps[#steps + 1] = ('Venda no comprador ("%s"): %s por %s. Só a venda paga.'):format(g.sell.label, money(output.price), output.unit)
		end
		steps[#steps + 1] = 'Para parar, venda o que tem, traga a pickup até aqui e escolha "Encerrar o trabalho".'
		return steps
	end
	if g.fishing then
		local f = g.fishing
		local areas = {}
		for _, zone in ipairs(f.areas) do
			areas[#areas + 1] = zone.label
		end
		local rod, bait = f.rods[f.rodOrder[1]], f.baits[f.baitOrder[1]]
		steps[1] = ('Compre uma vara e iscas na %s (a mais simples: %s e %s).'):format(job.shop and job.shop.label:lower() or 'loja', rod.label:lower(), bait.label:lower())
		steps[#steps + 1] = ('Vá a uma área de pesca (%s) e use a vara no inventário para pegá-la na mão. Do alto do píer também vale.'):format(table.concat(areas, ', '))
		steps[#steps + 1] = 'De frente para a água, segure E para carregar a força e solte para arremessar. Mais longe chega em água funda: a mordida vem antes e aparecem mais raros. X guarda a vara.'
		steps[#steps + 1] = 'Cada arremesso gasta uma isca. Usar uma isca no inventário escolhe qual vai no anzol; sem escolher, vai a mais simples que você tiver.'
		steps[#steps + 1] = 'Quando morder, aperte E na hora para fisgar. Depois, segure e solte E para manter o peixe dentro da faixa até a barra de progresso encher; se esvaziar, ele escapa.'
		steps[#steps + 1] = ('Você leva até %d peixes. Venda num comprador marcado no mapa ("%s"): cada espécie tem o seu preço.'):format(g.capacity, g.sell.label)
		steps[#steps + 1] = 'Varas e iscas melhores pedem nível no emprego: o peixe morde antes, a faixa é maior e aparecem mais raros.'
		return steps
	end
	if #products == 1 then
		local item = products[1]
		steps[#steps + 1] = ('Vá aos pontos marcados no mapa e use "%s". Cada ação leva cerca de %s e rende %s.'):format(
			item.actionLabel, duration(item.seconds), yieldText(item.yield, item))
		steps[#steps + 1] = ('Você carrega até %d %s. Cada ponto usado volta em %s.'):format(g.capacity, item.units, duration(item.cooldown))
		steps[#steps + 1] = ('Leve a carga ao comprador marcado no mapa e use "%s". Só a venda paga: %s por %s.'):format(
			g.sell.label, money(item.price), item.unit)
	else
		local fields = {}
		for _, field in ipairs(g.fields or {}) do
			fields[#fields + 1] = field.label
		end
		steps[#steps + 1] = ('Escolha um campo no mapa (%s) e use a opção de colher em cada pé. Cada produto tem seu tempo e rendimento.'):format(
			#fields > 0 and table.concat(fields, ', ') or 'pontos marcados')
		steps[#steps + 1] = ('Você carrega até %d itens somando todos os produtos. Cada pé colhido volta depois de alguns minutos.'):format(g.capacity)
		steps[#steps + 1] = ('Leve a colheita a um comprador marcado no mapa e use "%s". Só a venda paga, e cada produto tem o seu preço.'):format(g.sell.label)
	end
	steps[#steps + 1] = 'Repita quanto quiser. Para parar, venda o que carrega, volte aqui e escolha "Encerrar o trabalho".'
	if job.uniform then
		steps[#steps + 1] = ('Opcional: trabalhando, peça "%s" ao responsável. Sai ao tirar ou ao encerrar.'):format('Vestir ' .. job.uniform.label:lower())
	end
	return steps
end

local function routeSteps(job)
	local r = job.route
	local steps = { 'Fale com o responsável aqui e escolha "Começar".' }
	if job.vehicle then
		steps[#steps + 1] = job.vehicle.deposit > 0
			and ('O veículo da empresa sai na vaga ao lado. Ele custa um depósito de %s, devolvido quando você o traz de volta e encerra.'):format(money(job.vehicle.deposit))
			or 'O veículo da empresa sai na vaga ao lado.'
	end
	if r.mode == 'zone' then
		steps[#steps + 1] = 'Leve o veículo até a área marcada no mapa (o círculo no GPS).'
		steps[#steps + 1] = ('Dentro da área, procure lixeiras, caçambas ou sacos de lixo e use "%s". A mesma lixeira só enche de novo depois de %s.'):format(
			r.actionLabel, duration(r.binCooldown))
		steps[#steps + 1] = ('Na traseira do veículo, use "%s" e depois "%s" com o saco na mão.'):format(r.openLabel, r.dropLabel)
		steps[#steps + 1] = ('Cada área pede %d sacos; depois vem a próxima. A rota tem %d áreas e termina com bônus.'):format(r.perZone, r.perRoute)
	elseif r.mode == 'passenger' then
		steps[#steps + 1] = 'Siga o GPS até o passageiro e pare o veículo perto dele, ao volante: ele embarca sozinho.'
		steps[#steps + 1] = 'Leve até o destino marcado no GPS e pare: ele desembarca e a corrida é paga na hora.'
		steps[#steps + 1] = ('Cada rota tem %d corridas; ao fim vem o bônus e uma nova rota.'):format(r.perRoute)
	elseif r.mode == 'collect' then
		steps[#steps + 1] = 'Siga o GPS até a parada e deixe o veículo perto dela.'
		steps[#steps + 1] = ('Use "%s" na parada e depois "%s" no veículo. Cada parada é paga ao guardar.'):format(r.actionLabel, r.dropLabel)
		steps[#steps + 1] = ('Cada rota tem %d paradas; ao fim vem o bônus e uma nova rota no GPS.'):format(r.perRoute)
	else
		steps[#steps + 1] = 'Siga o GPS até a parada e deixe o veículo perto dela.'
		if r.carry then
			steps[#steps + 1] = ('Pegue a carga no veículo ("%s") e entregue a quem espera na parada ("%s").'):format(r.pickupLabel, r.actionLabel)
		else
			steps[#steps + 1] = ('Use "%s" com quem espera na parada.'):format(r.actionLabel)
		end
		steps[#steps + 1] = ('Cada rota tem %d paradas; ao fim vem o bônus e uma nova rota no GPS.'):format(r.perRoute)
	end
	steps[#steps + 1] = job.vehicle and 'Para parar, traga o veículo até aqui e escolha "Encerrar o trabalho".'
		or 'Para parar, volte aqui e escolha "Encerrar o trabalho".'
	if job.uniform then
		steps[#steps + 1] = ('Opcional: trabalhando, peça "%s" ao responsável. Sai ao tirar ou ao encerrar.'):format('Vestir ' .. job.uniform.label:lower())
	end
	return steps
end

local function payLines(job)
	local lines = {}
	if job.gather then
		for _, item in ipairs(productList(job.gather)) do
			if item.price > 0 then
				lines[#lines + 1] = { label = 'Por ' .. item.unit, value = money(item.price) }
			end
		end
	else
		local r = job.route
		local value = money(r.pay) .. (r.payPerKm > 0 and (' + %s por km'):format(money(r.payPerKm)) or '')
		lines[#lines + 1] = { label = r.mode == 'passenger' and 'Por corrida' or r.mode == 'zone' and 'Por saco' or 'Por parada', value = value }
		if r.bonus > 0 then
			lines[#lines + 1] = { label = 'Bônus ao fim da rota', value = money(r.bonus) }
		end
	end
	if job.vehicle then
		lines[#lines + 1] = { label = 'Depósito do veículo', value = job.vehicle.deposit > 0 and money(job.vehicle.deposit) .. ' (volta ao devolver)' or 'Sem depósito' }
	end
	if #job.levels > 1 then
		lines[#lines + 1] = { label = 'Nível do emprego', value = ('+%d%% por nível, até o nível %d'):format(percent(job.levelBonus), #job.levels) }
	end
	return lines
end

local function rules(job)
	local list = {}
	if job.gather then
		list[#list + 1] = 'A carga não vira item: encerrar o trabalho com carga descarta o que você carrega.'
		if job.gather.haul then
			list[#list + 1] = 'Árvores derrubadas somem para todos e rebrotam depois de um tempo.'
		end
		list[#list + 1] = 'Cada venda conta como trabalho concluído e sobe a reputação.'
	else
		list[#list + 1] = 'Cada rota concluída sobe a reputação.'
	end
	if job.vehicle then
		list[#list + 1] = 'Encerrar sem o veículo perto daqui perde o depósito e tira reputação; sair do jogo ou trocar de personagem trabalhando tira mais.'
	end
	return list
end

-- Requisito em texto (nil sem requisito).
function JobGuide.Requires(career, job)
	local req = job.requires
	if not req then
		return nil
	end
	local parts = {}
	if req.career then
		parts[#parts + 1] = ('carreira nível %d'):format(req.career)
	end
	local ids = {}
	for id in pairs(req.skills or {}) do
		ids[#ids + 1] = id
	end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local skill = career.skills[id]
		parts[#parts + 1] = ('%s nível %d'):format(skill and skill.label or id, req.skills[id])
	end
	if req.reputation then
		parts[#parts + 1] = ('reputação %d ou mais'):format(req.reputation)
	end
	return #parts > 0 and table.concat(parts, ', ') or nil
end

-- Guia completo (sem dados do jogador): { id, label, description, kind, steps, pay, rules, skills, requires, tips }.
function JobGuide.Build(career, job)
	local skills = {}
	for _, id in ipairs(job.skills or {}) do
		local skill = career.skills[id]
		if skill then
			local perks = {}
			for perk, value in pairs(skill.perks or {}) do
				perks[#perks + 1] = JobGuide.PerkText(perk, value) .. ' por nível'
			end
			table.sort(perks)
			skills[#skills + 1] = { id = id, label = skill.label, perks = perks }
		end
	end
	return {
		id = job.id, label = job.label, description = job.description, kind = JobGuide.KindLabel(job),
		steps = job.gather and gatherSteps(job) or routeSteps(job),
		pay = payLines(job), rules = rules(job), skills = skills,
		requires = JobGuide.Requires(career, job), tips = job.tips or {}
	}
end
