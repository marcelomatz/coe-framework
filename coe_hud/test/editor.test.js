const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { JSDOM } = require('jsdom');

const html = path.join(__dirname, '..', 'html');
const read = (name) => fs.readFileSync(path.join(html, name), 'utf8');
const Editor = require('../html/editor.js');

const W = 1000;
const H = 800;
const BASE = { l: 0.025, r: 0.1656, t: 0.7988, b: 0.975, safezone: 0.95 };

function defaults() {
	const layout = {};
	Editor.IDS.forEach((id) => { layout[id] = { size: 100 }; });
	return {
		accent: 'theme', style: 'glass', icons: 'round', position: 'left', unit: 'kmh', tint: 'status', speedo: 'panel', scale: 100,
		showHealth: true, showVehicle: true, showNeeds: true, showLocation: true, showRoute: true, showPercent: false,
		showMinimap: true, showIndicators: true, showLogo: true,
		layout,
		editor: { grid: true, safezone: false, anchors: true, hidden: true }
	};
}

// Geometria falsa: o jsdom não faz layout. Padrão em posições fixas; livre em --fx/--fy.
const DEFAULT_RECTS = {
	'hud-health': { left: 200, top: 700, width: 100, height: 50 },
	'hud-location': { left: 25, top: 600, width: 140, height: 40 },
	'hud-vehicle': { left: 800, top: 650, width: 180, height: 120 },
	'hud-speedo': { left: 400, top: 620, width: 200, height: 150 },
	'hud-indicators': { left: 420, top: 580, width: 160, height: 30 },
	'hud-logo': { left: 800, top: 30, width: 120, height: 32 }
};

function fakeRect(el, view) {
	const size = Number(el.style.getPropertyValue('--c-size') || 1);
	const base = DEFAULT_RECTS[el.id];
	const rect = { left: base.left, top: base.top, width: base.width * size, height: base.height * size };
	if (el.classList.contains('hud-free')) {
		rect.left = parseFloat(el.style.getPropertyValue('--fx')) / 100 * view.w;
		rect.top = parseFloat(el.style.getPropertyValue('--fy')) / 100 * view.h;
	}
	return rect;
}

function setup(start, view = { w: W, h: H }) {
	const dom = new JSDOM(read('index.html'), { runScripts: 'outside-only', pretendToBeVisual: true });
	const { window } = dom;
	Object.defineProperty(window, 'innerWidth', { value: view.w });
	Object.defineProperty(window, 'innerHeight', { value: view.h });
	const posts = [];
	window.GetParentResourceName = () => 'coe_hud';
	window.fetch = (url, init) => {
		posts.push({ name: url.split('/').pop(), data: JSON.parse(init.body) });
		return Promise.resolve({ json: () => ({}) });
	};
	window.HTMLElement.prototype.getBoundingClientRect = function () {
		return DEFAULT_RECTS[this.id] ? fakeRect(this, view) : { left: 0, top: 0, width: 0, height: 0 };
	};
	window.eval(read('speedo.js'));
	window.eval(read('editor.js'));
	window.eval(read('app.js'));
	const doc = window.document;
	const send = (data) => window.dispatchEvent(new window.MessageEvent('message', { data }));
	const prefs = start || defaults();
	send({ action: 'prefs', prefs });
	send({ action: 'minimap', anchor: { l: BASE.l, r: BASE.r, t: BASE.t, b: BASE.b }, base: BASE, extended: false });
	send({ action: 'state', state: { health: 90, armor: 0, vehicle: false, dir: 'N', street: 'A', zone: 'B', clock: '10:00' } });
	const open = () => send({ action: 'editor', open: true, prefs, defaults: defaults(), options: { accent: ['theme', 'cyan'], aspect: ['full', '16:9', '21:9'], minimapMode: ['always', 'vehicle'], locationMode: ['always', 'vehicle'] } });
	const $ = (sel) => doc.querySelector(sel);
	const box = (id) => $(`.ed-box[data-id="${id}"]`);
	const mouse = (target, type, x, y, extra) => target.dispatchEvent(new window.MouseEvent(type, Object.assign({ bubbles: true, cancelable: true, clientX: x, clientY: y, button: 0 }, extra)));
	const drag = (target, from, to) => {
		mouse(target, 'mousedown', from[0], from[1]);
		mouse(doc, 'mousemove', (from[0] + to[0]) / 2, (from[1] + to[1]) / 2);
		mouse(doc, 'mousemove', to[0], to[1]);
		mouse(doc, 'mouseup', to[0], to[1]);
	};
	const key = (k, extra) => doc.dispatchEvent(new window.KeyboardEvent('keydown', Object.assign({ key: k, bubbles: true }, extra)));
	const last = (name) => posts.filter((p) => p.name === name).pop();
	return { window, doc, send, open, $, box, mouse, drag, key, posts, last };
}

