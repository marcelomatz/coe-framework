--[[
	Coe Framework — Sistema de Internacionalização e Localização (i18n / l10n)
	Fornece gerenciamento de idiomas, interpolação de texto, formatação monetária
	e exportação para interfaces NUI/Web de forma tipada, leve e defensiva.
]]

CoeLocale = {}
local Locale = CoeLocale

-- Idioma padrão do framework
local DEFAULT_LANG = 'pt-BR'

---Normaliza o código do idioma para o padrão IETF (ex: 'pt-BR', 'en-US', 'es-ES')
---@param lang string|nil
---@return string
function Locale.NormalizeLang(lang)
	if type(lang) ~= 'string' or #lang == 0 then
		return DEFAULT_LANG
	end
	local clean = lang:gsub('_', '-'):lower()
	if clean:match('^pt') then
		return 'pt-BR'
	elseif clean:match('^en') then
		return 'en-US'
	elseif clean:match('^es') then
		return 'es-ES'
	end
	return lang
end

---Obtém o idioma padrão ativo do servidor (lê ConVar do FiveM ou padrão pt-BR)
---@return string
function Locale.GetDefaultLang()
	if type(GetConvar) == 'function' then
		local cvar = GetConvar('coe_locale', '')
		if cvar and #cvar > 0 then
			return Locale.NormalizeLang(cvar)
		end
	end
	return DEFAULT_LANG
end

---Define o idioma padrão global
---@param lang string
function Locale.SetDefaultLang(lang)
	DEFAULT_LANG = Locale.NormalizeLang(lang)
end

---Obtém o nome do servidor configurado
---@param fallback string|nil
---@return string
function Locale.GetServerName(fallback)
	if type(GetConvar) == 'function' then
		local name = GetConvar('coe_server_name', '')
		if name and #name > 0 then
			return name
		end
	end
	return fallback or 'Coe Roleplay'
end

---Formata um valor monetário de acordo com a convenção do idioma
---@param amount number
---@param lang string|nil
---@return string
function Locale.FormatMoney(amount, lang)
	local targetLang = Locale.NormalizeLang(lang or Locale.GetDefaultLang())
	local val = tonumber(amount) or 0
	local isNegative = val < 0
	val = math.abs(val)

	local formatted
	if targetLang == 'en-US' then
		-- Padrão americano: $1,234.50
		local intPart = math.floor(val)
		local decPart = math.floor((val - intPart) * 100 + 0.5)
		local s = tostring(intPart):reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
		formatted = string.format('$%s.%02d', s, decPart)
	elseif targetLang == 'es-ES' then
		-- Padrão espanhol: 1.234,50 €
		local intPart = math.floor(val)
		local decPart = math.floor((val - intPart) * 100 + 0.5)
		local s = tostring(intPart):reverse():gsub('(%d%d%d)', '%1.'):reverse():gsub('^%.', '')
		formatted = string.format('%s,%02d €', s, decPart)
	else
		-- Padrão brasileiro: R$ 1.234,50
		local intPart = math.floor(val)
		local decPart = math.floor((val - intPart) * 100 + 0.5)
		local s = tostring(intPart):reverse():gsub('(%d%d%d)', '%1.'):reverse():gsub('^%.', '')
		formatted = string.format('R$ %s,%02d', s, decPart)
	end

	return isNegative and ('-' .. formatted) or formatted
end

-- ============================================================================
-- MOTOR DE TRADUÇÃO DE INSTÂNCIA
-- ============================================================================
local LocaleInstance = {}
LocaleInstance.__index = LocaleInstance

---Interpola parâmetros em uma string de template (%{var} ou %s)
---@param template string
---@param params table|any
---@return string
local function interpolate(template, params)
	if type(template) ~= 'string' then
		return tostring(template or '')
	end
	if type(params) ~= 'table' then
		if params ~= nil then
			return template:gsub('%%s', tostring(params), 1)
		end
		return template
	end

	-- Substituição nomeada %{nome}
	local result = template:gsub('%%{(%w+)}', function(key)
		local val = params[key]
		if val ~= nil then
			return tostring(val)
		end
		return '%{' .. key .. '}'
	end)

	-- Se houver índices numéricos { 'arg1', 'arg2' }, suporta %s sequencial
	if #params > 0 then
		local i = 1
		result = result:gsub('%%s', function()
			local val = params[i]
			i = i + 1
			return val ~= nil and tostring(val) or '%s'
		end)
	end

	return result
