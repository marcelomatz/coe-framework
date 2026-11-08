---@meta
--- Contratos Oficiais LuaLS da Biblioteca @coe_core/lib/algorithms/
--- Compatível com FiveM Enhanced Gen9 (CfxLua 5.4 / LuaGLM) e CI Strict Check

---@class CoeSpatialEntity
---@field id string|integer Identificador único da entidade ou ponto de interação
---@field x number Coordenada X no mundo
---@field y number Coordenada Y no mundo
---@field z number Coordenada Z no mundo
---@field cellKey integer Chave inteira de 48+15 bits empacotada da célula atual
---@field cellIndex integer Índice denso (1..n) dentro do bucket da célula para remoção O(1)
---@field bucket integer Dimensão/Routing Bucket do FiveM Enhanced (padrão 0)
---@field payload table|nil Metadados associados (opções de target, garagem, blip)

---@class CoeSpatialGrid
---@field invCellSize number Inverso multiplicativo do tamanho da célula (1.0 / cellSize)
---@field insert fun(self: CoeSpatialGrid, id: string|integer, x: number, y: number, z: number, bucket?: integer, payload?: table): boolean
---@field update fun(self: CoeSpatialGrid, id: string|integer, x: number, y: number, z: number, bucket?: integer): boolean
---@field remove fun(self: CoeSpatialGrid, id: string|integer): boolean
---@field queryRadius fun(self: CoeSpatialGrid, x: number, y: number, z: number, radius: number, bucket?: integer, outBuffer?: table): CoeSpatialEntity[], integer
---@field clear fun(self: CoeSpatialGrid)

---@class CoePolygonZone
---@field minZ number Altura mínima Z da zona
---@field maxZ number Altura máxima Z da zona
---@field minX number Limite AABB mínimo X
---@field maxX number Limite AABB máximo X
---@field minY number Limite AABB mínimo Y
---@field maxY number Limite AABB máximo Y
---@field contains fun(self: CoePolygonZone, x: number, y: number, z: number): boolean

---@class CoeAliasSampler
---@field count integer Número de entradas na tabela de probabilidade
---@field sample fun(self: CoeAliasSampler, rngFloat?: fun(): number, rngInt?: fun(m: integer, n: integer): integer): any, integer
---@field sampleBatch fun(self: CoeAliasSampler, rolls: integer, uniqueSet?: table<any, boolean>, outBuffer?: table): any[], integer

---@class CoeRingBuffer<T>
---@field capacity integer Capacidade máxima fixa
---@field size integer Número atual de elementos
---@field push fun(self: CoeRingBuffer<T>, item: T): T|nil Retorna o item sobrescrito se cheio
---@field pop fun(self: CoeRingBuffer<T>): T|nil
---@field peekNewest fun(self: CoeRingBuffer<T>, offset?: integer): T|nil
---@field clear fun(self: CoeRingBuffer<T>)

---@class CoeLRUCache<K, V>
---@field get fun(self: CoeLRUCache<K, V>, key: K, nowMs?: integer): V|nil
---@field put fun(self: CoeLRUCache<K, V>, key: K, value: V, ttlMs?: integer, nowMs?: integer): K|nil, V|nil
---@field invalidate fun(self: CoeLRUCache<K, V>, key: K): boolean

---@class CoeMinHeap<K>
---@field size fun(self: CoeMinHeap<K>): integer
---@field push fun(self: CoeMinHeap<K>, id: K, priority: number, payload?: any)
---@field pop fun(self: CoeMinHeap<K>): K|nil, number|nil, any|nil
---@field peek fun(self: CoeMinHeap<K>): K|nil, number|nil, any|nil
---@field remove fun(self: CoeMinHeap<K>, id: K): boolean

---@class CoeLockGuard
---@field ok boolean Indica se o lock foi adquirido com sucesso
---@field token integer Token de geração monotônico (Session Fencing)
---@field epoch integer Época de sessão associada ao jogador
---@field release fun()
---@field __close fun(self: CoeLockGuard, err?: any)

---@class CoeStripedLockManager
---@field registerSession fun(self: CoeStripedLockManager, source: integer): integer
---@field dropSession fun(self: CoeStripedLockManager, source: integer)
---@field verifySession fun(self: CoeStripedLockManager, source: integer, expectedEpoch: integer): boolean
---@field acquire fun(self: CoeStripedLockManager, key: string, timeoutMs?: integer, ownerSource?: integer): CoeLockGuard|nil, string|nil
---@field acquireMulti fun(self: CoeStripedLockManager, keys: string[], timeoutMs?: integer, ownerSource?: integer): CoeLockGuard|nil, string|nil

---@class CoeGCRALimiter
---@field allow fun(self: CoeGCRALimiter, key: string|integer, nowMs: integer, cost?: integer): boolean, integer, integer
---@field reset fun(self: CoeGCRALimiter, key: string|integer)
---@field sweep fun(self: CoeGCRALimiter, nowMs: integer): integer

---@class CoeAnomalyMetricState
---@field count integer Número de amostras processadas
---@field mean number Média acumulada de Welford
---@field variance number Variância amostral de Welford
---@field stdDev number Desvio padrão amostral
---@field ewma number Média móvel exponencialmente ponderada
---@field cusumPos number Acumulador CUSUM superior (detecção de salto positivo)
---@field cusumNeg number Acumulador CUSUM inferior (detecção de salto negativo)
---@field isAlarm boolean Indica se o limiar de decisão H foi rompido