test('histórico: desfazer, refazer, ramificação e limite', () => {
	const history = Editor.createHistory({ v: 0 }, 3);
	assert.equal(history.canUndo(), false);
	assert.equal(history.undo(), null);
	history.push({ v: 1 });
	history.push({ v: 2 });
	assert.deepEqual(history.undo(), { v: 1 });
	assert.deepEqual(history.redo(), { v: 2 });
	assert.equal(history.redo(), null);
	history.undo();
	history.push({ v: 9 });
	assert.equal(history.canRedo(), false, 'nova alteração descarta o refazer');
	history.push({ v: 10 });
	history.push({ v: 11 });
	assert.deepEqual(history.undo(), { v: 10 });
	assert.deepEqual(history.undo(), { v: 9 });
	assert.equal(history.undo(), null, 'limite de estados');
});

test('minimapRect: mesma matemática do minimap.lua', () => {
	assert.deepEqual(Editor.minimapRect(BASE, null), { l: 0.025, t: 0.7988, r: 0.1656, b: 0.975 });
	assert.deepEqual(Editor.minimapRect(BASE, { size: 200 }), { l: 0.025, t: 0.6226, r: 0.3062, b: 0.975 });
	const moved = Editor.minimapRect(BASE, { x: 0.95, y: 0.95, size: 100 });
	assert.ok(moved.r <= 1 && moved.b <= 1);
	assert.equal(Editor.minimapRect(null, null), null);
});

test('sobreposição e grade', () => {
	const a = { left: 0, top: 0, width: 10, height: 10 };
	assert.equal(Editor.overlap(a, { left: 5, top: 0, width: 10, height: 10 }), 0.5);
	assert.equal(Editor.overlap(a, { left: 20, top: 0, width: 10, height: 10 }), 0);
	assert.equal(Editor.snap(29, 20), 20);
	assert.equal(Editor.snap(31, 20), 40);
});

test('/hud abre o editor com caixas, barra e componentes de exemplo', () => {
	const { doc, open, $, box } = setup();
	assert.ok($('#hud-editor').hidden);
	open();
	assert.ok(!$('#hud-editor').hidden);
	assert.ok(doc.body.classList.contains('editing'));
	Editor.IDS.forEach((id) => assert.ok(box(id), id));
	assert.ok(!$('#hud-vehicle').hidden, 'velocímetro aparece a pé para ser posicionado');
	assert.ok(!$('#hud-indicators').hidden, 'indicadores aparecem a pé');
	assert.equal(box('status').style.left, '200px');
	assert.ok(!box('minimap').hidden);
	assert.equal(box('minimap').style.left, '25px');
	assert.ok($('[data-act="undo"]').disabled);
});

test('olho oculta e mostra; ocultos aparecem como fantasma conforme a opção', () => {
	const { open, $, box, last } = setup();
	open();
	box('status').querySelector('.ed-eye').click();
	assert.equal(last('hudPreview').data.showHealth, false);
	assert.ok(!$('#hud-health').hidden, 'fantasma visível no editor');
	assert.ok($('#hud-health').classList.contains('ed-ghost'));
	assert.ok(box('status').classList.contains('off'));
	const hiddenOpt = $('[data-opt="hidden"]');
	hiddenOpt.checked = false;
	hiddenOpt.dispatchEvent(new hiddenOpt.ownerDocument.defaultView.Event('change'));
	assert.ok($('#hud-health').hidden, 'sem "Ocultos" o componente some');
	assert.ok(box('status').hidden);
	box('location').querySelector('.ed-eye').click();
	assert.equal(last('hudPreview').data.showLocation, false);
});

