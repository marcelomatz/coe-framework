const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

let JSDOM;
try {
	JSDOM = require('jsdom').JSDOM;
} catch {
	JSDOM = require('../../coe_hud/node_modules/jsdom').JSDOM;
}

const htmlDir = path.join(__dirname, '..', 'html');
const read = (name) => fs.readFileSync(path.join(htmlDir, name), 'utf8');

function setup() {
	const dom = new JSDOM(read('index.html'), { runScripts: 'outside-only' });
	const { window } = dom;
	const posts = [];

	window.GetParentResourceName = () => 'coe_pausemenu';
	window.fetch = (url, init) => {
		const endpoint = url.split('/').pop();
		posts.push({ endpoint, body: JSON.parse(init.body || '{}') });
		return Promise.resolve({ json: () => ({ ok: true }) });
	};

	window.eval(read('app.js'));

	const doc = window.document;
	const send = (data) => window.dispatchEvent(new window.MessageEvent('message', { data }));
	const $ = (sel) => doc.querySelector(sel);
	const $$ = (sel) => doc.querySelectorAll(sel);
	const key = (k) => doc.dispatchEvent(new window.KeyboardEvent('keydown', { key: k, bubbles: true }));
	const lastPost = () => posts[posts.length - 1];

	return { window, doc, send, $, $$, key, posts, lastPost };
}

test('menu de pausa: inicialmente oculto', () => {
	const { $ } = setup();
	assert.ok($('#pause-container').hidden, 'container principal oculto inicialmente');
	assert.ok($('#disconnect-dialog').hidden, 'diálogo de desconexão oculto');
});

test('recebimento de dados e preenchimento da interface', () => {
	const { send, $ } = setup();

	send({
		action: 'open',
		data: {
			character: {
				name: 'Marcus Holloway',
				stateId: 'COE9988',
				job: 'Especialista Cyber',
				jobGrade: 'Nível 3',
				faction: 'DedSec',
				factionGrade: 'Líder',
				location: 'Legion Square',
				gender: 'Masculino',
				birthDate: '1998-07-20',
				bank: 'R$ 750.000',
				coords: { x: 147, y: -1035, z: 29 },
				heading: 180
			},
			server: {
				sub: 'ROLEPLAY AVANÇADO',
				onlinePlayers: 32,
				maxPlayers: 128,
				ping: 18,
				gameTime: '15:45',
				uptime: '3h 10m',
				discord: 'discord.gg/coerp',
				website: 'https://coerp.com.br'
			},
			quickBinds: [
				{ key: 'N', desc: 'Falar' },
				{ key: 'M', desc: 'Mapa' }
			],
			rules: [
				{
					title: 'Geral',
					items: ['Sem VDM', 'Sem RDM']
				}
			]
		}
	});

	assert.ok(!$('#pause-container').hidden, 'container visível após open');
	assert.equal($('#char-name').textContent, 'Marcus Holloway');
	assert.equal($('#char-state-id').textContent, 'COE9988');
	assert.equal($('#char-job').textContent, 'Especialista Cyber');
	assert.equal($('#char-location').textContent, 'Legion Square');
	assert.equal($('#char-bank').textContent, 'R$ 750.000');
	assert.equal($('#player-count').textContent, '32 / 128');
	assert.equal($('#player-ping').textContent, '18 ms');
	assert.equal($('#rp-clock').textContent, '15:45');
	assert.equal($('#server-uptime').textContent, '3h 10m');
	assert.equal($('#map-street-tag').textContent, 'Legion Square');
});

test('navegação entre abas personalizadas (Dashboard, Mapa, Configurações, Regras)', () => {
	const { send, $ } = setup();
	send({ action: 'open', data: {} });

	// Inicia no dashboard
	assert.ok($('#view-dashboard').classList.contains('active'));
	assert.ok(!$('#view-map').classList.contains('active'));

	// Alterna para o Mapa Interativo
	$('.nav-tab[data-view="map"]').click();
	assert.ok(!$('#view-dashboard').classList.contains('active'));
	assert.ok($('#view-map').classList.contains('active'));

	// Alterna para Configurações
	$('.nav-tab[data-view="settings"]').click();
	assert.ok($('#view-settings').classList.contains('active'));

	// Alterna para Regras
	$('.nav-tab[data-view="rules"]').click();
	assert.ok($('#view-rules').classList.contains('active'));

	// Botão voltar retorna ao Dashboard
	$('#view-rules .back-btn').click();
	assert.ok($('#view-dashboard').classList.contains('active'));
});

