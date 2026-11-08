-- Cfx mfr packs {func(...)} and unpacks without n, also after Await.
-- Model WITHOUT_HOLES array detection and lua_newtable map decoding from
-- citizenfx/lua-cmsgpack f46b4a3 (mp_table_is_an_array / mp_decode_to_lua_type).
return function(callback, ...)
	local results = { callback(...) }
	local count, maximum = 0, 0
	for index in pairs(results) do
		count, maximum = count + 1, math.max(maximum, index)
	end
	if maximum ~= count then
		-- A sparse tuple is a map on the wire, not an array with reserved nil slots.
		local decodedMap = {}
		for index, value in pairs(results) do decodedMap[index] = value end
		return table.unpack(decodedMap)
	end
	return table.unpack(results)
end
