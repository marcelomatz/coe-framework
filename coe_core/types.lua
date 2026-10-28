---@meta
-- Contrato público de coe_core para LuaLS. Não é carregado pelo servidor. Ver docs/ANNOTATIONS.md.

---@class CoeGroupDefinition
---@field name string
---@field type string
---@field label string
---@field grades table[]

---@class CoeCoreExports
local exports_coe_core = {}

---Objeto Core (eventos, jogadores, grupos, estados). Server e client.
---@return table core
function exports_coe_core:GetCoreObject() end

---Personagem online pelo stateId. Server.
---@param stateId string
---@return table|nil snapshot
---@return string|nil errorCode
function exports_coe_core:GetCharacterByStateId(stateId) end

---Personagem ativo de um jogador online. Server.
---@param source integer
---@return table|nil snapshot
function exports_coe_core:GetActiveCharacter(source) end

---Jogador online pelo stateId. Server.
---@param stateId string
---@return table|nil snapshot
---@return string|nil errorCode
function exports_coe_core:GetPlayerByStateId(stateId) end

---Definições de grupos carregadas do config. Server.
---@return CoeGroupDefinition[]
function exports_coe_core:GetGroupDefinitions() end

---Grupos do personagem ativo do jogador. Server.
---@param source integer
---@return table[]|nil groups
function exports_coe_core:GetPlayerGroups(source) end

---Define o grupo do jogador. Só `coe_admin` pode chamar. Server.
---@param source integer
---@param name string
---@param grade integer
---@param callback fun(success: boolean, errorCode: string|nil)|nil
---@return true|string result `true` ou o código de erro (`forbidden`, `unknown_error`, ...)
function exports_coe_core:SetPlayerGroup(source, name, grade, callback) end

---Remove o vínculo de grupo do jogador. Só `coe_admin` pode chamar. Server.
---@param source integer
---@param name string
---@param callback fun(success: boolean, errorCode: string|nil)|nil
---@return true|string result `true` ou o código de erro (`forbidden`, `unknown_error`, ...)
function exports_coe_core:RemovePlayerGroup(source, name, callback) end

---@class CoePlatformEntity
---@field handle integer
---@field GetHandle fun(self: CoePlatformEntity): integer
---@field Exists fun(self: CoePlatformEntity): boolean
---@field GetCoords fun(self: CoePlatformEntity): vector3|nil
---@field SetCoords fun(self: CoePlatformEntity, x: number|vector3, y?: number, z?: number, clearArea?: boolean): boolean
---@field GetHeading fun(self: CoePlatformEntity): number
---@field SetHeading fun(self: CoePlatformEntity, heading: number): boolean
---@field GetModel fun(self: CoePlatformEntity): integer
---@field GetNetworkId fun(self: CoePlatformEntity): integer|nil
---@field GetState fun(self: CoePlatformEntity, key: string): any
---@field SetState fun(self: CoePlatformEntity, key: string, value: any, replicated?: boolean): boolean
---@field Delete fun(self: CoePlatformEntity): boolean

---@class CoePlatformVehicle : CoePlatformEntity
---@field GetPlate fun(self: CoePlatformVehicle): string
---@field SetPlate fun(self: CoePlatformVehicle, plate: string): boolean
---@field IsLocked fun(self: CoePlatformVehicle): boolean
---@field SetLocked fun(self: CoePlatformVehicle, locked: boolean): boolean
---@field GetEngineHealth fun(self: CoePlatformVehicle): number
---@field SetEngineHealth fun(self: CoePlatformVehicle, health: number): boolean
---@field IsEngineRunning fun(self: CoePlatformVehicle): boolean

---@class CoePlatformEntitiesModule
---@field Exists fun(entity: integer): boolean
---@field GetCoords fun(entity: integer): vector3|nil
---@field SetCoords fun(entity: integer, x: number|vector3, y?: number, z?: number, clearArea?: boolean): boolean
---@field GetHeading fun(entity: integer): number
---@field SetHeading fun(entity: integer, heading: number): boolean
---@field GetModel fun(entity: integer): integer
---@field Delete fun(entity: integer): boolean
---@field GetNetworkId fun(entity: integer): integer|nil
---@field FromNetworkId fun(netId: integer): integer|nil
---@field GetState fun(entity: integer, key: string): any
---@field SetState fun(entity: integer, key: string, value: any, replicated?: boolean): boolean
---@field Wrap fun(entity: integer): CoePlatformEntity|nil

