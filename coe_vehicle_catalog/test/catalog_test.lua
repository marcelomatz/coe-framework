dofile('../coe_vehicle_catalog/config.lua')
dofile('../coe_vehicle_catalog/data/native_vehicles.lua')
dofile('../coe_vehicle_catalog/shared/meta.lua')
dofile('../coe_vehicle_catalog/server/catalog.lua')

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error(('%s: expected %s, got %s'):format(message, tostring(expected), tostring(actual)))
	end
end

local vehiclesXml = [[
<?xml version="1.0" encoding="UTF-8"?>
<CVehicleModelInfo__InitDataList>
  <InitDatas>
    <!-- comentário <modelName>fake</modelName> -->
    <Item>
      <modelName>MyCar</modelName>
      <txdName>mycar</txdName>
      <handlingId>MYCAR</handlingId>
      <gameName>MYCAR</gameName>
      <vehicleMakeName>ACME</vehicleMakeName>
      <type>VEHICLE_TYPE_CAR</type>
      <drivableDoors><Item>x</Item></drivableDoors>
    </Item>
    <Item>
      <modelName>myboat</modelName>
      <handlingId>MYBOAT</handlingId>
      <gameName>MYBOAT</gameName>
      <type>VEHICLE_TYPE_BOAT</type>
    </Item>
    <Item>
      <modelName>adder</modelName>
      <handlingId>ADDER</handlingId>
      <type>VEHICLE_TYPE_CAR</type>
    </Item>
    <Item>
      <modelName>weird</modelName>
      <handlingId>WEIRD</handlingId>
      <type>VEHICLE_TYPE_ALIEN</type>
    </Item>
  </InitDatas>
</CVehicleModelInfo__InitDataList>
]]

local handlingXml = [[
<CHandlingDataMgr>
  <HandlingData>
    <Item type="CHandlingData">
      <handlingName>MYCAR</handlingName>
      <fMass value="1500.000000" />
      <fInitialDriveForce value="0.320000"/>
      <nInitialDriveGears value="6" />
      <vecCentreOfMassOffset x="0.0" y="0.1" z="0.0" />
      <fBrakeForce value="oops" />
    </Item>
    <Item type="CHandlingData">
      <handlingName>MYBOAT</handlingName>
      <fMass value="900.0" />
    </Item>
  </HandlingData>
</CHandlingDataMgr>
]]

