'use strict';

// Ajustes da tela -----------------------------------------------------------------------------------------
const CONFIG = {
	eyebrow: 'COE · LOS SANTOS',
	title: 'Bem-vindo a Los Santos',
	subtitle: 'Preparando a cidade para você. Isso leva só um instante.',
	tag: 'Enhanced Roleplay',
	// Fotos em html/backgrounds/ (ex.: capturas do servidor). Vazio: usa o pôr do sol desenhado aqui.
	backgrounds: [],
	backgroundSeconds: 9,
	activitySeconds: 2.4
};

// Ordem da folha de estilos: 1) tema padrão (data-coe-theme), 2) tema definido pelo usuário (data-coe-user-theme).
const VALID_THEMES = { moss: true, ocean: true, amber: true, rose: true, violet: true };
const VALID_USER_THEMES = { lime: true, moss: true, cyan: true, ocean: true, amber: true, rose: true, violet: true };

function applyDefaultTheme(name) {
	const root = document.documentElement;
	if (typeof name === 'string' && VALID_THEMES[name]) {
		root.setAttribute('data-coe-theme', name);
		try { localStorage.setItem('coe_ui:theme', name); } catch (_) {}
	}
}

function applyUserTheme(name) {
	const root = document.documentElement;
	if (typeof name === 'string' && VALID_USER_THEMES[name]) {
		root.setAttribute('data-coe-user-theme', name);
		try { localStorage.setItem('coe_ui:user_theme', name); } catch (_) {}
	} else {
		root.removeAttribute('data-coe-user-theme');
		try { localStorage.removeItem('coe_ui:user_theme'); } catch (_) {}
	}
}

function initThemes() {
	let defaultTheme = null;
	let userTheme = null;
	try {
		defaultTheme = localStorage.getItem('coe_ui:theme');
		userTheme = localStorage.getItem('coe_ui:user_theme');
	} catch (_) {}
	const handover = window.nuiHandoverData;
	if (handover && typeof handover === 'object') {
		if (typeof handover.theme === 'string') defaultTheme = handover.theme;
		if ('userTheme' in handover) userTheme = handover.userTheme;
	}
	if (defaultTheme) applyDefaultTheme(defaultTheme);
	applyUserTheme(userTheme);
}

initThemes();

// Etapas do carregamento do FiveM. `floor` é o mínimo da barra ao entrar na etapa (a barra nunca volta).
const STEPS = [
	{
		id: 'connect',
		label: 'Conectando',
		detail: 'Falando com a imigração de Los Santos',
		doneDetail: 'Passaporte carimbado',
		floor: 0,
		activities: [
			'Subornando o fiscal da alfândega no aeroporto…',
			'Conferindo se seu nome não está na lista da LSPD…',
			'Carimbando o passaporte na fila de embarque…',
			'Sintonizando as antenas da Weazel News…'
		]
	},
	{
		id: 'core',
		label: 'Preparando o esquema',
		detail: 'Calibrando lockpicks e sistemas',
		doneDetail: 'Ferramentas calibradas',
		floor: 15,
		activities: [
			'Calibrando lockpicks e pés de cabra…',
			'Escondendo bancadas ilegais nos becos de Cypress Flats…',
			'Afiando as espátulas da chapa do Burger Shot…',
			'Testando o sinal dos rádios das facções…',
			'Abastecendo os caixas eletrônicos do Fleeca Bank…'
		]
	},
	{
		id: 'data',
		label: 'Abastecendo a cidade',
		detail: 'Carregando veículos, itens e interiores',
		doneDetail: 'Estoques abastecidos',
		floor: 38,
		activities: [
			'Lustrando as viaturas e calibrando os radares da LSPD…',
			'Empilhando caixas no almoxarifado das garagens…',
			'Gelando energéticos e estocando gaze no Pillbox Hill…',
			'Enchendo as bombas de combustível da LTD Gasoline…',
			'Separando fichas e trajes no guarda-roupa…'
		]
	},
	{
		id: 'map',
		label: 'Acendendo Los Santos',
		detail: 'Ruas, luzes e Blaine County',
		doneDetail: 'Cidade iluminada',
		floor: 65,
		activities: [
			'Trocando as lâmpadas queimadas do letreiro de Vinewood…',
			'Varrendo a calçada da Grove Street e do Mirror Park…',
			'Espalhando pombos estratégicos pela Legion Square…',
			'Liberando as cancelas do estacionamento central…',
			'Regulando o pôr do sol no Observatório Galileo…'
		]
	},
	{
		id: 'session',
		label: 'Entrando na cidade',
		detail: 'Sessão, personagem e últimas chaves',
		doneDetail: 'Pronto para entrar',
		floor: 88,
		activities: [
			'Passando um café forte e conferindo sua carteira…',
			'Ajustando o retrovisor para a sua chegada…',
			'Acordando os moradores e abrindo as portas…',
			'Tudo pronto. Bem-vindo a Los Santos!'
		]
	}
];

