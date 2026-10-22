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
		image = 'phone.png',
		animation = 'phone',
		category = 'misc'
	}
}

for name, definition in pairs(definitions) do
	local item, errorMessage = Inventory.Items.Register(name, definition)
	assert(item, ('failed to register item "%s": %s'):format(name, errorMessage))
end
