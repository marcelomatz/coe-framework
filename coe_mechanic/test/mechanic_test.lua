dofile('../coe_mechanic/config.lua')
dofile('../coe_mechanic/shared/parts.lua')
dofile('../coe_mechanic/server/service.lua')

local config = CoeMechanicConfig

local function check(name, condition)
	if not condition then
		error('FAIL: ' .. name, 2)
	end
	print('ok  ' .. name)
end

check('wear novo', MechanicParts.Wear(0, 0, 20000) == 0)
check('wear meio', MechanicParts.Wear(10000, 0, 20000) == 0.5)
check('wear satura', MechanicParts.Wear(1e9, 0, 20000) == 1)
check('wear invalido', MechanicParts.Wear(nil, 0, 20000) == 0)
check('condicao ok', MechanicParts.Condition(config, 0.2) == 'ok')
check('condicao warn', MechanicParts.Condition(config, 0.7) == 'warn')
check('condicao critical', MechanicParts.Condition(config, 0.9) == 'critical')

local mods, key = MechanicParts.Evaluate(config, {}, 0)
check('novo sem efeito', next(mods) == nil)
local wornMods, wornKey = MechanicParts.Evaluate(config, {}, 200000)
check('tudo gasto reduz freio', wornMods.fBrakeForce < 1)
check('tudo gasto reduz forca', wornMods.fInitialDriveForce < 1)
check('tudo gasto aumenta dano ao motor', wornMods.fEngineDamageMult > 1)
check('chave muda com desgaste', key ~= wornKey)
local _, k1 = MechanicParts.Evaluate(config, {}, 100)
local _, k2 = MechanicParts.Evaluate(config, {}, 120)
check('chave estavel em passo de 2%', k1 == k2)
local freshMods = MechanicParts.Evaluate(config, { brake_pads = 200000, brake_discs = 200000 }, 200000)
check('pastilhas novas restauram freio', (freshMods.fBrakeForce or 1) == 1)

local rows, saves, audits = {}, {}, {}
local service = MechanicService.New({
	config = config,
	persistence = {
		ListParts = function(id) return rows[id] or {} end,
		SavePart = function(id, part, at)
			saves[#saves + 1] = { id, part, at }
			rows[id] = rows[id] or {}
			rows[id][part] = at
			return true
		end
	},
	audit = function(event, ctx) audits[#audits + 1] = { event, ctx } end
})

local before = service.Inspect(1, 90000)
check('inspecao lista todas as pecas', #before.parts == 7)
check('desgastado critico', before.parts[1].condition ~= nil)
check('peca desconhecida', select(2, service.ReplacePart(1, 'xyz', 0, 't')) == 'unknown_part')
check('mileage invalido', select(2, service.ReplacePart(1, 'brake_pads', -1, 't')) == 'invalid_mileage')
check('troca ok', service.ReplacePart(1, 'brake_pads', 90000, 'oficina') == true)
check('troca persiste', saves[1][2] == 'brake_pads' and saves[1][3] == 90000)
check('troca audita', audits[1][1] == 'vehicle_part_replaced')
local after = service.Inspect(1, 90000)
check('freio melhora apos troca', (after.mods.fBrakeForce or 1) > (before.mods.fBrakeForce or 1))

local replaced = service.ServiceAll(1, 90000, 'oficina')
check('revisao troca as pecas fora do ok', #replaced > 0)
local final = service.Inspect(1, 90000)
for _, detail in ipairs(final.parts) do
	check('apos revisao ' .. detail.part .. ' ok', detail.condition == 'ok')
end

service.Forget(1)
check('recarrega apos Forget', service.Inspect(1, 90000).parts[1].wear == 0)

local failing = MechanicService.New({ config = config, persistence = { ListParts = function() return nil, 'database_error' end } })
check('erro do banco propaga', select(2, failing.Inspect(9, 0)) == 'database_error')

-- Desgaste extra (combustivel): envelhece as pecas e zera na troca
local extra = {}
local wearService = MechanicService.New({
	config = config,
	persistence = {
		ListParts = function(id)
			local out = {}
			for part, meters in pairs(extra[id] or {}) do out[part] = 0 - meters end
			return out
		end,
		AddWear = function(id, part, meters)
			extra[id] = extra[id] or {}
			extra[id][part] = math.max(0, (extra[id][part] or 0) + meters)
			return true
		end
	}
})
local clean = wearService.Inspect(5, 1000)
check('desgaste extra ok', wearService.AddWear(5, 5000, { 'spark_plugs', 'air_filter' }) == true)
local aged = wearService.Inspect(5, 1000)
local function wearOf(inspection, part) for _, d in ipairs(inspection.parts) do if d.part == part then return d.wear end end end
check('vela envelhece com o extra', wearOf(aged, 'spark_plugs') > wearOf(clean, 'spark_plugs'))
check('freio nao muda', wearOf(aged, 'brake_pads') == wearOf(clean, 'brake_pads'))
check('desconto nao passa de zero', wearService.AddWear(5, -99999, { 'spark_plugs' }) == true and extra[5].spark_plugs == 0)
check('metros invalidos', select(2, wearService.AddWear(5, 0, { 'spark_plugs' })) == 'invalid_meters')
check('peca desconhecida no extra', select(2, wearService.AddWear(5, 10, { 'turbo' })) == 'unknown_part')
check('sem pecas', select(2, wearService.AddWear(5, 10, {})) == 'invalid_parts')

print('mechanic_test: todos os testes passaram')
