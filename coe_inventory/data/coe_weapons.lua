local nonWeaponObjects = {
	WEAPON_BRIEFCASE = true,
	WEAPON_BRIEFCASE_02 = true,
	WEAPON_GARBAGEBAG = true
}

local weaponNames = {}
for weaponName in pairs(Inventory.Items.WeaponProfiles) do
	if not nonWeaponObjects[weaponName] then
		weaponNames[#weaponNames + 1] = weaponName
	end
end

table.sort(weaponNames)
local registered, errorMessage = Inventory.Items.RegisterImageGroup('weapons', table.concat(weaponNames, ' '))
assert(registered, ('failed to register weapons: %s'):format(errorMessage))
