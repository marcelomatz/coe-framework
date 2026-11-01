dofile('config.lua')
dofile('shared/rules.lua')

local config = CoePhoneConfig
local failures = 0

local function eq(actual, expected, label)
	if actual ~= expected then
		failures = failures + 1
		print(('FAIL %s: esperado %s, veio %s'):format(label, tostring(expected), tostring(actual)))
	end
end

-- Números
eq(PhoneRules.Normalize(config, '555-0123'), '5550123', 'normaliza com traço')
eq(PhoneRules.Normalize(config, ' (555) 01.23 '), '5550123', 'normaliza com pontuação')
eq(PhoneRules.Normalize(config, 5550123), '5550123', 'aceita número')
eq(PhoneRules.Normalize(config, '556-0123'), nil, 'prefixo errado')
eq(PhoneRules.Normalize(config, '555-012'), nil, 'curto')
eq(PhoneRules.Normalize(config, '555-01234'), nil, 'longo')
eq(PhoneRules.Normalize(config, '555-01a3'), nil, 'letras')
eq(PhoneRules.Normalize(config, {}), nil, 'tipo inválido')
eq(PhoneRules.Format(config, '5550123'), '555-0123', 'formata')

local sequence, index = { 0, 4, 2, 9 }, 0
local generated = PhoneRules.Generate(config, function(min, max)
	index = index + 1
	eq(min, 0, 'random min')
	eq(max, 9, 'random max')
	return sequence[index]
end)
eq(generated, '5550429', 'gera número')
eq(PhoneRules.Normalize(config, generated), generated, 'gerado é válido')

-- Textos
eq(PhoneRules.ContactName(config, '  Ana   Maria '), 'Ana Maria', 'nome limpo')
eq(PhoneRules.ContactName(config, 'Ana\nMaria'), 'Ana Maria', 'nome sem quebra')
eq(PhoneRules.ContactName(config, '   '), nil, 'nome vazio')
eq(PhoneRules.ContactName(config, string.rep('a', 40)), string.rep('a', 32), 'nome cortado')
eq(PhoneRules.ContactName(config, 'José'), 'José', 'nome com acento')
eq(PhoneRules.Message(config, 'oi\n\n\n\ntudo bem?'), 'oi\n\ntudo bem?', 'mensagem compacta linhas')
eq(PhoneRules.Message(config, 'a\0b'), 'ab', 'mensagem sem controle')
eq(PhoneRules.Message(config, 42), nil, 'mensagem tipo inválido')
eq(utf8.len(PhoneRules.Message(config, string.rep('é', 600))), config.Messages.BodyMax, 'mensagem cortada em utf8')

-- Ligações
eq(PhoneRules.CallStatus('hangup', true), 'answered', 'atendida')
eq(PhoneRules.CallStatus('declined', false), 'declined', 'recusada')
eq(PhoneRules.CallStatus('missed', false), 'missed', 'perdida')
eq(PhoneRules.CallStatus('hangup', false), 'missed', 'cancelada vira perdida')
eq(PhoneRules.CallStatus('busy', false), 'busy', 'ocupado')

-- Apps
local apps = PhoneRules.Apps(config, function(id)
	return id == 'store' or id == 'insta'
end)
local ids = {}
for i, app in ipairs(apps) do
	ids[i] = app.id
