-- test/algorithms_test.lua
-- Suíte de testes unitários offline e benchmark CI (< 50 ms) para @coe_core/lib/algorithms/
local startClock = os.clock()

local Algorithms  = dofile('lib/algorithms/init.lua')
local Spatial     = Algorithms.Spatial
local Sampling    = Algorithms.Sampling
local Containers  = Algorithms.Containers
local Graph       = Algorithms.Graph
local Concurrency = Algorithms.Concurrency
local RateLimit   = Algorithms.RateLimit
local Crypto      = Algorithms.Crypto
local Anomaly     = Algorithms.Anomaly
local Zones       = dofile('lib/zones.lua')

local passed = 0
local function assertTrue(cond, msg)
	if not cond then
		error('[FALHA DE TESTE] ' .. tostring(msg), 2)
	end
	passed = passed + 1
end

-- 1. Teste Spatial Grid 64-bit Bit-Packed & Isolamento de Routing Bucket (coe_housing / coetarget)
do
	local grid = Spatial.newGrid(50.0)
	grid:insert('atm_1', -1234.5, 2345.6, 45.2, 0, { label = 'ATM Pacific' })
	grid:insert('atm_2', -1230.1, 2340.0, 48.0, 0, { label = 'ATM Proximo' })
	grid:insert('prop_instanced', -1232.0, 2342.0, 46.0, 42, { label = 'Interior Bucket 42' })

	local outBuf = {}
	local resBucket0, count0 = grid:queryRadius(-1232.0, 2342.0, 46.0, 15.0, 0, outBuf)
	assertTrue(count0 == 2 and #resBucket0 == 2, 'Spatial queryRadius no bucket 0 deve retornar exatamente 2 entidades')

	local resBucket42, count42 = grid:queryRadius(-1232.0, 2342.0, 46.0, 15.0, 42)
	assertTrue(count42 == 1 and resBucket42[1].id == 'prop_instanced', 'Isolamento de Routing Bucket 42 falhou')

	grid:update('atm_1', 500.0, 500.0, 45.2, 0)
	local _, countMoved = grid:queryRadius(-1232.0, 2342.0, 46.0, 15.0, 0, outBuf)
	assertTrue(countMoved == 1, 'Update para outra celula deveria remover da celula anterior')

	grid:remove('atm_2')
	local _, countAfter = grid:queryRadius(-1232.0, 2342.0, 46.0, 15.0, 0, outBuf)
	assertTrue(countAfter == 0, 'Swap-and-Pop O(1) remove falhou')

	local poly = Spatial.newPolygon(20.0, 60.0, { 0.0, 0.0, 100.0, 0.0, 100.0, 100.0, 0.0, 100.0 })
	assertTrue(poly:contains(50.0, 50.0, 30.0) == true, 'Ponto interno ao poligono 2.5D deveria retornar true')
	assertTrue(poly:contains(50.0, 50.0, 75.0) == false, 'Ponto acima de maxZ deveria retornar false')
	assertTrue(poly:contains(150.0, 50.0, 30.0) == false, 'Ponto fora de AABB X deveria retornar false')

	-- Integração com Core.Zones.AddPolygon e Bit-Packed CellKey
	local z = Zones.New({ cellSize = 50.0 })
	z.AddPolygon('business_yard', {
		points = { 0.0, 0.0, 40.0, 0.0, 40.0, 40.0, 0.0, 40.0 },
		minZ = 10.0,
		maxZ = 30.0,
		bucket = 7
	})
	local hit7 = z.Nearest(20.0, 20.0, 15.0, 7)
	local hit0 = z.Nearest(20.0, 20.0, 15.0, 0)
	assertTrue(hit7 and hit7.id == 'business_yard', 'Core.Zones.AddPolygon deveria encontrar zona no bucket 7')
	assertTrue(hit0 == nil, 'Core.Zones deveria isolar buckets distintos na chave 64-bit')
end

-- 2. Teste Vose's Alias Method O(1) e Itens Únicos (coe_loot / coe_jobs)
do
	local sampler = Sampling.newAliasTable({
		{ item = 'common_water',   weight = 50 },
		{ item = 'uncommon_lock',  weight = 30 },
		{ item = 'rare_pistol',    weight = 15, unique = true },
		{ item = 'epic_rifle',     weight = 4,  unique = true },
		{ item = 'legendary_key',  weight = 1,  unique = true },
	})
	local seenUnique = {}
	local batch, count = sampler:sampleBatch(20, seenUnique)
	assertTrue(count <= 20 and #batch == count, 'Batch de loot inconsistente')
	local pistolCount = 0
	for i = 1, count do
		if batch[i] == 'rare_pistol' then
			pistolCount = pistolCount + 1
		end
	end
	assertTrue(pistolCount <= 1, 'Item marcado como unique foi sorteado mais de uma vez no mesmo batch')
end

-- 3. Teste Containers: RingBuffer, LRU Cache Intrusivo, MinHeap e TimingWheel
do
	local rb = Containers.newRingBuffer(3)
	rb:push('A'); rb:push('B'); rb:push('C')
	local evicted = rb:push('D')
	assertTrue(evicted == 'A' and rb:peekNewest(0) == 'D' and rb:pop() == 'B', 'RingBuffer falhou na rotacao circular')

	local lru = Containers.newLRUCache(2)
	lru:put('k1', 'v1', 1000, 100)
	lru:put('k2', 'v2', 1000, 100)
	assertTrue(lru:get('k1', 200) == 'v1', 'LRU get k1 falhou')
	local evKey = lru:put('k3', 'v3', 1000, 200)
	assertTrue(evKey == 'k2' and lru:get('k2', 200) == nil, 'LRU deveria ter evictado k2')
	assertTrue(lru:get('k1', 1500) == nil, 'LRU deveria ter expirado k1 por TTL')

	local heap = Containers.newMinHeap()
	heap:push('call_low', 30); heap:push('call_urgent', 10); heap:push('call_med', 20)
	heap:push('call_low', 5) -- Atualiza prioridade para mais urgente
	local topId, topPrio = heap:pop()
	assertTrue(topId == 'call_low' and topPrio == 5, 'MinHeap updatePriority/pop falhou')
	assertTrue(heap:remove('call_urgent') == true and heap:size() == 1, 'MinHeap remove falhou')

	local tw = Containers.newTimingWheel(100)
	local fired = 0
	tw:schedule('bleed_1', 300, function(id, payload)
		if id == 'bleed_1' and payload == 99 then
			fired = fired + 1
		end
	end, 99)
	tw:advanceTick(); tw:advanceTick()
	assertTrue(fired == 0, 'TimingWheel nao deveria disparar antes do 3o tick')
	tw:advanceTick()
	assertTrue(fired == 1, 'TimingWheel deveria disparar exatamente no 3o tick')
end

-- 4. Teste Grafo Topológico e Cascata de Restart (coe_supervisor) + A* (coe_jobs)
do
	local nodes = { 'coe_supervisor', 'coe_database', 'coe_core', 'coe_economy', 'coe_shops' }
	local deps = {
		coe_supervisor = {},
		coe_database   = { 'coe_supervisor' },
		coe_core       = { 'coe_supervisor', 'coe_database' },
		coe_economy    = { 'coe_core', 'coe_database' },
		coe_shops      = { 'coe_core', 'coe_economy' }
	}
	local order, waves, cycles = Graph.topologicalSort(nodes, deps)
	assertTrue(order ~= nil and cycles == nil and order[1] == 'coe_supervisor' and order[5] == 'coe_shops', 'Ordenacao topologica falhou')
	assertTrue(#waves == 5, 'Numero de ondas de boot incorreto')

	local stopOrder, startOrder = Graph.cascadeRestartPlan('coe_economy', nodes, deps)
	assertTrue(stopOrder[1] == 'coe_shops' and stopOrder[2] == 'coe_economy', 'Ordem reversa de parada do coe_supervisor incorreta')
	assertTrue(startOrder[1] == 'coe_economy' and startOrder[2] == 'coe_shops', 'Ordem direta de reinicio do coe_supervisor incorreta')

	local routeGraph = {
		A = { x = 0, y = 0, z = 0, edges = { { to = 'B', cost = 10 }, { to = 'C', cost = 50 } } },
		B = { x = 10, y = 0, z = 0, edges = { { to = 'C', cost = 10 } } },
		C = { x = 20, y = 0, z = 0, edges = {} },
	}
	local path, totalCost = Graph.astar(routeGraph, 'A', 'C')
	assertTrue(path and #path == 3 and path[2] == 'B' and totalCost == 20, 'Pathfinding A* falhou ao achar caminho otimo')
end

-- 5. Teste Concorrência: Lock Lexicográfico <close>, Session Fencing (FiveM Enhanced ID Reuse), Saga e Coalescer
do
	local mockTime = 1000
	local locks = Concurrency.newLockManager(function() mockTime = mockTime + 10 end, function() return mockTime end)
	local epochPlayer1 = locks:registerSession(1)
	assertTrue(locks:verifySession(1, epochPlayer1) == true, 'Sessao inicial deveria ser valida')

	-- Simula desconexão e reutilização imediata do source = 1 pelo próximo jogador no FiveM Enhanced
	locks:dropSession(1)
	local epochNewPlayer1 = locks:registerSession(1)
	assertTrue(locks:verifySession(1, epochPlayer1) == false, 'ABA Session Reuse: epoca antiga do source 1 deveria ser rejeitada!')
	assertTrue(locks:verifySession(1, epochNewPlayer1) == true, 'Nova epoca do source 1 deveria ser aceita')

	do
		local guard <close>, err = locks:acquireMulti({ 'inv:stash:99', 'inv:player:1001' }, 500, 1)
		assertTrue(guard ~= nil and err == nil and guard.ok == true, 'Falha ao adquirir multi-lock lexicografico')
	end
	-- Fora do bloco do..end, o metamétodo __close já liberou ambos os locks automaticamente!
	local reacquired <close> = locks:acquire('inv:player:1001', 100, 1)
	assertTrue(reacquired ~= nil and reacquired.ok == true, 'Variavel <close> nao liberou o lock na saida do escopo')

	-- Saga Rollback Determinístico
	local log = {}
	local sagaOk, failedStep = Concurrency.executeSaga({
		{
			name = 'debit_wallet',
			action = function() log[#log + 1] = 'debit'; return 500 end,
			compensate = function(_, amt) log[#log + 1] = 'refund:' .. tostring(amt) end
		},
		{
			name = 'spawn_vehicle',
			action = function() return false end
		}
	}, {})
	assertTrue(sagaOk == false and failedStep == 'spawn_vehicle' and log[2] == 'refund:500', 'Saga nao executou compensacao reversa')

	-- Write-Behind Coalescer
	local flushedBatches = 0
	local coalescer = Concurrency.newWriteBehindCoalescer(function(batch, n)
		if n == 1 and batch[1].data.km == 125 then
			flushedBatches = flushedBatches + 1
		end
	end)
	coalescer:markDirty('veh:1', { km = 100, fuel = 80 })
	coalescer:markDirty('veh:1', { km = 125 })
	assertTrue(coalescer:pendingCount() == 1 and coalescer:flush() == 1 and flushedBatches == 1, 'WriteBehindCoalescer falhou')
end

-- 6. Teste Rate Limiting GCRA (Precisão de Rajada e Retry-After)
do
	local gcra = RateLimit.newGCRA(200, 600) -- 5 req/s sustentado, burst de 4
	local allowedCount = 0
	for _ = 1, 6 do
		local ok = gcra:allow('player:1001', 1000, 1)
		if ok then
			allowedCount = allowedCount + 1
		end
	end
	assertTrue(allowedCount == 4, 'GCRA deveria permitir exatamente 4 requisicoes no burst inicial')
end

-- 7. Teste Criptografia: SHA-256, HMAC, Normalização JOAAT (#3827), Replay Window e Forensic Chain (coe_audit)
do
	local hex = Crypto.sha256('coe_framework_enhanced')
	assertTrue(#hex == 64, 'Hash SHA-256 deve ter 64 caracteres hexadecimais')
	assertTrue(Crypto.constantTimeEquals(hex, hex) == true, 'constantTimeEquals falhou para strings identicas')
	local hmacHex = Crypto.hmacSha256('secret_key', 'payload')
	assertTrue(#hmacHex == 64, 'HMAC-SHA256 deve ter 64 caracteres hexadecimais')

	-- Verifica correção da issue #3827 do weaponDamageEvent (2982836145 unsigned -> -1312131151 signed)
	assertTrue(Crypto.normalizeSignedJoaat(2982836145) == -1312131151, 'Normalizacao JOAAT int32 falhou')

	local rw = Crypto.newReplayWindow()
	assertTrue(rw:verifyAndMark(10) == true, 'Pacote seq 10 deveria ser aceito')
	assertTrue(rw:verifyAndMark(10) == false, 'Replay do pacote seq 10 deveria ser bloqueado')
	assertTrue(rw:verifyAndMark(8) == true, 'Pacote fora de ordem seq 8 dentro da janela de 64 bits deveria ser aceito')
	assertTrue(rw:verifyAndMark(8) == false, 'Replay do pacote seq 8 deveria ser bloqueado')

	local chain = Crypto.newForensicChain('SEED_TEST')
	local h1, prev1, seq1 = chain:append(100, 'coe_economy', 'char:1', 'transfer', '{"amount":500}')
	local h2, prev2, seq2 = chain:append(200, 'coe_economy', 'char:1', 'transfer', '{"amount":200}')
	assertTrue(seq1 == 1 and seq2 == 2 and prev2 == h1 and h1 ~= h2, 'Forensic Hash Chain falhou no encadeamento')
end

-- 8. Teste Anti-Cheat Comportamental: Welford + Tabular CUSUM, Entropia, Dead-Reckoning e Union-Find Ban Graph
do
	local detector = Anomaly.newWelfordCUSUM(0.20, 0.10, 2.50)
	local lastState
	for _ = 1, 10 do
		lastState = detector:observe(0.85) -- Salto para 85% de headshots (Silent Aim)
	end
	assertTrue(lastState.isAlarm == true and lastState.cusumPos > 5.4, 'Welford+CUSUM falhou ao detectar anomalia de Aimbot')

	local entropyAimbot = Anomaly.shannonEntropy({ [20] = 50 }) -- 100% no mesmo osso (cabeça)
	local entropyHuman = Anomaly.shannonEntropy({ [20] = 5, [0] = 20, [1] = 15, [2] = 10 })
	assertTrue(entropyAimbot == 0.0 and entropyHuman > 1.5, 'Entropia de Shannon falhou ao distinguir Aimbot de humano')

	local kinOk = Anomaly.verifyKinematics(0, 0, 0, 1000, 500, 0, 0, 2000, 60.0, 8.0)
	assertTrue(kinOk == false, 'Dead-Reckoning deveria reprovar deslocamento de 500m em 1s')

	local idGraph = Anomaly.newIdentityGraph()
	idGraph:linkIdentityCluster({ 'fp:license2:abc', 'fp:token:hw1', 'fp:token:hw2' })
	idGraph:banCluster('fp:license2:abc', 'Silent Aimbot Detectado pelo coe_shield')
	-- Cheater troca de conta Rockstar (fp:license2:xyz), mas mantém o mesmo token de placa-mãe/disco (fp:token:hw2)
	local _, isEvading, reason = idGraph:linkIdentityCluster({ 'fp:license2:xyz', 'fp:token:hw2', 'fp:token:hw9' })
	assertTrue(isEvading == true and reason == 'Silent Aimbot Detectado pelo coe_shield', 'Union-Find falhou ao detectar Ban Evasion por Hardware Token')
end

local elapsedMs = (os.clock() - startClock) * 1000.0
assertTrue(elapsedMs < 50.0, ('Tempo de execucao (%.2f ms) excedeu a meta CI de 50 ms'):format(elapsedMs))
print(string.format('[COE TEST SUITE] %d assercoes aprovadas com sucesso em %.2f ms (Meta CI: < 50.00 ms)', passed, elapsedMs))