test('mapa interativo: marcar e limpar waypoint sem abrir menu nativo', () => {
	const { send, $, lastPost } = setup();
	send({ action: 'open', data: {} });

	// Abre o mapa
	$('[data-view-btn="map"]').click();
	assert.ok($('#view-map').classList.contains('active'));

	// Clica em um blip POI (Hospital Central)
	const hospitalBlip = $('.map-blip[data-wp-x="298"]');
	hospitalBlip.click();
	assert.equal(lastPost().endpoint, 'setWaypoint');
	assert.equal(lastPost().body.x, 298);
	assert.equal(lastPost().body.y, -584);
	assert.equal($('#waypoint-map-marker').style.display, 'flex');

	// Clica para limpar waypoint
	$('#btn-clear-waypoint').click();
	assert.equal(lastPost().endpoint, 'clearWaypoint');
	assert.equal($('#waypoint-map-marker').style.display, 'none');
});

test('configurações personalizadas acionam callbacks corretos', () => {
	const { send, $, lastPost } = setup();
	send({ action: 'open', data: {} });

	// Vai para configurações
	$('[data-view-btn="settings"]').click();
	assert.ok($('#view-settings').classList.contains('active'));

	// Abrir editor de HUD fecha pause menu e posta openHud
	$('#btn-open-hud-editor').click();
	assert.ok($('#pause-container').hidden);
	assert.equal(lastPost().endpoint, 'openHud');

	// Reabre e testa alternar minimapa
	send({ action: 'open', data: {} });
	$('[data-view-btn="settings"]').click();
	$('#btn-toggle-minimap-mode').click();
	assert.equal(lastPost().endpoint, 'toggleMinimap');
});

test('tecla ESC volta para o dashboard ou fecha o menu', () => {
	const { send, $, key, lastPost } = setup();
	send({ action: 'open', data: {} });

	// Quando em sub-view (Mapa), ESC volta ao dashboard primeiro
	$('[data-view-btn="map"]').click();
	assert.ok($('#view-map').classList.contains('active'));
	key('Escape');
	assert.ok($('#view-dashboard').classList.contains('active'));
	assert.ok(!$('#pause-container').hidden, 'menu continua aberto');

	// Quando no dashboard, ESC fecha o menu
	key('Escape');
	assert.ok($('#pause-container').hidden);
	assert.equal(lastPost().endpoint, 'close');
});

test('confirmação de desconexão e ação de saída', () => {
	const { send, $, key, lastPost } = setup();
	send({ action: 'open', data: {} });
	assert.ok($('#disconnect-dialog').hidden);

	$('[data-act="disconnect"]').click();
	assert.ok(!$('#disconnect-dialog').hidden, 'diálogo de desconexão aberto');

	// Pressionar ESC fecha o diálogo primeiro sem fechar o menu todo
	key('Escape');
	assert.ok($('#disconnect-dialog').hidden, 'diálogo fechado pelo ESC');
	assert.ok(!$('#pause-container').hidden, 'menu continua aberto');

	// Abre novamente e confirma
	$('[data-act="disconnect"]').click();
	assert.ok(!$('#disconnect-dialog').hidden);
	$('#btn-confirm-dc').click();
	assert.ok($('#pause-container').hidden);
	assert.equal(lastPost().endpoint, 'disconnect');
});

test('mapa com imagem original: filtros de POI, zoom e telemetria de waypoint', () => {
	const { send, $, $$ } = setup();
	send({
		action: 'open',
		data: {
			character: {
				coords: { x: 147, y: -1035, z: 29 },
				heading: 90
			}
		}
	});

	// Vai para a tela do mapa
	$('[data-view-btn="map"]').click();

	// Verifica se a imagem original do mapa está presente
	const mapRaster = $('#map-raster');
	assert.ok(mapRaster, 'tag img do mapa original encontrada');
	assert.ok(mapRaster.getAttribute('src').includes('map.webp'), 'imagem map.webp configurada');

	// Filtros de POI: clicar em emergência deve esconder outras categorias
	const emergencyChip = $('[data-poi-filter="emergency"]');
	assert.ok(emergencyChip, 'chip de filtro de emergência existe');
	emergencyChip.click();

	const hospital = $('.map-blip.emergency');
	const mechanic = $('.map-blip.mechanic');
	assert.ok(!hospital.classList.contains('is-hidden'), 'hospital visível no filtro emergência');
	assert.ok(mechanic.classList.contains('is-hidden'), 'mecânica oculta no filtro emergência');

	// Voltar para "Todos" restaura visibilidade
	$('[data-poi-filter="all"]').click();
	assert.ok(!mechanic.classList.contains('is-hidden'), 'mecânica visível no filtro Todos');

	// Controles de Zoom e Centralizar
	$('#map-zoom-in').click();
	$('#map-zoom-out').click();
	$('#map-zoom-reset').click();
	$('#btn-center-player').click();

	// Clicar em um blip ativa o banner de rota com cálculo de distância
	hospital.click();
	assert.equal($('#active-waypoint-hud').style.display, 'flex', 'banner de destino ativo exibido');
	assert.ok($('#wp-hud-dist').textContent.includes('Distância:'), 'distância calculada no banner');

	// Cancelar pelo banner remove o waypoint
	$('#btn-cancel-route').click();
	assert.equal($('#active-waypoint-hud').style.display, 'none');
	assert.equal($('#waypoint-map-marker').style.display, 'none');
});