// Elementos ----------------------------------------------------------------------------------------------
const $ = (id) => document.getElementById(id);
const els = {
	eyebrow: $('eyebrow'), title: $('title'), subtitle: $('subtitle'), tag: $('tag'),
	steps: $('steps'), log: $('log'),
	heroState: $('hero-state'), heroName: $('hero-name'), heroDetail: $('hero-detail'),
	heroStep: $('hero-step'), heroTotal: $('hero-total'),
	percent: $('percent'), bar: $('bar'), fill: $('fill'),
	photos: $('photos'), skyline: $('skyline')
};

els.eyebrow.textContent = CONFIG.eyebrow;
els.title.textContent = CONFIG.title;
els.subtitle.textContent = CONFIG.subtitle;
els.tag.textContent = CONFIG.tag;
els.heroTotal.textContent = String(STEPS.length);

// Etapas -------------------------------------------------------------------------------------------------
const stepNodes = STEPS.map((step, index) => {
	const item = document.createElement('li');
	item.className = 'step';
	item.title = 'Clique para sortear outra atividade desta etapa';
	const number = document.createElement('span');
	number.className = 'step-number';
	number.textContent = String(index + 1);
	const body = document.createElement('div');
	body.className = 'step-body';
	const head = document.createElement('div');
	head.className = 'step-head';
	const label = document.createElement('span');
	label.className = 'step-label';
	label.textContent = step.label;
	const state = document.createElement('span');
	state.className = 'step-state';
	state.textContent = 'Aguardando';
	head.append(label, state);
	const detail = document.createElement('span');
	detail.className = 'step-detail';
	detail.textContent = step.detail;
	body.append(head, detail);
	const meter = document.createElement('span');
	meter.className = 'step-meter';
	const meterFill = document.createElement('span');
	meter.appendChild(meterFill);
	meterFill.className = 'step-meter-fill';
	item.append(number, body, meter);
	item.addEventListener('click', () => cycleStepActivity(index, true));
	els.steps.appendChild(item);
	return { item, number, detail, state, meterFill, activityCursor: 0 };
});

let stepIndex = -1;
let targetStep = 0;
let stepAdvanceTimer = null;
let progress = 0;

function stepCeiling(index) {
	return index + 1 < STEPS.length ? STEPS[index + 1].floor : 100;
}

function stepLocalPercent(index, currentProgress) {
	if (index < stepIndex) return 100;
	if (index > stepIndex) return 0;
	const start = STEPS[index].floor;
	const end = stepCeiling(index);
	const span = Math.max(1, end - start);
	return Math.max(6, Math.min(100, Math.round(((currentProgress - start) / span) * 100)));
}

function swapText(element, nextText) {
	if (!element || element.textContent === nextText) return;
	element.classList.add('is-swapping');
	setTimeout(() => {
		element.textContent = nextText;
		element.classList.remove('is-swapping');
	}, 180);
}

function cycleStepActivity(index, syncHero) {
	const step = STEPS[index];
	const node = stepNodes[index];
	if (!step || !node || !Array.isArray(step.activities) || step.activities.length === 0) return;
	node.activityCursor = (node.activityCursor + 1) % step.activities.length;
	const phrase = step.activities[node.activityCursor];
	if (index === stepIndex) {
		swapText(node.detail, phrase);
		swapText(els.heroDetail, phrase);
	} else if (syncHero) {
		swapText(els.heroDetail, phrase);
	}
}

function render() {
	els.fill.style.width = `${progress}%`;
	els.bar.setAttribute('aria-valuenow', String(progress));
	els.percent.textContent = `${progress}%`;
	els.heroState.textContent = progress >= 100 ? 'PRONTO · ENTRANDO' : `CARREGANDO · ${progress}%`;
	stepNodes.forEach((node, i) => {
		const localPct = stepLocalPercent(i, progress);
		node.meterFill.style.width = `${localPct}%`;
		if (i < stepIndex) {
			node.state.textContent = 'Concluído';
		} else if (i === stepIndex) {
			node.state.textContent = `${localPct}%`;
		} else {
			node.state.textContent = 'Na fila';
		}
	});
}

