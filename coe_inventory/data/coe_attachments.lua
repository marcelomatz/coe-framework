local items = [=[
at_barrel at_clip_drum at_clip_extended at_clip_extended2 at_flashlight at_grip
at_muzzle_bell at_muzzle_fat at_muzzle_flat at_muzzle_heavy at_muzzle_precision'
at_muzzle_slanted at_muzzle_split at_muzzle_squared at_muzzle_tactical at_scope_advanced
at_scope_holo at_scope_large at_scope_medium at_scope_nv at_scope_small at_scope_thermal at_suppressor
]=]

local registered, errorMessage = Inventory.Items.RegisterImageGroup('attachments', items, {
	aliases = {
		["at_muzzle_precision'"] = 'at_muzzle_precision'
	}
})
assert(registered, ('failed to register attachments: %s'):format(errorMessage))
