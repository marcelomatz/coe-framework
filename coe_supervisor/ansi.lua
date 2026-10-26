-- Módulo de formatação ANSI e sanitização UTF-8 para o coe_supervisor.
-- Suporta sequências de escape ANSI padrão de terminais e códigos de cor nativos do FiveM/FXServer.
SupervisorAnsi = {}

local ESC = '\27['
local C = {
	reset = ESC .. '0m',
	bold = ESC .. '1m',
	dim = ESC .. '2m',
	underline = ESC .. '4m',

	-- Cores de texto padrão
	black = ESC .. '30m',
	red = ESC .. '31m',
	green = ESC .. '32m',
	yellow = ESC .. '33m',
	blue = ESC .. '34m',
	magenta = ESC .. '35m',
	cyan = ESC .. '36m',
	white = ESC .. '37m',
	gray = ESC .. '90m',

	-- Cores de texto brilhantes
	brightRed = ESC .. '91m',
	brightGreen = ESC .. '92m',
	brightYellow = ESC .. '93m',
	brightBlue = ESC .. '94m',
	brightMagenta = ESC .. '95m',
	brightCyan = ESC .. '96m',
	brightWhite = ESC .. '97m',

	-- Cores personalizadas do COE
	coeBrand = ESC .. '38;5;39m',      -- Azul/ciano vibrante COE
	coeAccent = ESC .. '38;5;214m',    -- Âmbar de destaque
	coeBorder = ESC .. '38;5;242m',    -- Cinza elegante para bordas
	coeSuccess = ESC .. '38;5;42m',     -- Verde sucesso
	coeWarning = ESC .. '38;5;220m',    -- Amarelo aviso
	coeMuted = ESC .. '38;5;245m'       -- Texto secundário
}
SupervisorAnsi.Colors = C

-- Tabela de substituição de bytes Windows-1252 / ISO-8859-1 para caracteres UTF-8
local CP1252_MAP = {
	[0xC0] = 'À', [0xC1] = 'Á', [0xC2] = 'Â', [0xC3] = 'Ã', [0xC7] = 'Ç', [0xC9] = 'É', [0xCA] = 'Ê',
	[0xCD] = 'Í', [0xD3] = 'Ó', [0xD4] = 'Ô', [0xD5] = 'Õ', [0xDA] = 'Ú',
	[0xE0] = 'à', [0xE1] = 'á', [0xE2] = 'â', [0xE3] = 'ã', [0xE7] = 'ç', [0xE9] = 'é', [0xEA] = 'ê',
	[0xED] = 'í', [0xF3] = 'ó', [0xF4] = 'ô', [0xF5] = 'õ', [0xFA] = 'ú'
}