function applyStep(index) {
	if (index <= stepIndex || index >= STEPS.length) return;
	stepIndex = index;
	stepNodes.forEach((node, i) => {
		const isDone = i < index;
		const isActive = i === index;
		node.item.classList.toggle('is-done', isDone);
		node.item.classList.toggle('is-active', isActive);
		node.number.textContent = isDone ? '✓' : String(i + 1);
		if (isDone) {
			node.detail.textContent = STEPS[i].doneDetail || STEPS[i].detail;
		} else if (isActive) {
			const phrase = STEPS[i].activities[node.activityCursor] || STEPS[i].detail;
			node.detail.textContent = phrase;
			swapText(els.heroDetail, phrase);
		} else {
			node.detail.textContent = STEPS[i].detail;
		}
	});
	els.heroName.textContent = STEPS[index].label;
	els.heroName.classList.remove('is-changing');
	void els.heroName.offsetWidth;
	els.heroName.classList.add('is-changing');
	els.heroStep.textContent = String(index + 1);
	if (progress < STEPS[index].floor) {
		progress = STEPS[index].floor;
	}
	render();
}

function processStepQueue() {
	if (stepIndex >= targetStep) {
		stepAdvanceTimer = null;
		return;
	}
	applyStep(stepIndex + 1);
	if (stepIndex < targetStep) {
		stepAdvanceTimer = setTimeout(processStepQueue, 420);
	} else {
		stepAdvanceTimer = null;
	}
}

function requestStep(index) {
	const clamped = Math.max(0, Math.min(STEPS.length - 1, index));
	if (clamped <= targetStep && stepIndex >= 0) return;
	targetStep = clamped;
	if (stepIndex < 0) {
		applyStep(0);
	}
	if (stepIndex < targetStep && !stepAdvanceTimer) {
		stepAdvanceTimer = setTimeout(processStepQueue, 260);
	}
}

function syncStepFromProgress(value) {
	let matched = 0;
	for (let i = 0; i < STEPS.length; i += 1) {
		if (value >= STEPS[i].floor) matched = i;
	}
	requestStep(matched);
}

function setProgress(fraction) {
	const value = Math.max(progress, Math.min(100, Math.round(fraction * 100)));
	syncStepFromProgress(value);
	if (value === progress) return;
	progress = value;
	render();
}

requestStep(0);
render();

if (els.heroDetail) {
	els.heroDetail.addEventListener('click', () => cycleStepActivity(Math.max(0, stepIndex), true));
}

// Rotação automática das frases divertidas da etapa ativa + avanço suave entre etapas.
setInterval(() => {
	if (stepIndex >= 0 && stepIndex < STEPS.length) {
		cycleStepActivity(stepIndex, false);
	}
	if (progress < 92) {
		const step = progress < 65 ? 3 : 2;
		setProgress(Math.min(92, progress + step) / 100);
	}
}, CONFIG.activitySeconds * 1000);

// Eventos do FiveM (postMessage durante o carregamento) --------------------------------------------------
function stepForInitType(type) {
	if (type === 'INIT_AFTER_MAP_LOADED') return 4;
	if (type === 'INIT_SESSION') return progress >= 60 ? 4 : 1;
	if (type === 'INIT_BEFORE_MAP_LOADED') return 3;
	return 1;
}

const handlers = {
	loadProgress(data) {
		if (typeof data.loadFraction === 'number') setProgress(data.loadFraction);
	},
	startInitFunction(data) {
		if (data && data.type) requestStep(stepForInitType(data.type));
	},
	startInitFunctionOrder(data) {
		if (data && data.type) requestStep(stepForInitType(data.type));
	},
	initFunctionInvoking(data) {
		if (data && data.type) requestStep(stepForInitType(data.type));
		if (data && typeof data.name === 'string') {
			els.log.textContent = `Iniciando ${data.name}…`;
		}
	},
	startDataFileEntries() { requestStep(2); },
	onDataFileEntry(data) {
		requestStep(2);
		if (data && typeof data.name === 'string') {
			const shortName = data.name.split('/').pop();
			els.log.textContent = `Carregando ${shortName}…`;
		}
	},
	performMapLoadFunction() { requestStep(3); },
	endDataFileEntries() { requestStep(3); },
	onLogLine(data) {
		if (typeof data.message === 'string') {
			els.log.textContent = data.message.replace(/\.\.\.$/, '…');
			if (/session|spawn|network/i.test(data.message) && progress >= 55) {
				requestStep(4);
			}
		}
	}
};

