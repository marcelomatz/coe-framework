VehiclePlate = {}

local LETTERS = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
local DIGITS = '0123456789'
local MAX_LENGTH = 8

-- Normaliza para o formato da placa do GTA: 1 a 8 caracteres A-Z, 0-9 e espaço.
function VehiclePlate.Normalize(value)
	if type(value) ~= 'string' then
		return nil, 'invalid_plate'
	end
	local plate = value:gsub('^%s+', ''):gsub('%s+$', ''):upper()
	if #plate == 0 or #plate > MAX_LENGTH or not plate:match('^[A-Z0-9 ]+$') then
		return nil, 'invalid_plate'
	end
	return plate
end

-- `pattern`: N = dígito, L = letra, qualquer outro caractere é literal. Ex.: 'NNLLLNNN'.
function VehiclePlate.Generate(pattern, random)
	random = random or math.random
	if type(pattern) ~= 'string' or #pattern == 0 or #pattern > MAX_LENGTH then
		return nil, 'invalid_pattern'
	end
	local out = {}
	for index = 1, #pattern do
		local symbol = pattern:sub(index, index)
		if symbol == 'N' then
			local position = random(#DIGITS)
			out[index] = DIGITS:sub(position, position)
		elseif symbol == 'L' then
			local position = random(#LETTERS)
			out[index] = LETTERS:sub(position, position)
		else
			out[index] = symbol
		end
	end
	return VehiclePlate.Normalize(table.concat(out))
end