end
eq(table.concat(ids, ','), 'phone,messages,contacts,store,settings,camera,gallery,insta,wallet', 'apps visíveis em ordem')
eq(apps[1].native, true, 'telefone é nativo')
eq(apps[4].dock, true, 'loja no dock')
eq(apps[8].script, 'nui://coe_apps/html/apps.js', 'script da loja')
eq(#PhoneRules.Apps(config, function() return false end), 7, 'só nativos sem coe_apps')
eq(PhoneRules.IsValidScript('nui://coe_apps/html/apps.js'), true, 'script válido')
eq(PhoneRules.IsValidScript('https://x.com/a.js'), false, 'script externo')

-- Ajustes
local defaults = PhoneRules.Settings(config, nil)
eq(defaults.volume, 5, 'volume padrão')
eq(defaults.wifi, true, 'wifi padrão')
local loaded = PhoneRules.Settings(config, { volume = 9, silent = true, ringtone = 'xx', brightness = 10, junk = 1 })
eq(loaded.volume, 9, 'volume salvo')
eq(loaded.silent, true, 'silencioso salvo')
eq(loaded.ringtone, 'classico', 'toque inválido volta ao padrão')
eq(loaded.brightness, 100, 'brilho fora do limite volta ao padrão')
eq(loaded.junk, nil, 'chave desconhecida ignorada')
local patched = PhoneRules.Patch(config, defaults, { airplane = true })
eq(patched.airplane, true, 'modo avião')
eq(patched.wifi, false, 'avião desliga wifi')
eq(patched.bluetooth, false, 'avião desliga bluetooth')
eq(PhoneRules.Patch(config, patched, { wifi = true }).wifi, true, 'religa wifi no avião')
eq(PhoneRules.Patch(config, defaults, { airplane = true, wifi = true }).wifi, true, 'avião com wifi explícito')
eq(PhoneRules.Patch(config, defaults, { volume = 11 }), nil, 'volume acima do limite')
eq(PhoneRules.Patch(config, defaults, { volume = 2.5 }), nil, 'volume fracionado')
eq(PhoneRules.Patch(config, defaults, { hacked = true }), nil, 'chave desconhecida')
eq(PhoneRules.Patch(config, defaults, { silent = 'sim' }), nil, 'booleano inválido')
eq(PhoneRules.Patch(config, defaults, { wallpaper = 'oceano' }).wallpaper, 'oceano', 'papel de parede')
eq(defaults.wallpaper, 'padrao', 'patch não altera o original')
eq(PhoneRules.Passcode(config, '1234'), '1234', 'senha 4 dígitos')
eq(PhoneRules.Passcode(config, '123456'), '123456', 'senha 6 dígitos')
eq(PhoneRules.Passcode(config, '123'), nil, 'senha curta')
eq(PhoneRules.Passcode(config, '1234567'), nil, 'senha longa')
eq(PhoneRules.Passcode(config, '12a4'), nil, 'senha com letra')
eq(PhoneRules.Passcode(config, 1234), nil, 'senha não texto')

-- Telas iniciais
local function joined(list)
	return table.concat(list, ',')
end
local fresh = PhoneRules.Layout(config, nil, apps)
eq(joined(fresh.dock), 'phone,messages,contacts,store', 'dock padrão')
eq(#fresh.pages, 1, 'uma tela padrão')
eq(joined(fresh.pages[1]), 'settings,camera,gallery,insta,wallet', 'resto na primeira tela')
local custom = PhoneRules.Layout(config, { dock = { 'insta', 'insta', 'ghost' }, pages = { { 'store' }, {}, { 'phone', 'settings' } } }, apps)
eq(joined(custom.dock), 'insta', 'dock salvo sem repetidos nem desconhecidos')
eq(#custom.pages, 3, 'telas salvas mantidas, inclusive vazias')
eq(joined(custom.pages[1]), 'store,messages,contacts,camera,gallery,wallet', 'apps sem lugar vão para a primeira tela com espaço')
eq(joined(custom.pages[3]), 'phone,settings', 'terceira tela')
local many = {}
for i = 1, 40 do
	many[i] = { id = 'app' .. i }
end
local full = PhoneRules.Layout(config, nil, many)
eq(#full.pages, 3, 'apps distribuídos em telas')
eq(#full.pages[1], config.Home.PageSize, 'tela cheia')
local pagesTooMany = {}
for i = 1, 10 do
	pagesTooMany[i] = {}
end
eq(#PhoneRules.Layout(config, { pages = pagesTooMany }, apps).pages, config.Home.MaxPages, 'limite de telas')

-- Sinal
eq(PhoneRules.Signal(config, 150.0, -800.0), 4, 'sinal no centro')
eq(PhoneRules.Signal(config, 150.0, -1800.0), 3, 'sinal a 1 km')
eq(PhoneRules.Signal(config, 6000.0, -6000.0), 0, 'sem sinal no mar')
eq(PhoneRules.Signal(config, nil, 1), 0, 'coordenada inválida')

-- Aparelhos e chips
local serial = PhoneRules.Serial(function(min, max)
	return max
end)
eq(serial, 'SN9999999999', 'serial: SN + 10 caracteres')
eq(PhoneRules.IsSerial(serial), true, 'serial válido')
eq(PhoneRules.IsSerial('MG00000000000042'), true, 'serial migrado válido')
eq(PhoneRules.IsSerial('sn123'), false, 'serial minúsculo')
eq(PhoneRules.IsSerial(('A'):rep(17)), false, 'serial longo')
eq(PhoneRules.IsSerial(nil), false, 'serial nil')
local iccid = PhoneRules.Iccid(function()
	return 7
end)
eq(iccid, '8956' .. ('7'):rep(16), 'iccid: 8956 + 16 dígitos')
eq(#iccid, 20, 'iccid com 20 dígitos')
eq(PhoneRules.IsIccid(iccid), true, 'iccid válido')
eq(PhoneRules.IsIccid('8956abc'), false, 'iccid com letras')

eq(PhoneRules.FreeSimSlot(1, {}), 1, 'slot livre em aparelho vazio')
eq(PhoneRules.FreeSimSlot(1, { { slot = 1 } }), nil, 'aparelho de 1 chip cheio')
eq(PhoneRules.FreeSimSlot(2, { { slot = 2 } }), 1, 'primeiro slot livre')
eq(PhoneRules.FreeSimSlot(2, { { slot = 1 }, { slot = 2 } }), nil, 'aparelho de 2 chips cheio')

local phones = {
	{ slot = 7, name = 'phone', metadata = { serial = 'SNB' } },
	{ slot = 3, name = 'phone', metadata = { serial = 'SNA' } },
	{ slot = 9, name = 'phone' }
}
eq(PhoneRules.PickDevice(phones, nil, nil).slot, 3, 'sem ativo: menor slot')
eq(PhoneRules.PickDevice(phones, 'SNB', nil).slot, 7, 'aparelho ativo')
eq(PhoneRules.PickDevice(phones, 'SNX', nil).slot, 3, 'ativo sumiu: menor slot')
eq(PhoneRules.PickDevice(phones, 'SNB', 9).slot, 9, 'item usado tem prioridade')
eq(PhoneRules.PickDevice(phones, nil, 4), nil, 'slot usado sem celular')
eq(PhoneRules.PickDevice({}, nil, nil), nil, 'sem celular')

-- Fotos
local jpeg = 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQ=='
eq(PhoneRules.Photo(jpeg, 1000), jpeg, 'foto válida')
eq(PhoneRules.Photo(jpeg, 10), nil, 'foto grande demais')
eq(PhoneRules.Photo('data:image/png;base64,/9j/4AAQSkZJRgABAQ==', 1000), nil, 'só JPEG')
eq(PhoneRules.Photo('data:image/jpeg;base64,/9j/4AAQ<script>', 1000), nil, 'só base64')
eq(PhoneRules.Photo('data:image/jpeg;base64,/9j/4AAQSkZJRgABA', 1000), nil, 'base64 sem múltiplo de 4')
eq(PhoneRules.Photo('data:image/jpeg;base64,/9j/4A=QSkZJRgABAQ==', 1000), nil, 'padding no meio')
eq(PhoneRules.Photo('data:image/jpeg;base64,', 1000), nil, 'foto vazia')
eq(PhoneRules.Photo(nil, 1000), nil, 'foto nil')
eq(PhoneRules.StorageFits(1, 0, 1048576), true, 'cabe exatamente 1 MB')
eq(PhoneRules.StorageFits(1, 1, 1048576), false, 'passa de 1 MB')
eq(PhoneRules.StorageFits(nil, 0, 1), false, 'modelo sem armazenamento')
eq(config.Models.coe_one.storage > 0, true, 'COE One tem armazenamento')

if failures > 0 then
	error(failures .. ' falha(s)')
end
print('phone_test: ok')
