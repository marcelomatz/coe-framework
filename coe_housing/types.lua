---@meta
-- Contrato público de coe_housing para LuaLS. Não é carregado pelo servidor.
-- Gerado a partir dos exports registrados no código; refine descrições e tipos ao mexer em cada export.

---@class CoeHousingExports
local exports_coe_housing = {}

---O endereço ainda existe (contrato ativo ou imóvel ilegal com mundo)? Devolve o interior para posicionar a entrega.
---@param propertyId any
---@param owner any
---@return any
function exports_coe_housing:AddressActive(propertyId, owner) end

---Prévia: o admin vai para um mundo só dele enquanto visita interiores; EndPreview o devolve ao mundo comum.
---@param playerId any
---@return any
function exports_coe_housing:BeginPreview(playerId) end

---Imóveis comerciais de um negócio (alugados ou cedidos), para o tablet de negócios.
---@param businessId any
---@return any
function exports_coe_housing:BusinessProperties(businessId) end

---Espaço em que o jogador está agora: { propertyId, owner, interior }, ou nil fora de um imóvel.
---@param playerId any
---@return any
function exports_coe_housing:CurrentSpace(playerId) end

---Export server `DeleteProperty` (server/main.lua).
---@param propertyId any
---@return any
function exports_coe_housing:DeleteProperty(propertyId) end

---Endereços em que o personagem pode receber: moradias, comerciais dos negócios em que trabalha e imóveis ilegais com acesso. Contratos vencidos (fora da carência) ficam de fora.
---@param playerId any
---@return any
function exports_coe_housing:DeliveryAddresses(playerId) end

---Imobiliária (admin): encerra um contrato. O inicial e o cedido a um negócio não são encerrados por aqui.
---@param kind any
---@param contractId any
---@return any
function exports_coe_housing:EndContract(kind, contractId) end

---Export server `EndPreview` (server/main.lua).
---@param playerId any
---@return any
function exports_coe_housing:EndPreview(playerId) end

---Miniaturas capturadas no jogo: mapa id do interior -> data URL JPEG.
---@return any
function exports_coe_housing:InteriorThumbs() end

---Catálogo de interiores nativos (shared/interiors.lua), para o admin escolher o interior de cada imóvel.
---@return any
function exports_coe_housing:Interiors() end

---Export server `IsReady` (server/main.lua).
---@return any
function exports_coe_housing:IsReady() end

---Export server `ListProperties` (server/main.lua).
---@return any
function exports_coe_housing:ListProperties() end

---Jogadores dentro de um espaço (para mostrar entregas a quem já está lá).
---@param propertyId any
---@param owner any
---@return any
function exports_coe_housing:PlayersInSpace(propertyId, owner) end

---Imobiliária (admin): contratos de um imóvel, com quem está dentro agora.
---@param propertyId any
---@return any
function exports_coe_housing:PropertyContracts(propertyId) end

---Export server `SaveInteriorThumb` (server/main.lua).
---@param interiorId any
---@param image any
---@return any
function exports_coe_housing:SaveInteriorThumb(interiorId, image) end

---Export server `SaveProperty` (server/main.lua).
---@param raw any
---@return any
function exports_coe_housing:SaveProperty(raw) end

---Export server `TabletCall` (server/main.lua).
---@param playerId any
---@param appId any
---@param action any
---@param payload any
---@return any
function exports_coe_housing:TabletCall(playerId, appId, action, payload) end

---Export server `TabletVisible` (server/main.lua).
---@param playerId any
---@param appId any
---@return any
function exports_coe_housing:TabletVisible(playerId, appId) end
