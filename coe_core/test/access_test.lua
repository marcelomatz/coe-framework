-- CoeAccess: padrões do framework e ACE no principal do resource.
local asked = {}
local granted = { ['resource.meu_script|coe.economy.money'] = true }
local clock = 0
function IsPrincipalAceAllowed(principal, ace)
	asked[#asked + 1] = principal .. '|' .. ace
	return granted[principal .. '|' .. ace] == true
end
function GetGameTimer()
	return clock
end
local invoking = nil
function GetInvokingResource()
	return invoking
end

dofile('lib/access.lua')

local defaults = { coe_shops = true }
assert(CoeAccess.Allowed('coe_shops', 'coe.economy.money', defaults) == true, 'default allowed')
assert(#asked == 0, 'defaults skip ACE lookup')
assert(CoeAccess.Allowed('meu_script', 'coe.economy.money', defaults) == true, 'ACE allowed')
assert(CoeAccess.Allowed('stranger', 'coe.economy.money', defaults) == false, 'no ACE refused')
assert(CoeAccess.Allowed(nil, 'coe.economy.money', defaults) == false, 'nil refused')
assert(CoeAccess.Allowed('', 'coe.economy.money') == false, 'empty refused')
assert(CoeAccess.Allowed('meu_script', nil) == false, 'no ace refused')

-- Cache curto: a mesma pergunta dentro de 5 s não consulta de novo.
local before = #asked
CoeAccess.Allowed('meu_script', 'coe.economy.money')
assert(#asked == before, 'cached')
granted['resource.meu_script|coe.economy.money'] = nil
clock = 6000
assert(CoeAccess.Allowed('meu_script', 'coe.economy.money') == false, 'cache expires')
CoeAccess.Reset()

invoking = 'coe_shops'
assert(CoeAccess.Caller('coe.economy.money', defaults) == 'coe_shops', 'caller default')
invoking = 'stranger'
assert(CoeAccess.Caller('coe.economy.money', defaults) == nil, 'caller refused')

-- Scripts avançados do framework: concessões fixas (sem ACE), só nas capacidades listadas.
before = #asked
assert(CoeAccess.Allowed('coe_phone', 'coe.database') == true, 'first-party granted')
assert(CoeAccess.Allowed('coe_admin', 'coe.supervisor') == true, 'admin uses supervisor')
assert(#asked == before, 'first-party skips ACE lookup')
assert(CoeAccess.Allowed('coe_phone', 'coe.economy.admin') == false, 'first-party only for listed capabilities')

print('access tests passed')
