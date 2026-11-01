dofile('../coe_mechanic/config.lua')
dofile('../coe_mechanic/shared/appearance.lua')
dofile('../coe_mechanic/server/appearance_service.lua')

local config = CoeMechanicConfig

local function check(name, condition)
	if not condition then
		error('FAIL: ' .. name, 2)
	end
	print('ok  ' .. name)
end

local function sanitize(input)
	return MechanicAppearance.Sanitize(config, input)
end

check('nao-tabela', select(2, sanitize('x')) == 'invalid_appearance')
check('cor valida', sanitize({ colors = { primary = 12, secondary = 0 } }).colors.primary == 12)
check('cor fora do limite', select(2, sanitize({ colors = { primary = 999 } })) == 'invalid_color')
check('cor fracionaria', select(2, sanitize({ colors = { primary = 1.5 } })) == 'invalid_color')
check('rgb valido', sanitize({ colors = { primaryRgb = { 10, 20, 30 } } }).colors.primaryRgb[2] == 20)
check('rgb invalido', select(2, sanitize({ colors = { primaryRgb = { 300, 0, 0 } } })) == 'invalid_color')
check('mod valido', sanitize({ mods = { ['11'] = 3 } }).mods['11'] == 3)
check('mod chave numerica vira string', sanitize({ mods = { [11] = 3 } }).mods['11'] == 3)
check('mod remover', sanitize({ mods = { ['11'] = -1 } }).mods['11'] == -1)
check('mod toggle bloqueado', select(2, sanitize({ mods = { ['18'] = 0 } })) == 'invalid_mod')
check('mod livery bloqueado', select(2, sanitize({ mods = { ['48'] = 1 } })) == 'invalid_mod')
check('mod tipo invalido', select(2, sanitize({ mods = { ['99'] = 1 } })) == 'invalid_mod')
check('mod indice invalido', select(2, sanitize({ mods = { ['11'] = 1000 } })) == 'invalid_mod')
check('toggle valido', sanitize({ toggles = { turbo = true } }).toggles.turbo == true)
check('toggle nao-booleano', select(2, sanitize({ toggles = { turbo = 1 } })) == 'invalid_toggle')
check('campo desconhecido descartado', sanitize({ hack = 1, livery = 2 }).hack == nil)
check('livery valida', sanitize({ livery = 2 }).livery == 2)
check('livery invalida', select(2, sanitize({ livery = 500 })) == 'invalid_livery')
check('tint invalido', select(2, sanitize({ tint = 9 })) == 'invalid_tint')
check('neon', sanitize({ neon = { sides = { true, true }, rgb = { 255, 0, 0 } } }).neon.sides[3] == false)
check('neon invalido', select(2, sanitize({ neon = { rgb = { 1, 2 } } })) == 'invalid_neon')
check('extra valido', sanitize({ extras = { [3] = true } }).extras['3'] == true)
check('extra invalido', select(2, sanitize({ extras = { [30] = true } })) == 'invalid_extra')

local merged = MechanicAppearance.Merge(
	{ colors = { primary = 1, secondary = 2 }, mods = { ['11'] = 2 }, livery = 1 },
	{ colors = { primary = 5 }, mods = { ['12'] = 1 } }
)
check('merge escalar interno', merged.colors.primary == 5 and merged.colors.secondary == 2)
check('merge mods', merged.mods['11'] == 2 and merged.mods['12'] == 1)
check('merge preserva livery', merged.livery == 1)

local quote = MechanicAppearance.Quote(config, {}, { colors = { primary = 5 } }, 100000, 'sedans')
check('pintura proporcional ao valor', quote.total == math.floor(100000 * config.Pricing.ColorFraction))
local super = MechanicAppearance.Quote(config, {}, { colors = { primary = 5 } }, 100000, 'super')
check('classe super custa mais', super.total > quote.total)
local cheap = MechanicAppearance.Quote(config, {}, { colors = { primary = 5 } }, 10, 'sedans')
check('preco minimo', cheap.total == config.Pricing.MinPrice)
check('sem mudanca e gratis', MechanicAppearance.Quote(config, { colors = { primary = 5 } }, { colors = { primary = 5 } }, 1000).total == 0)
check('remover mod e gratis', MechanicAppearance.Quote(config, { mods = { ['11'] = 2 } }, { mods = { ['11'] = -1 } }, 100000).total == 0)
local lvl1 = MechanicAppearance.Quote(config, {}, { mods = { ['11'] = 0 } }, 100000).total
local lvl3 = MechanicAppearance.Quote(config, {}, { mods = { ['11'] = 3 } }, 100000).total
check('nivel maior custa mais', lvl3 > lvl1)
check('livery cobrada', MechanicAppearance.Quote(config, {}, { livery = 2 }, 100000).total > 0)
check('rgb mais caro que cor', MechanicAppearance.Quote(config, {}, { colors = { primaryRgb = { 1, 2, 3 } } }, 100000).total > quote.total)
check('preco padrao sem valor', MechanicAppearance.Quote(config, {}, { colors = { primary = 5 } }, nil).total > 0)

local rows, saves, audits = {}, {}, {}
local service = MechanicAppearanceService.New({
	config = config,
	persistence = {
		FindAppearance = function(id) return rows[id], nil end,
		SaveAppearance = function(id, data)
			saves[#saves + 1] = { id, data }
			rows[id] = data
			return true
		end
	},
	audit = function(event, ctx) audits[#audits + 1] = { event, ctx } end
})

check('Apply invalido nao grava', select(2, service.Apply(1, { colors = { primary = -1 } }, 't')) == 'invalid_color' and #saves == 0)
local result = service.Apply(1, { colors = { primary = 3 }, livery = 1 }, 'oficina')
check('Apply grava', result.colors.primary == 3 and #saves == 1)
check('Apply audita', audits[1][1] == 'vehicle_appearance_set')
service.Apply(1, { colors = { secondary = 4 } }, 'oficina')
check('Apply mescla com o salvo', service.Get(1).colors.primary == 3 and service.Get(1).colors.secondary == 4)
check('Quote nao grava', service.Quote(1, { colors = { primary = 9 } }, 50000, 'sedans').total > 0 and #saves == 2)
service.Forget(1)
check('recarrega do banco', service.Get(1).livery == 1)

local failing = MechanicAppearanceService.New({ config = config, persistence = { FindAppearance = function() return nil, 'database_error' end } })
check('erro do banco propaga', select(2, failing.Apply(9, { livery = 1 }, 't')) == 'database_error')

print('appearance_test: todos os testes passaram')
