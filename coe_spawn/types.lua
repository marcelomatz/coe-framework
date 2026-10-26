---@meta
---@diagnostic disable

---@class StarterHotelCoords
---@field x number
---@field y number
---@field z number
---@field h number?

---@class StarterHotelStash
---@field x number
---@field y number
---@field z number
---@field slots number
---@field maxWeight number

---@class StarterHotel
---@field name string
---@field enabled boolean
---@field entrance StarterHotelCoords
---@field room StarterHotelCoords
---@field exit StarterHotelCoords
---@field stash StarterHotelStash

---Retorna a configuração atual do hotel de nascimento dos jogadores.
---@return StarterHotel
function exports.coe_spawn:GetStarterHotel() end

---Salva e atualiza as configurações do hotel de nascimento, sincronizando com os jogadores conectados.
---@param data StarterHotel|table
---@return boolean success, string? errorCode
function exports.coe_spawn:SetStarterHotel(data) end
