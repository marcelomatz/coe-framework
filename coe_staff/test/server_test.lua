-- Servidor do painel da staff com natives e exports simulados: ACE por módulo, limite de taxa, ferramentas
-- pessoais, jogadores (teleporte, congelar, expulsar, item, dinheiro, grupos), veículos, mundo, negócios e Yield.
local handlers, netHandlers, exported, responses, clientEvents, notices, audits, dropped = {}, {}, {}, {}, {}, {}, {}, {}
local now = 1000
source = nil
GlobalState = {}

function GetGameTimer() return now end
local states = {}
function GetResourceState(name) return states[name] or 'started' end
function GetCurrentResourceName() return 'coe_staff' end
function CreateThread(fn) fn() end
function Wait() end
function SetTimeout() end
function RegisterNetEvent(name, fn) netHandlers[name] = fn end
function AddEventHandler(name, fn) handlers[name] = fn end
function TriggerClientEvent(name, target, a, b, c)
	if name == 'coe_staff:response' then
		responses[#responses + 1] = { target = target, id = a, result = b }
	else
		clientEvents[#clientEvents + 1] = { name = name, target = target, a = a, b = b }
	end
end
local invoking = nil
function GetInvokingResource() return invoking end
local aces = { [1] = { ['coe.staff.all'] = true }, [2] = { ['coe.staff.players'] = true } }
function IsPlayerAceAllowed(id, ace) return aces[id] and aces[id][ace] == true or false end
function IsPrincipalAceAllowed(principal, ace) return ace == 'coe.staff.yield' and principal == 'resource.pack_admin' end
function GetPlayers() return { '1', '2', '3' } end
local names = { [1] = 'admin', [2] = 'mod', [3] = 'player' }
function GetPlayerName(id) return names[id] end
function GetPlayerPing() return 30 end
function GetPlayerPed(id) return id end
local positions = { [1] = { x = 1, y = 2, z = 3 }, [2] = { x = 4, y = 5, z = 6 }, [3] = { x = 7, y = 8, z = 9 } }
function GetEntityCoords(id) return positions[id] end
function GetEntityHeading() return 90.0 end
function DropPlayer(id, reason) dropped[#dropped + 1] = { id = id, reason = reason } end
local entities = { [500] = { type = 2, state = {} }, [501] = { type = 2, state = { ['coe:vehicleId'] = 'v9' } }, [502] = { type = 1, state = {} } }
local deleted = {}
function NetworkGetEntityFromNetworkId(netId) return entities[netId] and netId or 0 end
function DoesEntityExist(e) return entities[e] ~= nil end
function GetEntityType(e) return entities[e].type end
function Entity(e) return { state = entities[e].state } end
function DeleteEntity(e) deleted[#deleted + 1] = e; entities[e] = nil end
promise = { new = function() local p = {}; function p:resolve(v) if self.value == nil then self.value = v end end; return p end }
Citizen = { Await = function(p) return p.value end }
json = { encode = function(t) return string.rep('x', t.size or 2) end }

local online = {
	[1] = { characterId = 11, stateId = 'AAAA2222', firstName = 'Ana', lastName = 'Souza' },
	[3] = { characterId = 33, stateId = 'CCCC4444', firstName = 'Caio', lastName = 'Melo' }
}
Core = {
	Players = {
		GetActiveCharacter = function(id) return online[id] end,
		GetPlayerByStateId = function(stateId)
			for id, c in pairs(online) do if c.stateId == stateId then return { source = id } end end
			return nil
		end
	}
}

-- Estado simulado dos resources do framework
local inventory = { inv1 = {}, inv3 = { money = 50 } }
local balances = { ['11'] = 100, ['33'] = 0 }
local groupCalls = {}
local businesses = {}
local saved = {}
local vehicles = {}
local stored = {}

exports = setmetatable({}, {
	__call = function(_, name, fn) exported[name] = fn end,
	__index = function(_, resource)
		if resource == 'coe_inventory' then
			return {
				Items = function(_, name)
					local all = { water = { label = 'Água' }, money = { label = 'Dinheiro' } }
					if name then return all[name] end
					return all
				end,
				GetPlayerInventory = function(_, id) return online[id] and ('inv' .. id) or nil end,
				AddItem = function(_, inv, item, count)
					if count > 500 then return false end
					inventory[inv][item] = (inventory[inv][item] or 0) + count; return true
				end,
				RemoveItemByName = function(_, inv, item, count)
					if (inventory[inv][item] or 0) < count then return false end
					inventory[inv][item] = inventory[inv][item] - count; return true
				end
			}
		end
		if resource == 'coe_economy' then
			return {
				Credit = function(_, id, amount, reason) eq_reason = reason; balances[id] = balances[id] + amount; return true end,
				Debit = function(_, id, amount) if balances[id] < amount then return nil end; balances[id] = balances[id] - amount; return true end
			}
		end
		if resource == 'coe_core' then
			return {
				GetPlayerGroups = function() return { job = { name = 'police', grade = 1 } } end,
				GetGroupDefinitions = function() return { { name = 'police', type = 'job' } } end,
				SetPlayerGroup = function(_, target, name, grade, cb)
					groupCalls[#groupCalls + 1] = { 'set', target, name, grade }
					if name == 'nope' then return 'group_not_found' end
					cb(true, {}); return true
				end,
				RemovePlayerGroup = function(_, target, name, cb)
					groupCalls[#groupCalls + 1] = { 'remove', target, name }
					cb(false, nil, 'not_member'); return true
				end
			}
		end
		if resource == 'coe_vehicle_catalog' then
			return {
				ListVehicles = function(_, filter) return { { model = 'adder', name = 'Adder', brand = 'Truffade', type = 'automobile', search = filter.search } } end,
				GetVehicleInfo = function(_, model) return { model = model, type = 'automobile' } end
			}
		end
		if resource == 'coe_vehicles' then
			return {
				Create = function(_, data)
					if data.model == 'bad' then return 'invalid_model' end
					vehicles[#vehicles + 1] = data; return { id = 'v' .. #vehicles, plate = 'ABC123' }
				end,
				Spawn = function(_, id, x, y, z, h, vtype) return vtype == 'automobile' and 777 or 'spawn_failed' end,
				Store = function(_, id) stored[#stored + 1] = id; return true end
			}
		end
		if resource == 'coe_businesses' then
			return {
				IsReady = function() return true end,
				List = function()
					local list = {}
					for _, b in pairs(businesses) do list[#list + 1] = b end
					return list
				end,
				Get = function(_, id) return businesses[id] end,
				Categories = function()
					return { restaurant = { label = 'Restaurantes', stations = { 'stashes', 'clocks' }, rules = { 'clockRequired' } } }
				end,
				RuleSchema = function() return { clockRequired = { type = 'boolean' } } end,
				Permissions = function() return { { name = 'business.staff', label = 'Equipe' } } end,
				Save = function(_, raw, by)
					if raw.label == 'Recusado' then return { error = 'invalid_label' } end
					saved[#saved + 1] = { id = raw.id, by = by }
					businesses[raw.id] = raw; return raw
				end,
				Delete = function(_, id)
					if not businesses[id] then return { error = 'unknown_business' } end
					businesses[id] = nil; return true
				end
			}
		end
		if resource == 'coe_database' then
			return {
				Query = function(_, sql, params, cb)
					if params[1] == 'DDDD5555' then
						cb(true, { { character_id = 44, first_name = 'Dani', last_name = 'Reis' } })
					else
						cb(true, {})
					end
				end
			}
		end
		if resource == 'coe_notify' then
			return { Notify = function(_, id, kind, message) notices[#notices + 1] = { id = id, kind = kind, message = message } end }
		end
		if resource == 'coe_audit' then
			return { Record = function(_, _, _, event, ctx) audits[#audits + 1] = { event = event, ctx = ctx } end }
		end
		return setmetatable({}, { __index = function() return function() return true end end })
	end
})

dofile('../coe_core/lib/access.lua')
dofile('config.lua')
dofile('locales/pt-br.lua')
dofile('shared/rules.lua')
dofile('server/main.lua')

function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end
local requestId = 0
local function act(admin, action, data)
	requestId = requestId + 1
	source = admin
	now = now + 1000
	netHandlers['coe_staff:request'](requestId, action, data or {})
	local response = responses[#responses]
	eq(response.id, requestId, 'resposta do pedido')
	eq(response.target, admin, 'para quem pediu')
	return response.result
end
local function lastEvent(name)
	for index = #clientEvents, 1, -1 do
		if clientEvents[index].name == name then return clientEvents[index] end
	end
end
local function lastAudit() return audits[#audits] end

-- Abrir: só quem tem algum módulo
source = 1
netHandlers['coe_staff:open']()
eq(lastEvent('coe_staff:opened').a.modules.businesses, true, 'admin ve todos os modulos')
clientEvents = {}
source = 3
netHandlers['coe_staff:open']()
eq(lastEvent('coe_staff:opened'), nil, 'sem ACE nao abre')
source = 2
netHandlers['coe_staff:open']()
local opened = lastEvent('coe_staff:opened').a
eq(opened.modules.players, true, 'moderador: jogadores')
eq(opened.modules.self, nil, 'moderador: sem pessoal')

-- Permissão por módulo, taxa e payload
eq(act(3, 'players').error, 'forbidden', 'sem ACE')
eq(act(2, 'noclip', { on = true }).error, 'forbidden', 'modulo nao liberado')
eq(act(2, 'players').ok, true, 'modulo liberado')
eq(act(1, 'hack').error, 'forbidden', 'acao desconhecida')
source = 1
netHandlers['coe_staff:request'](999, 'players', {})
netHandlers['coe_staff:request'](1000, 'players', {})
eq(responses[#responses].result.error, 'busy', 'limite de taxa')
now = now + 1000
netHandlers['coe_staff:request'](1001, 'players', { size = 99999 })
eq(responses[#responses].result.error, 'invalid_payload', 'payload grande')
netHandlers['coe_staff:request']('x', 'players', {})
eq(responses[#responses].id, 1001, 'requestId invalido ignorado')

-- Ferramentas pessoais
eq(act(1, 'noclip', { on = true }).ok, true, 'noclip autorizado')
eq(lastAudit().event, 'staff_noclip', 'noclip auditado')
eq(lastAudit().ctx.result, 'on', 'ligado')
eq(act(1, 'tpCoords', { x = 10, y = 20, z = 30 }).data.x, 10, 'teleporte por coordenadas')
eq(act(1, 'tpCoords', { x = 'a' }).error, 'invalid_coords', 'coordenadas invalidas')

-- Jogadores
local list = act(1, 'players').data.players
eq(#list, 3, 'tres online')
eq(list[1].character, 'Ana Souza', 'nome do personagem')
eq(list[3].stateId, 'CCCC4444', 'id de cidadao')
eq(act(1, 'gotoPlayer', { target = 3 }).data.x, 7, 'ir ate')
eq(act(1, 'gotoPlayer', { target = 9 }).error, 'player_offline', 'jogador offline')
act(1, 'bringPlayer', { target = 3 })
local e = lastEvent('coe_staff:effect')
eq(e.target, 3, 'trazer: efeito no alvo'); eq(e.a, 'teleport', 'teleporte'); eq(e.b.x, 1, 'para a posicao do admin')
act(1, 'freezePlayer', { target = 3, on = true })
eq(lastEvent('coe_staff:effect').b.on, true, 'congela')
eq(act(1, 'players').data.players[3].frozen, true, 'lista mostra congelado')
act(1, 'healPlayer', { target = 3 })
eq(lastEvent('coe_staff:effect').a, 'heal', 'cura')
act(1, 'revivePlayer', { target = 3 })
eq(lastEvent('coe_staff:effect').a, 'revive', 'revive')
eq(act(1, 'kickPlayer', { target = 1 }).error, 'self_target', 'nao expulsa a si mesmo')
eq(act(1, 'kickPlayer', { target = 3, reason = 'teste <b>' }).ok, true, 'expulsa')
eq(dropped[1].id, 3, 'expulso')
eq(dropped[1].reason:find('teste b', 1, true) ~= nil, true, 'motivo limpo')

-- Itens e dinheiro
eq(#act(1, 'items', { search = 'wat' }).data.items, 1, 'catalogo de itens')
eq(act(1, 'giveItem', { target = 3, item = 'water', count = 5 }).ok, true, 'da item')
eq(inventory.inv3.water, 5, 'item no inventario')
eq(lastAudit().ctx.item, 'water', 'auditado com o item')
eq(notices[#notices].id, 3, 'jogador avisado')
eq(act(1, 'giveItem', { target = 3, item = 'nope' }).error, 'invalid_item', 'item inexistente')
eq(act(1, 'giveItem', { target = 3, item = 'water', count = 0 }).error, 'invalid_item', 'quantidade zero')
eq(act(1, 'giveItem', { target = 2, item = 'water' }).error, 'no_character', 'sem personagem')
eq(act(1, 'money', { target = 3, kind = 'cash', amount = 100 }).ok, true, 'da especie')
eq(inventory.inv3.money, 150, 'especie no inventario')
eq(act(1, 'money', { target = 3, kind = 'cash', amount = 200, op = 'take' }).error, 'insufficient_funds', 'retira mais que tem')
eq(act(1, 'money', { target = 3, kind = 'bank', amount = 300 }).ok, true, 'credita conta')
eq(balances['33'], 300, 'saldo')
eq(eq_reason, 'admin_adjustment', 'motivo do extrato')
eq(act(1, 'money', { target = 3, kind = 'bank', amount = 100, op = 'take' }).ok, true, 'debita conta')
eq(balances['33'], 200, 'saldo depois do debito')
eq(act(1, 'money', { target = 3, kind = 'gold', amount = 1 }).error, 'invalid_kind', 'tipo invalido')
eq(act(1, 'money', { target = 3, kind = 'bank', amount = -5 }).error, 'invalid_amount', 'valor invalido')

-- Grupos
local groups = act(1, 'groups', { target = 3 }).data
eq(groups.current.job.name, 'police', 'grupos atuais')
eq(#groups.definitions, 1, 'definicoes')
eq(act(1, 'setGroup', { target = 3, name = 'police', grade = 2 }).ok, true, 'define grupo')
eq(groupCalls[1][4], 2, 'grau')
eq(act(1, 'setGroup', { target = 3, name = 'nope' }).error, 'group_not_found', 'grupo inexistente')
eq(act(1, 'setGroup', { target = 3, name = 'Bad Name' }).error, 'invalid_group', 'nome invalido')
eq(act(1, 'removeGroup', { target = 3, name = 'police' }).error, 'not_member', 'erro do callback')

-- Veículos
eq(act(1, 'catalog', { search = 'add' }).data.vehicles[1].model, 'adder', 'catalogo')
eq(act(1, 'spawnVehicle', { model = 'Adder' }).data.model, 'adder', 'temporario: client cria')
local owned = act(1, 'spawnVehicle', { model = 'adder', mode = 'owned' })
eq(owned.data.netId, 777, 'registrado: netId')
eq(vehicles[1].characterId, '11', 'do personagem do admin')
eq(act(1, 'spawnVehicle', { model = 'bad', mode = 'owned' }).error, 'invalid_model', 'erro do coe_vehicles')
eq(act(1, 'spawnVehicle', { model = 'a b' }).error, 'invalid_model', 'modelo invalido')
eq(act(1, 'deleteVehicle', { netId = 500 }).ok, true, 'apaga solto')
eq(deleted[1], 500, 'removido')
eq(act(1, 'deleteVehicle', { netId = 501 }).ok, true, 'guarda registrado')
eq(stored[1], 'v9', 'guardado pelo coe_vehicles')
eq(act(1, 'deleteVehicle', { netId = 502 }).error, 'no_vehicle', 'nao e veiculo')
eq(act(1, 'vehicleFix', { op = 'repair' }).ok, true, 'conserto autorizado')
eq(act(1, 'vehicleFix', { op = 'explode' }).error, 'invalid_action', 'operacao invalida')

-- Mundo
eq(act(1, 'setTime', { hour = 22, minute = 30, freeze = true }).data.time.hour, 22, 'hora')
eq(GlobalState.coeStaffWorld.time.freeze, true, 'publicado para todos')
local version = GlobalState.coeStaffWorld.version
act(1, 'setWeather', { weather = 'RAIN' })
eq(GlobalState.coeStaffWorld.weather, 'RAIN', 'clima')
eq(GlobalState.coeStaffWorld.version, version + 1, 'versao sobe')
eq(act(1, 'setWeather', { weather = 'LAVA' }).error, 'invalid_weather', 'clima invalido')
eq(act(1, 'setTime', { hour = 30 }).error, 'invalid_time', 'hora invalida')
act(1, 'resetWorld')
eq(GlobalState.coeStaffWorld, false, 'volta ao ciclo natural')
notices = {}
eq(act(1, 'announce', { text = 'Reinício em 5 min' }).ok, true, 'aviso')
eq(#notices, 3, 'para todos')

-- Negócios
local r = act(1, 'businessCreate', { id = 'burger', label = 'Burger', category = 'restaurant', radius = 20 })
eq(r.ok, true, 'cria negocio')
eq(r.data.business.area.x, 1, 'area na posicao do admin')
eq(saved[1].by, 'staff:1', 'quem gravou')
eq(act(1, 'businessCreate', { id = 'burger', label = 'X', category = 'restaurant' }).error, 'id_taken', 'id repetido')
local data = act(1, 'businesses').data
eq(#data.businesses, 1, 'lista')
eq(data.categories[1].id, 'restaurant', 'categorias')
eq(data.permissions[1].name, 'business.staff', 'permissoes')
positions[1] = { x = 50, y = 60, z = 70 }
r = act(1, 'stationAdd', { id = 'burger', kind = 'clocks', label = 'Relógio' })
eq(r.data.business.stations.clocks[1].x, 50, 'relogio na posicao do admin')
eq(lastAudit().event, 'staff_station_add', 'auditado')
r = act(1, 'businessOwner', { id = 'burger', stateId = 'DDDD5555' })
eq(r.data.business.owner.name, 'Dani Reis', 'dono offline pelo cadastro')
r = act(1, 'staffAdd', { id = 'burger', stateId = 'cccc4444' })
eq(r.data.business.staff[1].characterId, '33', 'equipe online')
eq(act(1, 'staffAdd', { id = 'burger', stateId = 'ZZZZ9999' }).error, 'character_not_found', 'cidadao inexistente')
eq(act(1, 'staffAdd', { id = 'burger', stateId = 'x' }).error, 'invalid_state_id', 'id invalido')
r = act(1, 'businessOwner', { id = 'burger', stateId = '' })
eq(r.data.business.owner, nil, 'remove dono')
eq(act(1, 'businessInfo', { id = 'burger', label = 'Recusado' }).error, 'invalid_label', 'erro do coe_businesses')
eq(act(1, 'businessInfo', { id = 'nope' }).error, 'unknown_business', 'negocio inexistente')
eq(act(1, 'businessGoto', { id = 'burger' }).data.x, 1, 'ir ate o negocio')
eq(#act(1, 'businessDelete', { id = 'burger' }).data.businesses, 0, 'apaga')
states.coe_businesses = 'stopped'
eq(act(1, 'businesses').error, 'businesses_unavailable', 'sem coe_businesses')
states.coe_businesses = nil

-- Pacote assume o painel
invoking = 'random'
eq(exported.Yield().error, 'forbidden', 'sem ACE nao assume')
invoking = 'pack_admin'
eq(exported.Yield(), true, 'pacote assume')
eq(GlobalState.coeStaffYielded, 'pack_admin', 'estado global')
eq(lastEvent('coe_staff:close').target, -1, 'fecha telas')
eq(act(1, 'players').error, 'unavailable', 'basico nao responde')
clientEvents = {}
source = 1
netHandlers['coe_staff:open']()
eq(lastEvent('coe_staff:opened'), nil, 'basico nao abre')
handlers.onResourceStop('pack_admin')
eq(exported.Status().active, true, 'volta')
eq(act(1, 'players').ok, true, 'volta a responder')

print('coe_staff server: ok')