test('configurações completas: sub-abas, remapeamento de teclas interativo e persistência', async () => {
	const { send, $, $$, key, lastPost } = setup();
	send({ action: 'open', data: {} });

	// Vai para as configurações
	$('[data-view-btn="settings"]').click();
	assert.ok($('#view-settings').classList.contains('active'));

	// 1. Alternância entre sub-abas das configurações
	const audioTabBtn = $('[data-set-tab="audio"]');
	assert.ok(audioTabBtn, 'aba de áudio encontrada');
	audioTabBtn.click();
	assert.ok($('#set-tab-audio').classList.contains('active'), 'painel de áudio ativo');
	assert.ok(!$('#set-tab-controls').classList.contains('active'), 'painel de controles inativo');

	const displayTabBtn = $('[data-set-tab="display"]');
	displayTabBtn.click();
	assert.ok($('#set-tab-display').classList.contains('active'), 'painel de tela ativo');

	const hudTabBtn = $('[data-set-tab="hud"]');
	hudTabBtn.click();
	assert.ok($('#set-tab-hud').classList.contains('active'), 'painel de hud ativo');

	const cameraTabBtn = $('[data-set-tab="camera"]');
	cameraTabBtn.click();
	assert.ok($('#set-tab-camera').classList.contains('active'), 'painel de câmera ativo');

	// Volta para a aba de controles/teclado
	$('[data-set-tab="controls"]').click();
	assert.ok($('#set-tab-controls').classList.contains('active'));

	// 2. Remapeamento Interativo de Teclas
	const voiceBtn = $('.keybind-btn[data-bind-id="voice_ptt"]');
	assert.ok(voiceBtn, 'botão de rebind de PTT encontrado');
	assert.equal(voiceBtn.textContent.trim(), 'N');

	// Clica para remapear -> entra em modo de escuta
	voiceBtn.click();
	assert.ok(voiceBtn.classList.contains('listening'));
	assert.equal(voiceBtn.textContent.trim(), 'Pressione...');

	// Pressiona tecla 'X'
	key('x');
	assert.ok(!voiceBtn.classList.contains('listening'), 'saiu do modo listening');
	assert.equal(voiceBtn.textContent.trim(), 'X', 'tecla atualizada para X');
	assert.equal(lastPost().endpoint, 'updateKeybind');
	assert.equal(lastPost().body.id, 'voice_ptt');
	assert.equal(lastPost().body.key, 'X');

	// 3. Restaurar Teclas Padrão
	$('#btn-reset-keybinds').click();
	assert.equal(voiceBtn.textContent.trim(), 'N', 'tecla voltou ao padrão N');

	// 4. Sliders e auto-save
	audioTabBtn.click();
	const voiceVolSlider = $('#cfg-voice-vol');
	voiceVolSlider.value = 95;
	voiceVolSlider.dispatchEvent(new voiceVolSlider.ownerDocument.defaultView.Event('input', { bubbles: true }));
	assert.equal($('#val-voice-vol').textContent, '95%');

	// Aguarda debounce de auto-save
	await new Promise((resolve) => setTimeout(resolve, 350));
	assert.equal(lastPost().endpoint, 'saveSettings');
	assert.equal(lastPost().body.voiceVol, '95');

	// 5. Botão de restaurar todos os padrões
	$('#btn-reset-all-settings').click();
	assert.equal(lastPost().endpoint, 'resetSettings');
	assert.equal($('#cfg-voice-vol').value, '85');
});
