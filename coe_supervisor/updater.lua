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

---Verifica se a extensão do arquivo é de tipo binário.
---@param relPath string|nil
---@return boolean
function SupervisorUpdater.IsBinaryFile(relPath)
	if type(relPath) ~= 'string' then
		return false
	end
	local ext = relPath:match('%.([^%.]+)$')
	if not ext then
		return false
	end
	ext = ext:lower()
	return ext == 'webp' or ext == 'png' or ext == 'jpg' or ext == 'jpeg'
		or ext == 'gif' or ext == 'ogg' or ext == 'wav' or ext == 'mp3'
		or ext == 'ttf' or ext == 'woff' or ext == 'woff2' or ext == 'ytd' or ext == 'ydr'
end

---Verifica se o caminho relativo corresponde a um arquivo de configuração que requer preservação.
---@param relPath string|nil
---@return boolean
function SupervisorUpdater.IsConfigFile(relPath)
	if type(relPath) ~= 'string' then
		return false
	end
	local clean = relPath:gsub('\\', '/')
	if clean:match('%.dist%.lua$') or clean:match('%.bak$') or clean:match('%.new%.lua$') then
		return false
	end
	if clean:match('^config%.lua$') or clean:match('/config%.lua$') then
		return true
	end
	if clean:match('^config/') or clean:match('/config/') then
		return true
	end
	return false
end

---Detecta novas chaves de configuração presentes na versão remota que não existem no arquivo local.
---@param localContent string|nil
---@param remoteContent string|nil
---@return string[] novasChaves
function SupervisorUpdater.DetectNewConfigKeys(localContent, remoteContent)
	if type(remoteContent) ~= 'string' then
		return {}
	end
	local localStr = type(localContent) == 'string' and localContent or ''

	local function extractKeys(content)
		local keys = {}
		for key in content:gmatch('Config%.([%a_][%w_]*)%s*=') do
			keys[key] = true
		end
		for key in content:gmatch('Config%s*%[%s*[\'"]([%a_][%w_]*)[\'"]%s*%]%s*=') do
			keys[key] = true
		end
		local body = content:match('Config%s*=%s*%{([^%}]+)%}')
		if body then
			for key in body:gmatch('([%a_][%w_]*)%s*=') do
				keys[key] = true
			end
		end
		return keys
	end

	local localKeys = extractKeys(localStr)
	local remoteKeys = extractKeys(remoteContent)

	local newKeys = {}
	for key in pairs(remoteKeys) do
		if not localKeys[key] then
			table.insert(newKeys, 'Config.' .. key)
		end
	end
	table.sort(newKeys)
	return newKeys
end

---Calcula hash FNV-1a de 32 bits em hexadecimal para uma string.
---Para arquivos de texto, normaliza CRLF para LF antes de calcular para evitar divergência de checkout Windows/Linux.
---@param content string|nil
---@param isBinary boolean|nil
---@return string
function SupervisorUpdater.Hash(content, isBinary)
	if type(content) ~= 'string' then
		return '00000000'
	end
	local data = isBinary and content or content:gsub('\r\n', '\n')
	local hash = 0x811c9dc5
	for i = 1, #data do
		hash = ((hash ~ data:byte(i)) * 0x01000193) & 0xffffffff
	end
	return string.format('%08x', hash)
end

local SHA256_K = {
	0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
	0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
	0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
	0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
	0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
	0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
	0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
	0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
}

