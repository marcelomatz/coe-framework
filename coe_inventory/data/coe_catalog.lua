local labelOverrides = {
	advancedkit = 'Kit avançado',
	armour = 'Colete',
	black_money = 'Dinheiro sujo',
	burger = 'Hambúrguer',
	business_tablet = 'Tablet de negócios',
	burger_chicken = 'Hambúrguer de frango',
	card_bank = 'Cartão bancário',
	card_id = 'Documento de identidade',
	carkey = 'Chave de veículo',
	cigarette = 'Cigarro',
	cigarettes_redwood = 'Cigarros Redwood',
	cocaine = 'Cocaína',
	donut = 'Rosquinha',
	fries = 'Batata frita',
	garbage = 'Lixo',
	lockpick = 'Gazua',
	medikit = 'Kit médico',
	meth = 'Metanfetamina',
	money = 'Dinheiro',
	mustard = 'Mostarda',
	oldkey = 'Chave antiga',
	paperbag = 'Saco de papel',
	parachute = 'Paraquedas',
	phone = 'Celular',
	pizza_ham = 'Pizza de presunto',
	pizza_ham_box = 'Caixa de pizza',
	pizza_ham_slice = 'Fatia de pizza',
	radio = 'Rádio',
	scrapmetal = 'Sucata metálica',
	sprunk = 'Sprunk',
	trash = 'Saco de lixo',
	trash_bread = 'Pão descartado',
	trash_burger = 'Hambúrguer descartado',
	trash_can = 'Lata de lixo',
	trash_chips = 'Salgadinho descartado',
	usb_black = 'Pen drive',
	weed = 'Maconha',
	ziptie = 'Abraçadeira plástica',
	WEAPON_BRIEFCASE = 'Maleta',
	WEAPON_BRIEFCASE_02 = 'Maleta rígida',
	WEAPON_GARBAGEBAG = 'Saco grande'
}

local categoryDefaults = {
	weapons = { weight = 2500, stack = false, usable = true, maxStack = 1 },
	ammo = { weight = 10, stack = true, usable = false, maxStack = 60 },
	attachments = { weight = 150, stack = true, usable = false, maxStack = 5 },
	food = { weight = 250, stack = true, usable = true, consume = 1, animation = 'eat', maxStack = 20 },
	consumables = { weight = 250, stack = true, usable = true, consume = 1, maxStack = 20 },
	containers = { weight = 1000, stack = false, usable = true, maxStack = 1 },
	misc = { weight = 250, stack = true, usable = false, maxStack = 20 }
}

local function makeLabel(name, category)
	if labelOverrides[name] then
		return labelOverrides[name]
	end

	if category == 'weapons' then
		name = 'arma ' .. name:sub(8)
	elseif category == 'ammo' then
		name = 'munição ' .. name:sub(6)
	elseif category == 'attachments' then
		name = 'acessório ' .. name:sub(4)
	end

	name = name:gsub('_', ' '):gsub('%-', ' '):lower()
	return (name:gsub('(%a)([%w]*)', function(first, rest)
		return first:upper() .. rest
	end))
end

local function valueOrDefault(values, key, default)
	local value = values[key]
	if value == nil then
		return default
	end
	return value
end

function Inventory.Items.RegisterImageGroup(category, names, options)
	if not Core.Functions.IsValidName(category) or type(names) ~= 'string' then
		return false, 'invalid_image_group'
	end

	options = options or {}
	local defaults = categoryDefaults[category] or categoryDefaults.misc
	local registeredCount = 0

	for imageName in names:gmatch('%S+') do
		local itemName = options.aliases and options.aliases[imageName] or imageName
		if not Inventory.Items.Get(itemName) then
			local weapon = category == 'weapons' and Inventory.Items.WeaponProfiles[itemName] or nil
			local container = options.containers and options.containers[itemName]
			local overrides = options.items and options.items[itemName] or {}
			local imageNameOverride = options.images and options.images[itemName]
			local imageFile = imageNameOverride or (imageName .. '.png')
			local metadata

			if weapon then
				metadata = {
					durability = 100,
					components = {}
				}
				if weapon.ammoType then
					metadata.ammo = 0
				end
			end

			local itemDefinition = {
				label = overrides.label or makeLabel(itemName, category),
				weight = valueOrDefault(overrides, 'weight', defaults.weight),
				stack = valueOrDefault(overrides, 'stack', defaults.stack),
				usable = valueOrDefault(overrides, 'usable', defaults.usable),
				consume = valueOrDefault(overrides, 'consume', defaults.consume or 0),
				maxStack = overrides.maxStack or defaults.maxStack,
				animation = overrides.animation or defaults.animation,
				category = category,
				attachment = category == 'attachments',
				container = container,
				weapon = weapon,
				metadata = overrides.metadata or metadata,
				close = true,
				image = imageFile
			}

			local definition, errorMessage = Inventory.Items.Register(itemName, itemDefinition)
			if not definition then
				return false, ('%s: %s'):format(itemName, errorMessage)
			end
			registeredCount = registeredCount + 1
		end
	end

	return true, registeredCount
end
