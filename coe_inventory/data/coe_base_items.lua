local definitions = {
	water = {
		label = 'Água mineral',
		weight = 500,
		stack = true,
		maxStack = 20,
		usable = true,
		consume = 1,
		animation = 'drink',
		category = 'food',
		close = true,
		image = 'water.png'
	},
	bread = {
		label = 'Pão',
		weight = 220,
		stack = true,
		maxStack = 10,
		usable = true,
		consume = 1,
		animation = 'eat',
		category = 'food',
		close = true,
		image = 'WEAPON_BREAD.png'
	},
	bandage = {
		label = 'Bandagem',
		weight = 100,
		stack = true,
		maxStack = 10,
		usable = true,
		consume = 1,
		animation = 'bandage',
		category = 'consumables',
		close = true,
		image = 'bandage.png'
	},
	repairkit = {
		label = 'Kit de reparo',
		weight = 1800,
		stack = true,
		maxStack = 3,
		animation = 'repair',
		category = 'misc',
		close = true,
		image = 'advancedkit.png'
	},
	phone = {
		label = 'Celular',
		weight = 350,
		stack = false,
		maxStack = 1,
		close = true,
		image = 'phone.png',
		animation = 'phone',
		category = 'misc',
		metadata = {
			durability = 100
		}
	},
	-- Chip da operadora (metadata.iccid). Item para pacotes de telefone com chips; o telefone básico (coe_mobile) não usa.
	sim_card = {
		label = 'Chip de celular',
		weight = 5,
		stack = false,
		maxStack = 1,
		consume = 0,
		close = true,
		image = 'card_id.png',
		category = 'misc'
	},
	-- Equipamentos de imprensa (coe_news): usar segura o equipamento com a animação; o item não é consumido.
	news_camera = {
		label = 'Câmera de TV',
		weight = 4500,
		stack = false,
		maxStack = 1,
		usable = true,
		consume = 0,
		close = true,
		image = 'news_camera.png',
		category = 'misc'
	},
	news_mic = {
		label = 'Microfone',
		weight = 300,
		stack = false,
		maxStack = 1,
		usable = true,
		consume = 0,
		close = true,
		image = 'news_mic.png',
		category = 'misc'
	},
	news_boom = {
		label = 'Microfone boom',
		weight = 1500,
		stack = false,
		maxStack = 1,
		usable = true,
		consume = 0,
		close = true,
		image = 'news_boom.png',
		category = 'misc'
	},
	-- DeepWeb (coe_deepweb): notebook portátil; desktop e servidor doméstico são instalados dentro de um imóvel.
	-- A série (metadata.serial) é gravada na primeira vez que liga ou instala e acompanha o aparelho.
	laptop = {
		label = 'Notebook',
		weight = 2200,
		stack = false,
		maxStack = 1,
		usable = true,
		consume = 0,
		close = true,
		image = 'laptop.png',
		category = 'misc'
	},
	desktop_pc = {
		label = 'Computador desktop',
		weight = 12000,
		stack = false,
		maxStack = 1,
		usable = true,
		consume = 0,
		close = true,
		image = 'desktop_pc.png',
		category = 'misc'
	},
	home_server = {
		label = 'Servidor doméstico',
		weight = 25000,
		stack = false,
		maxStack = 1,
		usable = true,
		consume = 0,
		close = true,
		image = 'home_server.png',
		category = 'misc'
	},
	-- Instala o navegador onion no celular em uso (ou no tablet). O coe_deepweb remove o item depois de instalar.
	onion_usb = {
		label = 'Pen drive (navegador onion)',
		weight = 20,
		stack = false,
		maxStack = 1,
		usable = true,
		consume = 0,
		close = true,
		image = 'onion_usb.png',
		category = 'misc'
	},
	-- Contrato de locação (coe_rentals): metadata { label, plate, model, vehicle, renter, stateId, station, rentedAt,
	-- price, deposit }. Usar mostra o documento; sai do inventário ao devolver ou encerrar o aluguel.
	rental_contract = {
		label = 'Contrato de locação',
		weight = 10,
		stack = false,
		maxStack = 1,
		usable = true,
		consume = 0,
		close = true,
		image = 'rental_contract.svg',
		category = 'misc'
	},
	-- Carteiras cripto frias (coe_crypto): metadata { address, key, label }. Quem carrega usa a carteira.
	crypto_usb = {
		label = 'Pen drive (carteira cripto)',
		weight = 20,
		stack = false,
		maxStack = 1,
		consume = 0,
		close = true,
		image = 'crypto_usb.png',
		category = 'misc'
	},
	crypto_paper = {
		label = 'Papel com chave',
		weight = 5,
		stack = false,
		maxStack = 1,
		consume = 0,
		close = true,
		image = 'crypto_paper.png',
		category = 'misc'
	},
	business_tablet = {
		label = 'Tablet de negócios',
		weight = 600,
		stack = false,
		maxStack = 1,
		consume = 0,
		close = true,
		image = 'business_tablet.png',
		animation = 'phone',
		category = 'misc'
	},
	-- Tablet de corridas (pacote de corridas ilegais): usar abre o tablet das corridas ilegais; o item não é consumido.
	race_tablet = {
		label = 'Tablet de corridas',
		weight = 700,
		stack = false,
		maxStack = 1,
		usable = true,
		consume = 0,
		close = true,
		image = 'race_tablet.png',
		category = 'misc'
	}
}