test('arrastar grava coordenadas relativas na grade e volta a ancorar na zona padrão', () => {
	const { open, $, box, drag, last } = setup();
	open();
	drag(box('status'), [210, 710], [517, 405]);
	const entry = last('hudPreview').data.layout.status;
	// 200 + 307 = 507 -> grade 20 -> 500; 700 - 305 = 395 -> 400
	assert.equal(entry.x, 0.5);
	assert.equal(entry.y, 0.5);
	assert.ok($('#hud-health').classList.contains('hud-free'));
	assert.equal($('#hud-health').style.getPropertyValue('--fx'), '50vw');
	assert.equal(box('status').style.left, '500px');
	assert.ok(box('status').classList.contains('free'));
	drag(box('status'), [510, 410], [215, 705]);
	const back = last('hudPreview').data.layout.status;
	assert.equal(back.x, undefined, 'soltar sobre a zona de âncora volta ao padrão');
	assert.ok(!$('#hud-health').classList.contains('hud-free'));
});

test('arrastar respeita os limites da tela', () => {
	const { open, box, drag, last } = setup();
	open();
	drag(box('status'), [210, 710], [5000, 5000]);
	const entry = last('hudPreview').data.layout.status;
	assert.ok(entry.x <= 1 - 100 / W);
	assert.ok(entry.y <= 1 - 50 / H);
});

test('redimensionar pela alça muda o tamanho em passos de 5%', () => {
	const { open, $, box, drag, last } = setup();
	open();
	drag(box('status').querySelector('.ed-resize'), [300, 750], [351, 760]);
	const entry = last('hudPreview').data.layout.status;
	assert.equal(entry.size, 150);
	assert.equal(entry.x, undefined, 'redimensionar mantém a âncora');
	assert.equal($('#hud-health').style.getPropertyValue('--c-size'), '1.5');
	drag(box('status').querySelector('.ed-resize'), [300, 750], [-500, 750]);
	assert.equal(last('hudPreview').data.layout.status.size, 50, 'tamanho mínimo');
});

test('desfazer e refazer por botões e atalhos', () => {
	const { open, $, box, drag, key, last } = setup();
	open();
	drag(box('status'), [210, 710], [517, 405]);
	box('location').querySelector('.ed-eye').click();
	assert.ok(!$('[data-act="undo"]').disabled);
	$('[data-act="undo"]').click();
	assert.equal(last('hudPreview').data.showLocation, true);
	assert.equal(last('hudPreview').data.layout.status.x, 0.5);
	key('z', { ctrlKey: true });
	assert.equal(last('hudPreview').data.layout.status.x, undefined);
	assert.ok($('[data-act="undo"]').disabled);
	key('y', { ctrlKey: true });
	assert.equal(last('hudPreview').data.layout.status.x, 0.5);
	$('[data-act="redo"]').click();
	assert.equal(last('hudPreview').data.showLocation, false);
	assert.ok($('[data-act="redo"]').disabled);
});

test('opções do editor ficam fora do desfazer e vão junto ao concluir', () => {
	const { open, $, box, drag, last } = setup();
	open();
	drag(box('status'), [210, 710], [517, 405]);
	const grid = $('[data-opt="grid"]');
	grid.checked = false;
	grid.dispatchEvent(new grid.ownerDocument.defaultView.Event('change'));
	$('[data-act="undo"]').click();
	assert.equal(last('hudPreview').data.editor.grid, false);
	$('[data-act="done"]').click();
	assert.equal(last('hudDone').data.editor.grid, false);
});

test('Restaurar padrão volta layout e visibilidade, mantendo a cor', () => {
	const start = defaults();
	start.accent = 'cyan';
	start.showIndicators = false;
	start.layout.speedo = { x: 0.1, y: 0.1, size: 160 };
	const { open, $, last } = setup(start);
	assert.ok($('#hud-vehicle').classList.contains('hud-free'));
	open();
	$('[data-act="reset"]').click();
	const data = last('hudPreview').data;
	assert.equal(data.accent, 'cyan');
	assert.equal(data.showIndicators, true);
	assert.deepEqual(data.layout.speedo, { size: 100 });
	assert.ok(!$('#hud-vehicle').classList.contains('hud-free'));
	$('[data-act="undo"]').click();
	assert.equal(last('hudPreview').data.layout.speedo.x, 0.1, 'restaurar pode ser desfeito');
});

