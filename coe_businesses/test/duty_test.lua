dofile('../coe_businesses/config.lua')
dofile('../coe_businesses/shared/area.lua')
dofile('../coe_businesses/server/duty.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local businesses = {
	loja = { id = 'loja', enabled = true, area = { kind = 'circle', x = 0.0, y = 0.0, z = 30.0, radius = 20.0 }, rules = { clockOffsite = false } },
	posto = { id = 'posto', enabled = true, area = { kind = 'circle', x = 100.0, y = 0.0, z = 30.0, radius = 20.0 }, rules = { clockOffsite = true } }
}
local events = {}
local duty = BusinessDuty.New({
	get = function(id) return businesses[id] end,
	changed = function(source, id, on, reason) events[#events + 1] = ('%s:%s:%s:%s'):format(source, id, tostring(on), reason) end
})

local inside, outside = { x = 1.0, y = 1.0, z = 30.0 }, { x = 500.0, y = 0.0, z = 30.0 }

eq(select(2, duty.ClockIn(1, '7', 'fantasma', inside, false)), 'unknown_business', 'negócio inexistente')
eq(select(2, duty.ClockIn(1, '7', 'loja', outside, false)), 'outside_area', 'fora da área, sem ponto')
eq(duty.ClockIn(1, '7', 'loja', outside, true), true, 'no ponto de bater cartão vale mesmo fora da área')
eq(duty.Current(1), 'loja', 'estado atual')
eq(duty.IsOnDuty('loja', 7), true, 'id numérico compara como texto')
eq(duty.IsOnDuty('posto', '7'), false, 'outro negócio')
eq(select(2, duty.ClockIn(1, '7', 'loja', inside, false)), 'already_on_duty', 'duplicado')
eq(select(2, duty.ClockIn(1, '7', 'posto', inside, true)), 'on_duty_elsewhere', 'um negócio por vez')

-- sem permissão fora da área: o sweep derruba
eq(duty.Sweep(function() return inside end), 0, 'dentro da área mantém')
eq(duty.Sweep(function() return outside end), 1, 'saiu da área: derruba')
eq(duty.Current(1), nil, 'ponto encerrado')
eq(events[#events], '1:loja:false:left_area', 'motivo do encerramento')

-- permitido fora da área: o sweep não derruba
eq(duty.ClockIn(2, '8', 'posto', { x = 100.0, y = 0.0, z = 30.0 }, false), true, 'bate ponto dentro da área')
eq(duty.Sweep(function() return outside end), 0, 'fora da área permitido')
eq(duty.IsOnDuty('posto', '8'), true, 'segue de ponto')

-- negócio desativado derruba mesmo com ponto fora permitido
businesses.posto.enabled = false
eq(duty.Sweep(function() return inside end), 1, 'negócio fechado derruba')
eq(events[#events], '2:posto:false:business_closed', 'motivo fechado')

-- sair
businesses.posto.enabled = true
duty.ClockIn(3, '9', 'posto', nil, true)
eq(duty.ClockOut(3), true, 'bater ponto de saída')
eq(select(2, duty.ClockOut(3)), 'not_on_duty', 'sair sem estar de ponto')
duty.ClockIn(4, '10', 'posto', nil, true)
duty.Drop(4)
eq(duty.IsOnDuty('posto', '10'), false, 'saiu do servidor')

print('duty_test ok')
