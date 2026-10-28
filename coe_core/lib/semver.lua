-- lib/semver.lua
-- Implementação SemVer 2.0.0 pura em Lua 5.4 para o COE Framework.
-- Suporta parsing, comparação, bump e avaliação de compatibilidade de versões (ranges).

local SemVer = {}

---@class SemVerData
---@field major integer
---@field minor integer
---@field patch integer
---@field prerelease string|nil
---@field build string|nil

---Faz o parsing de uma string SemVer 2.0.0.
---@param versionStr string
---@return SemVerData|nil, string|nil
function SemVer.Parse(versionStr)
	if type(versionStr) ~= 'string' then
		return nil, 'version_must_be_string'
	end

	-- Limpa espaços e prefixo comum 'v'
	local cleaned = versionStr:gsub('^%s*v?', ''):gsub('%s*$', '')
	if #cleaned == 0 then
		return nil, 'empty_version'
	end

	-- Separa build metadata se existir (+...)
	local withoutBuild, build = cleaned:match('^([^%+]+)%+([%w%.%-]+)$')
	if not withoutBuild then
		withoutBuild = cleaned
	end

	-- Separa prerelease se existir (-...)
	local withoutPre, prerelease = withoutBuild:match('^([^-]+)%-(.+)$')
	if not withoutPre then
		withoutPre = withoutBuild
	end

	-- Agora withoutPre DEVE ser MAJOR.MINOR.PATCH
	local majorStr, minorStr, patchStr = withoutPre:match('^(%d+)%.(%d+)%.(%d+)$')
	if not majorStr then
		return nil, 'invalid_semver_format'
	end

	return {
		major = tonumber(majorStr),
		minor = tonumber(minorStr),
		patch = tonumber(patchStr),
		prerelease = prerelease,
		build = build
	}
end

---Converte uma estrutura SemVerData de volta para string.
---@param v SemVerData
---@return string
function SemVer.Format(v)
	if not v or type(v.major) ~= 'number' then return '0.0.0' end
	local res = string.format('%d.%d.%d', v.major, v.minor, v.patch)
	if v.prerelease and #v.prerelease > 0 then
		res = res .. '-' .. v.prerelease
	end
	if v.build and #v.build > 0 then
		res = res .. '+' .. v.build
	end
	return res
end

