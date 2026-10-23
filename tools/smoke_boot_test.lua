--[[
	tools/smoke_boot_test.lua
	Suíte de Testes de Boot, Inicialização e Fronteira de Runtime (Smoke Boot)
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
		local f = io.open(resource .. '/' .. path, 'r')
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
print("🧪 SUÍTE DE TESTES DE BOOT E FRONTEIRA DE EXPORT / RUNTIME (SMOKE BOOT)")
print("======================================================================")

-- ---------------------------------------------------------------------------
-- 1. TESTE DE FRONTEIRA: SERIALIZAÇÃO E PERDA DE METATABLES EM EXPORTS
-- ---------------------------------------------------------------------------
print("\n[1/4] Simulação de Perda de Metatables por MsgPack em Exports FiveM...")

test("Locale.New com metatable preservada é chamável", function()
	local Locale = dofile('coe_core/lib/locale.lua')
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
	dofile('coe_core/lib/init.lua')

	assertTrue(type(_G.Core.Locale.New) == 'function', "Core.Locale.New local deve ser função")
	local instance = _G.Core.Locale.New({
		default = 'pt-BR',
		locales = { ['pt-BR'] = { test_key = 'Sucesso Local' } }
	})
	assertEqual(instance('test_key'), 'Sucesso Local', "Instância local deve ter metatable intacta e __call funcional")
end)

-- ---------------------------------------------------------------------------
-- 3. TESTE DE BOOT DOS CHUNKS GLOBAIS DE RECURSOS CRÍTICOS DO FRAMEWORK
-- ---------------------------------------------------------------------------
print("\n[3/4] Avaliação de Chunks Globais em Recursos Críticos...")

test("coe_businesses: inicialização do chunk global e CLOCK_MESSAGES", function()
	setupFiveMEnvironment()
	dofile('coe_core/lib/init.lua')

	dofile('coe_businesses/config.lua')
	_G.Locales = {}
	dofile('coe_businesses/locales/pt-br.lua')
	dofile('coe_businesses/locales/en-us.lua')
	-- Mesma ordem do fxmanifest: helper de acesso e registro de extensões antes do main.
	dofile('coe_core/lib/access.lua')
	dofile('coe_businesses/server/extensions.lua')

	local ok, err = pcall(dofile, 'coe_businesses/server/main.lua')
	assertTrue(ok, "coe_businesses/server/main.lua deve carregar sem erro: " .. tostring(err))
end)

test("coe_inventory: apresentação e sincronização de C.syncCarriedState", function()
	setupFiveMEnvironment()
	dofile('coe_core/lib/init.lua')

	_G.Config = {
		Locale = 'pt-BR',
		Client = {
			streamTimeoutMs = 1000,
			networkControlTimeoutMs = 1000,
			openKey = 289
		},
		Containers = { items = {} }
	}
	_G.Inventory = { Client = {} }
	_G.Locales = {}
	dofile('coe_inventory/locales/pt-br.lua')
	dofile('coe_inventory/locales/en-us.lua')

	local okState, errState = pcall(dofile, 'coe_inventory/presentation/state.lua')
	assertTrue(okState, "coe_inventory/presentation/state.lua deve carregar sem erro: " .. tostring(errState))

	local C = _G.Inventory.Client
	assertTrue(type(C.syncCarriedState) == 'function', "C.syncCarriedState DEVE ser uma função definida")
	assertTrue(type(C.ERROR_MESSAGES) == 'table', "C.ERROR_MESSAGES deve ser tabela avaliada")
	assertTrue(type(C.ERROR_MESSAGES.rate_limited) == 'string', "C.ERROR_MESSAGES.rate_limited deve conter texto traduzido")

	_G.Core.Events.OnNet = function(eventName, handler)
		if eventName == 'inventory.response' then
			C.state.activeRequestId = 123
			local okCall, errCall = pcall(handler, 123, { items = {} })
			assertTrue(okCall, "handler de inventory.response deve executar sem erro: " .. tostring(errCall))
		end
	end
	_G.C = C
	C.reconcileContainerProps = function() end
	C.openInventoryUi = function() end

	local okEvents, errEvents = pcall(dofile, 'coe_inventory/presentation/server_events.lua')
	assertTrue(okEvents, "coe_inventory/presentation/server_events.lua deve carregar sem erro: " .. tostring(errEvents))
end)

test("coe_economy: inicialização do chunk global com _t defensivo", function()
	setupFiveMEnvironment()
	dofile('coe_core/lib/init.lua')

	_G.config = {
		Locale = 'pt-BR',
		Currency = 'R$'
	}
	_G.Locales = {}
	dofile('coe_economy/locales/pt-br.lua')
	dofile('coe_economy/locales/en-us.lua')

	local ok, err = pcall(dofile, 'coe_economy/server/main.lua')
	assertTrue(ok, "coe_economy/server/main.lua deve carregar sem erro: " .. tostring(err))
end)

test("coe_vehicles: inicialização do chunk global com _t defensivo", function()
	setupFiveMEnvironment()
	dofile('coe_core/lib/init.lua')

	_G.CoeVehiclesConfig = {
		Locale = 'pt-BR'
	}
	_G.Locales = {}
	dofile('coe_vehicles/locales/pt-br.lua')
	dofile('coe_vehicles/locales/en-us.lua')
	dofile('coe_vehicles/server/registry.lua')
	dofile('coe_vehicles/server/keys.lua')

	local okServer, errServer = pcall(dofile, 'coe_vehicles/server/main.lua')
	assertTrue(okServer, "coe_vehicles/server/main.lua deve carregar sem erro: " .. tostring(errServer))

	local okClient, errClient = pcall(dofile, 'coe_vehicles/client/keys.lua')
	assertTrue(okClient, "coe_vehicles/client/keys.lua deve carregar sem erro: " .. tostring(errClient))
end)

test("coe_bank: inicialização do servidor e do client com _t defensivo", function()
	setupFiveMEnvironment()
	dofile('coe_core/lib/init.lua')
	_G.GlobalState = {}
	_G.Locales = {}
	dofile('coe_bank/config.lua')
	dofile('coe_bank/locales/pt-br.lua')
	dofile('coe_bank/locales/en-us.lua')
	dofile('coe_bank/shared/rules.lua')
	dofile('coe_core/lib/access.lua')

	local okServer, errServer = pcall(dofile, 'coe_bank/server/main.lua')
	assertTrue(okServer, "coe_bank/server/main.lua deve carregar sem erro: " .. tostring(errServer))
	assertEqual(_G.GlobalState.coeBankYielded, false, "coe_bank começa atendendo")

	_G.AddStateBagChangeHandler = function() end
	_G.RegisterNUICallback = function() end
	_G.joaat = function(name) return #name end
	local okClient, errClient = pcall(dofile, 'coe_bank/client/main.lua')
	assertTrue(okClient, "coe_bank/client/main.lua deve carregar sem erro: " .. tostring(errClient))
end)

test("coe_mobile: inicialização do servidor e do client com _t defensivo", function()
	setupFiveMEnvironment()
	dofile('coe_core/lib/init.lua')
	_G.GlobalState = {}
	_G.Locales = {}
	dofile('coe_mobile/config.lua')
	dofile('coe_mobile/locales/pt-br.lua')
	dofile('coe_mobile/locales/en-us.lua')
	dofile('coe_mobile/shared/rules.lua')
	dofile('coe_core/lib/access.lua')
	dofile('coe_core/lib/migrations.lua')
	dofile('coe_mobile/server/migrations.lua')
	dofile('coe_mobile/server/persistence.lua')

	local okServer, errServer = pcall(dofile, 'coe_mobile/server/main.lua')
	assertTrue(okServer, "coe_mobile/server/main.lua deve carregar sem erro: " .. tostring(errServer))
	assertEqual(_G.GlobalState.coeMobileYielded, false, "coe_mobile começa atendendo")

	_G.AddStateBagChangeHandler = function() end
	_G.RegisterNUICallback = function() end
	_G.RegisterKeyMapping = function() end
	local okClient, errClient = pcall(dofile, 'coe_mobile/client/main.lua')
	assertTrue(okClient, "coe_mobile/client/main.lua deve carregar sem erro: " .. tostring(errClient))
end)

test("coe_workpad: inicialização do servidor e do client com _t defensivo", function()
	setupFiveMEnvironment()
	dofile('coe_core/lib/init.lua')
	_G.GlobalState = {}
	_G.Locales = {}
	dofile('coe_workpad/config.lua')
	dofile('coe_workpad/locales/pt-br.lua')
	dofile('coe_workpad/locales/en-us.lua')
	dofile('coe_workpad/shared/rules.lua')
	dofile('coe_core/lib/access.lua')

	local okServer, errServer = pcall(dofile, 'coe_workpad/server/main.lua')
	assertTrue(okServer, "coe_workpad/server/main.lua deve carregar sem erro: " .. tostring(errServer))
	assertEqual(_G.GlobalState.coeWorkpadYielded, false, "coe_workpad começa atendendo")

	_G.AddStateBagChangeHandler = function() end
	_G.RegisterNUICallback = function() end
	_G.RegisterKeyMapping = function() end
	local okClient, errClient = pcall(dofile, 'coe_workpad/client/main.lua')
	assertTrue(okClient, "coe_workpad/client/main.lua deve carregar sem erro: " .. tostring(errClient))
end)

-- ---------------------------------------------------------------------------
-- 4. TESTE DE CONFORMIDADE DOS RECURSOS DO FRAMEWORK COM I18N
-- ---------------------------------------------------------------------------
print("\n[4/4] Validação de Recursos do Framework com i18n...")

local frameworkLocales = {
	'coe_core', 'coe_businesses', 'coe_economy', 'coe_inventory',
	'coe_jobs', 'coe_talk', 'coe_vehicles', 'coe_bank', 'coe_mobile', 'coe_workpad'
}
for _, res in ipairs(frameworkLocales) do
	test(res .. ": locales e instanciação de _t sem falhas", function()
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
