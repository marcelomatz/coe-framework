Rules = {}

function Rules.FormatUptime(seconds)
	seconds = math.max(0, tonumber(seconds) or 0)
	local hours = math.floor(seconds / 3600)
	local mins = math.floor((seconds % 3600) / 60)
	local secs = math.floor(seconds % 60)
	if hours > 0 then
		return string.format('%dh %02dm', hours, mins)
	end
	return string.format('%dm %02ds', mins, secs)
end

function Rules.FormatCurrency(amount)
	amount = tonumber(amount) or 0
	local formatted = tostring(math.floor(amount))
	local k
	while true do
		formatted, k = string.gsub(formatted, '^(-?%d+)(%d%d%d)', '%1.%2')
		if k == 0 then break end
	end
	return 'R$ ' .. formatted
end

function Rules.BuildPayload(character, serverInfo)
	character = character or {}
	serverInfo = serverInfo or {}

	local payload = {
		character = {
			name = character.name or 'Cidadão',
			stateId = character.stateId or 'COE0000',
			job = character.job or 'Desempregado',
			jobGrade = character.jobGrade or 'N/A',
			faction = character.faction or 'Nenhuma',
			factionGrade = character.factionGrade or 'N/A',
			bank = Rules.FormatCurrency(character.bank or 0),
			bankRaw = character.bank or 0,
			birthDate = character.birthDate or 'Desconhecida',
			gender = character.gender == 'female' and 'Feminino' or (character.gender == 'male' and 'Masculino' or 'Outro'),
			createdAt = character.createdAt or 'N/A'
		},
		server = {
			name = serverInfo.name or (Config and Config.ServerName) or 'COE Enhanced RP',
			sub = serverInfo.sub or (Config and Config.ServerSub) or 'ENHANCED ROLEPLAY',
			onlinePlayers = serverInfo.onlinePlayers or 1,
			maxPlayers = serverInfo.maxPlayers or 128,
			ping = serverInfo.ping or 0,
			uptime = Rules.FormatUptime(serverInfo.uptime or 0),
			discord = (Config and Config.Discord) or 'discord.gg/coerp',
			website = (Config and Config.Website) or 'https://coerp.com.br'
		},
		quickBinds = (Config and Config.QuickBinds) or {},
		rules = (Config and Config.Rules) or {}
	}

	return payload
end