test('Concluir envia o rascunho e fecha; Descartar volta ao salvo', () => {
	const { doc, open, $, box, drag, last } = setup();
	open();
	drag(box('speedo'), [810, 660], [100, 100]);
	$('[data-act="done"]').click();
	assert.ok(last('hudDone').data.layout.speedo.x > 0);
	assert.ok($('#hud-editor').hidden);
	assert.ok(!doc.body.classList.contains('editing'));
	assert.ok($('#hud-vehicle').classList.contains('hud-free'), 'layout concluído continua aplicado');

	const other = setup();
	other.open();
	other.drag(other.box('speedo'), [810, 660], [100, 100]);
	other.$('[data-act="discard"]').click();
	assert.ok(other.last('hudDiscard'));
	assert.ok(!other.$('#hud-vehicle').classList.contains('hud-free'));
	assert.ok(other.$('#hud-editor').hidden);
});

test('minimapa movido leva junto os componentes ancorados', () => {
	const { window, open, box, drag, last } = setup();
	open();
	const root = window.document.documentElement;
	assert.equal(root.style.getPropertyValue('--mm-left'), '2.5vw');
	// caixa do minimapa: 25..165 x 639..780 px
	drag(box('minimap'), [60, 700], [460, 300]);
	const entry = last('hudPreview').data.layout.minimap;
	assert.equal(entry.x, 0.42);
	assert.equal(entry.y, 0.3);
	assert.equal(root.style.getPropertyValue('--mm-left'), '42vw', 'localização ancorada segue o minimapa');
	assert.equal(root.style.getPropertyValue('--mm-bottom'), `${Math.round((1 - (0.3 + 0.1762)) * 1000) / 10}vh`);
	assert.equal(box('minimap').style.left, '420px');
	drag(box('minimap').querySelector('.ed-resize'), [560, 440], [700, 440]);
	assert.equal(last('hudPreview').data.layout.minimap.size, 200);
	assert.equal(root.style.getPropertyValue('--mm-w'), '28.1vw', 'largura da âncora acompanha o tamanho');
});

test('opções mostram grade, zona segura e zonas de âncora', () => {
	const { open, $ } = setup();
	open();
	const editorRoot = $('#hud-editor');
	assert.ok(editorRoot.classList.contains('show-grid'));
	assert.ok(editorRoot.classList.contains('show-anchors'));
	assert.ok(!editorRoot.classList.contains('show-safe'));
	assert.equal($('.ed-zone[data-id="status"]').style.left, '200px');
	assert.equal($('.ed-safe').style.top, '2.5%', 'zona segura pela safezone do jogo');
	const safe = $('[data-opt="safezone"]');
	safe.checked = true;
	safe.dispatchEvent(new safe.ownerDocument.defaultView.Event('change'));
	assert.ok(editorRoot.classList.contains('show-safe'));
	const anchors = $('[data-opt="anchors"]');
	anchors.checked = false;
	anchors.dispatchEvent(new anchors.ownerDocument.defaultView.Event('change'));
	assert.ok($('.ed-zone[data-id="status"]').hidden);
});

test('preferências dentro do editor vão para o rascunho; Esc fecha preferências e depois descarta', () => {
	const { open, $, key, posts, last } = setup();
	open();
	$('[data-act="settings"]').click();
	assert.ok(!$('#settings').hidden);
	$('#settings [data-value="cyan"]').click();
	assert.equal(last('hudPreview').data.accent, 'cyan');
	assert.equal(posts.filter((p) => p.name === 'hudSave').length, 0, 'nada salvo antes de concluir');
	key('Escape');
	assert.ok($('#settings').hidden);
	assert.ok(!$('#hud-editor').hidden, 'primeiro Esc só fecha as preferências');
	key('Escape');
	assert.ok(last('hudDiscard'));
	assert.ok($('#hud-editor').hidden);
});

test('eco de preferências do client não sobrescreve o rascunho; /hud de novo fecha sem postar', () => {
	const { send, open, $, box, drag, posts } = setup();
	open();
	drag(box('status'), [210, 710], [517, 405]);
	send({ action: 'prefs', prefs: defaults() });
	assert.ok($('#hud-health').classList.contains('hud-free'));
	const before = posts.length;
	send({ action: 'editor', open: false });
	assert.ok($('#hud-editor').hidden);
	assert.equal(posts.length, before);
	assert.ok(!$('#hud-health').classList.contains('hud-free'), 'volta ao salvo');
});