window.addEventListener('message', (event) => {
	const data = event.data;
	if (!data) return;
	if (data.action === 'coe:theme') applyDefaultTheme(data.theme);
	if (data.action === 'coe:accent' || data.action === 'coe:userTheme') {
		applyUserTheme(data.userTheme || data.accent);
	}
	if (typeof data.eventName === 'string' && handlers[data.eventName]) {
		handlers[data.eventName](data);
	}
});

// Fundo: fotos em sequência ou o pôr do sol desenhado ---------------------------------------------------
function startPhotos() {
	const list = CONFIG.backgrounds.filter((name) => typeof name === 'string' && name !== '');
	if (list.length === 0) return;
	const layers = list.map((name) => {
		const layer = document.createElement('div');
		layer.className = 'photo';
		layer.style.backgroundImage = `url("backgrounds/${encodeURI(name)}")`;
		els.photos.appendChild(layer);
		return layer;
	});
	els.photos.classList.add('is-on');
	let current = Math.floor(Math.random() * layers.length);
	layers[current].classList.add('is-visible');
	if (layers.length > 1) {
		setInterval(() => {
			layers[current].classList.remove('is-visible');
			current = (current + 1) % layers.length;
			layers[current].classList.add('is-visible');
		}, CONFIG.backgroundSeconds * 1000);
	}
}

// Silhueta procedural: colinas de Vinewood, centro com prédios altos e janelas acesas.
function drawSkyline() {
	const ns = 'http://www.w3.org/2000/svg';
	const svg = els.skyline;
	let seed = 7;
	const rand = () => {
		seed = (seed * 16807) % 2147483647;
		return (seed - 1) / 2147483646;
	};
	const add = (parent, tag, attrs) => {
		const node = document.createElementNS(ns, tag);
		Object.keys(attrs).forEach((key) => node.setAttribute(key, attrs[key]));
		parent.appendChild(node);
		return node;
	};
	const hills = (className, base, amplitude, step) => {
		let d = `M0 1080 L0 ${base}`;
		for (let x = 0; x <= 1920; x += step) {
			const y = base - Math.sin(x / 260) * amplitude * 0.5 - Math.sin(x / 97 + 1.3) * amplitude * 0.25 - rand() * amplitude * 0.2;
			d += ` L${x} ${y.toFixed(1)}`;
		}
		add(svg, 'path', { d: `${d} L1920 1080 Z`, class: className });
	};
	hills('hills-far', 760, 90, 40);
	hills('hills-near', 840, 60, 30);

	const lights = [add(svg, 'g', { class: 'lights-a' }), add(svg, 'g', { class: 'lights-b' }), add(svg, 'g', { class: 'lights-c' })];
	const city = (className, count, minH, maxH, baseY, centerBias, windows) => {
		const group = add(svg, 'g', { class: className });
		for (let i = 0; i < count; i += 1) {
			const center = 1100 + (rand() - 0.5) * 900;
			const x = Math.round(centerBias ? center : rand() * 1920);
			const w = Math.round(18 + rand() * 46);
			const closeness = 1 - Math.min(1, Math.abs(x - 1150) / 900);
			const h = Math.round(minH + (maxH - minH) * (centerBias ? closeness * (0.4 + rand() * 0.6) : rand()));
			const y = baseY - h;
			add(group, 'rect', { x, y, width: w, height: h + 300 });
			if (h > 200 && rand() > 0.55) add(svg, 'rect', { x: x + w / 2 - 1.5, y: y - 6, width: 3, height: 3, class: 'beacon' });
			if (!windows) continue;
			for (let wy = y + 8; wy < baseY - 6; wy += 11) {
				for (let wx = x + 4; wx < x + w - 4; wx += 8) {
					if (rand() > 0.82) add(lights[Math.floor(rand() * 3)], 'rect', { x: wx, y: wy, width: 3, height: 4, class: 'window' });
				}
			}
		}
	};
	city('city', 46, 60, 380, 900, true, true);
	// Mantém as luzes acima dos prédios de trás e abaixo dos da frente.
	lights.forEach((group) => svg.appendChild(group));
	city('city-front', 70, 20, 120, 960, false, false);
}

startPhotos();
drawSkyline();
