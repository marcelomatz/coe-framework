--[[
	tools/smoke_boot_scripts_test.lua
	Smoke boot dos scripts avançados (vindos do antigo coe-resources): chunks globais e locales.
	Complementa tools/smoke_boot_test.lua, que cobre a base do framework.
	Previne regressões de 'attempt to call a table value (local _t)' e falhas em chunks globais.
]]

local failures = 0
local totalTests = 0

local function test(name, fn)
	totalTests = totalTests + 1
	local ok, err = pcall(fn)
	if ok then
		print(string.format("  ✅ %s", name))
	else
		failures = failures + 1
		print(string.format("  ❌ %s: %s", name, tostring(err)))
	end
end

local function assertEqual(actual, expected, msg)
	if actual ~= expected then
		error(string.format("%s: esperado %s, obtido %s", msg or "Valor incorreto", tostring(expected), tostring(actual)), 2)
	end
end

local function assertTrue(condition, msg)
	if not condition then
		error(msg or "Condição booleana falhou", 2)
	end
end

local function findResourcePath(res)
	local f = io.open(res .. '/fxmanifest.lua', 'r')
	if f then f:close() return res end
	return res
end

-- Configura stubs globais de runtime do FiveM
local function setupFiveMEnvironment()
	_G.GetGameTimer = function() return 1000 end
	_G.Wait = function() end
	_G.CreateThread = function() end
	_G.RegisterNetEvent = function() end
	_G.AddEventHandler = function() end
	_G.RegisterCommand = function() end
	_G.RemoveEventHandler = function() end
	_G.GetPlayerPed = function() return 1 end
	_G.PlayerPedId = function() return 1 end
	_G.PlayerId = function() return 1 end
	_G.DoesEntityExist = function() return false end
	_G.GetEntityCoords = function() return { x = 0, y = 0, z = 0 } end
	_G.SendNUIMessage = function() end

	_G.LoadResourceFile = function(resource, path)
		local base = findResourcePath(resource)
		local f = io.open(base .. '/' .. path, 'r')
		if not f then return nil end
		local content = f:read('*a')
		f:close()
		return content
	end

	_G.GetConvar = function(key, default)
		if key == 'coe_locale' then return 'pt-BR' end
		return default
	end

	local registry = {}
	_G.exports = setmetatable({
		['coe_core'] = {
			GetCoreObject = function()
				return {
					Prefix = 'coe_core',
					Events = { OnNet = function() end, ToServer = function() end, Emit = function() end },
					Classes = { Registry = {} },
					Locale = { New = function() error("RPC REMOTO NUNCA DEVE SER CHAMADO") end },
					Platform = {}
				}
			end
		},
		['coe_logging'] = { Log = function() end },
		['coe_audit'] = { Record = function() end },
		['coe_notify'] = { Notify = function() end, Show = function() end }
	}, {
		__call = function(_, name, fn)
			registry[name] = fn
		end
	})

	_G.GetInvokingResource = function() return 'test' end
	_G.GetCurrentResourceName = function() return 'test' end
end

setupFiveMEnvironment()

print("======================================================================")
print("🧪 SUÍTE DE TESTES DE BOOT E FRONTEIRA DE EXPORT / RUNTIME (SMOKE BOOT) — SCRIPTS AVANÇADOS")
print("======================================================================")

-- ---------------------------------------------------------------------------
-- 1. TESTE DE FRONTEIRA: SERIALIZAÇÃO E PERDA DE METATABLES EM EXPORTS
-- ---------------------------------------------------------------------------
print("\n[1/4] Simulação de Perda de Metatables por MsgPack em Exports FiveM...")

local coreBase = findResourcePath('coe_core')

test("Locale.New com metatable preservada é chamável", function()
	local Locale = dofile(coreBase .. '/lib/locale.lua')
	local loc = Locale.New({
		default = 'pt-BR',
		locales = { ['pt-BR'] = { hello = 'Olá Mundo' } }
	})
	assertTrue(type(loc) == 'table', "Instância deve ser tabela")
	assertEqual(loc('hello'), 'Olá Mundo', "Chamada direta __call deve funcionar")
end)

