--[[
	Testes unitários do subsistema de Internacionalização e Localização (i18n) do Coe Framework
]]

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error(string.format('%s: esperado %s, recebido %s', message or 'Falha na asserção', tostring(expected), tostring(actual)), 2)
	end
end

local function assertTrue(condition, message)
	if condition ~= true then
		error(message or 'Esperava true', 2)
	end
end

local Locale = dofile('lib/locale.lua')
assertTrue(type(Locale) == 'table', 'Locale deve ser uma tabela')

-- ============================================================================
-- 1. NORMALIZAÇÃO E CONFIGURAÇÕES GLOBAIS
-- ============================================================================
assertEqual(Locale.NormalizeLang('pt-br'), 'pt-BR', 'Normaliza pt-br')
assertEqual(Locale.NormalizeLang('pt_BR'), 'pt-BR', 'Normaliza pt_BR com underline')
assertEqual(Locale.NormalizeLang('pt'), 'pt-BR', 'Normaliza pt simples')
assertEqual(Locale.NormalizeLang('en-us'), 'en-US', 'Normaliza en-us')
assertEqual(Locale.NormalizeLang('en'), 'en-US', 'Normaliza en')
assertEqual(Locale.NormalizeLang('es-es'), 'es-ES', 'Normaliza es-es')
assertEqual(Locale.NormalizeLang(nil), 'pt-BR', 'Nil vira padrão pt-BR')

assertEqual(Locale.GetDefaultLang(), 'pt-BR', 'Idioma padrão inicial')
assertEqual(Locale.GetServerName('Meu Servidor'), 'Meu Servidor', 'ServerName usa fallback fora do FXServer')

-- Formatação monetária
assertEqual(Locale.FormatMoney(1250, 'pt-BR'), 'R$ 1.250,00', 'Moeda pt-BR')
assertEqual(Locale.FormatMoney(1250.75, 'pt-BR'), 'R$ 1.250,75', 'Moeda pt-BR com centavos')
assertEqual(Locale.FormatMoney(1250.75, 'en-US'), '$1,250.75', 'Moeda en-US')
assertEqual(Locale.FormatMoney(1250.75, 'es-ES'), '1.250,75 €', 'Moeda es-ES')
assertEqual(Locale.FormatMoney(-500, 'pt-BR'), '-R$ 500,00', 'Moeda negativa pt-BR')

-- ============================================================================
-- 2. INSTÂNCIA DE LOCALE E DICIONÁRIOS
-- ============================================================================
local dicts = {
	['pt-BR'] = {
		welcome = 'Bem-vindo ao %{server}!',
		vehicle_created = 'Veículo %{model} criado com sucesso (placa: %{plate}).',
		player_count = 'Jogadores online: %s / %s',
		nested = {
			door_locked = 'Porta trancada.',
			door_unlocked = 'Porta destrancada.'
		},
		only_in_pt = 'Texto exclusivo em português.'
	},
	['en-US'] = {
		welcome = 'Welcome to %{server}!',
		vehicle_created = 'Vehicle %{model} successfully created (plate: %{plate}).',
		player_count = 'Online players: %s / %s',
		nested = {
			door_locked = 'Door locked.',
			door_unlocked = 'Door unlocked.'
		}
	}
}

local loc = Locale.New({
	default = 'pt-BR',
	fallback = 'pt-BR',
	locales = dicts
})

-- 2.1 Tradução direta e interpolação nomeada
assertEqual(loc:T('welcome', { server = 'Coe Roleplay' }), 'Bem-vindo ao Coe Roleplay!', 'Interpolação nomeada pt-BR')
assertEqual(loc:T('vehicle_created', { model = 'Adder', plate = 'ABC-1234' }), 'Veículo Adder criado com sucesso (placa: ABC-1234).', 'Múltiplas variáveis')

-- 2.2 Chamada direta do objeto (callable metatable)
assertEqual(loc('welcome', { server = 'Coe RP' }), 'Bem-vindo ao Coe RP!', 'Invocação direta da instância como função')

-- 2.3 Interpolação sequencial %s
assertEqual(loc:T('player_count', { 32, 64 }), 'Jogadores online: 32 / 64', 'Interpolação posicional')

