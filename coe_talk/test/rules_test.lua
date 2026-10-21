dofile('config.lua')
dofile('shared/rules.lua')

local function eq(a, b, msg)
	if a ~= b then
		error(('%s: esperado %s, obtido %s'):format(msg, tostring(b), tostring(a)))
	end
end

-- Sanitizacao de frequencia
eq(Rules.SanitizeFrequency('101.5'), 101.5, 'converte string para 101.5')
eq(Rules.SanitizeFrequency(50.24), 50.2, 'arredonda para 1 casa decimal')
eq(Rules.SanitizeFrequency(0.5), nil, 'abaixo do minimo e invalido')
eq(Rules.SanitizeFrequency(1000.0), nil, 'acima do maximo e invalido')
eq(Rules.SanitizeFrequency('invalido'), nil, 'texto invalido')
eq(Rules.SanitizeFrequency(nil), nil, 'nil e invalido')

-- Acesso a frequencias restritas
eq(Rules.CanAccessFrequency(101.5, 'civil'), true, 'frequencia comum e publica')
eq(Rules.CanAccessFrequency(1.0, 'police'), true, 'policia pode acessar canal 1')
eq(Rules.CanAccessFrequency(1.0, 'civil'), false, 'civil nao pode acessar canal 1')
eq(Rules.CanAccessFrequency(1.0, nil), false, 'sem emprego nao pode acessar canal 1')
eq(Rules.CanAccessFrequency(4.5, 'ems'), true, 'ems pode acessar canal 4.5')
eq(Rules.CanAccessFrequency(4.5, 'police'), false, 'police nao pode acessar canal 4.5')

-- Modos de voz
eq(Rules.GetModeByIndex(1).id, 'whisper', 'modo 1 e sussurro')
eq(Rules.GetModeByIndex(2).id, 'normal', 'modo 2 e normal')
eq(Rules.GetModeByIndex(3).id, 'shout', 'modo 3 e grito')
eq(Rules.NextModeIndex(1), 2, '1 avanca para 2')
eq(Rules.NextModeIndex(2), 3, '2 avanca para 3')
eq(Rules.NextModeIndex(3), 1, '3 volta para 1')

-- Subir e baixar voz (PageUp / PageDown)
local idx, ch = Rules.IncreaseModeIndex(1)
eq(idx, 2, 'sobe de 1 para 2')
eq(ch, true, 'houve mudanca')
idx, ch = Rules.IncreaseModeIndex(2)
eq(idx, 3, 'sobe de 2 para 3')
eq(ch, true, 'houve mudanca')
idx, ch = Rules.IncreaseModeIndex(3)
eq(idx, 3, 'mantem em 3 no maximo')
eq(ch, false, 'nao houve mudanca no topo')

idx, ch = Rules.DecreaseModeIndex(3)
eq(idx, 2, 'desce de 3 para 2')
eq(ch, true, 'houve mudanca')
idx, ch = Rules.DecreaseModeIndex(2)
eq(idx, 1, 'desce de 2 para 1')
eq(ch, true, 'houve mudanca')
idx, ch = Rules.DecreaseModeIndex(1)
eq(idx, 1, 'mantem em 1 no minimo')
eq(ch, false, 'nao houve mudanca na base')

-- Volume
eq(Rules.SanitizeVolume(50), 50, 'volume 50')
eq(Rules.SanitizeVolume(-10), 0, 'volume negativo limitado a 0')
eq(Rules.SanitizeVolume(150), 100, 'volume alto limitado a 100')
eq(Rules.SanitizeVolume('abc', 75), 75, 'fallback de volume')

print('coe_talk rules tests passed')
