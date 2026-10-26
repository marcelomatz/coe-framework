-- Verificador de versão SemVer e planejador de atualização de resources a partir do repositório oficial.
-- Regras puras (sem natives), testadas em test/updater_test.lua.
SupervisorUpdater = {}

local PRERELEASE_RANK = {
	alpha = 1,
	beta = 2,
	rc = 3
}

---Interpreta uma versão SemVer (ex.: '0.1.0-beta.1', 'v0.1.0-rc.2', '0.1.0').
---@param raw string|nil
---@return table|nil parsed
function SupervisorUpdater.ParseVersion(raw)
	if type(raw) ~= 'string' then
		return nil
	end
	local clean = raw:gsub('^%s+', ''):gsub('%s+$', ''):gsub('^[vV]', '')
	local majorStr, minorStr, patchStr, rest = clean:match('^(%d+)%.(%d+)%.(%d+)(.*)$')
	if not majorStr then
		return nil
	end
	local major = tonumber(majorStr)
	local minor = tonumber(minorStr)
	local patch = tonumber(patchStr)
	if not (major and minor and patch) then
		return nil
	end

	local prerelease = {}
	local channel = 'stable'
	if rest and rest ~= '' then
		local pre = rest:match('^%-([0-9A-Za-z%.%-]+)$')
		if not pre then
			return nil
		end
		for token in pre:gmatch('[^%.]+') do
			local num = tonumber(token)
			if num and tostring(num) == token then
				prerelease[#prerelease + 1] = num
			else
				prerelease[#prerelease + 1] = token:lower()
			end
		end
		if type(prerelease[1]) == 'string' then
			channel = prerelease[1]
		else
			channel = 'prerelease'
		end
	end

	return {
		raw = clean,
		major = major,
		minor = minor,
		patch = patch,
		prerelease = prerelease,
		channel = channel
	}
end

local function compareIdentifiers(left, right)
	if left == right then
		return 0
	end
	local leftNum = type(left) == 'number'
	local rightNum = type(right) == 'number'
	if leftNum and rightNum then
		return left < right and -1 or 1
	end
	if not leftNum and not rightNum then
		local lRank = PRERELEASE_RANK[left]
		local rRank = PRERELEASE_RANK[right]
		if lRank and rRank and lRank ~= rRank then
			return lRank < rRank and -1 or 1
		end
		return left < right and -1 or 1
	end
	-- Identificadores numéricos têm precedência menor que alfanuméricos na especificação SemVer 2.0.
	return leftNum and -1 or 1
end

---Compara duas versões SemVer: retorna -1 se left < right, 0 se iguais, 1 se left > right, ou nil se inválidas.
---@param left string|table
---@param right string|table
---@return integer|nil cmp
function SupervisorUpdater.CompareVersions(left, right)
	local l = type(left) == 'table' and left or SupervisorUpdater.ParseVersion(left)
	local r = type(right) == 'table' and right or SupervisorUpdater.ParseVersion(right)
	if not l or not r then
		return nil
	end
	if l.major ~= r.major then
		return l.major < r.major and -1 or 1
	end
	if l.minor ~= r.minor then
		return l.minor < r.minor and -1 or 1
	end
	if l.patch ~= r.patch then
		return l.patch < r.patch and -1 or 1
	end

	local lPre = l.prerelease or {}
	local rPre = r.prerelease or {}
	if #lPre == 0 and #rPre == 0 then
		return 0
	end
	-- Release estável (sem sufixo) é mais nova que pre-release de mesmo major.minor.patch.
	if #lPre == 0 then
		return 1
	end
	if #rPre == 0 then
		return -1
	end

	local limit = math.max(#lPre, #rPre)
	for index = 1, limit do
		local li = lPre[index]
		local ri = rPre[index]
		if li == nil then
			return -1
		end
		if ri == nil then
			return 1
		end
		local cmp = compareIdentifiers(li, ri)
		if cmp ~= 0 then
			return cmp
		end
	end
	return 0
end

---Retorna true somente quando `remoteVer` é estritamente mais nova que `localVer`.
---@param localVer string|nil
---@param remoteVer string|nil
---@return boolean newer
function SupervisorUpdater.IsNewer(localVer, remoteVer)
	if not remoteVer then
		return false
	end
	if not localVer or localVer == '' then
		return SupervisorUpdater.ParseVersion(remoteVer) ~= nil
	end
	local cmp = SupervisorUpdater.CompareVersions(localVer, remoteVer)
	return cmp == -1
end

---Valida e normaliza um caminho relativo de arquivo dentro de um resource (previne path traversal).
---@param relPath string|nil
---@return string|nil safePath
function SupervisorUpdater.SanitizeRelativePath(relPath)
	if type(relPath) ~= 'string' or #relPath == 0 or #relPath > 240 then
		return nil
	end
	if relPath:find('[%c:]') then
		return nil
	end
	local norm = relPath:gsub('\\', '/')
	if norm:sub(1, 1) == '/' or norm:sub(-1) == '/' or norm:find('//', 1, true) then
		return nil
	end
	for segment in norm:gmatch('[^/]+') do
		if segment == '.' or segment == '..' or segment == '' then
			return nil
		end
	end
	return norm
end

---Monta o plano de atualização comparando manifesto local, versões instaladas e manifesto remoto.
---@param localManifest table|nil
---@param remoteManifest table|nil
---@param installedVersions table<string, string|nil>|nil
---@param catalog table<string, table>|nil
---@param rawBaseUrl string|nil
---@return table|nil plan
---@return string|nil errorCode
function SupervisorUpdater.BuildUpdatePlan(localManifest, remoteManifest, installedVersions, catalog, rawBaseUrl)
	if type(remoteManifest) ~= 'table' or type(remoteManifest.version) ~= 'string' then
		return nil, 'invalid_remote_manifest'
	end
	local parsedRemote = SupervisorUpdater.ParseVersion(remoteManifest.version)
	if not parsedRemote then
		return nil, 'invalid_remote_version'
	end

	local localVer = (type(localManifest) == 'table' and type(localManifest.version) == 'string' and localManifest.version) or '0.1.0-beta.1'
	local parsedLocal = SupervisorUpdater.ParseVersion(localVer)
	local localVersionStr = parsedLocal and parsedLocal.raw or localVer
	local remoteVersionStr = parsedRemote.raw

	local frameworkNewer = SupervisorUpdater.IsNewer(localVersionStr, remoteVersionStr)
	local remoteResources = type(remoteManifest.resources) == 'table' and remoteManifest.resources or {}
	local localResources = (type(localManifest) == 'table' and type(localManifest.resources) == 'table') and localManifest.resources or {}
	local installed = type(installedVersions) == 'table' and installedVersions or {}

	local repo = type(remoteManifest.repository) == 'string' and remoteManifest.repository ~= '' and remoteManifest.repository or 'marcelomatz/coe-framework'
	local branch = type(remoteManifest.branch) == 'string' and remoteManifest.branch ~= '' and remoteManifest.branch or 'main'
	local base = (type(rawBaseUrl) == 'string' and rawBaseUrl ~= '' and rawBaseUrl:gsub('/+$', ''))
		or ('https://raw.githubusercontent.com/' .. repo .. '/' .. branch)

	local outdatedResources = {}
	local downloads = {}
	local requiresFullRestart = false

	local names = {}
	for resName in pairs(remoteResources) do
		if type(resName) == 'string' and resName:match('^[%w_%-]+$') then
			names[#names + 1] = resName
		end
	end
	table.sort(names)

	for _, resName in ipairs(names) do
		local remoteEntry = remoteResources[resName]
		local remoteResVer = (type(remoteEntry) == 'table' and remoteEntry.version) or remoteVersionStr
		local localEntry = localResources[resName]
		local localResVer = installed[resName]
			or (type(localEntry) == 'table' and localEntry.version)
			or (type(localEntry) == 'string' and localEntry)
			or localVersionStr

		local resOutdated = frameworkNewer or SupervisorUpdater.IsNewer(localResVer, remoteResVer)
		if resOutdated then
			outdatedResources[#outdatedResources + 1] = resName
			local catEntry = catalog and catalog[resName]
			if resName == 'coe_supervisor' or (catEntry and catEntry.critical == true) then
				requiresFullRestart = true
			end
			local files = type(remoteEntry) == 'table' and type(remoteEntry.files) == 'table' and remoteEntry.files or { 'fxmanifest.lua' }
			for _, rel in ipairs(files) do
				local safeRel = SupervisorUpdater.SanitizeRelativePath(rel)
				if safeRel then
					downloads[#downloads + 1] = {
						resource = resName,
						file = safeRel,
						url = string.format('%s/%s/%s', base, resName, safeRel)
					}
				end
			end
		end
	end

	local available = frameworkNewer or (#outdatedResources > 0)

	-- Identificação e validação de releases pendentes / atrasadas
	local pendingReleases = {}
	local pendingVersions = {}
	local seenPending = {}

	if type(remoteManifest.releases) == 'table' then
		for _, rel in ipairs(remoteManifest.releases) do
			if type(rel) == 'table' and type(rel.version) == 'string' then
				local relVerStr = rel.version:gsub('^[vV]', '')
				if not seenPending[relVerStr] and SupervisorUpdater.IsNewer(localVersionStr, relVerStr) then
					seenPending[relVerStr] = true
					local pRel = SupervisorUpdater.ParseVersion(relVerStr)
					pendingReleases[#pendingReleases + 1] = {
						version = relVerStr,
						tag = rel.tag or ('v' .. relVerStr),
						channel = rel.channel or (pRel and pRel.channel) or 'beta',
						date = rel.date or '',
						notes = rel.notes or ''
					}
				end
			end
		end
	end

	-- Se a lista de releases não mapeou a versão remota alvo mas o framework é mais novo, inclui a versão remota
	if not seenPending[remoteVersionStr] and frameworkNewer then
		seenPending[remoteVersionStr] = true
		pendingReleases[#pendingReleases + 1] = {
			version = remoteVersionStr,
			tag = type(remoteManifest.tag) == 'string' and remoteManifest.tag or ('v' .. remoteVersionStr),
			channel = type(remoteManifest.channel) == 'string' and remoteManifest.channel or parsedRemote.channel,
			date = type(remoteManifest.date) == 'string' and remoteManifest.date or '',
			notes = type(remoteManifest.notes) == 'string' and remoteManifest.notes or ''
		}
	end

	-- Ordena em ordem cronológica de aplicação (da versão mais antiga para a mais recente)
	table.sort(pendingReleases, function(a, b)
		local cmp = SupervisorUpdater.CompareVersions(a.version, b.version)
		return (cmp or 0) < 0
	end)

	for _, rel in ipairs(pendingReleases) do
		pendingVersions[#pendingVersions + 1] = rel.tag
	end

	local pendingCount = #pendingReleases
	local isCumulative = pendingCount >= 2
	local planType = isCumulative and 'cumulative' or 'direct'
	local planSummary = isCumulative
		and string.format('Plano de atualização cumulativo: %d releases pendentes (%s)', pendingCount, table.concat(pendingVersions, ' → '))
		or (pendingCount == 1 and ('Atualização direta para ' .. pendingReleases[1].tag) or 'Atualização direta')

	return {
		available = available,
		localVersion = localVersionStr,
		remoteVersion = remoteVersionStr,
		tag = type(remoteManifest.tag) == 'string' and remoteManifest.tag or ('v' .. remoteVersionStr),
		channel = type(remoteManifest.channel) == 'string' and remoteManifest.channel or parsedRemote.channel,
		notes = type(remoteManifest.notes) == 'string' and remoteManifest.notes or '',
		repository = repo,
		branch = branch,
		outdatedResources = outdatedResources,
		outdatedCount = #outdatedResources,
		downloads = downloads,
		filesCount = #downloads,
		requiresFullRestart = requiresFullRestart,
		-- Múltiplas releases e plano cumulativo de atualização
		pendingReleases = pendingReleases,
		pendingVersions = pendingVersions,
		pendingCount = pendingCount,
		isCumulative = isCumulative,
		planType = planType,
		planSummary = planSummary
	}, nil
end
