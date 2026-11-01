HandlingEngine = {}

-- Campos de CHandlingData que o resource pode alterar (multiplicadores sobre o valor original do modelo).
HandlingEngine.FIELDS = {
	fMass = true,
	fInitialDragCoeff = true,
	fDownforceModifier = true,
	fInitialDriveForce = true,
	fInitialDriveMaxFlatVel = true,
	fBrakeForce = true,
	fHandBrakeForce = true,
	fSteeringLock = true,
	fTractionCurveMax = true,
	fTractionCurveMin = true,
	fLowSpeedTractionLossMult = true,
	fTractionLossMult = true,
	fSuspensionForce = true,
	fSuspensionCompDamp = true,
	fSuspensionReboundDamp = true,
	fAntiRollBarForce = true,
	fCollisionDamageMult = true,
	fEngineDamageMult = true,
	fDeformationDamageMult = true,
	fClutchChangeRateScaleUpShift = true,
	fClutchChangeRateScaleDownShift = true
}

local MIN_MULTIPLIER = 0.2
local MAX_MULTIPLIER = 3.0

local function clamp(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end

local function round(value)
	return math.floor(value * 10000 + 0.5) / 10000
end

-- Fração de desgaste (0 = novo, 1 = no limite) pela distância rodada desde a montagem.
function HandlingEngine.WearFraction(mileage, fittedAt, lifeMeters)
	if type(mileage) ~= 'number' or type(fittedAt) ~= 'number' or type(lifeMeters) ~= 'number' or lifeMeters <= 0 then
		return 0
	end
	return clamp((mileage - fittedAt) / lifeMeters, 0, 1)
end

-- Categoria (override do catálogo) vence a classe; sem perfil, o veículo não é alterado.
function HandlingEngine.ResolveProfile(config, class, category)
	if type(category) == 'string' and config.CategoryProfiles[category] then
		return config.CategoryProfiles[category], 'category'
	end
	if type(class) == 'string' and config.ClassProfiles[class] then
		return config.ClassProfiles[class], 'class'
	end
	if config.FallbackProfile then
		return config.FallbackProfile, 'fallback'
	end
	return nil
end

-- Multiplicador de desgaste: cai devagar no começo e mais rápido perto do fim.
local function wearFactor(tyre, wear)
	return 1 - (1 - tyre.floor) * wear ^ 1.5
end

-- `extra`: multiplicadores adicionais por campo (ex.: desgaste de peças da mecânica).
function HandlingEngine.Compose(config, profile, tyreName, wear, extra)
	local tyre = config.Tyres[tyreName]
	if not tyre then
		return nil, 'unknown_tyre'
	end
	wear = clamp(tonumber(wear) or 0, 0, 1)
	local factor = wearFactor(tyre, wear)

	local mods = {}
	for field, multiplier in pairs(profile.multipliers or {}) do
		if HandlingEngine.FIELDS[field] and type(multiplier) == 'number' then
			mods[field] = multiplier
		end
	end

	local function scale(field, value)
		mods[field] = (mods[field] or 1) * value
	end

	scale('fTractionCurveMax', tyre.grip * factor)
	scale('fTractionCurveMin', tyre.grip * factor)
	scale('fBrakeForce', tyre.brake * math.sqrt(factor))
	scale('fLowSpeedTractionLossMult', tyre.spin * (2 - factor))
	scale('fTractionLossMult', tyre.surface * (2 - factor))
	scale('fInitialDriveMaxFlatVel', tyre.topSpeed)
	for field, multiplier in pairs(extra or {}) do
		if HandlingEngine.FIELDS[field] and type(multiplier) == 'number' then
			scale(field, multiplier)
		end
	end

	for field, multiplier in pairs(mods) do
		mods[field] = round(clamp(multiplier, MIN_MULTIPLIER, MAX_MULTIPLIER))
	end
	return mods, round(wear)
end
