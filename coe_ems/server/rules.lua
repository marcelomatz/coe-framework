EmsRules = {}

EmsRules.States = { healthy = true, injured = true, unconscious = true, dead = true }

-- O cliente só reporta o que o próprio jogo mostra; morrer e reviver são decisões do servidor.
local CLIENT_REPORTS = {
	healthy = { injured = true, unconscious = true },
	injured = { healthy = true, unconscious = true }
}

function EmsRules.CanReport(from, to)
	return CLIENT_REPORTS[from] ~= nil and CLIENT_REPORTS[from][to] == true
end

-- Pré-condição do estado do paciente para cada ação. Retorna true ou false, 'invalid_state'.
function EmsRules.CanApply(action, state, config)
	if action == 'revive' then
		if state == 'unconscious' or (state == 'dead' and config.ReviveDead == true) then
			return true
		end
	elseif action == 'treat' then
		if state == 'injured' then
			return true
		end
	elseif action == 'respawn' then
		if state == 'dead' then
			return true
		end
	end
	return false, 'invalid_state'
end

-- Resultado de cada ação no estado do paciente.
EmsRules.Outcome = { revive = 'healthy', treat = 'healthy', respawn = 'healthy' }

function EmsRules.Detail(value)
	if value == nil then
		return ''
	end
	if type(value) ~= 'string' or #value > 32 or not value:match('^[a-z0-9_]*$') then
		return nil, 'invalid_detail'
	end
	return value
end

function EmsRules.InRange(distance, config)
	return type(distance) == 'number' and distance <= config.ActionRange
end

-- Segundos inconsciente até o óbito; 0 desliga.
function EmsRules.BledOut(since, now, config)
	return config.BleedoutSeconds > 0 and now - since >= config.BleedoutSeconds
end