for name, definition in pairs(definitions) do
	local item, errorMessage = Inventory.Items.Register(name, definition)
	assert(item, ('failed to register item "%s": %s'):format(name, errorMessage))
end


local expansionDefinitions = {
	keycard_encrypted = { label = 'Keycard criptografado', weight = 15, stack = false, maxStack = 1, usable = true, consume = 0, close = true, image = 'card_id.png', category = 'misc' },
	safe_unit = { label = 'Cofre blindado', weight = 35000, stack = false, maxStack = 1, usable = true, consume = 0, close = true, image = 'WEAPON_BRIEFCASE_02.png', category = 'misc' },
	weapon_locker = { label = 'Armário tático de armas', weight = 28000, stack = false, maxStack = 1, usable = true, consume = 0, close = true, image = 'WEAPON_BRIEFCASE.png', category = 'misc' },
	ammo_crate = { label = 'Caixa de munição pesada', weight = 15000, stack = false, maxStack = 1, usable = true, consume = 0, close = true, image = 'ammo-rifle.png', category = 'misc' },
	smart_lock = { label = 'Fechadura inteligente 3-em-1', weight = 1200, stack = false, maxStack = 1, usable = true, consume = 0, close = true, image = 'advancedkit.png', category = 'misc' },
	router_wifi6 = { label = 'Roteador Wi-Fi 6 Fibra', weight = 800, stack = false, maxStack = 1, usable = true, consume = 0, close = true, image = 'radio.png', category = 'misc' },
	network_firewall_rack = { label = 'Switch Gigabit & Firewall', weight = 4500, stack = false, maxStack = 1, usable = true, consume = 0, close = true, image = 'home_server.png', category = 'misc' },
	orbitlink_dish = { label = 'Antena satélite OrbitLink', weight = 6500, stack = false, maxStack = 1, usable = true, consume = 0, close = true, image = 'news_camera.png', category = 'misc' },
	server_rack_4u = { label = 'Rack de servidor Blade 4U', weight = 32000, stack = false, maxStack = 1, usable = true, consume = 0, close = true, image = 'home_server.png', category = 'misc' },
	desktop_workstation = { label = 'Estação desktop multi-monitor', weight = 14000, stack = false, maxStack = 1, usable = true, consume = 0, close = true, image = 'desktop_pc.png', category = 'misc' },
	monitor_ultrawide = { label = 'Monitor curvo ultrawide DUI', weight = 4200, stack = false, maxStack = 1, usable = true, consume = 0, close = true, image = 'laptop.png', category = 'misc' },
	diesel_generator = { label = 'Gerador industrial a diesel', weight = 45000, stack = false, maxStack = 1, usable = true, consume = 0, close = true, image = 'scrapmetal.png', category = 'misc' },
	solar_panel_array = { label = 'Painel solar fotovoltaico', weight = 18000, stack = false, maxStack = 1, usable = true, consume = 0, close = true, image = 'scrapmetal.png', category = 'misc' },
	battery_wall = { label = 'Bateria estacionária de parede', weight = 22000, stack = false, maxStack = 1, usable = true, consume = 0, close = true, image = 'advancedkit.png', category = 'misc' },
	fib_chem_scanner = { label = 'Espectrômetro de Massa Portátil (DEA)', weight = 1400, stack = false, maxStack = 1, usable = true, consume = 0, close = true, image = 'radio.png', category = 'misc' },
	fib_ballistic_kit = { label = 'Maleta Forense Balística IBIS (ATF)', weight = 2200, stack = false, maxStack = 1, usable = true, consume = 0, close = true, image = 'WEAPON_BRIEFCASE_02.png', category = 'misc' },
	fib_forensic_usb = { label = 'Drive Forense Hot-Dump (FIB Cyber)', weight = 80, stack = false, maxStack = 1, usable = true, consume = 0, close = true, image = 'usb_black.png', category = 'misc' },
	fib_badge = { label = 'Credencial Federal FIB', weight = 120, stack = false, maxStack = 1, usable = true, consume = 0, close = true, image = 'card_id.png', category = 'misc' }
}

for name, definition in pairs(expansionDefinitions) do
	local item, errorMessage = Inventory.Items.Register(name, definition)
	assert(item, ('failed to register expansion item "%s": %s'):format(name, errorMessage))
end