---@class CoePlatformVehiclesModule
---@field Create fun(model: string|integer, coords: vector3|table, heading?: number, isNetworked?: boolean): CoePlatformVehicle|nil
---@field GetPlate fun(vehicle: integer): string
---@field SetPlate fun(vehicle: integer, plate: string): boolean
---@field IsLocked fun(vehicle: integer): boolean
---@field SetLocked fun(vehicle: integer, locked: boolean): boolean
---@field GetEngineHealth fun(vehicle: integer): number
---@field SetEngineHealth fun(vehicle: integer, health: number): boolean
---@field IsEngineRunning fun(vehicle: integer): boolean
---@field FromNetworkId fun(netId: integer): CoePlatformVehicle|nil
---@field Wrap fun(vehicle: integer): CoePlatformVehicle|nil

---@class CoePlatform
---@field Entities CoePlatformEntitiesModule
---@field Vehicles CoePlatformVehiclesModule
---@field Peds CoePlatformPedsModule
---@field Players CoePlatformPlayersModule
---@field Routing CoePlatformRoutingModule
---@field StateBags CoePlatformStateBagsModule
---@field SetMock fun(mock: table|nil)
---@field GetMock fun(): table|nil

---@class CoePlatformPed : CoePlatformEntity
---@field GetHealth fun(self: CoePlatformPed): number
---@field SetHealth fun(self: CoePlatformPed, health: number): boolean
---@field GetArmour fun(self: CoePlatformPed): integer
---@field SetArmour fun(self: CoePlatformPed, armour: number): boolean
---@field IsDead fun(self: CoePlatformPed): boolean
---@field GetVehicle fun(self: CoePlatformPed): integer
---@field SetIntoVehicle fun(self: CoePlatformPed, vehicle: integer, seat?: integer): boolean
---@field ClearTasks fun(self: CoePlatformPed): boolean

---@class CoePlatformPlayer
---@field playerId integer
---@field GetId fun(self: CoePlatformPlayer): integer
---@field GetPed fun(self: CoePlatformPlayer): integer|nil
---@field GetName fun(self: CoePlatformPlayer): string
---@field GetPing fun(self: CoePlatformPlayer): integer
---@field GetEndpoint fun(self: CoePlatformPlayer): string
---@field GetIdentifiers fun(self: CoePlatformPlayer): table
---@field GetBucket fun(self: CoePlatformPlayer): integer
---@field SetBucket fun(self: CoePlatformPlayer, bucket: integer): boolean
---@field GetState fun(self: CoePlatformPlayer, key: string): any
---@field SetState fun(self: CoePlatformPlayer, key: string, value: any, replicated?: boolean): boolean
---@field IsAceAllowed fun(self: CoePlatformPlayer, ace: string): boolean
---@field Drop fun(self: CoePlatformPlayer, reason?: string): boolean

---@class CoePlatformPedsModule
---@field Exists fun(ped: integer): boolean
---@field GetCoords fun(ped: integer): vector3|nil
---@field SetCoords fun(ped: integer, x: number|vector3, y?: number, z?: number, clearArea?: boolean): boolean
---@field GetHeading fun(ped: integer): number
---@field SetHeading fun(ped: integer, heading: number): boolean
---@field GetHealth fun(ped: integer): number
---@field SetHealth fun(ped: integer, health: number): boolean
---@field GetArmour fun(ped: integer): integer
---@field SetArmour fun(ped: integer, armour: number): boolean
---@field IsDead fun(ped: integer): boolean
---@field GetVehicle fun(ped: integer): integer
---@field SetIntoVehicle fun(ped: integer, vehicle: integer, seat?: integer): boolean
---@field ClearTasks fun(ped: integer): boolean
---@field Wrap fun(ped: integer): CoePlatformPed|nil