---Compara identificadores de pré-release segundo especificação SemVer 2.0.0.
local function comparePrerelease(pre1, pre2)
	if pre1 == pre2 then return 0 end
	-- Versão final sem prerelease tem maior precedência que com prerelease (1.0.0 > 1.0.0-alpha)
	if not pre1 and pre2 then return 1 end
	if pre1 and not pre2 then return -1 end

	local parts1, parts2 = {}, {}
	for part in pre1:gmatch('[^%.]+') do parts1[#parts1 + 1] = part end
	for part in pre2:gmatch('[^%.]+') do parts2[#parts2 + 1] = part end

	local maxParts = math.max(#parts1, #parts2)
	for i = 1, maxParts do
		local p1, p2 = parts1[i], parts2[i]
		if not p1 then return -1 end
		if not p2 then return 1 end

		local n1, n2 = tonumber(p1), tonumber(p2)
		if n1 and n2 then
			if n1 < n2 then return -1 end
			if n1 > n2 then return 1 end
		elseif n1 and not n2 then
			return -1 -- numérico tem menor precedência que textual
		elseif not n1 and n2 then
			return 1
		else
			if p1 < p2 then return -1 end
			if p1 > p2 then return 1 end
		end
	end

	return 0
end

---Compara duas versões SemVer.
---Retorna -1 se v1 < v2, 0 se v1 == v2, 1 se v1 > v2.
---@param v1 string|SemVerData
---@param v2 string|SemVerData
---@return integer|nil, string|nil
function SemVer.Compare(v1, v2)
	local p1 = type(v1) == 'table' and v1 or SemVer.Parse(v1)
	if not p1 then return nil, 'invalid_v1' end

	local p2 = type(v2) == 'table' and v2 or SemVer.Parse(v2)
	if not p2 then return nil, 'invalid_v2' end

	if p1.major < p2.major then return -1 end
	if p1.major > p2.major then return 1 end

	if p1.minor < p2.minor then return -1 end
	if p1.minor > p2.minor then return 1 end

	if p1.patch < p2.patch then return -1 end
	if p1.patch > p2.patch then return 1 end

	return comparePrerelease(p1.prerelease, p2.prerelease)
end

---Verifica se uma versão satisfaz um operador de comparação simples.
---@param v string|SemVerData
---@param op string
---@param target string|SemVerData
---@return boolean
local function checkSimpleCondition(v, op, target)
	local cmp = SemVer.Compare(v, target)
	if cmp == nil then return false end

	if op == '=' or op == '==' or op == '' then
		return cmp == 0
	elseif op == '>=' then
		return cmp >= 0
	elseif op == '<=' then
		return cmp <= 0
	elseif op == '>' then
		return cmp > 0
	elseif op == '<' then
		return cmp < 0
	elseif op == '!=' or op == '~=' then
		return cmp ~= 0
	end

	return false
end

---Verifica se a versão satisfaz um range no padrão SemVer (ex: '>=1.0.0', '^1.2.0', '~1.2.0', '1.0.0 - 2.0.0').
---@param version string|SemVerData
---@param rangeStr string
---@return boolean
function SemVer.Satisfies(version, rangeStr)
	if type(rangeStr) ~= 'string' then return false end
	local parsedVer = type(version) == 'table' and version or SemVer.Parse(version)
	if not parsedVer then return false end

	local cleanRange = rangeStr:gsub('^%s*', ''):gsub('%s*$', '')
	if cleanRange == '*' or cleanRange == '' or cleanRange == 'x' then
		return true
	end

	-- Normaliza espaços entre operador e versão: '>= 1.2.0' -> '>=1.2.0'
	cleanRange = cleanRange:gsub('([><=!~]+)%s+', '%1')

	-- Suporte a Caret: ^1.2.3 -> >=1.2.3 <2.0.0 (se major > 0) ou >=0.2.3 <0.3.0 (se major == 0)
	local caretVer = cleanRange:match('^%^%s*(.+)$')
	if caretVer then
		local target = SemVer.Parse(caretVer)
		if not target then return false end
		if SemVer.Compare(parsedVer, target) < 0 then return false end

		if target.major > 0 then
			local upper = { major = target.major + 1, minor = 0, patch = 0 }
			return SemVer.Compare(parsedVer, upper) < 0
		elseif target.minor > 0 then
			local upper = { major = 0, minor = target.minor + 1, patch = 0 }
			return SemVer.Compare(parsedVer, upper) < 0
		else
			local upper = { major = 0, minor = 0, patch = target.patch + 1 }
			return SemVer.Compare(parsedVer, upper) < 0
		end
	end

	-- Suporte a Tilde: ~1.2.3 -> >=1.2.3 <1.3.0
	local tildeVer = cleanRange:match('^%~%s*(.+)$')
	if tildeVer then
		local target = SemVer.Parse(tildeVer)
		if not target then return false end
		if SemVer.Compare(parsedVer, target) < 0 then return false end
		local upper = { major = target.major, minor = target.minor + 1, patch = 0 }
		return SemVer.Compare(parsedVer, upper) < 0
	end

	-- Suporte a condições combinadas (ex: '>=1.0.0 <2.0.0' ou '>=1.0.0, <=1.5.0')
	local tokens = {}
	for token in cleanRange:gmatch('[^,%s]+') do
		tokens[#tokens + 1] = token
	end

	for _, token in ipairs(tokens) do
		local op, ver = token:match('^([><=!~]+)(.+)$')
		if not op then
			op = '='
			ver = token
		end

		if not checkSimpleCondition(parsedVer, op, ver) then
			return false
		end
	end

	return true
end

---Calcula o próximo número de versão baseado no tipo de incremento (major, minor, patch).
---@param currentVersion string|SemVerData
---@param bumpType 'major'|'minor'|'patch'
---@return string|nil, string|nil
function SemVer.Bump(currentVersion, bumpType)
	local p = type(currentVersion) == 'table' and currentVersion or SemVer.Parse(currentVersion)
	if not p then return nil, 'invalid_current_version' end

	local bump = string.lower(bumpType or 'patch')
	local nextVer = {
		major = p.major,
		minor = p.minor,
		patch = p.patch,
		prerelease = nil,
		build = nil
	}

	if bump == 'major' then
		nextVer.major = nextVer.major + 1
		nextVer.minor = 0
		nextVer.patch = 0
	elseif bump == 'minor' then
		nextVer.minor = nextVer.minor + 1
		nextVer.patch = 0
	elseif bump == 'patch' then
		nextVer.patch = nextVer.patch + 1
	else
		return nil, 'invalid_bump_type (must be major, minor, or patch)'
	end

	return SemVer.Format(nextVer)
end

return SemVer
