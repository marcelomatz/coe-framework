(() => {
	// Velocímetros do HUD. Cada estilo é um template estático com ganchos data-*; o update só toca o DOM quando o valor muda.
	const STYLES = ['modern', 'modernpro', 'bold', 'retro', 'minimal', 'analog'];
	const MAX = { kmh: 240, mph: 160 };
	const STEP = { kmh: 40, mph: 20 };
	const FUEL_LOW = 15;
	const ENGINE_LOW = 30;
	const RETRO_SEGMENTS = 24;

	const clamp = (value, min, max) => Math.max(min, Math.min(max, value));
	const num = (value) => Math.round(value * 100) / 100;

	function polar(cx, cy, r, deg) {
		const rad = (deg - 90) * Math.PI / 180;
		return [num(cx + r * Math.cos(rad)), num(cy + r * Math.sin(rad))];
	}

	// Ângulo 0 = topo, sentido horário. a1 < a0 desenha no sentido anti-horário (o preenchimento nasce em a0).
	function arc(cx, cy, r, a0, a1) {
		const [x0, y0] = polar(cx, cy, r, a0);
		const [x1, y1] = polar(cx, cy, r, a1);
		const delta = a1 - a0;
		return `M${x0} ${y0}A${r} ${r} 0 ${Math.abs(delta) > 180 ? 1 : 0} ${delta > 0 ? 1 : 0} ${x1} ${y1}`;
	}

	function ring(cx, cy, r, a0, a1, key, cls) {
		const d = arc(cx, cy, r, a0, a1);
		return `<path class="sp-track" d="${d}" pathLength="100"/><path class="sp-fill ${cls || ''}" d="${d}" pathLength="100" data-arc="${key}"/>`;
	}

	function ticks(cx, cy, r1, r2, a0, a1, count, cls) {
		let out = '';
		for (let i = 0; i <= count; i += 1) {
			const a = a0 + (a1 - a0) * i / count;
			const [x1, y1] = polar(cx, cy, r1, a);
			const [x2, y2] = polar(cx, cy, r2, a);
			out += `<line class="${cls || 'sp-tick'}" x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}"/>`;
		}
		return out;
	}

	function labels(cx, cy, r, a0, a1, values, max) {
		return values.map((value) => {
			const [x, y] = polar(cx, cy, r, a0 + (a1 - a0) * value / max);
			return `<text class="sp-label" x="${x}" y="${y}">${value}</text>`;
		}).join('');
	}

	function needle(cx, cy, length, key, a0, a1) {
		return `<line class="sp-needle" x1="${cx}" y1="${cy}" x2="${cx}" y2="${num(cy - length)}" style="transform-origin:${cx}px ${cy}px" data-needle="${key}" data-a0="${a0}" data-a1="${a1}"/><circle class="sp-hub" cx="${cx}" cy="${cy}" r="4"/>`;
	}

	function range(max, step) {
		const out = [];
		for (let v = 0; v <= max; v += step) {
			out.push(v);
		}
		return out;
	}

	// Faixa de indicadores: componente próprio do HUD (createIndicators), posicionável no modo de edição.
	const FLAGS = '<div class="sp-flags">'
		+ '<span data-flag="left">&#9664;</span><span data-flag="engine">MOTOR</span>'
		+ '<span data-flag="lights" data-text="lights">FAROL</span><span data-flag="belt">CINTO</span>'
		+ '<span data-flag="fuel">COMB</span><span data-flag="right">&#9654;</span></div>';

	const TEMPLATES = {
		modern() {
			return '<svg class="sp-svg sp-modern" viewBox="0 0 230 160">'
				+ ring(150, 80, 66, -135, 135, 'speed', 'sp-white')
				+ ring(42, 48, 24, -135, 135, 'engine', 'sp-amber')
				+ ring(42, 112, 24, -135, 135, 'fuel', 'sp-white')
				+ '<text class="sp-cap" x="42" y="51">MOT</text><text class="sp-cap" x="42" y="115">COMB</text>'
				+ '<circle class="sp-badge-bg" cx="150" cy="44" r="10"/><text class="sp-badge-t" x="150" y="48" data-text="gear"></text>'
				+ '<text class="sp-speed" x="150" y="92" data-text="speed"></text>'
				+ '<text class="sp-unit" x="150" y="110" data-text="unit"></text></svg>';
		},
		modernpro() {
			return '<svg class="sp-svg sp-pro" viewBox="0 0 200 200">'
				+ ring(100, 100, 92, -160, -20, 'speed', 'sp-white')
				+ ring(100, 100, 92, 160, 20, 'rpm', 'sp-amber')
				+ ticks(100, 100, 70, 78, -125, 125, 40)
				+ ticks(100, 100, 66, 78, -125, 125, 10, 'sp-tick sp-tick-major')
				+ '<circle class="sp-badge-bg" cx="100" cy="72" r="10"/><text class="sp-badge-t" x="100" y="76" data-text="gear"></text>'
				+ '<text class="sp-speed sp-speed-l" x="100" y="116" data-text="speed"></text>'
				+ '<text class="sp-unit" x="100" y="136" data-text="unit"></text>'
				+ '<text class="sp-cap" x="40" y="34">COMB</text><text class="sp-cap" x="160" y="34">MOT</text></svg>';
		},
		bold() {
			return '<div class="sp-html sp-bold"><div class="sp-big"><span class="dim" data-text="zeros"></span><span data-text="speed"></span></div>'
				+ '<div class="sp-row"><div class="sp-bar sp-grow"><i data-bar="speed"></i></div>'
				+ '<span class="sp-pill" data-text="gear" data-gear></span><span class="sp-pill sp-light" data-text="unit"></span></div>'
				+ '<div class="sp-row"><span class="sp-mini"><em>COMB</em><div class="sp-bar"><i data-bar="fuel"></i></div></span>'
				+ '<span class="sp-mini"><em>MOT</em><div class="sp-bar sp-amber"><i data-bar="engine"></i></div></span></div></div>';
		},
		retro() {
			let segs = '';
			for (let i = 0; i < RETRO_SEGMENTS; i += 1) {
				segs += '<i></i>';
			}
			return '<div class="sp-html sp-retro"><div class="sp-row">'
				+ '<span class="sp-pill sp-light" data-text="gear" data-gear></span>'
				+ '<div class="sp-big"><span class="dim" data-text="zeros"></span><span data-text="speed"></span></div>'
				+ '<div class="sp-chips"><span class="sp-chip sp-amber"><b data-text="enginePct"></b></span>'
				+ '<span class="sp-chip"><b data-text="fuelPct"></b></span></div></div>'
				+ `<div class="sp-segs" data-segs="rpm">${segs}</div></div>`;
		},
		minimal() {
			return '<div class="sp-html sp-minimal"><div class="sp-bars">'
				+ '<span class="sp-mini"><em>COMB</em><div class="sp-bar"><i data-bar="fuel"></i></div></span>'
				+ '<span class="sp-mini"><em>MOT</em><div class="sp-bar sp-amber"><i data-bar="engine"></i></div></span></div>'
				+ '<div class="sp-pillrow"><span class="sp-pill" data-text="gear" data-gear></span>'
				+ '<b class="sp-num" data-text="speed"></b><small data-text="unit"></small></div></div>';
		},
		analog(unit) {
			const max = MAX[unit] || MAX.kmh;
			const step = STEP[unit] || STEP.kmh;
			return '<svg class="sp-svg sp-analog" viewBox="0 0 290 150">'
				+ '<circle class="sp-face" cx="72" cy="86" r="62"/>'
				+ ticks(72, 86, 52, 58, -135, 135, 40) + ticks(72, 86, 48, 58, -135, 135, 10, 'sp-tick sp-tick-major')
				+ `<path class="sp-red" d="${arc(72, 86, 55, 81, 135)}"/>`
				+ labels(72, 86, 38, -135, 135, range(10, 1), 10)
				+ '<text class="sp-cap" x="72" y="118">x1000 rpm</text>' + needle(72, 86, 50, 'rpm', -135, 135)
				+ '<circle class="sp-face" cx="212" cy="86" r="62"/>'
				+ ticks(212, 86, 52, 58, -135, 135, 40) + ticks(212, 86, 48, 58, -135, 135, 10, 'sp-tick sp-tick-major')
				+ labels(212, 86, 38, -135, 135, range(max, step), max)
				+ '<text class="sp-cap" x="212" y="118" data-text="unit"></text>' + needle(212, 86, 50, 'speed', -135, 135)
				+ '<circle class="sp-face" cx="142" cy="28" r="24"/>'
				+ ticks(142, 28, 17, 21, -60, 60, 6) + '<text class="sp-cap" x="128" y="40">E</text><text class="sp-cap" x="156" y="40">F</text>'
				+ needle(142, 28, 17, 'fuel', -60, 60) + '</svg>';
		}
	};

	function collect(host) {
		const refs = { text: [], arc: [], needle: [], bar: [], segs: [], flag: [], gear: [] };
		host.querySelectorAll('[data-text]').forEach((el) => refs.text.push(el));
		host.querySelectorAll('[data-arc]').forEach((el) => refs.arc.push(el));
		host.querySelectorAll('[data-needle]').forEach((el) => refs.needle.push(el));
		host.querySelectorAll('[data-bar]').forEach((el) => refs.bar.push(el));
		host.querySelectorAll('[data-segs]').forEach((el) => refs.segs.push(el));
		host.querySelectorAll('[data-flag]').forEach((el) => refs.flag.push(el));
		host.querySelectorAll('[data-gear]').forEach((el) => refs.gear.push(el));
		return refs;
	}

	function create(host, templates) {
		const source = templates || TEMPLATES;
		let refs = null;
		let unit = 'kmh';
		let current = null;

		function mount(style, nextUnit) {
			unit = nextUnit === 'mph' ? 'mph' : 'kmh';
			if (current) {
				host.classList.remove(`sp-s-${current}`);
			}
			current = Object.prototype.hasOwnProperty.call(source, style) ? style : null;
			host.textContent = '';
			refs = null;
			if (!current) {
				return false;
			}
			host.innerHTML = source[current](unit);
			// classList preserva as classes do layout (posição livre, fantasma do editor).
			host.classList.add('sp-host', `sp-s-${current}`);
			refs = collect(host);
			refs.cache = new WeakMap();
			return true;
		}

		function put(el, key, value) {
			const slot = refs.cache.get(el) || {};
			if (slot[key] === value) {
				return false;
			}
			slot[key] = value;
			refs.cache.set(el, slot);
			return true;
		}

		function update(state) {
			if (!refs || !state) {
				return;
			}
			const max = MAX[unit];
			const speed = Math.max(0, state.speed || 0);
			const v = {
				speed: clamp(speed / max, 0, 1),
				rpm: clamp((state.rpm || 0) / 100, 0, 1),
				fuel: clamp((state.fuel || 0) / 100, 0, 1),
				engine: clamp((state.engine || 0) / 100, 0, 1)
			};
			const speedText = String(speed);
			const text = {
				speed: speedText,
				zeros: '0'.repeat(Math.max(0, 3 - speedText.length)),
				unit: unit === 'mph' ? 'MPH' : 'KM/H',
				gear: state.gear > 0 ? String(state.gear) : (speed > 0 ? 'R' : 'N'),
				fuelPct: `${state.fuel || 0}%`,
				enginePct: `${state.engine || 0}%`,
				lights: state.lights === 2 ? 'ALTO' : 'FAROL'
			};
			const noGear = state.kind === 'boat' || state.kind === 'air';
			const flags = {
				left: [state.left, false],
				right: [state.right, false],
				belt: [state.belt, !state.belt && speed > 20],
				lights: [(state.lights || 0) > 0, false],
				engine: [false, (state.engine || 0) <= ENGINE_LOW],
				fuel: [false, (state.fuel || 0) <= FUEL_LOW]
			};

			refs.text.forEach((el) => {
				const value = text[el.dataset.text];
				if (value !== undefined && put(el, 't', value)) {
					el.textContent = value;
				}
			});
			refs.gear.forEach((el) => {
				if (put(el, 'g', noGear)) {
					el.style.display = noGear ? 'none' : '';
				}
			});
			refs.arc.forEach((el) => {
				const value = v[el.dataset.arc];
				if (put(el, 'a', value)) {
					el.style.strokeDasharray = `${num(value * 100)} 100`;
				}
			});
			refs.needle.forEach((el) => {
				const value = v[el.dataset.needle];
				if (put(el, 'n', value)) {
					const a0 = Number(el.dataset.a0);
					const a1 = Number(el.dataset.a1);
					el.style.transform = `rotate(${num(a0 + (a1 - a0) * value)}deg)`;
				}
			});
			refs.bar.forEach((el) => {
				const value = v[el.dataset.bar];
				if (put(el, 'b', value)) {
					el.style.setProperty('--v', value);
					el.parentElement.classList.toggle('low', el.dataset.bar !== 'speed' && value * 100 <= (el.dataset.bar === 'fuel' ? FUEL_LOW : ENGINE_LOW));
				}
			});
			refs.segs.forEach((el) => {
				const lit = Math.round(v[el.dataset.segs] * el.children.length);
				if (put(el, 's', lit)) {
					Array.prototype.forEach.call(el.children, (seg, index) => {
						seg.classList.toggle('on', index < lit);
						seg.classList.toggle('hot', index >= el.children.length * 0.8);
					});
				}
			});
			refs.flag.forEach((el) => {
				const [on, warn] = flags[el.dataset.flag] || [false, false];
				const key = `${on ? 1 : 0}${warn ? 1 : 0}`;
				if (put(el, 'f', key)) {
					el.classList.toggle('on', !!on);
					el.classList.toggle('warn', !!warn);
				}
			});
		}

		return { mount, update };
	}

	// Indicadores (setas, motor, farol, cinto, combustível) fora do velocímetro, para qualquer estilo.
	function createIndicators(host) {
		const instance = create(host, { indicators: () => FLAGS });
		instance.mount('indicators', 'kmh');
		return { update: instance.update };
	}

	const api = { STYLES, MAX, create, createIndicators };
	if (typeof module !== 'undefined' && module.exports) {
		module.exports = api;
	}
	if (typeof window !== 'undefined') {
		window.CoeSpeedo = api;
	}
})();
