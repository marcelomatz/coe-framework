dofile('../coe_businesses/server/extensions.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local ext = BusinessExtensions.New()
local calls = {}
local stations = { posto_1 = true }
local function call(resource, name, ...)
	calls[#calls + 1] = resource .. ':' .. name
	if name == 'IsStation' then
		return stations[(...)] == true
	end
	return nil
end

-- Registro válido: o caminho nui:// usa o resource que registrou, vindo do runtime
eq(ext:RegisterTab('pack_fuel', { id = 'fuel', label = 'Posto', script = 'html/business.js', css = 'html/business.css', handler = 'BusinessTablet', visible = 'IsStation', order = 10 }), true, 'aba registrada')
eq(ext:RegisterTab('pack_bank', { id = 'bank', label = 'Banco', script = 'html/business.js', handler = 'BusinessTablet', replaces = 'finance', order = 30 }), true, 'aba sem visible')

-- Validações
local _, err = ext:RegisterTab('pack_x', { id = 'staff', label = 'X', script = 'a.js', handler = 'H' })
eq(err, 'invalid_tab', 'id de aba própria')
_, err = ext:RegisterTab('pack_x', { id = 'fuel', label = 'X', script = 'a.js', handler = 'H' })
eq(err, 'tab_taken', 'id de outro resource')
_, err = ext:RegisterTab('pack_x', { id = 'x', label = 'X', script = '../coe_core/a.js', handler = 'H' })
eq(err, 'invalid_tab', 'caminho fora do resource')
_, err = ext:RegisterTab('pack_x', { id = 'x', label = 'X', script = 'a.js', handler = 'bad name' })
eq(err, 'invalid_tab', 'export inválido')
_, err = ext:RegisterTab('pack_x', { id = 'x', label = '<b>', script = 'a.js', handler = 'H' })
eq(err, 'invalid_tab', 'rótulo com HTML')
_, err = ext:RegisterTab('pack_x', { id = 'x', label = 'X', script = 'a.js', handler = 'H', replaces = 'overview' })
eq(err, 'invalid_tab', 'não substitui o resumo')
eq(ext:RegisterTab('pack_fuel', { id = 'fuel', label = 'Postos', script = 'html/business.js', handler = 'BusinessTablet', visible = 'IsStation', order = 10 }), true, 'o dono atualiza a aba')

-- Visibilidade por negócio e ordem
local tabs = ext:VisibleTabs('posto_1', call)
eq(#tabs, 2, 'posto vê as duas abas')
eq(tabs[1].id, 'fuel', 'ordem')
eq(tabs[1].script, 'nui://pack_fuel/html/business.js', 'script no resource que registrou')
eq(tabs[1].css, nil, 'css removido na atualização')
eq(tabs[2].replaces, 'finance', 'substitui o Financeiro')
eq(#ext:VisibleTabs('loja_1', call), 1, 'loja não vê a aba do posto')
eq(ext:Tab('fuel', 'loja_1', call), nil, 'aba invisível não atende')
eq(ext:Tab('fuel', 'posto_1', call).resource, 'pack_fuel', 'aba visível atende')

-- Provedores
eq(ext:RegisterProvider('pack_garages', 'fleet', { list = 'BusinessFleet', setStaff = 'SetFleetStaffAccess' }), true, 'provedor de frota')
_, err = ext:RegisterProvider('pack_housing', 'properties', {})
eq(err, 'invalid_provider', 'list obrigatório')
_, err = ext:RegisterProvider('pack_housing', 'weather', { list = 'X' })
eq(err, 'invalid_provider', 'tipo desconhecido')
eq(ext:RegisterProvider('pack_housing', 'properties', { list = 'BusinessProperties' }), true, 'provedor de imóveis')
eq(ext:Provider('fleet').setStaff, 'SetFleetStaffAccess', 'export do provedor')

-- Resource parado: some o que ele registrou
ext:Drop('pack_fuel')
ext:Drop('pack_garages')
eq(ext:Tab('fuel', 'posto_1', call), nil, 'aba do resource parado')
eq(ext:Provider('fleet'), nil, 'provedor do resource parado')
eq(ext:Provider('properties').resource, 'pack_housing', 'os demais continuam')
eq(#ext:VisibleTabs('posto_1', call), 1, 'só o banco')

print('extensions tests passed')