---@class CoePlatformPlayersModule
---@field GetPed fun(playerId: integer): integer|nil
---@field GetName fun(playerId: integer): string
---@field GetPing fun(playerId: integer): integer
---@field GetEndpoint fun(playerId: integer): string
---@field GetIdentifiers fun(playerId: integer): table
---@field Drop fun(playerId: integer, reason?: string): boolean
---@field IsAceAllowed fun(playerId: integer, ace: string): boolean
---@field GetAll fun(): integer[]
---@field GetRoutingBucket fun(playerId: integer): integer
---@field SetRoutingBucket fun(playerId: integer, bucket: integer): boolean
---@field GetState fun(playerId: integer, key: string): any
---@field SetState fun(playerId: integer, key: string, value: any, replicated?: boolean): boolean
---@field Wrap fun(playerId: integer): CoePlatformPlayer|nil

---@class CoePlatformRoutingModule
---@field GetPlayerBucket fun(playerId: integer): integer
---@field SetPlayerBucket fun(playerId: integer, bucket: integer): boolean
---@field GetEntityBucket fun(entity: integer): integer
---@field SetEntityBucket fun(entity: integer, bucket: integer): boolean
---@field SetPopulationEnabled fun(bucket: integer, enabled: boolean): boolean
---@field SetLockdownMode fun(bucket: integer, mode?: string): boolean

---@class CoePlatformStateBagsModule
---@field GetGlobal fun(key: string): any
---@field SetGlobal fun(key: string, value: any, replicated?: boolean): boolean
---@field GetPlayer fun(playerId: integer, key: string): any
---@field SetPlayer fun(playerId: integer, key: string, value: any, replicated?: boolean): boolean
---@field GetEntity fun(entity: integer, key: string): any
---@field SetEntity fun(entity: integer, key: string, value: any, replicated?: boolean): boolean
---@field AddChangeHandler fun(key: string, filter: string|nil, callback: fun(bagName: string, key: string, value: any, reserved: integer, replicated: boolean)): integer|nil

---@class CoeLocaleInstance
---@field T fun(self: CoeLocaleInstance, key: string, params?: table|any): string
---@field Translate fun(self: CoeLocaleInstance, key: string, params?: table|any): string
---@field SetLanguage fun(self: CoeLocaleInstance, lang: string)
---@field GetLanguage fun(self: CoeLocaleInstance): string
---@field Register fun(self: CoeLocaleInstance, lang: string, dict: table)
---@field Merge fun(self: CoeLocaleInstance, lang: string, patch: table)
---@field ExportForNui fun(self: CoeLocaleInstance, lang?: string): table

---@class CoeLocaleModule
---@field NormalizeLang fun(lang?: string): string
---@field GetDefaultLang fun(): string
---@field SetDefaultLang fun(lang: string)
---@field GetServerName fun(fallback?: string): string
---@field FormatMoney fun(amount: number, lang?: string): string
---@field ExportForNui fun(lang?: string): table
---@field New fun(opts?: { default?: string, fallback?: string, locales?: table }): CoeLocaleInstance

---@class CoeSemVerData
---@field major integer
---@field minor integer
---@field patch integer
---@field prerelease string|nil
---@field build string|nil

---@class CoeSemVerModule
---@field Parse fun(versionStr: string): CoeSemVerData|nil, string|nil
---@field Format fun(data: CoeSemVerData): string
---@field Compare fun(v1: string|CoeSemVerData, v2: string|CoeSemVerData): integer|nil, string|nil
---@field Satisfies fun(version: string|CoeSemVerData, rangeStr: string): boolean
---@field Bump fun(currentVersion: string|CoeSemVerData, bumpType: 'major'|'minor'|'patch'): string|nil, string|nil

---@class CoeCoreInstance
---@field Name string
---@field Prefix string
---@field Version string
---@field Platform CoePlatform
---@field Locale CoeLocaleModule
---@field SemVer CoeSemVerModule
---@field RequireVersion fun(resourceName: string, requiredRange: string): boolean, string|nil
---@field Functions table
---@field Events table
---@field Classes table

