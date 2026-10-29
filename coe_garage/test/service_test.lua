-- Testes da camada de aplicação de coe_garage com natives, Core e banco simulados.
-- Rodar a partir da pasta do resource: lua test/service_test.lua
local exportsMap, netEvents, sent, threads, notified = {}, {}, {}, {}, {}
local registeredStaffProvider = nil
local memoryGarages = {}
local memorySlots = {}

source = 1

GetResourceState = function(res)
	return 'started'
end

exports = setmetatable({
	coe_notify = {
		Notify = function(_, target, kind, message)
			notified[#notified + 1] = { target, kind, message }
		end
	},
	coe_logging = {
		Log = function() end
	},
	coe_vehicles = {
		ListByOwner = function() return {} end,
		Get = function() return nil end,
		Spawn = function() return 1 end,
		Store = function() return true end,
		GiveKey = function() return true end
	},
	coe_staff = {
		RegisterGaragesProvider = function(_, provider)
			registeredStaffProvider = provider
			return true
		end
	}
}, {
	__call = function(_, name, fn)
		exportsMap[name] = fn
	end
})

RegisterNetEvent = function(name, fn)
	netEvents[name] = fn
end
AddEventHandler = function(name, fn)
	netEvents[name] = fn
end
TriggerClientEvent = function(name, target, payload)
	sent[#sent + 1] = { name = name, target = target, payload = payload }
end
local clock = 1000
GetGameTimer = function()
	return clock
end
GetPlayerPed = function() return 1 end
local playerPos = { x = 215.0, y = -805.0, z = 30.0 }
GetEntityCoords = function() return playerPos end
GetInvokingResource = function()
	return 'test'
end
GetCurrentResourceName = function()
	return 'coe_garage'
end
CreateThread = function(fn)
	threads[#threads + 1] = fn
end
Wait = function() end

Core = {
	Players = {
		GetActiveCharacterId = function() return 'char_1' end
	}
}

GaragePersistence = {
	Initialize = function() return true end,
	ListGarages = function()
		local list = {}
		for _, g in pairs(memoryGarages) do
			list[#list + 1] = g
		end
		return list
	end,
	SaveGarage = function(g)
		memoryGarages[g.id] = g
		return true
	end,
	DeleteGarage = function(id)
		memoryGarages[id] = nil
		return true
	end,
	GetSlot = function(vId)
		return memorySlots[vId]
	end,
	SaveSlot = function(vId, gId)
		memorySlots[vId] = gId
		return true
	end,
	SlotsOf = function()
		return memorySlots
	end
}

dofile('config.lua')
dofile('locales/pt-br.lua')
_t = function(k) return Locales['pt-BR'][k] or k end
dofile('domain/garage.lua')
dofile('application/service.lua')

-- Executa a thread de boot
for _, fn in ipairs(threads) do
	fn()
end

local function eq(a, b, msg)
	if a ~= b then
		error(('%s: esperado %s, obtido %s'):format(msg, tostring(b), tostring(a)), 2)
	end
end

-- 1. Verifica IsReady
eq(exportsMap.IsReady(), true, 'serviço pronto')

-- 2. Salva uma garagem via export
local saved = exportsMap.SaveGarage({
	id = 'garagem_central',
	label = 'Garagem Legion Square',
	kind = 'public',
	enabled = true,
	spots = {
		{ id = 'vaga_1', label = 'Vaga 1', x = 215.0, y = -805.0, z = 30.0, heading = 250.0, radius = 3.5 }
	},
	blip = { enabled = true, sprite = 357, color = 3, scale = 0.8 }
})
eq(saved ~= nil, true, 'garagem salva com sucesso')
eq(saved.id, 'garagem_central', 'id correto')

-- 3. Lista e busca
local list = exportsMap.ListGarages()
eq(#list, 1, 'uma garagem cadastrada')
local g = exportsMap.GetGarage('garagem_central')
eq(g ~= nil, true, 'garagem encontrada')
eq(g.label, 'Garagem Legion Square', 'label confere')

-- 4. Provedor coe_staff registrado
eq(registeredStaffProvider ~= nil, true, 'provedor staff registrado')
local staffList = registeredStaffProvider.List()
eq(#staffList, 1, 'staff vê garagem')

-- Salva nova pelo provedor staff
local staffSaved = registeredStaffProvider.Save({
	id = 'garagem_sandy',
	label = 'Garagem Sandy Shores',
	kind = 'public',
	enabled = true,
	spots = {
		{ id = 'vaga_1', label = 'Vaga 1', x = 1982.0, y = 3775.0, z = 32.0, heading = 120.0, radius = 3.5 }
	}
})
eq(staffSaved ~= nil and staffSaved.error == nil, true, 'staff salvou garagem')
eq(#exportsMap.ListGarages(), 2, 'agora duas garagens cadastradas')

-- Remove via provedor staff
local deleted = registeredStaffProvider.Delete('garagem_sandy')
eq(deleted, true, 'staff removeu garagem')
eq(#exportsMap.ListGarages(), 1, 'uma garagem restante')

-- 5. Retirada respeita a vaga fixa: veículo guardado em outra garagem não sai daqui.
local vehicles = {
	v1 = { id = 'v1', owner_id = 'char_1', state = 'stored', model = 'panto', plate = 'AAA111' }
}
exports.coe_vehicles.Get = function(_, id) return vehicles[id] end
local spawned = {}
exports.coe_vehicles.Spawn = function(_, id) spawned[#spawned + 1] = id return 77 end
memorySlots['v1'] = 'garagem_sandy'

local function retrieve(vehicleId)
	clock = clock + 5000
	notified = {}
	netEvents['coe_garage:retrieveVehicle']('garagem_central', 'vaga_1', vehicleId)
	return notified[#notified] and notified[#notified][3]
end

eq(retrieve('v1'), Locales['pt-BR']['wrong_garage'], 'veículo de outra garagem é recusado')
eq(#spawned, 0, 'nada spawnado')

memorySlots['v1'] = 'garagem_central'
eq(retrieve('v1'), Locales['pt-BR']['vehicle_retrieved'], 'retirada na garagem certa')
eq(spawned[1], 'v1', 'veículo spawnado')

memorySlots['v1'] = nil
vehicles.v1.state = 'stored'
eq(retrieve('v1'), Locales['pt-BR']['vehicle_retrieved'], 'sem vaga fixa sai em qualquer garagem')

vehicles.v2 = { id = 'v2', owner_id = 'char_9', state = 'stored' }
eq(retrieve('v2'), Locales['pt-BR']['not_your_vehicle'], 'veículo de outro dono é recusado')

print('coe_garage service_test: ok')
