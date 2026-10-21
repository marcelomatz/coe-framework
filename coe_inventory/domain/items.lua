Inventory = {
	Items = {
		Registry = {},
		Animations = {},
		WeaponProfiles = {}
	}
}

local ItemDefinition = assert(Core.Classes.Register('ItemDefinition'))
local InventoryItem = assert(Core.Classes.Register('InventoryItem'))

local function isFiniteNumber(value)
	return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local function isVector3(value)
	return type(value) == 'table'
		and isFiniteNumber(value.x)
		and isFiniteNumber(value.y)
		and isFiniteNumber(value.z)
end

local function valuesEqual(first, second)
	if type(first) ~= type(second) then
		return false
	end
	if type(first) ~= 'table' then
		return first == second
	end

	for key, value in pairs(first) do
		if not valuesEqual(value, second[key]) then
			return false
		end
	end
	for key in pairs(second) do
		if first[key] == nil then
			return false
		end
	end

	return true
end

local function cloneMetadata(metadata)
	if type(metadata) ~= 'table' then
		return nil
	end

	local encodedOk, encoded = pcall(json.encode, metadata)
	if not encodedOk or type(encoded) ~= 'string' then
		return nil
	end

	local decodedOk, copy = pcall(json.decode, encoded)
	if not decodedOk or type(copy) ~= 'table' then
		return nil
	end

	return copy
end

local function mergeMetadata(defaults, metadata)
	local result = Core.Functions.DeepCopy(defaults)
	for key, value in pairs(metadata) do
		result[key] = Core.Functions.DeepCopy(value)
	end
	return result
end

function ItemDefinition:init(name, data)
	self.name = name
	self.label = data.label or name
	self.weight = data.weight or 0
	self.stack = data.stack ~= false
	self.close = data.close ~= false
	self.image = data.image or (name .. '.png')
	self.usable = data.usable ~= false
	self.consume = data.consume or 0
	self.animation = data.animation
	self.attachment = data.attachment == true
	self.category = data.category or 'misc'
	self.container = data.container and Core.Functions.DeepCopy(data.container) or nil
	self.weapon = data.weapon and Core.Functions.DeepCopy(data.weapon) or nil
	self.maxStack = data.maxStack
	if not self.stack and self.maxStack == nil then
		self.maxStack = 1
	end
	self.metadata = Core.Functions.DeepCopy(data.metadata or {})
end

function ItemDefinition:toTable()
	return {
		name = self.name,
		label = self.label,
		weight = self.weight,
		stack = self.stack,
		close = self.close,
		image = self.image,
		usable = self.usable,
		consume = self.consume,
		animation = self.animation,
		attachment = self.attachment,
		category = self.category,
		container = self.container and Core.Functions.DeepCopy(self.container) or nil,
		weapon = self.weapon and Core.Functions.DeepCopy(self.weapon) or nil,
		maxStack = self.maxStack,
		metadata = Core.Functions.DeepCopy(self.metadata)
	}
end

function InventoryItem:init(definition, count, metadata, slot)
	self.definition = definition
	self.name = definition.name
	self.count = count
	self.metadata = mergeMetadata(definition.metadata, metadata)
	self.slot = slot
end

function InventoryItem:canStack(other)
	return self.definition.stack
		and other.definition.stack
		and self.name == other.name
		and valuesEqual(self.metadata, other.metadata)
end

function InventoryItem:getWeight()
	return self.definition.weight * self.count
end

function InventoryItem:toTable()
	return {
		name = self.name,
		label = self.metadata.label or self.definition.label,
		count = self.count,
		weight = self:getWeight(),
		metadata = Core.Functions.DeepCopy(self.metadata),
		slot = self.slot,
		stack = self.definition.stack,
		close = self.definition.close,
		image = self.definition.image,
		usable = self.definition.usable,
		consume = self.definition.consume,
		animation = self.definition.animation,
		attachment = self.definition.attachment,
		category = self.definition.category,
		container = self.definition.container and Core.Functions.DeepCopy(self.definition.container) or nil,
		weapon = self.definition.weapon and Core.Functions.DeepCopy(self.definition.weapon) or nil
	}
end

function InventoryItem:toStorage()
	return {
		name = self.name,
		count = self.count,
		metadata = Core.Functions.DeepCopy(self.metadata)
	}
end

function Inventory.Items.RegisterAnimation(name, animation)
	if not Core.Functions.IsValidName(name) then
		return false, 'invalid_animation_name'
	end
	if Inventory.Items.Animations[name] then
		return false, 'animation_already_registered'
	end
	if type(animation) ~= 'table'
		or type(animation.dict) ~= 'string'
		or type(animation.clip) ~= 'string'
		or not Core.Functions.IsInteger(animation.duration)
		or animation.duration < 1
		or not Core.Functions.IsInteger(animation.flag)
		or animation.flag < 0
		or (animation.advanced ~= nil and type(animation.advanced) ~= 'boolean')
		or (animation.startTime ~= nil and (type(animation.startTime) ~= 'number'
			or animation.startTime ~= animation.startTime
			or animation.startTime < 0
			or animation.startTime > 1))
		or (animation.equipAt ~= nil and (not isFiniteNumber(animation.equipAt)
			or animation.equipAt < 0
			or animation.equipAt > 1)) then
		return false, 'invalid_animation_definition'
	end
	local prop = animation.prop
	if prop ~= nil then
		if type(prop) ~= 'table'
			or (prop.weaponModel ~= nil and type(prop.weaponModel) ~= 'boolean')
			or (prop.weaponModel ~= true and (type(prop.model) ~= 'string' or not Core.Functions.IsValidName(prop.model)))
			or (prop.attachAt ~= nil and (not isFiniteNumber(prop.attachAt) or prop.attachAt < 0 or prop.attachAt > 1))
			or not Core.Functions.IsInteger(prop.bone)
			or prop.bone < 0
			or not isVector3(prop.position)
			or not isVector3(prop.rotation) then
			return false, 'invalid_animation_prop'
		end
	end

	Inventory.Items.Animations[name] = Core.Functions.DeepCopy(animation)
	return true
