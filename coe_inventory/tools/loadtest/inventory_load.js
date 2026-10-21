'use strict'
// Teste de carga da persistência de inventário contra um MariaDB real (use um banco de teste).
//
// Compara o modo síncrono (um UPSERT por ação, como transferências/add/remove) com o
// write-behind (ações agrupadas por flush, como swap/split).
//
// Uso (PowerShell):
//   $env:COE_DB_HOST='127.0.0.1'; $env:COE_DB_USER='...'; $env:COE_DB_PASSWORD='...'; $env:COE_DB_NAME='...'
//   node coe_inventory/tools/loadtest/inventory_load.js --players 500 --seconds 20 --actionsPerSec 0.5 --pool 10
//
// Só escreve chaves `loadtest:*` em coe_inventory_records e as apaga ao final.

const path = require('path')
const mysql = require(path.join(__dirname, '..', '..', '..', 'coe_database', 'node_modules', 'mysql2', 'promise'))

function arg(name, fallback) {
	const index = process.argv.indexOf('--' + name)
	return index > -1 ? Number(process.argv[index + 1]) : fallback
}

const players = arg('players', 200)
const seconds = arg('seconds', 15)
const actionsPerSec = arg('actionsPerSec', 0.5)
const poolSize = arg('pool', 10)
const flushMs = arg('flushMs', 1500)
const payload = JSON.stringify({
	id: 'x', slots: 30, maxWeight: 50000,
	items: Object.fromEntries(Array.from({ length: 12 }, (_, i) => [String(i + 1), { name: 'water', count: 3, metadata: {} }]))
})

const UPSERT = `INSERT INTO coe_inventory_records (record_key, record_value) VALUES (?, ?)
	ON DUPLICATE KEY UPDATE record_value = VALUES(record_value)`

function percentile(sorted, p) {
	return sorted.length ? sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * p))] : 0
}

async function run(pool, mode) {
	const latencies = []
	let errors = 0
	const dirty = new Set()
	const end = Date.now() + seconds * 1000
	const write = async (ids) => {
		const started = process.hrtime.bigint()
		try {
			if (ids.length === 1) {
				await pool.query(UPSERT, [ids[0], payload])
			} else {
				const connection = await pool.getConnection()
				try {
					await connection.beginTransaction()
					for (const id of ids) await connection.query(UPSERT, [id, payload])
					await connection.commit()
				} catch (error) {
					await connection.rollback()
					throw error
				} finally {
					connection.release()
				}
			}
			latencies.push(Number(process.hrtime.bigint() - started) / 1e6)
		} catch (error) {
			errors++
		}
	}

	const flusher = mode === 'write-behind' ? setInterval(async () => {
		const ids = [...dirty]
		dirty.clear()
		for (let i = 0; i < ids.length; i += 64) await write(ids.slice(i, i + 64))
	}, flushMs) : null

	const pending = []
	const timers = []
	for (let player = 0; player < players; player++) {
		const key = `loadtest:${mode}:${player}`
		const tick = () => {
			if (Date.now() >= end) return
			if (mode === 'sync') pending.push(write([key])); else dirty.add(key)
			timers.push(setTimeout(tick, (1000 / actionsPerSec) * (0.5 + Math.random())))
		}
		timers.push(setTimeout(tick, Math.random() * (1000 / actionsPerSec)))
	}

	await new Promise((resolve) => setTimeout(resolve, seconds * 1000 + 200))
	if (flusher) clearInterval(flusher)
	timers.forEach(clearTimeout)
	if (mode === 'write-behind' && dirty.size) await write([...dirty].slice(0, 64))
	await Promise.all(pending)

	latencies.sort((a, b) => a - b)
	return {
		modo: mode,
		gravacoes: latencies.length,
		erros: errors,
		'p50 ms': percentile(latencies, 0.5).toFixed(1),
		'p95 ms': percentile(latencies, 0.95).toFixed(1),
		'p99 ms': percentile(latencies, 0.99).toFixed(1)
	}
}

async function main() {
	const config = {
		host: process.env.COE_DB_HOST || '127.0.0.1',
		user: process.env.COE_DB_USER,
		password: process.env.COE_DB_PASSWORD,
		database: process.env.COE_DB_NAME
	}
	if (!config.user || !config.password || !config.database) {
		throw new Error('Defina COE_DB_USER, COE_DB_PASSWORD e COE_DB_NAME (e opcionalmente COE_DB_HOST).')
	}
	const pool = mysql.createPool({ ...config, connectionLimit: poolSize, queueLimit: 0 })
	console.log(`players=${players} segundos=${seconds} acoes/s/player=${actionsPerSec} pool=${poolSize} flushMs=${flushMs}`)
	try {
		const results = []
		for (const mode of ['sync', 'write-behind']) results.push(await run(pool, mode))
		console.table(results)
	} finally {
		await pool.query("DELETE FROM coe_inventory_records WHERE record_key >= 'loadtest:' AND record_key < 'loadtest;'")
		await pool.end()
	}
}

main().catch((error) => { console.error(error.message); process.exit(1) })