-- parser de vehicles.meta
local parsed = VehicleMeta.ParseVehicles(vehiclesXml)
assertEqual(#parsed, 4, 'quatro modelos; comentário ignorado')
assertEqual(parsed[1].model, 'mycar', 'modelo em minúsculas')
assertEqual(parsed[1].brand, 'ACME', 'marca')
assertEqual(parsed[1].type, 'automobile', 'tipo mapeado')
assertEqual(parsed[1].handlingId, 'mycar', 'handlingId em minúsculas')
assertEqual(parsed[2].type, 'boat', 'barco')
assertEqual(parsed[4].type, nil, 'tipo desconhecido')
assertEqual(select(2, VehicleMeta.ParseVehicles(nil)), 'invalid_xml', 'entrada inválida')
assertEqual(#VehicleMeta.ParseVehicles(''), 0, 'vazio')

-- parser de handling.meta
local handlings = VehicleMeta.ParseHandling(handlingXml)
assertEqual(#handlings, 2, 'dois handlings')
assertEqual(handlings[1].name, 'mycar', 'nome em minúsculas')
assertEqual(handlings[1].values.fMass, 1500, 'fMass')
assertEqual(handlings[1].values.nInitialDriveGears, 6, 'inteiro')
assertEqual(handlings[1].values.fBrakeForce, nil, 'valor não numérico ignorado')
assertEqual(handlings[1].values.vecCentreOfMassOffset, nil, 'vetor ignorado')

-- catálogo
local catalog = VehicleCatalog.New({ config = CoeVehicleCatalogConfig, seed = CoeNativeVehicles })
catalog.Rebuild({ { resource = 'pack_a', vehicles = parsed, handlings = handlings, problems = { 'glob_not_supported' } } })

local adder = catalog.GetVehicleInfo('ADDER')
assertEqual(adder.class, 'super', 'nativo mantém a classe')
assertEqual(adder.isAddon, true, 'addon substitui o nativo')
assertEqual(adder.price, CoeVehicleCatalogConfig.PriceByClass.super, 'preço da classe')
local blista = catalog.GetVehicleInfo('blista')
assertEqual(blista.isAddon, false, 'nativo puro')
assertEqual(blista.hasHandling, false, 'nativo sem handling carregado')

local mycar = catalog.GetVehicleInfo('mycar')
assertEqual(mycar.isAddon, true, 'addon')
assertEqual(mycar.resource, 'pack_a', 'resource de origem')
assertEqual(mycar.hasHandling, true, 'handling encontrado')
assertEqual(mycar.class, 'unknown', 'classe desconhecida')
assertEqual(mycar.price, CoeVehicleCatalogConfig.DefaultPrice, 'preço padrão')
assertEqual(catalog.GetBaseHandling('mycar').fMass, 1500, 'handling base')
assertEqual(catalog.GetBaseHandling('blista'), nil, 'sem handling')
assertEqual(catalog.GetBaseHandling(12), nil, 'tipo inválido')
assertEqual(catalog.GetVehicleInfo('nope'), nil, 'modelo inexistente')

local codes = {}
for _, issue in ipairs(catalog.Issues()) do
	codes[issue.code .. ':' .. tostring(issue.model)] = true
end
assertEqual(codes['glob_not_supported:nil'], true, 'problema do resource')
assertEqual(codes['replaces_native:adder'], true, 'substituição de nativo')
assertEqual(codes['handling_missing:adder'], true, 'handling ausente')
assertEqual(codes['unknown_vehicle_type:weird'], true, 'tipo desconhecido')

-- duplicados entre resources
catalog.Rebuild({
	{ resource = 'pack_a', vehicles = parsed, handlings = handlings },
	{ resource = 'pack_b', vehicles = { parsed[1] }, handlings = { handlings[1] } }
})
codes = {}
for _, issue in ipairs(catalog.Issues()) do
	codes[issue.code .. ':' .. tostring(issue.model)] = issue.resource
end
assertEqual(codes['duplicate_model:mycar'], 'pack_b', 'modelo duplicado')
assertEqual(codes['duplicate_handling:mycar'], 'pack_b', 'handling duplicado')
assertEqual(catalog.GetVehicleInfo('mycar').resource, 'pack_a', 'primeiro vence')

-- modelo inválido
catalog.Rebuild({ { resource = 'bad', vehicles = { { model = 'bad model', handlingId = 'x' } }, handlings = {} } })
assertEqual(catalog.Issues()[1].code, 'invalid_model_name', 'nome inválido')
assertEqual(catalog.GetVehicleInfo('bad model'), nil, 'inválido não entra')

-- overrides
catalog.Rebuild({ { resource = 'pack_a', vehicles = parsed, handlings = handlings } })
local merged, model = catalog.MergeOverride('MyCar', { price = 5000, stock = 3, category = 'luxo' })
assertEqual(model, 'mycar', 'modelo normalizado')
assertEqual(merged.price, 5000, 'preço')
catalog.MergeOverride('mycar', { hidden = true })
local overridden = catalog.GetVehicleInfo('mycar')
assertEqual(overridden.price, 5000, 'merge preserva campos')
assertEqual(overridden.stock, 3, 'estoque')
assertEqual(overridden.category, 'luxo', 'categoria')
assertEqual(overridden.hidden, true, 'oculto')
assertEqual(select(2, catalog.MergeOverride('mycar', { price = -1 })), 'invalid_price', 'preço negativo')
assertEqual(select(2, catalog.MergeOverride('mycar', { price = 1.5 })), 'invalid_price', 'preço fracionado')
assertEqual(select(2, catalog.MergeOverride('mycar', { stock = 'x' })), 'invalid_stock', 'estoque inválido')
assertEqual(select(2, catalog.MergeOverride('mycar', { category = 'Ruim!' })), 'invalid_category', 'categoria inválida')
assertEqual(select(2, catalog.MergeOverride('mycar', { hidden = 1 })), 'invalid_hidden', 'oculto inválido')
assertEqual(select(2, catalog.MergeOverride('mycar', { foo = 1 })), 'unknown_override_field', 'campo desconhecido')
assertEqual(select(2, catalog.MergeOverride('nope', { price = 1 })), 'unknown_model', 'modelo desconhecido')
assertEqual(catalog.GetVehicleInfo('mycar').price, 5000, 'override inválido não altera')

-- listagem
for _, item in ipairs(catalog.List({ addon = true })) do
	assertEqual(item.model ~= 'mycar', true, 'oculto fora da listagem')
end
assertEqual(#catalog.List({ includeHidden = true, addon = true }), 4, 'com ocultos')
assertEqual(#catalog.List({ class = 'super', addon = false }), 4, 'supers nativos sem adder')
assertEqual(catalog.List({ search = 'zentor' })[1].model, 'zentorno', 'busca por nome')
assertEqual(catalog.List({ brand = 'PEGASSI', class = 'super' })[1].model, 'infernus', 'marca sem caixa')
assertEqual(#catalog.List({ type = 'boat', addon = false }), 3, 'tipo barco')
assertEqual(#catalog.List({ limit = 2 }), 2, 'limite')
assertEqual(#catalog.List({ maxPrice = 600, addon = false }), 6, 'preço máximo (gratuitos e bicicleta)')
assertEqual(catalog.List({ limit = 1 })[1].model, 'adder', 'ordem alfabética')

-- restauração e remoção
catalog.RestoreOverride('mycar', nil)
assertEqual(catalog.GetVehicleInfo('mycar').price, CoeVehicleCatalogConfig.DefaultPrice, 'restaurado')
catalog.MergeOverride('mycar', { price = 1 })
assertEqual(catalog.RemoveOverride('mycar'), true, 'remove')
assertEqual(catalog.GetVehicleInfo('mycar').price, CoeVehicleCatalogConfig.DefaultPrice, 'sem override')

-- semente nativa íntegra
local seen = {}
for _, row in ipairs(CoeNativeVehicles) do
	assertEqual(seen[row[1]], nil, 'modelo repetido na semente: ' .. row[1])
	seen[row[1]] = true
	assertEqual(row[1]:match('^[%l%d_]+$') ~= nil, true, 'modelo minúsculo: ' .. row[1])
	assertEqual(CoeVehicleCatalogConfig.PriceByClass[row[4]] ~= nil, true, 'classe sem preço: ' .. row[4])
end

print('coe_vehicle_catalog: ok')
