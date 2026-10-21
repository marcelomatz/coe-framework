-- Uso (na pasta coe_vehicle_catalog): lua tools/check.lua <vehicles.meta|handling.meta>...
-- Lista modelos inválidos, duplicados e handlings ausentes. Sai com código 1 se houver erros.
dofile('shared/meta.lua')
dofile('server/catalog.lua')
dofile('config.lua')

local files = { ... }
if #files == 0 then
	io.stderr:write('Informe ao menos um arquivo .meta\n')
	os.exit(2)
end

local source = { resource = 'cli', vehicles = {}, handlings = {}, problems = {} }
for _, path in ipairs(files) do
	local handle = io.open(path, 'rb')
	if not handle then
		source.problems[#source.problems + 1] = 'meta_file_not_found'
		io.stderr:write(('não foi possível abrir %s\n'):format(path))
	else
		local content = handle:read('a')
		handle:close()
		for _, entry in ipairs(VehicleMeta.ParseVehicles(content)) do
			entry.file = path
			source.vehicles[#source.vehicles + 1] = entry
		end
		for _, entry in ipairs(VehicleMeta.ParseHandling(content)) do
			source.handlings[#source.handlings + 1] = entry
		end
	end
end

local catalog = VehicleCatalog.New({ config = CoeVehicleCatalogConfig, seed = {} })
catalog.Rebuild({ source })

local errors = 0
for _, issue in ipairs(catalog.Issues()) do
	if issue.level == 'error' then
		errors = errors + 1
	end
	print(('%s %s %s'):format(issue.level, issue.code, tostring(issue.model)))
end
print(('%d veículos, %d handlings, %d erros'):format(catalog.Count(), #source.handlings, errors))
os.exit(errors == 0 and 0 or 1)
