PoliceRules = {}

-- Valor inteiro dentro de 1..max; retorna o inteiro ou nil, codigo.
local function wholeNumber(value, max, errorCode)
	if type(value) ~= 'number' or value ~= value or value % 1 ~= 0 or value < 1 or value > max then
		return nil, errorCode
	end
	return math.tointeger(value)
end

function PoliceRules.Fine(value, config)
	return wholeNumber(value, config.MaxFine, 'invalid_amount')
end

function PoliceRules.Minutes(value, config)
	return wholeNumber(value, config.MaxSentenceMinutes, 'invalid_sentence')
end

-- Motivo da multa ou prisão: código curto, sem texto livre.
function PoliceRules.Charge(value)
	if type(value) ~= 'string' or #value < 2 or #value > 32 or not value:match('^[a-z0-9_]+$') then
		return nil, 'invalid_charge'
	end
	return value
end

-- Pré-condição do alvo por ação. Retorna true ou false, codigo.
function PoliceRules.CanApply(action, cuffed, jailed)
	if jailed then
		return false, 'already_jailed'
	end
	if action == 'cuff' then
		return not cuffed, 'already_cuffed'
	elseif action == 'uncuff' or action == 'jail' or action == 'search' or action == 'seize' or action == 'escort' then
		return cuffed, 'not_cuffed'
	elseif action == 'fine' then
		return true
	end
	return false, 'invalid_action'
end

-- Apreensão: slot e quantidade inteiros e limitados.
function PoliceRules.Seizure(slot, count)
	local cleanSlot = wholeNumber(slot, 200, 'invalid_slot')
	if not cleanSlot then
		return nil, 'invalid_slot'
	end
	local cleanCount = wholeNumber(count, 9999, 'invalid_count')
	if not cleanCount then
		return nil, 'invalid_count'
	end
	return cleanSlot, cleanCount
end

-- Resumo da revista: só nome, rótulo e quantidade; ignora slots vazios e entradas malformadas.
function PoliceRules.SearchList(snapshot, limit)
	local list = {}
	if type(snapshot) ~= 'table' or type(snapshot.items) ~= 'table' then
		return list
	end
	for slot = 1, tonumber(snapshot.slots) or 0 do
		local item = snapshot.items[slot]
		if type(item) == 'table' and type(item.name) == 'string' and type(item.count) == 'number' then
			list[#list + 1] = { slot = slot, name = item.name, label = tostring(item.label or item.name), count = item.count }
			if #list >= limit then
				break
			end
		end
	end
	return list
end

function PoliceRules.InRange(distance, config)
	return type(distance) == 'number' and distance <= config.ActionRange
end

function PoliceRules.ReleaseAt(now, minutes)
	return now + minutes * 60
end

-- Segundos que faltam; 0 quando a pena acabou.
function PoliceRules.Remaining(releaseAt, now)
	return math.max(releaseAt - now, 0)
end