---Calcula SHA-256 (hex minúsculo). Mesma normalização do Hash: texto tem CRLF convertido para LF antes.
---Usado para verificar a integridade de cada arquivo baixado pelo updater e gerado pelo tools/bump_version.lua.
---@param content string|nil
---@param isBinary boolean|nil
---@return string|nil hex `nil` quando o conteúdo não é string
function SupervisorUpdater.Sha256(content, isBinary)
	if type(content) ~= 'string' then
		return nil
	end
	local data = isBinary and content or content:gsub('\r\n', '\n')
	local h0, h1, h2, h3 = 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a
	local h4, h5, h6, h7 = 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
	local bitLen = #data * 8
	data = data .. '\128' .. string.rep('\0', (55 - #data) % 64) .. string.pack('>I8', bitLen)
	local w = {}
	for chunk = 1, #data, 64 do
		for i = 0, 15 do
			w[i] = string.unpack('>I4', data, chunk + i * 4)
		end
		for i = 16, 63 do
			local a, b = w[i - 15], w[i - 2]
			local s0 = ((a >> 7) | (a << 25)) ~ ((a >> 18) | (a << 14)) ~ (a >> 3)
			local s1 = ((b >> 17) | (b << 15)) ~ ((b >> 19) | (b << 13)) ~ (b >> 10)
			w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff
		end
		local a, b, c, d, e, f, g, h = h0, h1, h2, h3, h4, h5, h6, h7
		for i = 0, 63 do
			local S1 = ((e >> 6) | (e << 26)) ~ ((e >> 11) | (e << 21)) ~ ((e >> 25) | (e << 7))
			local ch = (e & f) ~ ((~e) & g)
			local t1 = (h + (S1 & 0xffffffff) + (ch & 0xffffffff) + SHA256_K[i + 1] + w[i]) & 0xffffffff
			local S0 = ((a >> 2) | (a << 30)) ~ ((a >> 13) | (a << 19)) ~ ((a >> 22) | (a << 10))
			local maj = (a & b) ~ (a & c) ~ (b & c)
			local t2 = ((S0 & 0xffffffff) + maj) & 0xffffffff
			h, g, f, e = g, f, e, (d + t1) & 0xffffffff
			d, c, b, a = c, b, a, (t1 + t2) & 0xffffffff
		end
		h0 = (h0 + a) & 0xffffffff
		h1 = (h1 + b) & 0xffffffff
		h2 = (h2 + c) & 0xffffffff
		h3 = (h3 + d) & 0xffffffff
		h4 = (h4 + e) & 0xffffffff
		h5 = (h5 + f) & 0xffffffff
		h6 = (h6 + g) & 0xffffffff
		h7 = (h7 + h) & 0xffffffff
	end
	return string.format('%08x%08x%08x%08x%08x%08x%08x%08x', h0, h1, h2, h3, h4, h5, h6, h7)
end

---Confere o conteúdo baixado contra o SHA-256 do manifesto antes de qualquer gravação.
---@param item { sha256: string|nil, isBinary: boolean|nil }
---@param content string|nil
---@return boolean ok
---@return string|nil errorCode 'integrity_missing' | 'integrity_mismatch'
function SupervisorUpdater.VerifyContent(item, content)
	if type(item) ~= 'table' or type(item.sha256) ~= 'string' then
		return false, 'integrity_missing'
	end
	if SupervisorUpdater.Sha256(content, item.isBinary == true) ~= item.sha256 then
		return false, 'integrity_mismatch'
	end
	return true, nil
end

---Config local foi editada pelo dono do servidor? Compara com o SHA-256 da versão instalada; sem ele, com a nova.
---Uma config apenas antiga (igual à instalada) não é customizada e recebe a versão nova.
---@param localContent string|nil
---@param item { sha256: string|nil, installedSha256: string|nil }
---@return boolean
function SupervisorUpdater.IsCustomizedConfig(localContent, item)
	if type(localContent) ~= 'string' or localContent == '' or type(item) ~= 'table' then
		return false
	end
	local current = SupervisorUpdater.Sha256(localContent, false)
	if current == item.sha256 then
		return false
	end
	if type(item.installedSha256) == 'string' then
		return current ~= item.installedSha256
	end
	return true
end

---Só HTTPS: o updater nunca baixa código por HTTP simples.
---@param url string|nil
---@return boolean
function SupervisorUpdater.IsSecureUrl(url)
	return type(url) == 'string' and url:match('^https://[%w%.%-]+/') ~= nil
end

---Ref imutável de onde os arquivos são baixados: a tag da release, nunca um branch.
---@param remoteManifest table
---@param remoteVersion string
---@return string|nil ref
function SupervisorUpdater.ReleaseRef(remoteManifest, remoteVersion)
	local tag = type(remoteManifest) == 'table' and remoteManifest.tag or nil
	if type(tag) ~= 'string' or tag == '' then
		tag = 'v' .. tostring(remoteVersion)
	end
	if not tag:match('^v?%d+%.%d+%.%d+[%w%.%-]*$') then
		return nil
	end
	return tag
end

---Monta o plano de atualização comparando manifesto local, versões instaladas e manifesto remoto.
---@param localManifest table|nil
---@param remoteManifest table|nil
---@param installedVersions table<string, string|nil>|nil
---@param catalog table<string, table>|nil
---@param options { rawRepoUrl: string|nil, allowed: table<string, boolean>|nil }|nil
---  rawRepoUrl: raiz HTTPS do repositório (sem ref); a ref usada é sempre a tag da release.
---  allowed: resources que o updater pode tocar (gerenciados + coe_supervisor). Os demais do manifesto são ignorados.
---@return table|nil plan
---@return string|nil errorCode
function SupervisorUpdater.BuildUpdatePlan(localManifest, remoteManifest, installedVersions, catalog, options)
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
	local opts = type(options) == 'table' and options or {}
	local allowed = type(opts.allowed) == 'table' and opts.allowed or nil
	local repoUrl = (type(opts.rawRepoUrl) == 'string' and opts.rawRepoUrl ~= '' and opts.rawRepoUrl:gsub('/+$', ''))
		or ('https://raw.githubusercontent.com/' .. repo)
	if not SupervisorUpdater.IsSecureUrl(repoUrl .. '/') then
		return nil, 'insecure_url'
	end
	local ref = SupervisorUpdater.ReleaseRef(remoteManifest, parsedRemote.raw)
	if not ref then
		return nil, 'invalid_remote_tag'
	end
	-- Arquivos vêm da tag da release (imutável), nunca de um branch que pode mudar entre a verificação e o download.
	local base = repoUrl .. '/' .. ref

	local outdatedResources = {}
	local downloads = {}
	local missingIntegrity = 0
	local requiresFullRestart = false

	local names = {}
	for resName in pairs(remoteResources) do
		if type(resName) == 'string' and resName:match('^[%w_%-]+$') and (not allowed or allowed[resName] == true) then
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
			local hashes = type(remoteEntry) == 'table' and type(remoteEntry.hashes) == 'table' and remoteEntry.hashes or nil
			local sha = type(remoteEntry) == 'table' and type(remoteEntry.sha256) == 'table' and remoteEntry.sha256 or nil
			local installedSha = type(localEntry) == 'table' and type(localEntry.sha256) == 'table' and localEntry.sha256 or nil
			for _, rel in ipairs(files) do
				local safeRel = SupervisorUpdater.SanitizeRelativePath(rel)
				if safeRel then
					local fileSha = sha and sha[safeRel] or nil
					if type(fileSha) ~= 'string' or not fileSha:match('^%x+$') or #fileSha ~= 64 then
						fileSha = nil
						missingIntegrity = missingIntegrity + 1
					end
					downloads[#downloads + 1] = {
						resource = resName,
						file = safeRel,
						url = string.format('%s/%s/%s', base, resName, safeRel),
						hash = hashes and hashes[safeRel] or nil,
						sha256 = fileSha and fileSha:lower() or nil,
						-- SHA-256 do arquivo como foi instalado: distingue config customizada de config apenas antiga.
						installedSha256 = installedSha and type(installedSha[safeRel]) == 'string' and installedSha[safeRel]:lower() or nil,
						isBinary = SupervisorUpdater.IsBinaryFile(safeRel)
					}
				end
			end
		end
	end

	-- Ordena para priorizar coe_supervisor no topo da fila (atualizador atualiza a si mesmo primeiro)
	table.sort(downloads, function(a, b)
		if a.resource == 'coe_supervisor' and b.resource ~= 'coe_supervisor' then
			return true
		elseif b.resource == 'coe_supervisor' and a.resource ~= 'coe_supervisor' then
			return false
		end
		if a.resource ~= b.resource then
			return a.resource < b.resource
		end
		return a.file < b.file
	end)

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
		ref = ref,
		-- Arquivos sem SHA-256 no manifesto: o apply recusa o plano inteiro (fail-closed).
		missingIntegrity = missingIntegrity,
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