end

function Inventory.Items.Register(name, data)
	if not Core.Functions.IsValidName(name) then
		return nil, 'invalid_item_name'
	end
	if Inventory.Items.Registry[name] then
		return nil, 'item_already_registered'
	end
	if type(data) ~= 'table' then
		return nil, 'invalid_item_definition'
	end

	local label = data.label
	if label == nil then
		label = name
	end
	local weight = data.weight
	if weight == nil then
		weight = 0
	end
	local stack = data.stack ~= false
	local maxStack = data.maxStack
	local usable = data.usable
	if usable == nil then
		usable = true
	end
	local consume = data.consume
	if consume == nil then
		consume = 0
	end
	local animation = data.animation
	local attachment = data.attachment
	local category = data.category or 'misc'
	local container = data.container
	local weapon = data.weapon
	local image = data.image
	if image == nil then
		image = name .. '.png'
	end
	local metadata = data.metadata
	if metadata == nil then
		metadata = {}
	end

	if type(label) ~= 'string' or #label == 0 then
		return nil, 'invalid_item_label'
	end
	if not Core.Functions.IsInteger(weight) or weight < 0 then
		return nil, 'invalid_item_weight'
	end
	if data.stack ~= nil and type(data.stack) ~= 'boolean' then
		return nil, 'invalid_stack_setting'
	end
	if data.close ~= nil and type(data.close) ~= 'boolean' then
		return nil, 'invalid_close_setting'
	end
	if type(usable) ~= 'boolean' then
		return nil, 'invalid_usable_setting'
	end
	if not Core.Functions.IsInteger(consume) or consume < 0 then
		return nil, 'invalid_consume_count'
	end
	if animation ~= nil
		and (type(animation) ~= 'string' or not Inventory.Items.Animations[animation]) then
		return nil, 'invalid_item_animation'
	end
	if attachment ~= nil and type(attachment) ~= 'boolean' then
		return nil, 'invalid_attachment_setting'
	end
	if not Core.Functions.IsValidName(category) then
		return nil, 'invalid_item_category'
	end
	if container ~= nil and (type(container) ~= 'table'
		or not Core.Functions.IsInteger(container.slots)
		or container.slots < 1
		or not Core.Functions.IsInteger(container.maxWeight)
		or container.maxWeight < 1) then
		return nil, 'invalid_container_profile'
	end
	if container and stack then
		return nil, 'container_not_stackable'
	end
	if weapon ~= nil then
		if type(weapon) ~= 'table'
			or (weapon.ammoType ~= nil and not Core.Functions.IsValidName(weapon.ammoType))
			or (weapon.caliber ~= nil and (type(weapon.caliber) ~= 'string' or #weapon.caliber == 0)) then
			return nil, 'invalid_weapon_profile'
		end
	end
	if type(image) ~= 'string' or image:match("^[%w_%-'.]+%.png$") == nil then
		return nil, 'invalid_item_image'
	end
	if maxStack ~= nil and (not Core.Functions.IsInteger(maxStack) or maxStack < 1) then
		return nil, 'invalid_max_stack'
	end
	if not stack and maxStack and maxStack ~= 1 then
		return nil, 'invalid_max_stack'
	end
	if type(metadata) ~= 'table' then
		return nil, 'invalid_item_metadata'
	end
	local metadataCopy = cloneMetadata(metadata)
	if not metadataCopy then
		return nil, 'invalid_item_metadata'
	end

	local definition = ItemDefinition:new(name, {
		label = label,
		weight = weight,
		stack = stack,
		close = data.close,
		image = image,
		usable = usable,
		consume = consume,
		animation = animation,
		attachment = attachment,
		category = category,
		container = container and Core.Functions.DeepCopy(container) or nil,
		weapon = weapon and Core.Functions.DeepCopy(weapon) or nil,
		maxStack = maxStack,
		metadata = metadataCopy
	})
	Inventory.Items.Registry[name] = definition
	return definition
end

function Inventory.Items.Get(name)
	return Inventory.Items.Registry[name]
end

function Inventory.Items.GetAll()
	local definitions = {}
	for name, definition in pairs(Inventory.Items.Registry) do
		definitions[name] = definition:toTable()
	end
	return definitions
end

function Inventory.Items.Create(name, count, metadata, slot)
	local definition = Inventory.Items.Get(name)
	if not definition then
		return nil, 'invalid_item'
	end
	if not Core.Functions.IsInteger(count) or count < 1 then
		return nil, 'invalid_count'
	end

	if type(metadata) == 'string' then
		metadata = { type = metadata }
	elseif metadata == nil then
		metadata = {}
	elseif type(metadata) ~= 'table' then
		return nil, 'invalid_item_metadata'
	end

	local metadataCopy = cloneMetadata(metadata)
	if not metadataCopy then
		return nil, 'invalid_item_metadata'
	end
	return InventoryItem:new(definition, count, metadataCopy, slot)
end

function Inventory.Items.MetadataMatches(metadata, filter, strict)
	if filter == nil then
		return true
	end
	if type(filter) == 'string' then
		filter = { type = filter }
	end
	if type(filter) ~= 'table' or type(metadata) ~= 'table' then
		return false
	end
	if strict ~= false then
		return valuesEqual(metadata, filter)
	end

	for key, value in pairs(filter) do
		if not valuesEqual(metadata[key], value) then
			return false
		end
	end
	return true
end
