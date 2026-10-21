Rules = {}

local function round1(value)
	return math.floor(value * 10 + 0.5) / 10
end

-- Sanitiza uma frequencia de radio informada (string ou numero).
function Rules.SanitizeFrequency(raw, min, max)
	local freq = tonumber(raw)
	if not freq or freq ~= freq then
		return nil
	end
	freq = round1(freq)
	local minFreq = min or (Config and Config.Radio and Config.Radio.minFrequency) or 1.0
	local maxFreq = max or (Config and Config.Radio and Config.Radio.maxFrequency) or 999.9
	if freq < minFreq or freq > maxFreq then
		return nil
	end
	return freq
end

-- Verifica se o jogador pode acessar a frequencia (restricoes de servico).
function Rules.CanAccessFrequency(frequency, jobName, restrictedList)
	local list = restrictedList or (Config and Config.Radio and Config.Radio.restricted) or {}
	local rounded = math.floor(frequency)
	local rule = list[rounded]
	if not rule then
		-- Canal publico
		return true
	end
	if not jobName or jobName == '' then
		return false
	end
	for _, allowed in ipairs(rule.jobs or {}) do
		if allowed == jobName then
			return true
		end
	end
	return false
end

-- Retorna o modo de proximidade por indice.
function Rules.GetModeByIndex(index, modes)
	local list = modes or (Config and Config.Modes) or {}
	if #list == 0 then
		return { id = 'normal', label = 'Normal', distance = 5.0, level = 2 }
	end
	local i = math.max(1, math.min(#list, math.floor(tonumber(index) or 1)))
	return list[i]
end

-- Retorna o proximo indice do modo em loop.
function Rules.NextModeIndex(currentIndex, modes)
	local list = modes or (Config and Config.Modes) or {}
	local total = #list
	if total <= 1 then
		return 1
	end
	local current = math.floor(tonumber(currentIndex) or 1)
	if current >= total then
		return 1
	end
	return current + 1
end

-- Aumenta o alcance da voz (Subir). Retorna o novo indice e se mudou.
function Rules.IncreaseModeIndex(currentIndex, modes)
	local list = modes or (Config and Config.Modes) or {}
	local total = #list
	local current = math.floor(tonumber(currentIndex) or 1)
	if current >= total then
		return total, false
	end
	return current + 1, true
end

-- Diminui o alcance da voz (Baixar). Retorna o novo indice e se mudou.
function Rules.DecreaseModeIndex(currentIndex, modes)
	local current = math.floor(tonumber(currentIndex) or 1)
	if current <= 1 then
		return 1, false
	end
	return current - 1, true
end

-- Sanitiza o volume de 0 a 100.
function Rules.SanitizeVolume(raw, fallback)
	local vol = tonumber(raw)
	if not vol or vol ~= vol then
		return fallback or 80
	end
	vol = math.floor(math.max(0, math.min(100, vol)) + 0.5)
	return vol
end