test('indicadores ancorados ficam acima do velocímetro e podem ser soltos', () => {
	const { window, send, $, open, box, drag, last } = setup();
	send({ action: 'state', state: { health: 90, armor: 0, vehicle: true, kind: 'car', speed: 40, rpm: 30, gear: 2, fuel: 50, engine: 80, lights: 0, left: true, right: false, belt: true } });
	const host = $('#hud-indicators');
	assert.ok(!host.hidden);
	assert.ok(host.querySelector('[data-flag="left"]').classList.contains('on'));
	assert.equal(host.style.getPropertyValue('--dock-x'), '890px', 'centro do painel');
	assert.equal(host.style.getPropertyValue('--dock-y'), '644px', 'logo acima do painel');
	open();
	drag(box('indicators'), [430, 590], [100, 100]);
	assert.ok(last('hudPreview').data.layout.indicators.x >= 0);
	assert.ok(host.classList.contains('hud-free'));
	assert.ok(window.document.querySelector('#hud-vehicle .sp-flags') === null);
});

test('área útil: mesma matemática do minimap.lua', () => {
	assert.deepEqual(Editor.areaFor('16:9', 21 / 9), { l: 0.1191, w: 0.7619 });
	assert.deepEqual(Editor.areaFor('21:9', 16 / 9), { l: 0, w: 1 });
	assert.deepEqual(Editor.areaFor('full', 32 / 9), { l: 0, w: 1 });
	const shifted = Editor.shiftBase(BASE, Editor.areaFor('16:9', 21 / 9));
	assert.equal(shifted.l, 0.1441);
	assert.equal(Editor.minimapRect(shifted, { x: 0.5, y: 0.2 }, Editor.areaFor('16:9', 21 / 9)).l, 0.5001);
});

test('escala automática: 4K dobra o HUD, desligada mantém o Tamanho', () => {
	const start = defaults();
	start.autoScale = true;
	const { doc } = setup(start, { w: 3840, h: 2160 });
	assert.equal(doc.body.style.getPropertyValue('--hud-scale'), '2');
	const off = defaults();
	off.autoScale = false;
	off.scale = 120;
	assert.equal(setup(off, { w: 3840, h: 2160 }).doc.body.style.getPropertyValue('--hud-scale'), '1.2');
	const qhd = defaults();
	qhd.autoScale = true;
	assert.equal(setup(qhd, { w: 2560, h: 1440 }).doc.body.style.getPropertyValue('--hud-scale'), '1.33');
});

test('ultrawide 16:9: âncora, posição livre e arraste ficam dentro da área', () => {
	const start = defaults();
	start.aspect = '16:9';
	start.layout.status = { x: 0, y: 0.5, size: 100 };
	const view = { w: 2520, h: 1080 };
	const { window, open, $, box, drag, last } = setup(start, view);
	const root = window.document.documentElement;
	assert.equal(root.style.getPropertyValue('--area-l'), '11.91vw');
	assert.equal($('#hud-health').style.getPropertyValue('--fx'), '11.91vw', 'x = 0 é a borda da área');
	open();
	assert.equal(root.style.getPropertyValue('--mm-left'), '14.4vw', 'minimapa padrão entra na área');
	assert.ok(!$('.ed-area').hidden, 'moldura da área no editor');
	assert.equal($('.ed-area').style.left, '11.91%');
	drag(box('status'), [310, 550], [0, 550]);
	assert.equal(last('hudPreview').data.layout.status.x, 0, 'arraste não sai da área pela esquerda');
	drag(box('status'), [310, 550], [5000, 550]);
	const entry = last('hudPreview').data.layout.status;
	assert.ok(entry.x <= 1 - 100 / (0.7619 * view.w), 'nem pela direita');
	$('[data-act="settings"]').click();
	assert.ok($('#settings [data-key="aspect"] [data-value="21:9"]'));
});

test('tela inteira esconde a moldura da área', () => {
	const { open, $ } = setup();
	open();
	assert.ok($('.ed-area').hidden);
});

