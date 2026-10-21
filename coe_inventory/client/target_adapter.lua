Inventory.Target = {
	AddModel = function(model, options)
		return exports.coetarget:AddTargetModel(model, options)
	end,
	AddSurface = function(options)
		return exports.coetarget:AddTargetSurface(options)
	end
}
