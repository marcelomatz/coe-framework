dofile('../coe_handling/config.lua')
dofile('../coe_handling/shared/engine.lua')
dofile('../coe_handling/server/service.lua')

local config = CoeHandlingConfig

local function check(name, condition)
	if not condition then
		error('FAIL: ' .. name, 2)
	end
	print('ok  ' .. name)
end

-- engine
check('wear 0 no inicio', HandlingEngine.WearFraction(1000, 1000, 60000) == 0)
check('wear meio', HandlingEngine.WearFraction(31000, 1000, 60000) == 0.5)
check('wear satura em 1', HandlingEngine.WearFraction(999999, 0, 60000) == 1)
check('wear invalido', HandlingEngine.WearFraction(nil, 0, 60000) == 0)

local profile, source = HandlingEngine.ResolveProfile(config, 'super', nil)
check('classe resolve', profile == config.ClassProfiles.super and source == 'class')
config.CategoryProfiles.pickup = { multipliers = { fMass = 1.5 } }
profile, source = HandlingEngine.ResolveProfile(config, 'super', 'pickup')
check('categoria vence classe', profile == config.CategoryProfiles.pickup and source == 'category')
config.CategoryProfiles.pickup = nil
profile, source = HandlingEngine.ResolveProfile(config, 'unknown', nil)
check('fallback para addon', source == 'fallback')
check('barco sem classe usa fallback', select(2, HandlingEngine.ResolveProfile(config, 'boats', nil)) == 'fallback')

local street = HandlingEngine.Compose(config, config.ClassProfiles.sedans, 'street', 0)
local slick = HandlingEngine.Compose(config, config.ClassProfiles.sedans, 'slick', 0)
local worn = HandlingEngine.Compose(config, config.ClassProfiles.sedans, 'slick', 1)
check('slick gruda mais que street', slick.fTractionCurveMax > street.fTractionCurveMax)
check('slick freia mais', slick.fBrakeForce > street.fBrakeForce)
check('slick gasto perde aderencia', worn.fTractionCurveMax < slick.fTractionCurveMax)
check('slick gasto patina mais', worn.fLowSpeedTractionLossMult > slick.fLowSpeedTractionLossMult)
local offroad = HandlingEngine.Compose(config, config.ClassProfiles.sedans, 'offroad', 0)
check('offroad melhor em piso ruim', offroad.fTractionLossMult < street.fTractionLossMult)
check('offroad perde grip no asfalto', offroad.fTractionCurveMax < street.fTractionCurveMax)
check('composto desconhecido', select(2, HandlingEngine.Compose(config, profile, 'xyz', 0)) == 'unknown_tyre')
check('simulador: grip base abaixo de 1', street.fTractionCurveMax < 1)
check('simulador: massa acima de 1', street.fMass > 1)

local muscle = HandlingEngine.Compose(config, config.ClassProfiles.muscle, 'street', 0)
local super = HandlingEngine.Compose(config, config.ClassProfiles.super, 'street', 0)
check('super gruda mais que muscle', super.fTractionCurveMax > muscle.fTractionCurveMax)
check('muscle patina mais', muscle.fLowSpeedTractionLossMult > super.fLowSpeedTractionLossMult * 0.9)

for name, mods in pairs({ street = street, slick = slick, worn = worn, super = super }) do
	for field, value in pairs(mods) do
		check(name .. ' ' .. field .. ' em [0.2,3]', value >= 0.2 and value <= 3.0 and HandlingEngine.FIELDS[field])
	end
end

-- service
local rows, saves = {}, {}
local audits = {}
local persistence = {
	FindTyre = function(id)
		return rows[id], nil
	end,
	SaveTyre = function(id, compound, fittedAt)
		saves[#saves + 1] = { id, compound, fittedAt }
		rows[id] = { compound = compound, fittedAt = fittedAt }
		return true
	end
}
local service = HandlingService.New({
	config = config,
	persistence = persistence,
	getVehicleInfo = function(model)
		if model == 'zentorno' then
			return { class = 'super' }
		end
		if model == 'bison' then
			return { class = 'offroad' }
		end
		return nil
	end,
	audit = function(event, ctx)
		audits[#audits + 1] = { event, ctx }
	end
})

local computed = service.Compute(1, 'zentorno', 0)
check('super usa pneu performance', computed.compound == 'performance')
local computedOff = service.Compute(2, 'bison', 0)
check('offroad usa all_terrain', computedOff.compound == 'all_terrain')
check('addon usa street', service.Compute(3, 'addoncar', 0).compound == 'street')

local early = service.Compute(1, 'zentorno', 100)
local sameStep = service.Compute(1, 'zentorno', 110)
check('chave estavel dentro do passo', early.key == sameStep.key)
local later = service.Compute(1, 'zentorno', 20000)
check('chave muda com desgaste', later.key ~= early.key)
check('desgaste reduz aderencia', later.mods.fTractionCurveMax < early.mods.fTractionCurveMax)

check('SetTyre invalido', select(2, service.SetTyre(1, 'xyz', 0, 'test')) == 'unknown_tyre')
check('SetTyre mileage invalido', select(2, service.SetTyre(1, 'slick', -1, 'test')) == 'invalid_mileage')
check('SetTyre ok', service.SetTyre(1, 'slick', 20000, 'test') == true)
check('SetTyre persiste', saves[1][2] == 'slick' and saves[1][3] == 20000)
check('SetTyre audita', audits[1][1] == 'vehicle_tyre_set')
local fresh = service.Compute(1, 'zentorno', 20000)
check('pneu novo zera desgaste', fresh.wear == 0 and fresh.compound == 'slick')
check('GetTyre', service.GetTyre(1, 20000).compound == 'slick')

service.Forget(1)
check('recarrega do banco apos Forget', service.Compute(1, 'zentorno', 20000).compound == 'slick')

local failing = HandlingService.New({
	config = config,
	persistence = { FindTyre = function() return nil, 'database_error' end },
	getVehicleInfo = function() return nil end
})
check('erro do banco propaga', select(2, failing.Compute(9, 'x', 0)) == 'database_error')

local base = service.Compute(5, 'zentorno', 0)
local withExtra = service.Compute(5, 'zentorno', 0, { mods = { fBrakeForce = 0.5 }, key = 'p1' })
check('extra reduz freio', withExtra.mods.fBrakeForce < base.mods.fBrakeForce)
check('extra altera a chave', withExtra.key ~= base.key)

print('handling_test: todos os testes passaram')
