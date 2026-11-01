-- Valores iniciais de um handling "simulador": mais massa, menos força de arranque, menos pico de aderência,
-- freio e suspensão mais pesados. São pontos de partida e precisam de ajuste fino dirigindo no jogo.
local BASE = {
	fMass = 1.08,
	fInitialDragCoeff = 1.05,
	fInitialDriveForce = 0.92,
	fBrakeForce = 0.95,
	fHandBrakeForce = 0.9,
	fSteeringLock = 0.9,
	fTractionCurveMax = 0.92,
	fTractionCurveMin = 0.94,
	fLowSpeedTractionLossMult = 1.15,
	fTractionLossMult = 1.1,
	fSuspensionForce = 1.05,
	fSuspensionCompDamp = 1.1,
	fSuspensionReboundDamp = 1.1,
	fAntiRollBarForce = 1.1,
	fCollisionDamageMult = 1.2,
	fDeformationDamageMult = 1.2,
	fClutchChangeRateScaleUpShift = 0.8,
	fClutchChangeRateScaleDownShift = 0.8
}

local function profile(overrides, defaultTyre)
	local multipliers = {}
	for field, value in pairs(BASE) do
		multipliers[field] = value
	end
	for field, value in pairs(overrides or {}) do
		multipliers[field] = value
	end
	return { multipliers = multipliers, defaultTyre = defaultTyre }
end

CoeHandlingConfig = {
	-- Quem pode trocar pneus (nome vem do runtime).
	WriterResources = {
		coe_admin = true,
		coe_handling = true,
		coe_mechanic = true,
		coe_dealerships = true
	},
	DefaultTyre = 'street',

	-- Perfis por classe do catálogo. Classes ausentes (boats, helicopters, planes, cycles) não são alteradas.
	ClassProfiles = {
		compacts = profile({ fMass = 1.05, fInitialDriveForce = 0.95, fSteeringLock = 0.93 }),
		sedans = profile({ fSuspensionCompDamp = 1.15, fSuspensionReboundDamp = 1.15, fAntiRollBarForce = 1.15 }),
		suvs = profile({ fMass = 1.15, fAntiRollBarForce = 1.3, fSuspensionForce = 1.15, fTractionCurveMax = 0.9,
			fBrakeForce = 0.92 }),
		coupes = profile({ fInitialDriveForce = 0.93, fTractionCurveMax = 0.94 }),
		muscle = profile({ fMass = 1.12, fInitialDriveForce = 1.0, fTractionCurveMax = 0.86, fTractionCurveMin = 0.88,
			fLowSpeedTractionLossMult = 1.35, fAntiRollBarForce = 0.95 }),
		sports_classics = profile({ fMass = 1.05, fInitialDriveForce = 0.9, fTractionCurveMax = 0.88,
			fBrakeForce = 0.88, fAntiRollBarForce = 0.9 }),
		sports = profile({ fInitialDriveForce = 0.93, fTractionCurveMax = 0.97, fTractionCurveMin = 0.98,
			fDownforceModifier = 1.1, fBrakeForce = 1.0 }, 'sport'),
		super = profile({ fMass = 1.04, fInitialDriveForce = 0.88, fTractionCurveMax = 1.02, fTractionCurveMin = 1.02,
			fDownforceModifier = 1.2, fBrakeForce = 1.05, fLowSpeedTractionLossMult = 1.25 }, 'performance'),
		motorcycles = profile({ fMass = 1.0, fSteeringLock = 0.95, fTractionCurveMax = 0.9, fBrakeForce = 0.9,
			fSuspensionForce = 1.0, fAntiRollBarForce = 1.0 }),
		offroad = profile({ fMass = 1.1, fTractionCurveMax = 0.9, fTractionLossMult = 0.85, fSuspensionForce = 0.95,
			fSuspensionCompDamp = 1.0, fSuspensionReboundDamp = 1.0 }, 'all_terrain'),
		vans = profile({ fMass = 1.2, fInitialDriveForce = 0.88, fBrakeForce = 0.9, fSteeringLock = 0.85,
			fAntiRollBarForce = 1.3 }),
		commercial = profile({ fMass = 1.25, fInitialDriveForce = 0.85, fBrakeForce = 0.88, fSteeringLock = 0.82,
			fAntiRollBarForce = 1.35 }),
		emergency = profile({ fInitialDriveForce = 0.95, fBrakeForce = 1.0 }),
		service = profile({ fMass = 1.15, fInitialDriveForce = 0.88, fSteeringLock = 0.85 }),
		utility = profile({ fMass = 1.15, fInitialDriveForce = 0.9 })
	},

	-- Perfis por categoria (override do catálogo por modelo) têm prioridade sobre a classe.
	-- Exemplo: CategoryProfiles.pickup = profile({ ... }). Vazio por padrão.
	CategoryProfiles = {},

	-- Addons sem classe (`unknown`) usam o perfil base.
	FallbackProfile = profile({}),

	-- Compostos de pneu.
	-- grip: pico de aderência; brake: frenagem; spin: patinagem em baixa velocidade (maior = mais);
	-- surface: perda em piso ruim (menor = melhor fora de asfalto); topSpeed: resistência ao rolamento;
	-- life: metros até o desgaste total; floor: fração de aderência que resta com o pneu no limite.
	Tyres = {
		street = { grip = 1.0, brake = 1.0, spin = 1.0, surface = 1.0, topSpeed = 1.0, life = 60000, floor = 0.75 },
		sport = { grip = 1.08, brake = 1.05, spin = 1.1, surface = 1.1, topSpeed = 1.0, life = 40000, floor = 0.7 },
		performance = { grip = 1.15, brake = 1.1, spin = 1.2, surface = 1.25, topSpeed = 1.0, life = 25000, floor = 0.65 },
		slick = { grip = 1.25, brake = 1.18, spin = 1.4, surface = 1.6, topSpeed = 1.0, life = 15000, floor = 0.55 },
		all_terrain = { grip = 0.94, brake = 0.97, spin = 0.85, surface = 0.65, topSpeed = 0.98, life = 70000, floor = 0.78 },
		offroad = { grip = 0.88, brake = 0.95, spin = 0.75, surface = 0.5, topSpeed = 0.96, life = 80000, floor = 0.8 },
		drift = { grip = 0.8, brake = 0.95, spin = 1.3, surface = 1.1, topSpeed = 1.0, life = 12000, floor = 0.6 }
	}
}
