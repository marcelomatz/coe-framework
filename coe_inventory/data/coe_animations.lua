local animations = {
	eat = {
		dict = 'mp_player_inteat@burger',
		clip = 'mp_player_int_eat_burger',
		duration = 2600,
		flag = 49,
		prop = {
			model = 'prop_cs_burger_01',
			bone = 18905,
			position = { x = 0.13, y = 0.05, z = 0.02 },
			rotation = { x = -50.0, y = 16.0, z = 60.0 }
		}
	},
	drink = {
		dict = 'mp_player_intdrink',
		clip = 'loop_bottle',
		duration = 2600,
		flag = 49,
		prop = {
			model = 'prop_ld_flow_bottle',
			bone = 18905,
			position = { x = 0.12, y = 0.008, z = 0.03 },
			rotation = { x = 240.0, y = -60.0, z = 0.0 }
		}
	},
	bandage = {
		dict = 'amb@medic@standing@tendtodead@base',
		clip = 'base',
		duration = 3200,
		flag = 49,
		prop = {
			model = 'prop_ld_health_pack',
			bone = 57005,
			position = { x = 0.1, y = 0.02, z = -0.02 },
			rotation = { x = -90.0, y = 0.0, z = 0.0 }
		}
	},
	repair = {
		dict = 'mini@repair',
		clip = 'fixing_a_ped',
		duration = 4200,
		flag = 49,
		prop = {
			model = 'prop_tool_box_04',
			bone = 57005,
			position = { x = 0.12, y = 0.02, z = -0.04 },
			rotation = { x = -90.0, y = 0.0, z = 0.0 }
		}
	},
	phone = {
		dict = 'cellphone@',
		clip = 'cellphone_text_in',
		duration = 1700,
		flag = 49,
		prop = {
			model = 'prop_npc_phone_02',
			bone = 57005,
			position = { x = 0.12, y = 0.02, z = 0.0 },
			rotation = { x = -90.0, y = 0.0, z = 0.0 }
		}
	},
	smoke = {
		dict = 'amb@world_human_smoking@male@male_a@base',
		clip = 'base',
		duration = 3800,
		flag = 49,
		prop = {
			model = 'prop_cs_ciggy_01',
			bone = 57005,
			position = { x = 0.13, y = 0.02, z = 0.0 },
			rotation = { x = 0.0, y = 0.0, z = 0.0 }
		}
	},
	drug = {
		dict = 'switch@trevor@trev_smoking_meth',
		clip = 'trev_smoking_meth_loop',
		duration = 3200,
		flag = 49
	},
	weapon_draw = {
		dict = 'reaction@intimidation@1h',
		clip = 'intro',
		duration = 2400,
		flag = 50,
		advanced = true,
		startTime = 0.1,
		equipAt = 0.5
	},
	-- Maletas: pegar do chao, equipar pelo inventario e guardar (nao reutilizam o saque de arma).
	container_pickup = {
		dict = 'pickup_object',
		clip = 'pickup_low',
		duration = 1500,
		flag = 48,
		equipAt = 0.55
	},
	container_equip = {
		dict = 'mp_common',
		clip = 'givetake1_a',
		duration = 1300,
		flag = 48,
		equipAt = 0.5
	},
	container_stow = {
		dict = 'mp_common',
		clip = 'givetake2_a',
		duration = 1300,
		flag = 48,
		equipAt = 0.6
	},
	weapon_holster = {
		dict = 'reaction@intimidation@1h',
		clip = 'outro',
		duration = 1200,
		flag = 50,
		advanced = true
	}
}

for name, definition in pairs(animations) do
	local registered, errorMessage = Inventory.Items.RegisterAnimation(name, definition)
	assert(registered, ('failed to register animation "%s": %s'):format(name, errorMessage))
end
