-- Amostragem probabilística em tempo constante O(1) via Método de Alias de Vose
-- com suporte a lotes (sampleBatch) e itens únicos (unique = true).
local math_random = math.random
local table_wipe = table.wipe or function(t)
	for k in pairs(t) do
		t[k] = nil
	end
end

local Sampling = {}

---@param entries { item: any, weight: number, unique?: boolean }[]
---@return CoeAliasSampler
function Sampling.newAliasTable(entries)
	local n = #entries
	assert(n > 0, 'Tabela de amostragem nao pode ser vazia')
	local totalWeight = 0.0
	for i = 1, n do
		local w = entries[i].weight
		assert(w and w >= 0, 'Peso invalido na entrada ' .. tostring(i))
		totalWeight = totalWeight + w
	end
	assert(totalWeight > 0, 'Soma dos pesos deve ser maior que zero')

	local prob = {}
	local alias = {}
	local items = {}
	local uniqueFlags = {}
	local scaled = {}
	local small, large = {}, {}
	local nSmall, nLarge = 0, 0
	local scaleFactor = n / totalWeight

	for i = 1, n do
		items[i] = entries[i].item ~= nil and entries[i].item or entries[i].value
		uniqueFlags[i] = entries[i].unique == true
		local s = entries[i].weight * scaleFactor
		scaled[i] = s
		if s < 1.0 then
			nSmall = nSmall + 1
			small[nSmall] = i
		else
			nLarge = nLarge + 1
			large[nLarge] = i
		end
	end

	while nSmall > 0 and nLarge > 0 do
		local l = small[nSmall]
		nSmall = nSmall - 1
		local g = large[nLarge]
		nLarge = nLarge - 1
		prob[l] = scaled[l]
		alias[l] = g
		local newScaledG = (scaled[g] + scaled[l]) - 1.0
		scaled[g] = newScaledG
		if newScaledG < 1.0 then
			nSmall = nSmall + 1
			small[nSmall] = g
		else
			nLarge = nLarge + 1
			large[nLarge] = g
		end
	end

	while nLarge > 0 do
		local g = large[nLarge]
		nLarge = nLarge - 1
		prob[g] = 1.0
		alias[g] = g
	end
	while nSmall > 0 do
		local l = small[nSmall]
		nSmall = nSmall - 1
		prob[l] = 1.0
		alias[l] = l
	end

	local sampler = {
		count = n,
		prob = prob,
		alias = alias,
		items = items,
		uniqueFlags = uniqueFlags
	}

	function sampler:sample(rngFloat, rngInt)
		local rInt = rngInt and rngInt(1, self.count) or math_random(1, self.count)
		local rFloat = rngFloat and rngFloat() or math_random()
		local idx = (rFloat < self.prob[rInt]) and rInt or self.alias[rInt]
		return self.items[idx], idx
	end

	function sampler:sampleBatch(rolls, seenUnique, outBuffer)
		local results = outBuffer or {}
		if outBuffer then
			table_wipe(results)
		end
		local seen = seenUnique or {}
		local outCount = 0
		for _ = 1, rolls do
			local item, idx = self:sample()
			if item ~= nil then
				if self.uniqueFlags[idx] then
					if not seen[item] then
						seen[item] = true
						outCount = outCount + 1
						results[outCount] = item
					end
				else
					outCount = outCount + 1
					results[outCount] = item
				end
			end
		end
		return results, outCount
	end

	return sampler
end

return Sampling