test("Simulação de des-serialização (strip de metatable): fallback e .T defensivo", function()
	local strippedInstance = {
		lang = 'pt-BR',
		fallback = 'pt-BR',
		locales = { ['pt-BR'] = { not_staff = 'Sem permissão' } }
	}
	assertTrue(getmetatable(strippedInstance) == nil, "Tabela simulada sem metatable")

	local rawLocales = strippedInstance.locales
	local _t = function(k, params)
		if type(strippedInstance) == 'table' then
			if strippedInstance.T then
				return strippedInstance:T(k, params)
			end
			local lang = strippedInstance.lang or 'pt-BR'
			local dict = (strippedInstance.locales and strippedInstance.locales[lang]) or rawLocales[lang] or rawLocales['pt-BR']
			if dict and dict[k] then
				return dict[k]
			end
		elseif type(strippedInstance) == 'function' then
			return strippedInstance(k, params)
		end
		return (rawLocales['pt-BR'] and rawLocales['pt-BR'][k]) or k
	end

	assertTrue(type(_t) == 'function', "_t deve ser função")
	assertEqual(_t('not_staff'), 'Sem permissão', "Deve resolver chave mesmo com metatable stripped")
	assertEqual(_t('desconhecido'), 'desconhecido', "Fallback para a própria chave")
end)

-- ---------------------------------------------------------------------------
-- 2. TESTE DE CARREGAMENTO LOCAL EM @coe_core/lib/init.lua
-- ---------------------------------------------------------------------------
print("\n[2/4] Validação do Inicializador @coe_core/lib/init.lua...")

test("init.lua sobrepõe Core.Locale com módulo local via LoadResourceFile", function()
	setupFiveMEnvironment()
	dofile(coreBase .. '/lib/init.lua')

	assertTrue(type(_G.Core.Locale.New) == 'function', "Core.Locale.New local deve ser função")
	local instance = _G.Core.Locale.New({
		default = 'pt-BR',
		locales = { ['pt-BR'] = { test_key = 'Sucesso Local' } }
	})
	assertEqual(instance('test_key'), 'Sucesso Local', "Instância local deve ter metatable intacta e __call funcional")
end)

-- ---------------------------------------------------------------------------
-- 3. TESTE DE BOOT DOS CHUNKS GLOBAIS DE RECURSOS CRÍTICOS PROPRIETÁRIOS
-- ---------------------------------------------------------------------------
print("\n[3/4] Avaliação de Chunks Globais em Scripts Avançados...")

test("coe_banking: inicialização do chunk global e MESSAGES", function()
	setupFiveMEnvironment()
	dofile(coreBase .. '/lib/init.lua')

	_G.BankingConfig = {
		Locale = 'pt-BR',
		Currency = 'R$',
		PinHashRounds = 10,
		MaxBalance = 100000000
	}
	_G.Locales = {}
	dofile('coe_banking/locales/pt-br.lua')
	dofile('coe_banking/locales/en-us.lua')

	local ok, err = pcall(dofile, 'coe_banking/server/main.lua')
	assertTrue(ok, "coe_banking/server/main.lua deve carregar sem erro: " .. tostring(err))
end)

-- ---------------------------------------------------------------------------
-- 4. TESTE DE CONFORMIDADE DOS RECURSOS PROPRIETÁRIOS COM I18N
-- ---------------------------------------------------------------------------
print("\n[4/4] Validação de Scripts Avançados com i18n...")

local advancedLocales = {
	'coe_news', 'coe_telecom', 'coe_fuel', 'coe_amzg',
	'coe_police', 'coe_ems', 'coe_dispatch',
	'coe_mechanic', 'coe_housing',
	'coe_deepweb', 'coe_loot', 'coe_tablet', 'coe_races'
}
for _, res in ipairs(advancedLocales) do
	test(res .. ": locales e instanciação de _t sem falhas", function()
		setupFiveMEnvironment()
		dofile(coreBase .. '/lib/init.lua')

		_G.Locales = {}
		dofile(res .. '/locales/pt-br.lua')
		dofile(res .. '/locales/en-us.lua')

		local loc = _G.Core.Locale.New({
			default = 'pt-BR',
			locales = _G.Locales
		})
		assertTrue(type(loc) == 'table', res .. ": loc deve ser tabela com metatable")
		local sampleKey = next(_G.Locales['pt-BR'])
		assertTrue(sampleKey ~= nil, res .. ": deve ter chaves em pt-BR")
		local translated = loc(sampleKey)
		assertTrue(type(translated) == 'string' and #translated > 0, res .. ": tradução de " .. sampleKey .. " válida")
	end)
end

print("\n======================================================================")
print(string.format("📊 RESULTADO DO SMOKE BOOT: %d passaram, %d falharam", totalTests - failures, failures))
print("======================================================================")

if failures > 0 then
	os.exit(1)
end