end

---Busca uma chave em um dicionário (suporta chaves aninhadas 'a.b.c' ou diretas)
---@param dict table
---@param key string
---@return any
local function resolveKey(dict, key)
	if type(dict) ~= 'table' or type(key) ~= 'string' then
		return nil
	end
	-- Tenta acesso direto primeiro (alta performance)
	if dict[key] ~= nil then
		return dict[key]
	end
	-- Tenta navegação aninhada 'categoria.subchave'
	local current = dict
	for part in key:gmatch('[^.]+') do
		if type(current) ~= 'table' then
			return nil
		end
		current = current[part]
		if current == nil then
			return nil
		end
	end
	return current
end

---Traduz uma chave para o idioma ativo com interpolação de parâmetros
---@param key string
---@param params table|any
---@return string
function LocaleInstance:T(key, params)
	if type(key) ~= 'string' then
		return tostring(key or '')
	end

	local lang = self.lang
	local dict = self.locales[lang]
	local template = dict and resolveKey(dict, key)

	-- Se não encontrar no idioma ativo, tenta o fallback
	if template == nil and lang ~= self.fallback then
		local fbDict = self.locales[self.fallback]
		template = fbDict and resolveKey(fbDict, key)
	end

	-- Se ainda não encontrar, retorna a própria chave
	if template == nil then
		return key
	end

	return interpolate(template, params)
end

function LocaleInstance:Translate(key, params)
	return self:T(key, params)
end

---Define o idioma ativo da instância
---@param lang string
function LocaleInstance:SetLanguage(lang)
	self.lang = Locale.NormalizeLang(lang)
end

---Obtém o idioma ativo da instância
---@return string
function LocaleInstance:GetLanguage()
	return self.lang
end

---Registra ou sobrescreve dicionário de um idioma
---@param lang string
---@param dict table
function LocaleInstance:Register(lang, dict)
	local norm = Locale.NormalizeLang(lang)
	if type(dict) == 'table' then
		self.locales[norm] = dict
	end
end

---Mescla chaves em um idioma existente
---@param lang string
---@param patch table
function LocaleInstance:Merge(lang, patch)
	local norm = Locale.NormalizeLang(lang)
	if type(patch) ~= 'table' then return end
	self.locales[norm] = self.locales[norm] or {}
	for k, v in pairs(patch) do
		self.locales[norm][k] = v
	end
end

---Exporta o dicionário completo do idioma para a interface web NUI
---@param lang string|nil
---@return table
function Locale.ExportForNui(lang)
	local targetLang = Locale.NormalizeLang(lang or Locale.GetDefaultLang())
	local locales = _G.Locales or {}
	local dict = locales[targetLang] or {}
	local fbDict = locales[DEFAULT_LANG] or {}
	local merged = {}

	for k, v in pairs(fbDict) do
		merged[k] = v
	end
	for k, v in pairs(dict) do
		merged[k] = v
	end

	return merged
end

---Exporta o dicionário completo do idioma para a interface web NUI
---@param lang string|nil
---@return table
function LocaleInstance:ExportForNui(lang)
	local targetLang = Locale.NormalizeLang(lang or self.lang)
	local dict = self.locales[targetLang] or {}
	local fbDict = self.locales[self.fallback] or {}
	local merged = {}

	-- Aplica fallback primeiro, depois as chaves do idioma
	for k, v in pairs(fbDict) do
		merged[k] = v
	end
	for k, v in pairs(dict) do
		merged[k] = v
	end

	return merged
end

---Permite chamar a instância diretamente como função: `loc('chave', { var = 1 })`
LocaleInstance.__call = function(self, key, params)
	return self:T(key, params)
end

---Cria uma nova instância de internacionalização para um resource ou módulo
---@param opts table { default?: string, fallback?: string, locales?: table }
---@return table
function Locale.New(opts)
	local config = type(opts) == 'table' and opts or {}
	local defaultLang = Locale.NormalizeLang(config.default or Locale.GetDefaultLang())
	local fallbackLang = Locale.NormalizeLang(config.fallback or DEFAULT_LANG)
	local locales = {}

	if type(config.locales) == 'table' then
		for lang, dict in pairs(config.locales) do
			locales[Locale.NormalizeLang(lang)] = dict
		end
	end

	local instance = {
		lang = defaultLang,
		fallback = fallbackLang,
		locales = locales
	}

	return setmetatable(instance, LocaleInstance)
end

return Locale