EmsConfig = {
	-- Permissões de cargo registradas no coe_businesses (prefixo = nome do resource sem "coe_").
	Permissions = {
		{ name = 'ems.revive', label = 'Reanimar pacientes' },
		{ name = 'ems.treat', label = 'Tratar ferimentos' },
		{ name = 'ems.records', label = 'Consultar prontuários' }
	},

	-- Distância máxima entre o médico e o paciente (verificada no servidor).
	ActionRange = 4.0,
	-- Segundos inconsciente até morrer (0 desliga o sangramento).
	BleedoutSeconds = 300,
	-- Se verdadeiro, o médico também reanima quem já morreu; senão o morto precisa usar /respawn.
	ReviveDead = false,
	-- Vida (0..1) abaixo da qual o cliente reporta "ferido".
	InjuredBelow = 0.5,
	-- Hospital de reserva quando não há negócio ems com área circular.
	Respawn = { x = 298.0, y = -584.0, z = 43.3, heading = 70.0 },

	-- Resources que podem definir o estado (ex.: integração com necessidades/HUD) e chamar ações.
	StateResources = { coe_needs = true, coe_hud = true, coe_admin = true },
	ActionResources = { coe_ems = true, coe_tablet = true, coe_admin = true },
	Limits = { MaxRecords = 100 }
}