-- 2.4 Chaves aninhadas por ponto
assertEqual(loc:T('nested.door_locked'), 'Porta trancada.', 'Chave aninhada')
assertEqual(loc:T('nested.door_unlocked'), 'Porta destrancada.', 'Chave aninhada')

-- 2.5 Troca dinâmica de idioma
loc:SetLanguage('en-US')
assertEqual(loc:GetLanguage(), 'en-US', 'Idioma alterado para en-US')
assertEqual(loc:T('welcome', { server = 'Coe RP' }), 'Welcome to Coe RP!', 'Tradução em en-US')
assertEqual(loc:T('nested.door_locked'), 'Door locked.', 'Chave aninhada em en-US')

-- 2.6 Fallback automático para chaves inexistentes no idioma ativo
assertEqual(loc:T('only_in_pt'), 'Texto exclusivo em português.', 'Fallback de chave para pt-BR')

-- 2.7 Chave inexistente em qualquer idioma (defensivo)
assertEqual(loc:T('chave_inexistente'), 'chave_inexistente', 'Chave inexistente devolve a própria chave')
assertEqual(loc:T(nil), '', 'Nil devolve string vazia sem lançar erro')

-- 2.8 Registro dinâmico e Merge
loc:Register('es-ES', {
	welcome = '¡Bienvenido a %{server}!'
})
loc:SetLanguage('es-ES')
assertEqual(loc:T('welcome', { server = 'Coe' }), '¡Bienvenido a Coe!', 'Idioma es-ES registrado dinamicamente')

loc:Merge('es-ES', {
	extra_msg = 'Mensaje extra'
})
assertEqual(loc:T('extra_msg'), 'Mensaje extra', 'Merge adiciona chaves sem apagar anteriores')

-- 2.9 Exportação NUI
local nuiDict = loc:ExportForNui('en-US')
assertTrue(type(nuiDict) == 'table', 'ExportForNui retorna tabela')
assertEqual(nuiDict.only_in_pt, 'Texto exclusivo em português.', 'ExportForNui inclui chaves de fallback')

Locales = {
	['pt-BR'] = { static_key = 'Chave Estática', shared_key = 'Compartilhada PT' },
	['en-US'] = { shared_key = 'Shared EN' }
}
local staticNuiDict = Locale.ExportForNui('en-US')
assertTrue(type(staticNuiDict) == 'table', 'Locale.ExportForNui estático retorna tabela')
assertEqual(staticNuiDict.shared_key, 'Shared EN', 'Locale.ExportForNui prioriza idioma alvo')
assertEqual(staticNuiDict.static_key, 'Chave Estática', 'Locale.ExportForNui inclui fallback pt-BR')

-- 3.0 Validação de Dicionários da Fase 2 (Núcleo e Economia)
local phase2Resources = { 'coe_core', 'coe_inventory', 'coe_economy', 'coe_banking', 'coe_businesses' }
for _, resName in ipairs(phase2Resources) do
	local basePath = resName == 'coe_core' and '.' or ('../' .. resName)
	Locales = {}
	local ptFile = basePath .. '/locales/pt-br.lua'
	local enFile = basePath .. '/locales/en-us.lua'

	local fPt = io.open(ptFile, 'r')
	if fPt then
		fPt:close()
		dofile(ptFile)
		assertTrue(type(Locales['pt-BR']) == 'table', resName .. ': pt-BR deve ser uma tabela')
		local countPt = 0
		for _ in pairs(Locales['pt-BR']) do countPt = countPt + 1 end
		assertTrue(countPt > 0, resName .. ': pt-BR deve conter chaves')
	end

	local fEn = io.open(enFile, 'r')
	if fEn then
		fEn:close()
		dofile(enFile)
		assertTrue(type(Locales['en-US']) == 'table', resName .. ': en-US deve ser uma tabela')
		local countEn = 0
		for _ in pairs(Locales['en-US']) do countEn = countEn + 1 end
		assertTrue(countEn > 0, resName .. ': en-US deve conter chaves')
	end
end

print('✅ Todos os testes de CoeLocale (i18n / l10n) passaram com sucesso!')