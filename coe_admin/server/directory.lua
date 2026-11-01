AdminDirectory = {}

-- Busca de personagens por nome ou ID público para os painéis.
-- Custo controlado em três camadas: jogadores online saem da memória (sem banco); a consulta ao banco é por
-- prefixo (índices em first_name/last_name), limitada e com mínimo de caracteres; e o resultado fica em cache
-- com TTL e tamanho máximo, inclusive buscas sem resultado.
-- deps: query(sql, params) -> rows|nil,erro; online() -> { { characterId, stateId, name } }; now() -> ms;
-- isStateId(texto) -> bool.
function AdminDirectory.New(deps, options)
	options = options or {}
	local ttlMs = options.ttlMs or 30000
	local maxEntries = options.maxEntries or 200
	local minLength = options.minLength or 2
	local limit = options.limit or 10
	local maxTokens = 3
	local maxTokenLength = 24

	local cache, size, stats = {}, 0, { hits = 0, misses = 0, queries = 0 }
	local service = {}

	-- Minúsculas, espaços colapsados e curingas do LIKE neutralizados.
	function service.Tokens(term)
		if type(term) ~= 'string' then
			return nil
		end
		local text = term:lower():gsub('[%c\\%%_]', ' ')
		local tokens = {}
		for word in text:gmatch('%S+') do
			if #tokens >= maxTokens then
				break
			end
			tokens[#tokens + 1] = word:sub(1, maxTokenLength)
		end
		if #tokens == 0 or #table.concat(tokens) < minLength then
			return nil
		end
		return tokens
	end

	local function matchesOnline(entry, tokens)
		local words = {}
		for word in (entry.name or ''):lower():gmatch('%S+') do
			words[#words + 1] = word
		end
		for _, token in ipairs(tokens) do
			local found = false
			for _, word in ipairs(words) do
				if word:sub(1, #token) == token then
					found = true
					break
				end
			end
			if not found then
				return false
			end
		end
		return true
	end

	local function fullName(row)
		return ('%s %s'):format(row.first_name or '', row.last_name or ''):gsub('^%s+', ''):gsub('%s+$', '')
	end

	local function store(key, value)
		local now = deps.now()
		if cache[key] == nil then
			if size >= maxEntries then
				for cachedKey, entry in pairs(cache) do
					if now - entry.at >= ttlMs then
						cache[cachedKey] = nil
						size = size - 1
					end
				end
			end
			if size >= maxEntries then
				cache, size = {}, 0
			end
			size = size + 1
		end
		cache[key] = { at = now, value = value }
	end

	local function cached(key)
		local entry = cache[key]
		if entry and deps.now() - entry.at < ttlMs then
			stats.hits = stats.hits + 1
			return entry.value
		end
		stats.misses = stats.misses + 1
		return nil
	end

	local function fromRows(rows, onlineByCharacter)
		local list = {}
		for _, row in ipairs(rows) do
			local characterId = tostring(row.character_id)
			list[#list + 1] = {
				characterId = characterId,
				stateId = row.state_id,
				name = fullName(row):sub(1, 48),
				online = onlineByCharacter[characterId] == true
			}
		end
		return list
	end

	-- Retorna lista de { characterId, stateId, name, online } ou nil,erro.
	function service.Search(term)
		local online, onlineByCharacter = deps.online() or {}, {}
		for _, entry in ipairs(online) do
			onlineByCharacter[tostring(entry.characterId)] = true
		end

		local exact = type(term) == 'string' and term:match('^%s*(%S+)%s*$')
		exact = exact and deps.isStateId(exact:upper()) and exact:upper() or nil

		local rows, key
		if exact then
			key = 'id:' .. exact
			local hit = cached(key)
			if hit then
				return fromRows(hit, onlineByCharacter)
			end
			stats.queries = stats.queries + 1
			local queryError
			rows, queryError = deps.query(
				'SELECT character_id, state_id, first_name, last_name FROM coe_characters WHERE state_id = ? AND archived_at IS NULL LIMIT 1',
				{ exact }
			)
			if not rows then
				return nil, queryError or 'database_error'
			end
			store(key, rows)
			return fromRows(rows, onlineByCharacter)
		end

		local tokens = service.Tokens(term)
		if not tokens then
			return nil, 'term_too_short'
		end

		local results, seen = {}, {}
		for _, entry in ipairs(online) do
			if #results < limit and matchesOnline(entry, tokens) then
				seen[tostring(entry.characterId)] = true
				results[#results + 1] = {
					characterId = tostring(entry.characterId), stateId = entry.stateId, name = entry.name, online = true
				}
			end
		end
		if #results >= limit then
			return results
		end

		key = 'name:' .. table.concat(tokens, ' ')
		rows = cached(key)
		if not rows then
			local conditions, parameters = {}, {}
			for _, token in ipairs(tokens) do
				conditions[#conditions + 1] = '(first_name LIKE ? OR last_name LIKE ?)'
				parameters[#parameters + 1] = token .. '%'
				parameters[#parameters + 1] = token .. '%'
			end
			parameters[#parameters + 1] = limit
			stats.queries = stats.queries + 1
			local queryError
			rows, queryError = deps.query(
				'SELECT character_id, state_id, first_name, last_name FROM coe_characters WHERE archived_at IS NULL AND '
					.. table.concat(conditions, ' AND ') .. ' ORDER BY first_name, last_name LIMIT ?',
				parameters
			)
			if not rows then
				return nil, queryError or 'database_error'
			end
			store(key, rows)
		end
		for _, entry in ipairs(fromRows(rows, onlineByCharacter)) do
			if #results < limit and not seen[entry.characterId] then
				results[#results + 1] = entry
			end
		end
		return results
	end

	function service.Invalidate()
		cache, size = {}, 0
	end

	function service.Stats()
		return { hits = stats.hits, misses = stats.misses, queries = stats.queries, entries = size }
	end

	return service
end