test('minimapa só em veículo: moldura some a pé, volta no veículo e aparece no editor', () => {
	const start = defaults();
	start.minimapMode = 'vehicle';
	start.locationMode = 'vehicle';
	const { send, open, $, last } = setup(start);
	send({ action: 'state', state: { health: 90, armor: 0, vehicle: false, inVehicle: false } });
	assert.ok($('#hud-mapframe').hidden, 'a pé sem moldura');
	assert.ok($('#hud-location').hidden, 'a pé sem bússola (o client não manda a direção)');
	send({ action: 'state', state: { health: 90, armor: 0, vehicle: false, inVehicle: true, dir: 'N', street: 'A', zone: 'B', clock: '10:00' } });
	assert.ok(!$('#hud-mapframe').hidden, 'passageiro com moldura');
	assert.ok(!$('#hud-location').hidden, 'passageiro com bússola');
	send({ action: 'state', state: { health: 90, armor: 0, vehicle: false, inVehicle: false } });
	open();
	assert.ok(!$('#hud-mapframe').hidden, 'editor mostra a moldura a pé');
	$('[data-act="settings"]').click();
	$('#settings [data-key="minimapMode"] [data-value="always"]').click();
	assert.equal(last('hudPreview').data.minimapMode, 'always');
	assert.ok($('#settings [data-key="locationMode"] [data-value="vehicle"]').classList.contains('on'));
});

test('logotipo: visibilidade e arraste no editor', () => {
	const { open, box, drag, last } = setup();
	open();
	const logoBox = box('logo');
	assert.ok(logoBox, 'caixa do logo existe');
	logoBox.querySelector('.ed-eye').click();
	assert.equal(last('hudPreview').data.showLogo, false, 'olho oculta o logo');
	logoBox.querySelector('.ed-eye').click();
	assert.equal(last('hudPreview').data.showLogo, true, 'olho mostra o logo');
	drag(logoBox, [800, 30], [200, 100]);
	const entry = last('hudPreview').data.layout.logo;
	assert.equal(entry.x, 0.2, 'x arrastado');
	assert.equal(entry.y, 0.125, 'y arrastado');
});

test('preferências categorizadas em abas: alternância de abas', () => {
	const { open, $ } = setup();
	open();
	$('[data-act="settings"]').click();
	assert.ok(!$('#settings').hidden);

	// Inicialmente aba aparencia ativa
	assert.ok($('.set-tab[data-tab="appearance"]').classList.contains('on'));
	assert.ok($('.set-pane[data-pane="appearance"]').classList.contains('on'));
	assert.ok(!$('.set-pane[data-pane="vehicle"]').classList.contains('on'));

	// Clica na aba veículo
	$('.set-tab[data-tab="vehicle"]').click();
	assert.ok($('.set-tab[data-tab="vehicle"]').classList.contains('on'));
	assert.ok($('.set-pane[data-pane="vehicle"]').classList.contains('on'));
	assert.ok(!$('.set-pane[data-pane="appearance"]').classList.contains('on'));

	// Clica na aba radar
	$('.set-tab[data-tab="radar"]').click();
	assert.ok($('.set-tab[data-tab="radar"]').classList.contains('on'));
	assert.ok($('.set-pane[data-pane="radar"]').classList.contains('on'));

	// Clica na aba componentes
	$('.set-tab[data-tab="components"]').click();
	assert.ok($('.set-tab[data-tab="components"]').classList.contains('on'));
	assert.ok($('.set-pane[data-pane="components"]').classList.contains('on'));
});

test('arrastar barra superior e painel de preferências', () => {
	const { open, $, mouse } = setup();
	open();
	const bar = $('.ed-bar');
	assert.ok(bar);
	const dragHandle = $('.ed-drag-handle');
	assert.ok(dragHandle);

	// Arrastar barra
	mouse(dragHandle, 'mousedown', 500, 20);
	mouse(bar.ownerDocument, 'mousemove', 300, 100);
	mouse(bar.ownerDocument, 'mouseup', 300, 100);
	assert.ok(bar.style.left);
	assert.ok(bar.style.top);

	// Abrir preferências e arrastar painel
	$('[data-act="settings"]').click();
	const settings = $('#settings');
	assert.ok(!settings.hidden);
	const setGrip = $('.set-drag-bar');
	assert.ok(setGrip);

	mouse(setGrip, 'mousedown', 300, 150);
	mouse(settings.ownerDocument, 'mousemove', 100, 250);
	mouse(settings.ownerDocument, 'mouseup', 100, 250);
	assert.equal(settings.dataset.customPos, 'true');
	assert.ok(settings.style.left);
	assert.ok(settings.style.top);
});
