-- Substituição de resources básicos por pacotes completos, sem o framework citar os pacotes.
-- O básico se declara substituível no próprio fxmanifest:    coe_supervisor_replaceable 'yes'
-- O pacote declara quem substitui no fxmanifest dele:        coe_supervisor_replaces 'coe_mobile'
-- Enquanto um substituto roda (ou pode subir no boot), o básico não inicia; se o substituto parar ou não subir, o
-- básico volta. Regras puras (sem natives), testadas em test/replace_test.lua.
SupervisorReplace = {}

local ACTIVE = { started = true, starting = true }
local PRESENT = { started = true, starting = true, stopped = true, stopping = true }

---resources = { [nome] = { state, replaceable = boolean, replaces = { nomes } } }
---Retorna { [básico] = { substitutos em ordem alfabética } }, só para básicos substituíveis.
function SupervisorReplace.Map(resources)
	local map = {}
	for name, info in pairs(resources) do
		for _, target in ipairs(info.replaces or {}) do
			local basic = resources[target]
			if target ~= name and basic and basic.replaceable then
				map[target] = map[target] or {}
				map[target][#map[target] + 1] = name
			end
		end
	end
	for _, list in pairs(map) do
		table.sort(list)
	end
	return map
end

local function any(list, resources, states)
	for _, name in ipairs(list or {}) do
		local info = resources[name]
		if info and states[info.state] then
			return name
		end
	end
	return nil
end

---Substituto rodando (ou subindo) agora, ou nil.
function SupervisorReplace.ActiveReplacer(basic, map, resources)
	return any(map[basic], resources, ACTIVE)
end

---O básico pode iniciar? Não, se um substituto roda; nem no boot (antes de assentar) se há substituto instalado,
---porque o substituto pode subir logo depois na ordem alfabética.
---Retorna permitido, substituto (o que roda ou o que está instalado).
function SupervisorReplace.CanStart(basic, map, resources, settled)
	local active = SupervisorReplace.ActiveReplacer(basic, map, resources)
	if active then
		return false, active
	end
	if not settled then
		local present = any(map[basic], resources, PRESENT)
		if present then
			return false, present
		end
	end
	return true, nil
end

---Ações para acertar o estado depois que os resources assentam:
---- substituto rodando e básico rodando: parar o básico;
---- nenhum substituto rodando e básico segurado por nós: iniciar o básico.
---held = { [básico] = true } (os que o supervisor impediu ou parou). Retorna { { op, name, replacer } }.
function SupervisorReplace.Reconcile(map, resources, held)
	local actions = {}
	local names = {}
	for basic in pairs(map) do
		names[#names + 1] = basic
	end
	for basic in pairs(held) do
		if not map[basic] then
			names[#names + 1] = basic
		end
	end
	table.sort(names)
	for _, basic in ipairs(names) do
		local info = resources[basic]
		local active = SupervisorReplace.ActiveReplacer(basic, map, resources)
		if info then
			if active and ACTIVE[info.state] then
				actions[#actions + 1] = { op = 'stop', name = basic, replacer = active }
			elseif not active and held[basic] and info.state == 'stopped' then
				actions[#actions + 1] = { op = 'start', name = basic }
			end
		end
	end
	return actions
end