---Sanitiza e garante codificação UTF-8 válida para strings lidas de arquivos, HTTP ou entrada de usuário.
---@param str string|any
---@return string
function SupervisorAnsi.SanitizeUtf8(str)
	if type(str) ~= 'string' or str == '' then
		return type(str) == 'string' and str or tostring(str or '')
	end

	-- Corrige padrão conhecido de dupla interrogação proveniente de conversão CP1252 truncada
	local text = str:gsub('atualiza%?%?o%(%?es%)', 'atualização(ões)')
	text = text:gsub('atualiza%?%?o', 'atualização')
	text = text:gsub('atualiza%?es', 'atualizações')
	text = text:gsub('vers%?%?o', 'versão')
	text = text:gsub('configura%?%?o', 'configuração')
	text = text:gsub('opera%?%?o', 'operação')

	-- Se utf8.len validar a string como UTF-8 legítimo, retorna diretamente
	if pcall(utf8.len, text) and utf8.len(text) ~= nil then
		return text
	end

	-- Se houver bytes avulsos no range Windows-1252/ISO-8859-1 (128..255), converte para UTF-8
	local out = {}
	local i = 1
	local len = #text
	while i <= len do
		local b = text:byte(i)
		if b < 128 then
			out[#out + 1] = string.char(b)
			i = i + 1
		elseif b >= 192 and b <= 223 and i + 1 <= len and text:byte(i + 1) >= 128 and text:byte(i + 1) <= 191 then
			out[#out + 1] = text:sub(i, i + 1)
			i = i + 2
		elseif b >= 224 and b <= 239 and i + 2 <= len and text:byte(i + 1) >= 128 and text:byte(i + 1) <= 191 and text:byte(i + 2) >= 128 and text:byte(i + 2) <= 191 then
			out[#out + 1] = text:sub(i, i + 2)
			i = i + 3
		elseif b >= 240 and b <= 247 and i + 3 <= len and text:byte(i + 1) >= 128 and text:byte(i + 1) <= 191 and text:byte(i + 2) >= 128 and text:byte(i + 2) <= 191 and text:byte(i + 3) >= 128 and text:byte(i + 3) <= 191 then
			out[#out + 1] = text:sub(i, i + 3)
			i = i + 4
		else
			local mapped = CP1252_MAP[b]
			if mapped then
				out[#out + 1] = mapped
			elseif b >= 128 and b <= 255 then
				pcall(function()
					out[#out + 1] = utf8.char(b)
				end)
			else
				out[#out + 1] = string.char(b)
			end
			i = i + 1
		end
	end
	return table.concat(out)
end

---Calcula o comprimento visual de uma string sem contar as sequências de escape ANSI.
---@param str string
---@return integer
function SupervisorAnsi.VisibleLength(str)
	if type(str) ~= 'string' then return 0 end
	local clean = str:gsub('\27%[[%d;]*m', ''):gsub('%^%d', '')
	local ok, len = pcall(utf8.len, clean)
	return (ok and len) or #clean
end

---Exibe o banner estruturado de atualização disponível com sequências ANSI e bordas modernas.
---@param plan table
function SupervisorAnsi.PrintUpdateAvailable(plan)
	local notes = SupervisorAnsi.SanitizeUtf8(plan.notes or '')
	local channel = tostring(plan.channel or 'beta'):upper()
	local localVer = tostring(plan.localVersion or '?')
	local remoteVer = tostring(plan.remoteVersion or '?')
	local tag = tostring(plan.tag or ('v' .. remoteVer))
	local outdated = tonumber(plan.outdatedCount) or 0
	local files = tonumber(plan.filesCount) or 0

	local W = 74
	local border = C.coeBorder .. '═' .. C.reset
	local hLine = C.coeBorder .. string.rep('═', W) .. C.reset
	local sepLine = C.coeBorder .. string.rep('─', W) .. C.reset

	local pendingCount = tonumber(plan.pendingCount) or 0
	local isCumulative = plan.isCumulative == true or pendingCount >= 2
	local pendingReleases = plan.pendingReleases or {}

	local isSameVersion = (localVer == remoteVer)
	local bannerTitle = isSameVersion
		and string.format('  %s%sSCRIPTS PENDENTES DE SINCRONIZAÇÃO (%s)%s', C.bold, C.brightYellow, channel, C.reset)
		or string.format('  %s%sNOVA VERSÃO DISPONÍVEL NO REPOSITÓRIO (%s)%s', C.bold, C.brightYellow, channel, C.reset)

	print(hLine)
	print(string.format('%s  %sCOE FRAMEWORK%s  •  %sSUPERVISOR%s', C.coeBorder, C.bold .. C.coeBrand, C.reset, C.bold .. C.brightWhite, C.reset))
	print(bannerTitle)
	print(sepLine)
	if isSameVersion then
		print(string.format('  %sVersão do framework:%s %sv%s%s', C.brightWhite, C.reset, C.bold .. C.brightGreen, localVer, C.reset))
	else
		print(string.format('  %sVersão instalada :%s %sv%s%s', C.brightWhite, C.reset, C.gray, localVer, C.reset))
		print(string.format('  %sNova versão      :%s %sv%s%s %s(%s)%s', C.brightWhite, C.reset, C.bold .. C.brightGreen, remoteVer, C.reset, C.brightCyan, tag, C.reset))
	end
	print(string.format('  %sCanal de release :%s %s%s%s', C.brightWhite, C.reset, C.yellow, channel:lower(), C.reset))

	if isCumulative and #pendingReleases > 0 then
		print(string.format('  %sAtraso de release:%s %s%d release(s) pendente(s) acumulada(s)!%s', C.brightWhite, C.reset, C.bold .. C.brightYellow, pendingCount, C.reset))
		print(string.format('  %sReleases no plano:%s', C.brightWhite, C.reset))
		for idx, rel in ipairs(pendingReleases) do
			local relNote = SupervisorAnsi.SanitizeUtf8(rel.notes or '')
			if #relNote > 54 then
				relNote = relNote:sub(1, 51) .. '...'
			end
			print(string.format('    %s[%d/%d]%s %s%-14s%s %s%s%s',
				C.coeMuted, idx, pendingCount, C.reset,
				C.bold .. C.brightCyan, tostring(rel.tag), C.reset,
				C.brightWhite, relNote ~= '' and relNote or 'Atualizações acumuladas', C.reset))
		end
		print(string.format('  %sPlano de update  :%s %sAtualização cumulativa segura (%sv%s → %s)%s',
			C.brightWhite, C.reset, C.bold .. C.brightGreen, C.reset .. C.gray, localVer, tag, C.reset))
	elseif notes ~= '' then
		print(string.format('  %sNotas da release :%s %s%s%s', C.brightWhite, C.reset, C.brightWhite, notes, C.reset))
	end

	print(string.format('  %sScripts pendentes:%s %s%d resource(s)%s %s(%d arquivo(s))%s', C.brightWhite, C.reset, C.bold .. C.brightCyan, outdated, C.reset, C.coeMuted, files, C.reset))
	print(sepLine)
	print(string.format('  %sComo atualizar   :%s %sdigite "coe_update apply" no console do servidor%s', C.brightWhite, C.reset, C.bold .. C.brightYellow, C.reset))
	print(string.format('  %sOu via Staff     :%s %spainel F10 -> aba Sistema / Updates%s', C.brightWhite, C.reset, C.brightCyan, C.reset))
	print(hLine)
end

---Exibe as informações estruturadas de versão (comando coe_version).
---@param st table
function SupervisorAnsi.PrintVersion(st)
	local localVer = tostring(st.localVersion or '?')
	local channel = tostring(st.channel or 'beta')
	local repo = tostring(st.repository or 'marcelomatz/coe-framework')
	local branch = tostring(st.branch or 'main')

	print(string.format('%s[COE Framework]%s v%s%s%s (canal: %s%s%s) • Repositório: %s%s%s (%s%s%s)',
		C.bold .. C.coeBrand, C.reset,
		C.bold .. C.brightWhite, localVer, C.reset,
		C.brightYellow, channel, C.reset,
		C.brightCyan, repo, C.reset,
		C.coeMuted, branch, C.reset))

	if st.available then
		local pCount = tonumber(st.pendingCount) or 1
		local pType = (pCount >= 2) and string.format(' (%d releases atrasadas)', pCount) or ''
		print(string.format('  %s➜ Atualização disponível:%s %sv%s%s%s %s(%d resource(s) pendente(s))%s',
			C.bold .. C.brightYellow, C.reset,
			C.bold .. C.brightGreen, tostring(st.remoteVersion), C.reset,
			C.brightYellow .. pType .. C.reset,
			C.brightCyan, st.outdatedCount or 0, C.reset))
		if pCount >= 2 and type(st.pendingVersions) == 'table' and #st.pendingVersions > 0 then
			print(string.format('    %sCadeia de releases:%s %s%s%s',
				C.brightWhite, C.reset, C.brightCyan, table.concat(st.pendingVersions, ' → '), C.reset))
		end
		print(string.format('    %sExecute %s"coe_update apply"%s para atualizar.%s',
			C.coeMuted, C.bold .. C.brightYellow, C.reset .. C.coeMuted, C.reset))
	elseif st.remoteVersion then
		print(string.format('  %s✔ Todos os scripts e resources estão na versão mais recente.%s',
			C.bold .. C.brightGreen, C.reset))
	end
end

---Exibe o banner estruturado de conclusão de atualização.
---@param result table
function SupervisorAnsi.PrintUpdateCompleted(result)
	local W = 74
	local hLine = C.coeBorder .. string.rep('═', W) .. C.reset
	local sepLine = C.coeBorder .. string.rep('─', W) .. C.reset

	local written = tonumber(result.filesUpdated) or 0
	local skipped = tonumber(result.filesSkipped) or 0
	local downloaded = written - skipped
	if downloaded < 0 then downloaded = 0 end

	print(hLine)
	print(string.format('  %s%s✔ ATUALIZAÇÃO DO COE FRAMEWORK APLICADA COM SUCESSO!%s', C.bold, C.brightGreen, C.reset))
	print(sepLine)
	print(string.format('  %sVersão instalada :%s %sv%s%s', C.brightWhite, C.reset, C.bold .. C.brightGreen, tostring(result.version), C.reset))
	print(string.format('  %sResources salvos :%s %s%d atualizado(s)%s', C.brightWhite, C.reset, C.brightCyan, result.updatedResources or 0, C.reset))
	if skipped > 0 then
		print(string.format('  %sArquivos salvos  :%s %s%d arquivo(s)%s (%s%d baixados%s, %s%d já idênticos%s)',
			C.brightWhite, C.reset, C.brightCyan, written, C.reset,
			C.brightYellow, downloaded, C.reset,
			C.brightGreen, skipped, C.reset))
	else
		print(string.format('  %sArquivos salvos  :%s %s%d arquivo(s)%s', C.brightWhite, C.reset, C.brightCyan, written, C.reset))
	end
	if result.requiresFullRestart then
		print(string.format('  %sAtenção          :%s %sRecomendado reiniciar o FXServer (restart do binário/txAdmin).%s', C.bold .. C.brightYellow, C.reset, C.brightYellow, C.reset))
	else
		print(string.format('  %sPróximo passo    :%s %sResources recarregados. Execute "restart <nome>" se necessário.%s', C.brightWhite, C.reset, C.coeMuted, C.reset))
	end
	print(hLine)
end

---Exibe aviso estruturado de pausa para respeitar o limite de requisições do GitHub (HTTP 429 ou timeout).
---@param attempt integer
---@param maxRetries integer
---@param backoffMs integer
---@param isRateLimit boolean
function SupervisorAnsi.PrintRateLimitWait(attempt, maxRetries, backoffMs, isRateLimit)
	local reason = isRateLimit and 'Limite de requisições atingido (HTTP 429 Rate Limit)' or 'Timeout na resposta do servidor'
	print(string.format('  %s%s[!] %s%s - pausando %s%.1fs%s para retomar (%d/%d)...',
		C.bold, C.brightYellow, reason, C.reset,
		C.bold .. C.brightWhite, backoffMs / 1000, C.reset,
		attempt, maxRetries))
end

---Exibe o banner estruturado de início de atualização.
---@param plan table
---@param requester string|integer|nil
function SupervisorAnsi.PrintUpdateStart(plan, requester)
	local W = 74
	local hLine = C.coeBorder .. string.rep('═', W) .. C.reset
	local sepLine = C.coeBorder .. string.rep('─', W) .. C.reset
	local req = (type(requester) == 'number' and requester > 0) and ('Staff (ID ' .. requester .. ')') or tostring(requester or 'console')
	local localVer = tostring(plan.localVersion or '?')
	local targetTag = tostring(plan.tag or ('v' .. (plan.remoteVersion or '?')))

	print(hLine)
	print(string.format('%s  %sCOE FRAMEWORK%s  •  %sSUPERVISOR%s', C.coeBorder, C.bold .. C.coeBrand, C.reset, C.bold .. C.brightWhite, C.reset))
	print(string.format('  %s%sINICIANDO APLICAÇÃO DE ATUALIZAÇÃO (%sv%s → %s)%s', C.bold, C.brightCyan, C.reset .. C.gray, localVer, C.bold .. C.brightGreen .. targetTag, C.reset))
	print(sepLine)
	print(string.format('  %sArquivos a gravar :%s %s%d arquivo(s)%s em %s%d resource(s)%s',
		C.brightWhite, C.reset, C.bold .. C.brightCyan, tonumber(plan.filesCount) or 0, C.reset, C.brightYellow, tonumber(plan.outdatedCount) or 0, C.reset))
	print(string.format('  %sSolicitado por    :%s %s%s%s', C.brightWhite, C.reset, C.brightWhite, req, C.reset))
	print(string.format('  %sStatus            :%s %sBaixando scripts e gravando no servidor...%s', C.brightWhite, C.reset, C.bold .. C.brightYellow, C.reset))
	print(sepLine)
	print(string.format('  %sAcompanhe o progresso abaixo ou digite "coe_update status"%s', C.coeMuted, C.reset))
	print(hLine)
end

---Exibe o banner estruturado de atualização que já está em andamento.
---@param st table
function SupervisorAnsi.PrintUpdateInProgress(st)
	local W = 74
	local hLine = C.coeBorder .. string.rep('═', W) .. C.reset
	local sepLine = C.coeBorder .. string.rep('─', W) .. C.reset
	local written = tonumber(st.filesWritten) or 0
	local total = tonumber(st.filesCount) or 0
	local pct = total > 0 and math.floor((written / total) * 100) or 0
	local req = (type(st.requester) == 'number' and st.requester > 0) and ('Staff (ID ' .. st.requester .. ')') or tostring(st.requester or 'console/automático')
	local elapsed = st.startTime and (os.time() - st.startTime) or 0
	local targetVer = tostring(st.remoteVersion or st.tag or '?')

	print(hLine)
	print(string.format('  %s%s[!] UMA ATUALIZAÇÃO JÁ ESTÁ EM ANDAMENTO NO SERVIDOR%s', C.bold, C.brightYellow, C.reset))
	print(sepLine)
	print(string.format('  %sVersão de destino :%s %sv%s%s', C.brightWhite, C.reset, C.bold .. C.brightGreen, targetVer:gsub('^v', ''), C.reset))
	print(string.format('  %sProgresso atual   :%s %s%d / %d arquivo(s) gravados (%d%%)%s',
		C.brightWhite, C.reset, C.bold .. C.brightCyan, written, total, pct, C.reset))
	if st.currentResource then
		print(string.format('  %sResource atual    :%s %s%s%s', C.brightWhite, C.reset, C.bold .. C.brightYellow, st.currentResource, C.reset))
	end
	print(string.format('  %sSolicitado por    :%s %s%s%s (há %ds)', C.brightWhite, C.reset, C.brightWhite, req, C.reset, elapsed))
	print(string.format('  %sStatus            :%s %sDownload e gravação em execução em segundo plano...%s', C.brightWhite, C.reset, C.brightYellow, C.reset))
	print(sepLine)
	SupervisorAnsi.PrintProgress(written, total, st.currentResource or 'preparando...')
	print(string.format('  %sDica: "coe_update status" para acompanhar | "coe_update reset" para destravar%s', C.coeMuted, C.reset))
	print(hLine)
end

---Exibe o progresso de atualização de um arquivo/resource.
---@param current integer
---@param total integer
---@param resourceName string
function SupervisorAnsi.PrintProgress(current, total, resourceName)
	local pct = total > 0 and math.floor((current / total) * 100) or 100
	local barWidth = 24
	local filled = math.floor((pct / 100) * barWidth)
	local empty = barWidth - filled
	local bar = C.brightGreen .. string.rep('█', filled) .. C.coeBorder .. string.rep('░', empty) .. C.reset

	print(string.format('%s[coe_updater]%s [%s] %s%3d%%%s (%d/%d) %s%s%s',
		C.bold .. C.coeBrand, C.reset,
		bar,
		C.bold .. C.brightWhite, pct, C.reset,
		current, total,
		C.brightCyan, resourceName, C.reset))
end
