-- Servidor do banco básico com natives e exports simulados: agência e caixa eletrônico, saque, depósito, estornos,
-- transferência para cidadão online e offline, distância, limite por operação e o Yield de um pacote.
local handlers, netHandlers, exported, responses, notices, audits, clientEvents = {}, {}, {}, {}, {}, {}, {}
local now = 1000
source = nil
GlobalState = {}

function GetGameTimer() return now end
function GetResourceState() return 'started' end
function GetCurrentResourceName() return 'coe_bank' end
function CreateThread(fn) fn() end
function Wait() end
function RegisterNetEvent(name, fn) netHandlers[name] = fn end
function AddEventHandler(name, fn) handlers[name] = fn end
function TriggerClientEvent(name, target, a, b)
	if name == 'coe_bank:response' then
		responses[#responses + 1] = { target = target, id = a, result = b }
	else
		clientEvents[#clientEvents + 1] = { name = name, target = target }
	end
end
local invoking = nil
function GetInvokingResource() return invoking end
function IsPrincipalAceAllowed(principal, ace) return ace == 'coe.bank.yield' and principal == 'resource.pack_bank' end

local positions = {}
local inVehicle = {}
function GetPlayerPed(id) return id end
function GetEntityCoords(id) return positions[id] or { x = 0, y = 0, z = 0 } end
function GetVehiclePedIsIn(ped) return inVehicle[ped] and 1 or 0 end

-- promise/Await síncronos (o banco simulado responde na hora).
promise = { new = function() local p = {}; function p:resolve(v) self.value = v end; return p end }
Citizen = { Await = function(p) return p.value end }

-- Personagens: 1 e 2 online, 3 offline (só no cadastro).
local online = {
	[1] = { characterId = 11, stateId = 'AAAA2222', firstName = 'Ana', lastName = 'Souza' },
	[2] = { characterId = 22, stateId = 'BBBB3333', firstName = 'Bruno', lastName = 'Lima' },
	[4] = { characterId = 44, stateId = 'DDDD5555', firstName = 'Dani', lastName = 'Reis' }
}
local registry = { CCCC4444 = { character_id = 33, first_name = 'Caio', last_name = 'Melo' } }
Core = {
	Players = {
		GetActiveCharacter = function(id) return online[id] end,
		GetPlayerByStateId = function(stateId)
			for id, c in pairs(online) do
				if c.stateId == stateId then return { source = id, character = c } end
			end
			return nil, 'character_not_online'
		end
	}
}

-- Economia, inventário e banco de dados
local balances = { ['11'] = 1000, ['22'] = 50, ['33'] = 0, ['44'] = 10 }
local ledger = {}
local creditFails = false
local inventories = { inv1 = 300, inv2 = 0, inv4 = 0 }
local fullInventory = {}

local function entry(id, delta, reason, reference)
	table.insert(ledger, 1, { id = id, delta = delta, reason = reason, reference = reference, created_at = 1792000000 })
end

exports = setmetatable({}, {
	__call = function(_, name, fn) exported[name] = fn end,
	__index = function(_, resource)
		if resource == 'coe_economy' then
			return {
				GetBalance = function(_, id) return balances[id] end,
				Credit = function(_, id, amount, reason, reference)
					if creditFails then return nil end
					balances[id] = balances[id] + amount; entry(id, amount, reason, reference); return true
				end,
				Debit = function(_, id, amount, reason, reference)
					if balances[id] < amount then return nil end
					balances[id] = balances[id] - amount; entry(id, -amount, reason, reference); return true
				end,
				Transfer = function(_, from, to, amount, reason, reference)
					if balances[from] < amount then return nil end
					balances[from] = balances[from] - amount; balances[to] = balances[to] + amount
					entry(from, -amount, reason, reference); entry(to, amount, reason, reference); return true
				end,
				Ledger = function(_, id, limit)
					local list = {}
					for _, row in ipairs(ledger) do
						if row.id == id and #list < limit then list[#list + 1] = row end
					end
					return list
				end
			}
		end
		if resource == 'coe_inventory' then
			return {
				GetPlayerInventory = function(_, id) return 'inv' .. id end,
				GetItemCount = function(_, inv, item) return item == 'money' and (inventories[inv] or 0) or 0 end,
				RemoveItemByName = function(_, inv, item, count)
					if item ~= 'money' or inventories[inv] < count then return false end
					inventories[inv] = inventories[inv] - count; return true
				end,
				AddItem = function(_, inv, item, count)
					if fullInventory[inv] then return false end
					inventories[inv] = (inventories[inv] or 0) + count; return true
				end
			}
		end
		if resource == 'coe_database' then
			return {
				Query = function(_, sql, params, cb)
					assert(sql:find('coe_characters', 1, true), 'consulta no cadastro de personagens')
					local row = registry[params[1]]
					cb(true, row and { row } or {})
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

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end
local requestId = 0
local function call(playerId, kind, payload)
	requestId = requestId + 1
	source = playerId
	now = now + 1000
	netHandlers['coe_bank:request'](requestId, kind, payload)
	local last = responses[#responses]
	eq(last.id, requestId, 'resposta do pedido')
	eq(last.target, playerId, 'resposta para quem pediu')
	return last.result
end
local function act(playerId, action, data)
	return call(playerId, 'action', { action = action, data = data or {} })
end

local legion = BankRules.Agency(BankConfig, 'legion')
local atCounter = { x = legion.x + 0.5, y = legion.y, z = legion.z }

eq(GlobalState.coeBankYielded, false, 'banco ativo ao iniciar')
eq(exported.Status().active, true, 'status ativo')

-- Agência: longe e perto
positions[1] = { x = 0, y = 0, z = 0 }
eq(call(1, 'open', { mode = 'agency', agencyId = 'legion' }).error, 'too_far', 'longe do balcao')
eq(act(1, 'refresh').error, 'unavailable', 'sem sessao')
positions[1] = atCounter
local opened = call(1, 'open', { mode = 'agency', agencyId = 'legion' })
eq(opened.ok, true, 'abre a agencia')
eq(opened.view.mode, 'agency', 'modo agencia')
eq(opened.view.title, 'Agência Legion Square', 'titulo da agencia')
eq(opened.view.balance, 1000, 'saldo')
eq(opened.view.cash, 300, 'especie')
eq(opened.view.stateId, 'AAAA2222', 'id do titular')
eq(opened.view.holder, 'Ana Souza', 'titular')
eq(opened.view.max, BankConfig.MaxAgencyAmount, 'teto da agencia')
eq(call(1, 'open', { mode = 'agency', agencyId = 'nope' }).error, 'too_far', 'agencia desconhecida')
call(1, 'open', { mode = 'agency', agencyId = 'legion' })

-- Saque
local r = act(1, 'withdraw', { amount = 200 })
eq(r.ok, true, 'saque')
eq(balances['11'], 800, 'saldo apos saque')
eq(inventories.inv1, 500, 'especie apos saque')
eq(r.view.balance, 800, 'tela atualizada')
eq(r.view.statement[1].reason, 'bank_withdraw', 'extrato do saque')
eq(r.view.statement[1].reference, 'agency:legion', 'referencia da agencia')
eq(audits[#audits].event, 'bank_withdraw', 'auditoria do saque')
eq(act(1, 'withdraw', { amount = 5000 }).error, 'insufficient_funds', 'sem saldo')
eq(act(1, 'withdraw', { amount = 0 }).error, 'invalid_amount', 'valor invalido')
eq(act(1, 'withdraw', { amount = 'abc' }).error, 'invalid_amount', 'valor texto')

-- Saque com bolsos cheios: estorna na conta
fullInventory.inv1 = true
r = act(1, 'withdraw', { amount = 100 })
eq(r.error, 'inventory_full', 'bolsos cheios')
eq(balances['11'], 800, 'estornado')
eq(ledger[1].reason, 'bank_refund', 'estorno no extrato')
fullInventory.inv1 = nil

-- Depósito
r = act(1, 'deposit', { amount = 150 })
eq(r.ok, true, 'deposito')
eq(balances['11'], 950, 'saldo apos deposito')
eq(inventories.inv1, 350, 'especie apos deposito')
eq(act(1, 'deposit', { amount = 10000 }).error, 'insufficient_cash', 'sem especie')
creditFails = true
r = act(1, 'deposit', { amount = 50 })
eq(r.error, 'balance_limit', 'credito falhou')
eq(inventories.inv1, 350, 'especie devolvida')
creditFails = false

-- Trava de intervalo entre movimentações
now = now + 100000
source = 1
requestId = requestId + 1
netHandlers['coe_bank:request'](requestId, 'action', { action = 'deposit', data = { amount = 1 } })
requestId = requestId + 1
netHandlers['coe_bank:request'](requestId, 'action', { action = 'deposit', data = { amount = 1 } })
eq(responses[#responses].result.error, 'busy', 'operacao seguida')

-- Destinatário
eq(act(1, 'lookup', { stateId = 'aaaa2222' }).error, 'same_account', 'proprio id')
eq(act(1, 'lookup', { stateId = 'xx' }).error, 'invalid_state_id', 'id invalido')
eq(act(1, 'lookup', { stateId = 'ZZZZ9999' }).error, 'character_not_found', 'id desconhecido')
r = act(1, 'lookup', { stateId = 'bbbb3333' })
eq(r.ok, true, 'destinatario online')
eq(r.data.name, 'Bruno Lima', 'nome do destinatario online')
eq(r.data.stateId, 'BBBB3333', 'id normalizado')
r = act(1, 'lookup', { stateId = 'CCCC4444' })
eq(r.data.name, 'Caio Melo', 'destinatario offline pelo cadastro')

-- Transferência
local before = balances['11']
r = act(1, 'transfer', { stateId = 'BBBB3333', amount = 100 })
eq(r.ok, true, 'transferencia online')
eq(balances['11'], before - 100, 'debitou')
eq(balances['22'], 150, 'creditou')
eq(ledger[2].reference, 'state:BBBB3333', 'referencia da transferencia')
eq(notices[#notices].id, 2, 'destinatario avisado')
r = act(1, 'transfer', { stateId = 'CCCC4444', amount = 50 })
eq(r.ok, true, 'transferencia offline')
eq(balances['33'], 50, 'offline recebeu')
eq(act(1, 'transfer', { stateId = 'BBBB3333', amount = 999999 }).error, 'insufficient_funds', 'sem saldo para transferir')
eq(act(1, 'transfer', { stateId = 'AAAA2222', amount = 10 }).error, 'same_account', 'para si mesmo')

-- Afastou-se: sessão fecha
positions[1] = { x = legion.x + 20, y = legion.y, z = legion.z }
eq(act(1, 'refresh').error, 'too_far', 'afastou')
positions[1] = atCounter
eq(act(1, 'refresh').error, 'unavailable', 'sessao encerrada')

-- Caixa eletrônico
positions[2] = { x = 500, y = 500, z = 30 }
inVehicle[2] = true
eq(call(2, 'open', { mode = 'atm' }).error, 'too_far', 'caixa dentro do veiculo')
inVehicle[2] = nil
r = call(2, 'open', { mode = 'atm' })
eq(r.ok, true, 'abre o caixa')
eq(r.view.max, BankConfig.MaxAtmAmount, 'teto do caixa')
eq(#r.view.quick, #BankConfig.AtmQuickAmounts, 'atalhos do caixa')
eq(act(2, 'transfer', { stateId = 'AAAA2222', amount = 10 }).error, 'unavailable', 'caixa nao transfere')
eq(act(2, 'withdraw', { amount = BankConfig.MaxAtmAmount + 1 }).error, 'invalid_amount', 'acima do teto do caixa')
r = act(2, 'withdraw', { amount = 100 })
eq(r.ok, true, 'saque no caixa')
eq(r.view.statement[1].reference, 'atm', 'referencia do caixa')
eq(inventories.inv2, 100, 'especie do caixa')

-- Sem personagem
eq(call(9, 'open', { mode = 'atm' }).error, 'no_character', 'sem personagem')
-- Pedido malformado é ignorado
local count = #responses
netHandlers['coe_bank:request']('x', 'open', {})
netHandlers['coe_bank:request'](1, 'hack', {})
eq(#responses, count, 'pedidos invalidos ignorados')

-- Pacote assume o banco
invoking = 'random_script'
eq(exported.Yield().error, 'forbidden', 'sem ACE nao assume')
invoking = 'pack_bank'
eq(exported.Yield(), true, 'pacote assume')
eq(GlobalState.coeBankYielded, 'pack_bank', 'estado global')
eq(clientEvents[#clientEvents].name, 'coe_bank:close', 'fecha telas abertas')
eq(exported.Status().active, false, 'status inativo')
eq(exported.Status().yieldedBy, 'pack_bank', 'quem assumiu')
positions[4] = atCounter
eq(call(4, 'open', { mode = 'agency', agencyId = 'legion' }).error, 'unavailable', 'agencia fechada para o basico')
eq(act(2, 'refresh').error, 'unavailable', 'sessao do caixa encerrada')
handlers.onResourceStop('other_resource')
eq(exported.Status().active, false, 'outro resource parando nao muda nada')
handlers.onResourceStop('pack_bank')
eq(GlobalState.coeBankYielded, false, 'pacote parou: banco volta')
eq(call(4, 'open', { mode = 'agency', agencyId = 'legion' }).ok, true, 'agencia volta a atender')

print('coe_bank server: ok')
