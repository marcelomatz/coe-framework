-- Motor de detecção estatística e comportamental anti-cheat:
-- Welford Online + EWMA + Tabular CUSUM, Entropia de Shannon, Dead-Reckoning e Disjoint-Set Union-Find.
local math_sqrt = math.sqrt
local math_max = math.max
local math_log = math.log

local Anomaly = {}

--- 1. Rastreador Estatístico Welford + EWMA + Tabular CUSUM (O(1) Memória e Tempo)
---@param targetMean number Média esperada normal mu_0 (ex.: 0.20 para razão de headshots)
---@param slackK number Folga k de sensibilidade CUSUM (ex.: 0.10)
---@param thresholdH number Limiar de decisão H para alarme (ex.: 2.50)
---@param ewmaAlpha? number Peso exponencial alpha (padrão: 0.25)
function Anomaly.newWelfordCUSUM(targetMean, slackK, thresholdH, ewmaAlpha)
	local alpha = ewmaAlpha or 0.25
	return {
		n = 0,
		mean = 0.0,
		M2 = 0.0,
		ewma = targetMean,
		mu0 = targetMean,
		k = slackK,
		h = thresholdH,
		sPos = 0.0,
		sNeg = 0.0,
		observe = function(self, x)
			self.n = self.n + 1
			local delta = x - self.mean
			self.mean = self.mean + (delta / self.n)
			local delta2 = x - self.mean
			self.M2 = self.M2 + (delta * delta2)

			local variance = (self.n > 1) and (self.M2 / (self.n - 1)) or 0.0
			local stdDev = math_sqrt(variance)

			self.ewma = (alpha * x) + ((1.0 - alpha) * self.ewma)
			self.sPos = math_max(0.0, self.sPos + (x - self.mu0 - self.k))
			self.sNeg = math_max(0.0, self.sNeg + (self.mu0 - self.k - x))

			local isAlarm = (self.sPos > self.h) or (self.sNeg > self.h)
			return {
				count = self.n,
				mean = self.mean,
				variance = variance,
				stdDev = stdDev,
				ewma = self.ewma,
				cusumPos = self.sPos,
				cusumNeg = self.sNeg,
				isAlarm = isAlarm,
				cusumAlarm = isAlarm
			}
		end,
		resetCUSUM = function(self)
			self.sPos = 0.0
			self.sNeg = 0.0
		end
	}
end

--- 2. Cálculo de Entropia de Shannon H(X) em bits sobre distribuição de frequências
---@param counts table<any, integer> Mapa de categoria -> contagem de ocorrências
---@return number entropyBits, integer totalSamples
function Anomaly.shannonEntropy(counts)
	local total = 0
	for _, c in pairs(counts) do
		total = total + c
	end
	if total == 0 then
		return 0.0, 0
	end
	local invTotal = 1.0 / total
	local invLn2 = 1.0 / math_log(2.0)
	local entropy = 0.0
	for _, c in pairs(counts) do
		if c > 0 then
			local p = c * invTotal
			entropy = entropy - (p * (math_log(p) * invLn2))
		end
	end
	return entropy, total
end

--- 3. Verificador Cinemático Dead-Reckoning (Anti-Teleport / Speedhack)
function Anomaly.verifyKinematics(x1, y1, z1, t1Ms, x2, y2, z2, t2Ms, maxAllowedSpeedMps, jitterAllowanceMeters)
	local dtSec = (t2Ms - t1Ms) * 0.001
	if dtSec <= 0.001 then
		dtSec = 0.001
	end
	local dx, dy, dz = x2 - x1, y2 - y1, z2 - z1
	local distHoriz = math_sqrt(dx * dx + dy * dy)
	local dist3D = math_sqrt(dx * dx + dy * dy + dz * dz)

	local maxHorizDist = (maxAllowedSpeedMps * dtSec) + (jitterAllowanceMeters or 8.0)
	-- Permite velocidade terminal de queda livre em Z (-75 m/s) mas restringe ganho vertical abrupto
	local maxAscentDist = (math_max(maxAllowedSpeedMps, 25.0) * dtSec) + (jitterAllowanceMeters or 8.0)

	if distHoriz > maxHorizDist then
		return false, 'horizontal_speed_exceeded', distHoriz / dtSec
	end
	if dz > maxAscentDist then
		return false, 'vertical_teleport_exceeded', dz / dtSec
	end
	return true, nil, dist3D / dtSec
end

--- 4. Disjoint-Set Union-Find para Grafo de Identidade e Hardware Tokens (Anti-Spoofer Ban Evasion)
function Anomaly.newIdentityGraph()
	local parent = {}
	local rank = {}
	local bannedRoots = {}

	local function find(x)
		local p = parent[x]
		if not p then
			parent[x] = x
			rank[x] = 0
			return x
		end
		if p ~= x then
			parent[x] = find(p)
		end
		return parent[x]
	end

	local function union(a, b)
		local rootA, rootB = find(a), find(b)
		if rootA == rootB then
			return rootA
		end
		local rA, rB = rank[rootA], rank[rootB]
		local newRoot
		if rA < rB then
			parent[rootA] = rootB
			newRoot = rootB
		elseif rA > rB then
			parent[rootB] = rootA
			newRoot = rootA
		else
			parent[rootB] = rootA
			rank[rootA] = rA + 1
			newRoot = rootA
		end
		if bannedRoots[rootA] or bannedRoots[rootB] then
			bannedRoots[newRoot] = bannedRoots[rootA] or bannedRoots[rootB]
		end
		return newRoot
	end

	return {
		linkIdentityCluster = function(_, identifiersAndTokens)
			local n = #identifiersAndTokens
			if n == 0 then
				return nil, false, nil
			end
			local first = identifiersAndTokens[1]
			local root = find(first)
			for i = 2, n do
				root = union(first, identifiersAndTokens[i])
			end
			return root, bannedRoots[root] ~= nil, bannedRoots[root]
		end,
		banCluster = function(_, tokenOrId, banReason)
			local root = find(tokenOrId)
			bannedRoots[root] = banReason or 'banned_cluster'
			return root
		end,
		isBanned = function(_, tokenOrId)
			local root = find(tokenOrId)
			return bannedRoots[root] ~= nil, bannedRoots[root]
		end
	}
end

return Anomaly
