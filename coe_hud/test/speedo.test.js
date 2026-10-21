const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { JSDOM } = require('jsdom');

const source = fs.readFileSync(path.join(__dirname, '..', 'html', 'speedo.js'), 'utf8');
const STYLES = ['modern', 'modernpro', 'bold', 'retro', 'minimal', 'analog'];

function setup() {
	const dom = new JSDOM('<div id="host"></div>', { runScripts: 'outside-only' });
	dom.window.eval(source);
	const host = dom.window.document.getElementById('host');
	return { dom, host, speedo: dom.window.CoeSpeedo.create(host) };
}

const car = { vehicle: true, kind: 'car', speed: 30, rpm: 50, gear: 2, fuel: 60, engine: 90, lights: 0, left: false, right: false, belt: true };
const text = (host, key) => host.querySelector(`[data-text="${key}"]`);

test('estilo desconhecido não monta nada', () => {
	const { host, speedo } = setup();
	assert.equal(speedo.mount('panel', 'kmh'), false);
	assert.equal(host.children.length, 0);
});

for (const style of STYLES) {
	test(`${style}: monta, mostra velocidade e marcha e ignora estado vazio`, () => {
		const { host, speedo } = setup();
		assert.equal(speedo.mount(style, 'kmh'), true);
		speedo.update(null);
		speedo.update(car);
		const speedText = text(host, 'speed');
		if (style === 'analog') {
			assert.equal(speedText, null);
		} else {
			assert.equal(speedText.textContent, '30');
		}
		const gear = host.querySelector('[data-text="gear"]');
		if (gear) {
			assert.equal(gear.textContent, '2');
		}
		// A faixa de indicadores é um componente próprio (createIndicators).
		assert.equal(host.querySelector('.sp-flags'), null);
	});
}

test('bold e retro completam a velocidade com zeros à esquerda', () => {
	for (const style of ['bold', 'retro']) {
		const { host, speedo } = setup();
		speedo.mount(style, 'kmh');
		speedo.update({ ...car, speed: 7 });
		assert.equal(text(host, 'zeros').textContent, '00');
		assert.equal(text(host, 'speed').textContent, '7');
		speedo.update({ ...car, speed: 130 });
		assert.equal(text(host, 'zeros').textContent, '');
	}
});

test('arco de velocidade usa o máximo da unidade', () => {
	const { host, speedo } = setup();
	speedo.mount('modern', 'mph');
	speedo.update({ ...car, speed: 80 });
	assert.equal(host.querySelector('[data-arc="speed"]').style.strokeDasharray, '50 100');
	assert.equal(text(host, 'unit').textContent, 'MPH');
	speedo.mount('modern', 'kmh');
	speedo.update({ ...car, speed: 120 });
	assert.equal(host.querySelector('[data-arc="speed"]').style.strokeDasharray, '50 100');
	assert.equal(text(host, 'unit').textContent, 'KM/H');
});

test('agulhas giram entre os ângulos e limitam o valor', () => {
	const { host, speedo } = setup();
	speedo.mount('analog', 'kmh');
	speedo.update({ ...car, speed: 0, rpm: 0 });
	assert.equal(host.querySelector('[data-needle="speed"]').style.transform, 'rotate(-135deg)');
	speedo.update({ ...car, speed: 999, rpm: 100 });
	assert.equal(host.querySelector('[data-needle="speed"]').style.transform, 'rotate(135deg)');
	assert.equal(host.querySelector('[data-needle="rpm"]').style.transform, 'rotate(135deg)');
});

test('rótulos do mostrador seguem a unidade', () => {
	const { host, speedo } = setup();
	speedo.mount('analog', 'mph');
	const labels = Array.from(host.querySelectorAll('.sp-label')).map((el) => el.textContent);
	assert.ok(labels.includes('160'));
	assert.ok(!labels.includes('240'));
});

test('montar outro estilo preserva as classes do layout no host', () => {
	const { host, speedo } = setup();
	host.classList.add('hud-free');
	speedo.mount('bold', 'kmh');
	speedo.mount('retro', 'kmh');
	assert.ok(host.classList.contains('hud-free'));
	assert.ok(host.classList.contains('sp-s-retro'));
	assert.ok(!host.classList.contains('sp-s-bold'));
	speedo.mount('panel', 'kmh');
	assert.ok(!host.classList.contains('sp-s-retro'));
	assert.ok(host.classList.contains('hud-free'));
});

test('indicadores: setas, cinto, farol, combustível e motor', () => {
	const { dom, host } = setup();
	const speedo = dom.window.CoeSpeedo.createIndicators(host);
	assert.ok(host.querySelector('.sp-flags'));
	const flag = (name) => host.querySelector(`[data-flag="${name}"]`);
	speedo.update({ ...car, left: true, belt: false, speed: 50, lights: 2, fuel: 10, engine: 20 });
	assert.ok(flag('left').classList.contains('on'));
	assert.ok(!flag('right').classList.contains('on'));
	assert.ok(flag('belt').classList.contains('warn'));
	assert.ok(flag('lights').classList.contains('on'));
	assert.equal(flag('lights').textContent, 'ALTO');
	assert.ok(flag('fuel').classList.contains('warn'));
	assert.ok(flag('engine').classList.contains('warn'));
	speedo.update({ ...car, speed: 10, belt: false });
	assert.ok(!flag('belt').classList.contains('warn'));
	assert.ok(!flag('fuel').classList.contains('warn'));
});

test('barco e aeronave não mostram marcha; ré e ponto morto', () => {
	const { host, speedo } = setup();
	speedo.mount('retro', 'kmh');
	const gear = host.querySelector('[data-gear]');
	speedo.update({ ...car, kind: 'air' });
	assert.equal(gear.style.display, 'none');
	speedo.update({ ...car, kind: 'car', gear: 0, speed: 5 });
	assert.equal(gear.style.display, '');
	assert.equal(gear.textContent, 'R');
	speedo.update({ ...car, gear: 0, speed: 0 });
	assert.equal(gear.textContent, 'N');
});

test('segmentos de rotação acendem proporcionalmente', () => {
	const { host, speedo } = setup();
	speedo.mount('retro', 'kmh');
	speedo.update({ ...car, rpm: 50 });
	const segs = host.querySelector('[data-segs="rpm"]');
	assert.equal(segs.querySelectorAll('i.on').length, segs.children.length / 2);
	speedo.update({ ...car, rpm: 100 });
	assert.ok(segs.querySelectorAll('i.hot.on').length > 0);
});
