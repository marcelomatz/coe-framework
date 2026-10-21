local items = [=[
ammo-22 ammo-38 ammo-44 ammo-45 ammo-50 ammo-9 ammo-beanbag ammo-emp ammo-firework
ammo-flare ammo-grenade ammo-heavysniper ammo-laser ammo-musket ammo-railgun ammo-rifle
ammo-rifle2 ammo-rocket ammo-shotgun ammo-sniper
]=]

local registered, errorMessage = Inventory.Items.RegisterImageGroup('ammo', items)
assert(registered, ('failed to register ammunition: %s'):format(errorMessage))
