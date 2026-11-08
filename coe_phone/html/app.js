(function () {
	'use strict';

	const ERRORS = {
		forbidden: 'Você não pode fazer isso.',
		rate_limited: 'Calma, muitas ações seguidas.',
		app_unavailable: 'Aplicativo indisponível.',
		app_error: 'Falha no aplicativo.',
		timeout: 'Sem resposta do servidor.',
		closed: 'Celular fechado.',
		camera_unavailable: 'Câmera indisponível.',
		camera_timeout: 'A câmera não respondeu. Tente de novo (detalhes no F8).',
		camera_empty: 'A câmera não gerou a foto (detalhes no F8).',
		cancelled: 'Foto cancelada.',
		not_ready: 'Serviço ainda iniciando.',
		no_character: 'Personagem não carregado.',
		no_phone: 'Você não tem um celular.',
		database_error: 'Falha ao gravar. Tente de novo.',
		invalid_number: 'Número inválido.',
		number_not_found: 'Esse número não existe.',
		unavailable: 'O número está fora de área.',
		busy: 'Linha ocupada.',
		already_in_call: 'Você já está em uma ligação.',
		no_call: 'Nenhuma ligação.',
		invalid_name: 'Informe um nome.',
		contact_exists: 'Esse número já está nos contatos.',
		contacts_full: 'Agenda cheia.',
		invalid_message: 'Escreva uma mensagem.',
		number_unavailable: 'Sem números livres. Avise a administração.',
		airplane_mode: 'Desative o modo avião.',
		no_signal: 'Sem sinal aqui.',
		locked: 'Desbloqueie o celular.',
		wrong_passcode: 'Senha incorreta.',
		locked_out: 'Muitas tentativas. Aguarde um pouco.',
		invalid_passcode: 'A senha precisa ter só números (de 4 a 6).',
		passcode_required: 'Defina uma senha primeiro.',
		invalid_setting: 'Ajuste inválido.',
		invalid_layout: 'Tela inicial inválida.',
		no_credit: 'Sem crédito. Recarregue no app Minha linha.',
		line_suspended: 'Linha suspensa. Pague a fatura no app Minha linha.',
		telecom_unavailable: 'Operadora indisponível no momento.',
		invalid_request: 'Pedido inválido.',
		no_sim: 'Sem chip. Use um chip do inventário para colocar no celular.',
		no_device: 'Aparelho não reconhecido.',
		face_mismatch: 'Rosto não reconhecido.',
		no_sim_slot: 'Não há chip nesse slot.',
		in_call: 'Encerre a ligação antes.',
		inventory_full: 'Sem espaço no inventário.',
		inventory_unavailable: 'Inventário indisponível no momento.',
		invalid_sim: 'Este chip não funciona.',
		no_free_sim_slot: 'Não há espaço para outro chip neste celular.',
		slot_changed: 'O chip não está mais no inventário.',
		invalid_photo: 'Foto inválida.',
		storage_full: 'Armazenamento cheio. Apague fotos na Galeria.',
		photo_not_found: 'Foto não encontrada.',
		bank_unavailable: 'Banco indisponível no momento.',
		wallet_passcode: 'Defina uma senha do celular em Ajustes para usar a Carteira.',
		wallet_full: 'A Carteira está cheia. Remova um cartão.',
		already_in_wallet: 'Esse cartão já está na Carteira.',
		not_in_wallet: 'Esse cartão não está na Carteira.',
		wrong_pin: 'Senha do cartão incorreta.',
		card_blocked: 'Cartão bloqueado.',
		card_expired: 'Cartão vencido.',
		no_card: 'Cartão não encontrado. O cartão físico precisa estar no inventário.',
		not_owner: 'Esse cartão virtual é de outra pessoa.',
		no_account: 'Você não tem conta no banco.',
		insufficient_funds: 'Saldo insuficiente.',
		economy_unavailable: 'Banco indisponível no momento.',
		payment_expired: 'O pagamento expirou. Tente de novo.',
		payment_mismatch: 'Pagamento não confere. Tente de novo.'
	};

	const ICONS = {
		phone: '<path d="M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2"/>',
		contacts: '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
		messages: '<path d="M4 5h16v11H9l-5 4z"/><path d="M8 9h8M8 12h5"/>',
		settings: '<circle cx="12" cy="12" r="3.2"/><path d="M12 2.5v3M12 18.5v3M2.5 12h3M18.5 12h3M5.3 5.3l2.1 2.1M16.6 16.6l2.1 2.1M5.3 18.7l2.1-2.1M16.6 7.4l2.1-2.1"/>',
		store: '<path d="M4 8h16l-1 12H5z"/><path d="M9 8V6a3 3 0 0 1 6 0v2"/><path d="m10 14 2 2 3-4"/>',
		jobs: '<rect x="3" y="8" width="18" height="12" rx="2"/><path d="M9 8V6h6v2"/><path d="M12 12v3"/><path d="M3 13h18"/>',
		cart: '<circle cx="9" cy="20" r="1.4"/><circle cx="17" cy="20" r="1.4"/><path d="M3 4h2.5l2.2 11h10.6l2-8H6.6"/>',
		mail: '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3.5 7l8.5 6 8.5-6"/>',
		tv: '<rect x="3" y="6" width="18" height="13" rx="2"/><path d="M8 2.5l4 3.5 4-3.5"/><path d="M8 21h8"/>',
		radio: '<circle cx="12" cy="12" r="2"/><path d="M8.5 15.5a5 5 0 0 1 0-7M15.5 8.5a5 5 0 0 1 0 7"/><path d="M5.6 18.4a9 9 0 0 1 0-12.8M18.4 5.6a9 9 0 0 1 0 12.8"/>',
		news: '<path d="M4 5h13v15H6a2 2 0 0 1-2-2z"/><path d="M17 9h3v9a2 2 0 0 1-2 2"/><path d="M7 9h7M7 12h7M7 15h4"/>',
		camera: '<rect x="3" y="3" width="18" height="18" rx="5"/><circle cx="12" cy="12" r="4"/><circle cx="17.2" cy="6.8" r=".6"/>',
		shutter: '<path d="M4 8h3l2-3h6l2 3h3a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V9a1 1 0 0 1 1-1"/><circle cx="12" cy="13.5" r="3.8"/>',
		editor: '<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="m13.5 6.5 4 4"/><path d="M18 14v4M16 16h4M6 3v3M4.5 4.5h3"/>',
		gallery: '<rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="8.5" cy="9.5" r="1.6"/><path d="m3 17 5-5 4 4 3-3 6 6"/>',
		minimize: '<path d="M6 15l6-6 6 6"/>',
		airplane: '<path d="M10.5 3.5a1.5 1.5 0 0 1 3 0V9l7.5 4.5V16l-7.5-2.5v4.5l2.5 2V22L12 21l-4 1v-2l2.5-2v-4.5L3 16v-2.5L10.5 9z"/>',
		wifi: '<path d="M2.5 9a14 14 0 0 1 19 0"/><path d="M5.5 12.5a9.5 9.5 0 0 1 13 0"/><path d="M8.5 16a5 5 0 0 1 7 0"/><circle cx="12" cy="19.5" r=".9"/>',
		bluetooth: '<path d="m7 7 10 10-5 4V3l5 4L7 17"/>',
		moon: '<path d="M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5"/>',
		bell: '<path d="M6 16v-5a6 6 0 0 1 12 0v5l1.5 2h-15z"/><path d="M10 20.5a2 2 0 0 0 4 0"/>',
		bellOff: '<path d="M8.5 5.5A6 6 0 0 1 18 11v5"/><path d="M6 11v5l-1.5 2H16"/><path d="M10 20.5a2 2 0 0 0 4 0"/><path d="M3 3l18 18"/>',
		lock: '<rect x="5" y="11" width="14" height="10" rx="1"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>',
		face: '<path d="M4 8V5a1 1 0 0 1 1-1h3M16 4h3a1 1 0 0 1 1 1v3M20 16v3a1 1 0 0 1-1 1h-3M8 20H5a1 1 0 0 1-1-1v-3"/><path d="M9 9.5v1M15 9.5v1M12 9.5v4h-1M9.5 16a3.5 3.5 0 0 0 5 0"/>',
		volume: '<path d="M4 9h4l5-4v14l-5-4H4z"/><path d="M16.5 8.5a5 5 0 0 1 0 7M19 6a8.5 8.5 0 0 1 0 12"/>',
		vibrate: '<rect x="8" y="4" width="8" height="16" rx="1"/><path d="M4 9v6M20 9v6"/>',
		home: '<path d="M4 11 12 4l8 7v9h-5v-6H9v6H4z"/>',
		info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7.5v.5"/>',
		sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
		sim: '<path d="M7 3h7l4 4v13a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1"/><rect x="9" y="11" width="6" height="6" rx="1"/><path d="M12 11v6M9 14h6"/>',
		video: '<rect x="3" y="6" width="12" height="12" rx="2"/><path d="m15 10 6-3v10l-6-3"/>',
		bank: '<path d="M3 10h18L12 4z"/><path d="M5 10v8M9.5 10v8M14.5 10v8M19 10v8"/><path d="M3 20h18"/>',
		wallet: '<path d="M4 7a2 2 0 0 1 2-2h11v4"/><rect x="3" y="7" width="18" height="13" rx="2"/><path d="M16 12h5v4h-5a2 2 0 0 1 0-4"/>',
		crypto: '<circle cx="12" cy="12" r="9"/><path d="M9 7.5h4.5a2.25 2.25 0 0 1 0 4.5H9h5a2.25 2.25 0 0 1 0 4.5H9z"/><path d="M10.5 6v1.5M10.5 16.5V18M13 6v1.5M13 16.5V18"/>',
		onion: '<circle cx="12" cy="13" r="7"/><path d="M12 6c-2.5 2-3.5 4.5-3.5 7s1 5 3.5 7"/><path d="M12 6c2.5 2 3.5 4.5 3.5 7s-1 5-3.5 7"/><path d="M12 6V3"/><path d="M12 3c1.5 0 2.5-.7 3-1.5"/>',
		car: '<path d="M5 16V11l2-5h10l2 5v5"/><path d="M3 16h18v2H3z"/><circle cx="7.5" cy="13.5" r=".8"/><circle cx="16.5" cy="13.5" r=".8"/>',
		mdt: '<path d="M12 3 4 6v6c0 5 3.5 8 8 9 4.5-1 8-4 8-9V6z"/><path d="m9 12 2 2 4-4"/>',
		workshop: '<path d="M14 6a4 4 0 0 0-5 5L4 16l4 4 5-5a4 4 0 0 0 5-5l-3 3-3-1-1-3z"/>'
	};

	const DEFAULT_SETTINGS = {
		airplane: false, wifi: true, bluetooth: false, silent: false, vibrate: true, dnd: false,
		volume: 5, ringtone: 'classico', wallpaper: 'padrao', brightness: 100, faceId: false
	};

	const RINGTONES = {
		classico: { label: 'Clássico', every: 2200, play: function (beep, v) { beep([880, 1320], 0.18, v); setTimeout(function () { beep([880, 1320], 0.18, v); }, 260); } },
		digital: { label: 'Digital', every: 1800, play: function (beep, v) { [0, 1, 2, 3].forEach(function (i) { setTimeout(function () { beep([i % 2 ? 1568 : 1175], 0.09, v); }, i * 120); }); } },
		suave: { label: 'Suave', every: 2600, play: function (beep, v) { [523, 659, 784].forEach(function (f, i) { setTimeout(function () { beep([f], 0.32, v * 0.8); }, i * 280); }); } },
		pulso: { label: 'Pulso', every: 1300, play: function (beep, v) { beep([660, 990], 0.45, v * 0.7); } }
	};

	const WALLPAPERS = {
		padrao: 'Padrão', noite: 'Noite', oceano: 'Oceano', brasa: 'Brasa', floresta: 'Floresta', grafite: 'Grafite'
	};

	const $ = function (id) { return document.getElementById(id); };
	const els = {
		root: $('phone'), screen: $('phone-screen'), pill: $('phone-pill'), heroClock: $('phone-hero-clock'), heroDate: $('phone-hero-date'),
		number: $('phone-number'), home: $('phone-home'), pages: $('phone-pages'), track: $('phone-track'), dots: $('phone-dots'),
		edit: $('phone-edit'), edgeLeft: $('phone-edge-left'), edgeRight: $('phone-edge-right'), dock: $('phone-dock'), view: $('phone-view'),
		back: $('phone-back'), icon: $('phone-app-icon'), title: $('phone-app-title'), app: $('phone-app'), status: $('phone-status'),
		homeButton: $('phone-home-button'), call: $('phone-call'), callAvatar: $('phone-call-avatar'), callName: $('phone-call-name'),
		callNumber: $('phone-call-number'), callState: $('phone-call-state'), callActions: $('phone-call-actions'),
		peek: $('phone-peek'), peekName: $('phone-peek-name'), peekState: $('phone-peek-state'),
		signal: $('phone-signal'), carrier: $('phone-carrier'), indicators: $('phone-indicators'),
		lock: $('phone-lock'), lockClock: $('phone-lock-clock'), lockDate: $('phone-lock-date'), lockBody: $('phone-lock-body'),
		hud: $('phone-hud'), dim: $('phone-dim'),
		keySilent: $('phone-key-silent'), keyUp: $('phone-key-up'), keyDown: $('phone-key-down'), keyPower: $('phone-key-power')
	};

	const registry = {};
	const loaded = {};
	let profile = { apps: [] };
	let apps = [];
	let current = null;
	let isOpen = false;
	let clockTimer = null;
	let listeners = [];
	let unread = 0;
	let call = null;
	let callMinimized = false;
	let callTimer = null;
	let endedTimer = null;
	let queue = Promise.resolve();
	let lastCallAt = 0;

	let settings = Object.assign({}, DEFAULT_SETTINGS);
	let signal = { bars: 0, indoor: false };
	let home = { PageSize: 16, MaxPages: 6, DockSize: 4 };
	let layout = { pages: [[]], dock: [] };
	let page = 0;
	let editing = false;
	let dragId = null;
	let suppressClick = false;
	let pressTimer = null;
	let edgeTimer = null;
	let layoutDirty = false;
	let layoutTimer = null;
	let pendingPatch = {};
	let patchTimer = null;
	let hudTimer = null;
	let locked = false;
	let lockCode = '';
	let lockMessage = '';
	let lockFallback = false;

	function post(name, body) {
		return fetch('https://' + GetParentResourceName() + '/' + name, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json; charset=UTF-8' },
			body: JSON.stringify(body || {})
		}).then(function (response) { return response.json(); }).catch(function () { return { ok: false, error: 'closed' }; });
	}

	function setStatus(message, kind) {
		els.status.textContent = message || '';
		els.status.className = 'phone-status' + (kind ? ' is-' + kind : '');
	}

	function errorText(code) {
		return ERRORS[code] || ('Falha: ' + code);
	}

	function svg(icon) {
		return '<svg viewBox="0 0 24 24">' + (ICONS[icon] || '') + '</svg>';
	}

	function toArray(value) {
		return Array.isArray(value) ? value : [];
	}

	// Ações vão em fila com um pequeno intervalo, abaixo do limite do servidor.
	function call_(app, action, payload) {
		const run = function () {
			const wait = Math.max(0, lastCallAt + 220 - Date.now());
			return new Promise(function (resolve) { setTimeout(resolve, wait); }).then(function () {
				lastCallAt = Date.now();
				return post('call', { app: app, action: action, payload: payload || {} });
			});
		};
		const result = queue.then(run, run);
		queue = result.catch(function () {});
		return result;
	}

	function emit(event, data) {
		listeners.forEach(function (entry) {
			if (entry.event === event) {
				try { entry.fn(data); } catch (e) { /* app fechado */ }
			}
		});
	}

	function formatNumber(value) {
		const digits = String(value || '').replace(/\D/g, '');
		const size = (profile.prefix || '').length;
		return size && digits.length > size ? digits.slice(0, size) + '-' + digits.slice(size) : digits;
	}

	function findApp(id) {
		return apps.find(function (app) { return app.id === id; });
	}

	function paintIcon(tile, app) {
		tile.style.removeProperty('--app-color');
		if (/^#[0-9a-fA-F]{3,8}$/.test(app.color || '')) { tile.style.setProperty('--app-color', app.color); }
		if (ICONS[app.icon]) {
			tile.innerHTML = svg(app.icon);
		} else {
			tile.textContent = (app.label || app.id || '?').charAt(0).toUpperCase();
		}
	}

	// Som e vibração --------------------------------------------------------------------------------------

	function sound() {
		return Object.assign({ max: Number(profile.ringMax) || 0.5 }, settings);
	}

	const tone = (function () {
		let context = null;
		let timers = [];
		function beep(freqs, duration, volume, type) {
			if (!(volume > 0)) { return; }
			try { context = context || new (window.AudioContext || window.webkitAudioContext)(); } catch (e) { return; }
			const now = context.currentTime;
			const gain = context.createGain();
			gain.gain.setValueAtTime(volume, now);
			gain.gain.exponentialRampToValueAtTime(0.0001, now + duration);
			gain.connect(context.destination);
			freqs.forEach(function (freq) {
				const osc = context.createOscillator();
				osc.type = type || 'sine';
				osc.frequency.value = freq;
				osc.connect(gain);
				osc.start(now);
				osc.stop(now + duration);
			});
		}
		function level(s) {
			return Math.max(0, Math.min(1, (Number(s.max) || 0.5) * (Number(s.volume) || 0) / 10));
		}
		function repeat(fn, ms) {
			fn();
			timers.push(setInterval(fn, ms));
		}
		function buzz() {
			beep([92, 97], 0.3, 0.12, 'square');
			setTimeout(function () { beep([92, 97], 0.3, 0.12, 'square'); }, 450);
		}
		return {
			ring: function (s) {
				this.stop();
				if (s.dnd) { return; }
				if (!s.silent) {
					const ringtone = RINGTONES[s.ringtone] || RINGTONES.classico;
					const volume = level(s) * 0.5;
					repeat(function () { ringtone.play(beep, volume); }, ringtone.every);
				}
				if (s.vibrate) { repeat(buzz, 1800); }
			},
			ringback: function (s) {
				this.stop();
				const volume = Math.max(0.04, level(s) * 0.3);
				repeat(function () { beep([425], 1.0, volume); }, 4000);
			},
			preview: function (id, s) {
				this.stop();
				(RINGTONES[id] || RINGTONES.classico).play(beep, level(s) * 0.5);
			},
			notify: function (s) {
				if (s.dnd) { return; }
				if (!s.silent) {
					const volume = level(s) * 0.4;
					beep([1046], 0.12, volume);
					setTimeout(function () { beep([1568], 0.16, volume); }, 130);
				} else if (s.vibrate) {
					buzz();
				}
			},
			click: function () { beep([1800], 0.03, 0.05); },
			stop: function () {
				timers.forEach(clearInterval);
				timers = [];
			}
		};
	})();

	// Ajustes ---------------------------------------------------------------------------------------------

	function signalSvg(bars) {
		let out = '<svg class="phone-bars" viewBox="0 0 20 16">';
		for (let i = 0; i < 4; i++) {
			const height = 4 + i * 3.5;
			out += '<rect x="' + (1 + i * 5) + '" y="' + (15 - height) + '" width="3.2" height="' + height + '"' + (i < bars ? ' class="is-on"' : '') + '/>';
		}
		return out + '</svg>';
	}

	function paintBar() {
		const air = settings.airplane;
		els.signal.innerHTML = air ? svg('airplane') : signalSvg(signal.bars);
		els.signal.title = air ? 'Modo avião' : 'Sinal: ' + signal.bars + ' de 4';
		els.signal.classList.toggle('is-none', !air && signal.bars === 0);
		els.carrier.textContent = air ? 'Modo avião' : (signal.bars > 0 ? 'COE' : 'Sem serviço');
		const icons = [];
		if (settings.wifi) { icons.push(['wifi', signal.indoor ? 'Wi-Fi conectado' : 'Wi-Fi ligado, sem rede por perto', !signal.indoor]); }
		if (settings.bluetooth) { icons.push(['bluetooth', 'Bluetooth ligado', false]); }
		if (settings.dnd) { icons.push(['moon', 'Não perturbe', false]); }
		if (settings.silent) { icons.push(['bellOff', 'Modo silencioso', false]); }
		els.indicators.replaceChildren();
		icons.forEach(function (entry) {
			const node = document.createElement('i');
			node.title = entry[1];
			node.innerHTML = svg(entry[0]);
			if (entry[2]) { node.className = 'is-dim'; }
			els.indicators.appendChild(node);
		});
	}

	function applySettings() {
		els.screen.dataset.wallpaper = WALLPAPERS[settings.wallpaper] ? settings.wallpaper : 'padrao';
		const brightness = Math.max(30, Math.min(100, Number(settings.brightness) || 100));
		els.dim.style.opacity = String(((100 - brightness) / 70) * 0.6);
		els.keySilent.classList.toggle('is-on', settings.silent === true);
		paintBar();
		emit('settings', settings);
	}

	function flushSettings() {
		clearTimeout(patchTimer);
		const patch = pendingPatch;
		pendingPatch = {};
		if (Object.keys(patch).length === 0) { return Promise.resolve(null); }
		return call_('settings', 'save', { settings: patch }).then(function (result) {
			if (result && result.ok && result.data) {
				settings = Object.assign({}, DEFAULT_SETTINGS, result.data.settings || {});
				if (profile && profile.device && 'myFace' in result.data) { profile.device.myFace = result.data.myFace === true; }
				applySettings();
			} else {
				setStatus(errorText(result && result.error), 'error');
				post('refresh');
			}
			return result;
		});
	}

	// Aplica na hora e grava em lote (sliders e botões laterais geram vários cliques seguidos).
	function changeSetting(patch) {
		const before = settings;
		settings = Object.assign({}, settings, patch);
		if (patch.airplane === true && !before.airplane) {
			if (!('wifi' in patch)) { settings.wifi = false; }
			if (!('bluetooth' in patch)) { settings.bluetooth = false; }
		}
		applySettings();
		Object.assign(pendingPatch, patch);
		clearTimeout(patchTimer);
		patchTimer = setTimeout(flushSettings, 450);
	}

	function showHud(kind) {
		els.hud.replaceChildren();
		const icon = document.createElement('i');
		const label = document.createElement('span');
		if (kind === 'silent') {
			icon.innerHTML = svg(settings.silent ? 'bellOff' : 'bell');
			label.textContent = settings.silent ? 'Silencioso' + (settings.vibrate ? ' (vibrar)' : '') : 'Som ativado';
			els.hud.append(icon, label);
		} else {
			icon.innerHTML = svg(settings.silent ? 'bellOff' : 'volume');
			label.textContent = 'Volume ' + settings.volume + (settings.silent ? ' · silencioso' : '');
			const meter = document.createElement('div');
			meter.className = 'phone-hud-meter';
			for (let i = 0; i < 10; i++) {
				const step = document.createElement('b');
				if (i < settings.volume) { step.className = 'is-on'; }
				meter.appendChild(step);
			}
			els.hud.append(icon, label, meter);
		}
		els.hud.hidden = false;
		clearTimeout(hudTimer);
		hudTimer = setTimeout(function () { els.hud.hidden = true; }, 1400);
	}

	// Botões de volume também calam o toque de uma chamada recebida, como num aparelho de verdade.
	function quietRinging() {
		if (call && call.state === 'incoming') { tone.stop(); }
	}

	function volumeStep(delta) {
		quietRinging();
		const volume = Math.max(0, Math.min(10, (Number(settings.volume) || 0) + delta));
		if (volume !== settings.volume) { changeSetting({ volume: volume }); }
		tone.click();
		showHud('volume');
	}

	function toggleSilent() {
		quietRinging();
		changeSetting({ silent: !settings.silent });
		showHud('silent');
	}

	// Tela de bloqueio ------------------------------------------------------------------------------------

	function limits() {
		return Object.assign({ MinLength: 4, MaxLength: 6 }, profile.passcode || {});
	}

	function lockButton(label, className, onClick) {
		const button = document.createElement('button');
		button.type = 'button';
		button.className = className;
		button.innerHTML = label;
		button.addEventListener('click', onClick);
		return button;
	}

	function paintLock() {
		const body = els.lockBody;
		body.replaceChildren();
		if (settings.faceId && !lockFallback) {
			const face = document.createElement('i');
			face.className = 'phone-lock-face is-scanning';
			face.innerHTML = svg('face');
			const text = document.createElement('p');
			text.textContent = 'Reconhecendo rosto...';
			body.append(face, text, lockButton('Usar senha', 'phone-lock-link', function () { lockFallback = true; paintLock(); }));
			setTimeout(function () {
				if (!locked || lockFallback || !isOpen) { return; }
				call_('settings', 'unlock', { face: true }).then(function (result) {
					if (!locked) { return; }
					if (result && result.ok) {
						face.classList.remove('is-scanning');
						face.classList.add('is-ok');
						text.textContent = 'Desbloqueado';
						setTimeout(unlock, 350);
					} else {
						lockFallback = true;
						lockMessage = 'Rosto não reconhecido.';
						paintLock();
					}
				});
			}, 900);
			return;
		}
		const icon = document.createElement('i');
		icon.className = 'phone-lock-icon';
		icon.innerHTML = svg('lock');
		const dots = document.createElement('div');
		dots.className = 'phone-lock-dots';
		for (let i = 0; i < limits().MaxLength; i++) {
			const dot = document.createElement('b');
			if (i < lockCode.length) { dot.className = 'is-on'; }
			dots.appendChild(dot);
		}
		const message = document.createElement('p');
		message.className = lockMessage ? 'is-error' : '';
		message.textContent = lockMessage || 'Digite a senha';
		const pad = document.createElement('div');
		pad.className = 'phone-lock-pad';
		['1', '2', '3', '4', '5', '6', '7', '8', '9', 'del', '0', 'ok'].forEach(function (key) {
			if (key === 'del') {
				pad.appendChild(lockButton('⌫', 'is-muted', function () { lockKey('Backspace'); }));
			} else if (key === 'ok') {
				pad.appendChild(lockButton('OK', 'is-ok', function () { lockKey('Enter'); }));
			} else {
				pad.appendChild(lockButton(key, '', function () { lockKey(key); }));
			}
		});
		body.append(icon, dots, message, pad);
		if (settings.faceId) {
			body.appendChild(lockButton('Tentar rosto de novo', 'phone-lock-link', function () { lockFallback = false; lockMessage = ''; paintLock(); }));
		}
	}

	function lockKey(key) {
		if (/^\d$/.test(key)) {
			if (lockCode.length < limits().MaxLength) { lockCode += key; }
			lockMessage = '';
			paintLock();
			return;
		}
		if (key === 'Backspace') {
			lockCode = lockCode.slice(0, -1);
			paintLock();
			return;
		}
		if (key === 'Enter') {
			if (lockCode.length < limits().MinLength) {
				lockMessage = 'A senha tem pelo menos ' + limits().MinLength + ' números.';
				paintLock();
				return;
			}
			const code = lockCode;
			lockCode = '';
			call_('settings', 'unlock', { code: code }).then(function (result) {
				if (!locked) { return; }
				if (result && result.ok) {
					unlock();
					return;
				}
				lockMessage = result && result.error === 'locked_out' && result.data
					? 'Muitas tentativas. Aguarde ' + result.data.wait + ' s.'
					: errorText(result && result.error);
				paintLock();
				els.lockBody.classList.remove('is-shake');
				void els.lockBody.offsetWidth;
				els.lockBody.classList.add('is-shake');
			});
		}
	}

	function showLock() {
		locked = true;
		lockCode = '';
		lockMessage = '';
		lockFallback = false;
		els.lock.hidden = false;
		paintLock();
	}

	function unlock() {
		locked = false;
		lockCode = '';
		els.lock.hidden = true;
		els.lockBody.replaceChildren();
	}

	// Telas iniciais --------------------------------------------------------------------------------------

	function readLayout(raw) {
		const data = raw && typeof raw === 'object' ? raw : {};
		const clean = function (list) { return toArray(list).filter(function (id) { return typeof id === 'string'; }); };
		const pages = toArray(data.pages).map(clean);
		return { pages: pages.length ? pages : [[]], dock: clean(data.dock) };
	}

	function locate(id) {
		let index = layout.dock.indexOf(id);
		if (index >= 0) { return { list: layout.dock, index: index }; }
		for (let p = 0; p < layout.pages.length; p++) {
			index = layout.pages[p].indexOf(id);
			if (index >= 0) { return { list: layout.pages[p], index: index }; }
		}
		return null;
	}

	function capacityOf(list) {
		return list === layout.dock ? home.DockSize : home.PageSize;
	}

	// Move o app para a posição `index` da lista. Lista cheia: troca de lugar com o app que está ali.
	function move(id, list, index) {
		const from = locate(id);
		if (!from) { return; }
		if (list !== from.list && list.length >= capacityOf(list)) {
			if (index < list.length) {
				const other = list[index];
				list[index] = id;
				from.list[from.index] = other;
				commitLayout();
			} else {
				setStatus(list === layout.dock ? 'A barra inferior está cheia.' : 'Esta tela está cheia.', 'error');
			}
			return;
		}
		from.list.splice(from.index, 1);
		list.splice(Math.min(index, list.length), 0, id);
		commitLayout();
	}

	function commitLayout() {
		paintHome();
		layoutDirty = true;
		clearTimeout(layoutTimer);
		layoutTimer = setTimeout(flushLayout, 600);
	}

	function flushLayout() {
		clearTimeout(layoutTimer);
		if (!layoutDirty) { return Promise.resolve(null); }
		layoutDirty = false;
		return call_('settings', 'save', { layout: layout }).then(function (result) {
			if (result && result.ok && result.data) {
				if (!dragId && !layoutDirty) {
					layout = readLayout(result.data.layout);
					paintHome();
				}
			} else {
				setStatus(errorText(result && result.error), 'error');
			}
			return result;
		});
	}

	function resetLayout() {
		layoutDirty = false;
		clearTimeout(layoutTimer);
		return call_('settings', 'save', { resetLayout: true }).then(function (result) {
			if (result && result.ok && result.data) {
				layout = readLayout(result.data.layout);
				page = 0;
				paintHome();
			}
			return result;
		});
	}

	function setEditing(value) {
		editing = value;
		suppressClick = false;
		if (!value) { flushLayout(); }
		setStatus('');
		paintHome();
	}

	function addPage() {
		if (layout.pages.length >= home.MaxPages) { return false; }
		layout.pages.push([]);
		page = layout.pages.length - 1;
		commitLayout();
		return true;
	}

	function removePage() {
		if (layout.pages.length < 2 || layout.pages[page].length > 0) { return; }
		layout.pages.splice(page, 1);
		page = Math.min(page, layout.pages.length - 1);
		commitLayout();
	}

	function goPage(index) {
		const next = Math.max(0, Math.min(layout.pages.length - 1, index));
		if (next === page) { return; }
		page = next;
		els.track.style.transform = 'translateX(' + (-page * 100) + '%)';
		paintDots();
		paintEditBar();
	}

	function dropZone(node, list) {
		node.addEventListener('dragover', function (event) {
			if (editing && dragId) { event.preventDefault(); node.classList.add('is-over'); }
		});
		node.addEventListener('dragleave', function (event) {
			if (!node.contains(event.relatedTarget)) { node.classList.remove('is-over'); }
		});
		node.addEventListener('drop', function (event) {
			node.classList.remove('is-over');
			if (!editing || !dragId) { return; }
			event.preventDefault();
			const target = list();
			move(dragId, target, target.length);
		});
	}

	function iconFor(app) {
		const button = document.createElement('button');
		button.type = 'button';
		button.className = 'phone-icon';
		button.dataset.app = app.id;
		button.title = app.label;
		const tile = document.createElement('i');
		paintIcon(tile, app);
		const label = document.createElement('span');
		label.textContent = app.label;
		button.append(tile, label);
		button.addEventListener('click', function () {
			if (editing || suppressClick) { suppressClick = false; return; }
			render(app.id);
		});
		// Segurar o ícone entra no modo de edição.
		button.addEventListener('mousedown', function (event) {
			if (editing || event.button !== 0) { return; }
			clearTimeout(pressTimer);
			pressTimer = setTimeout(function () { suppressClick = true; setEditing(true); }, 550);
		});
		button.addEventListener('mouseup', function () { clearTimeout(pressTimer); });
		button.addEventListener('mouseleave', function () { clearTimeout(pressTimer); });
		if (editing) {
			button.draggable = true;
			button.addEventListener('dragstart', function (event) {
				dragId = app.id;
				event.dataTransfer.effectAllowed = 'move';
				event.dataTransfer.setData('text/plain', app.id);
				setTimeout(function () { button.classList.add('is-dragging'); }, 0);
			});
			button.addEventListener('dragend', function () {
				dragId = null;
				clearTimeout(edgeTimer);
				button.classList.remove('is-dragging');
				document.querySelectorAll('.is-over, .is-target').forEach(function (node) { node.classList.remove('is-over', 'is-target'); });
			});
			button.addEventListener('dragover', function (event) {
				if (dragId && dragId !== app.id) { event.preventDefault(); button.classList.add('is-target'); }
			});
			button.addEventListener('dragleave', function () { button.classList.remove('is-target'); });
			button.addEventListener('drop', function (event) {
				event.preventDefault();
				event.stopPropagation();
				button.classList.remove('is-target');
				if (!dragId || dragId === app.id) { return; }
				const target = locate(app.id);
				if (target) { move(dragId, target.list, target.index); }
			});
		}
		return button;
	}

	function paintDots() {
		els.dots.replaceChildren();
		layout.pages.forEach(function (_, index) {
			const dot = document.createElement('button');
			dot.type = 'button';
			dot.className = 'phone-dot' + (index === page ? ' is-active' : '');
			dot.title = 'Tela ' + (index + 1);
			dot.addEventListener('click', function () { goPage(index); });
			dot.addEventListener('dragover', function (event) { if (editing && dragId) { event.preventDefault(); dot.classList.add('is-over'); } });
			dot.addEventListener('dragleave', function () { dot.classList.remove('is-over'); });
			dot.addEventListener('drop', function (event) {
				if (!editing || !dragId) { return; }
				event.preventDefault();
				const id = dragId;
				goPage(index);
				move(id, layout.pages[index], layout.pages[index].length);
			});
			els.dots.appendChild(dot);
		});
		els.dots.hidden = layout.pages.length < 2;
	}

	function paintEditBar() {
		els.edit.hidden = !editing;
		if (!editing) { return; }
		els.edit.replaceChildren();
		const make = function (label, className, disabled, onClick) {
			const button = document.createElement('button');
			button.type = 'button';
			button.className = 'coe-button ' + className;
			button.textContent = label;
			button.disabled = disabled;
			button.addEventListener('click', onClick);
			return button;
		};
		els.edit.append(
			make('+ Tela', '', layout.pages.length >= home.MaxPages, addPage),
			make('Apagar tela', 'coe-button--danger', layout.pages.length < 2 || layout.pages[page].length > 0, removePage),
			make('Concluir', 'coe-button--primary', false, function () { setEditing(false); })
		);
	}

	function paintHome() {
		page = Math.max(0, Math.min(page, layout.pages.length - 1));
		els.track.replaceChildren();
		const anyApp = layout.pages.some(function (ids) { return ids.length > 0; });
		layout.pages.forEach(function (ids, index) {
			const grid = document.createElement('div');
			grid.className = 'phone-grid';
			grid.dataset.page = String(index);
			ids.forEach(function (id) {
				const app = findApp(id);
				if (app) { grid.appendChild(iconFor(app)); }
			});
			if (ids.length === 0 && (editing || (!anyApp && index === 0))) {
				const empty = document.createElement('p');
				empty.className = 'phone-empty';
				empty.textContent = editing ? 'Arraste apps para esta tela.' : 'Instale apps pela Loja.';
				grid.appendChild(empty);
			}
			dropZone(grid, function () { return layout.pages[index]; });
			els.track.appendChild(grid);
		});
		els.track.style.transform = 'translateX(' + (-page * 100) + '%)';
		els.dock.replaceChildren();
		layout.dock.forEach(function (id) {
			const app = findApp(id);
			if (app) { els.dock.appendChild(iconFor(app)); }
		});
		els.root.classList.toggle('is-editing', editing);
		els.number.textContent = profile.display ? 'MEU NÚMERO  ' + profile.display : 'SEM CHIP';
		paintDots();
		paintEditBar();
		paintBadges();
	}

	function edgeHover(direction) {
		clearTimeout(edgeTimer);
		edgeTimer = setTimeout(function () {
			if (!dragId) { return; }
			if (direction > 0 && page === layout.pages.length - 1) {
				// Arrastar para a borda da última tela cria uma tela nova.
				if (layout.pages.length < home.MaxPages) {
					layout.pages.push([]);
					layoutDirty = true;
					page = layout.pages.length - 1;
					paintHomeKeepingDrag();
				}
				return;
			}
			goPage(page + direction);
		}, 450);
	}

	// Repinta as telas sem recriar o ícone arrastado (perderia o arrasto em andamento).
	function paintHomeKeepingDrag() {
		const grid = document.createElement('div');
		grid.className = 'phone-grid';
		const index = layout.pages.length - 1;
		grid.dataset.page = String(index);
		const empty = document.createElement('p');
		empty.className = 'phone-empty';
		empty.textContent = 'Arraste apps para esta tela.';
		grid.appendChild(empty);
		dropZone(grid, function () { return layout.pages[index]; });
		els.track.appendChild(grid);
		els.track.style.transform = 'translateX(' + (-page * 100) + '%)';
		paintDots();
		paintEditBar();
	}

	[[els.edgeLeft, -1], [els.edgeRight, 1]].forEach(function (entry) {
		entry[0].addEventListener('dragenter', function () { if (editing && dragId) { edgeHover(entry[1]); } });
		entry[0].addEventListener('dragover', function (event) { if (editing && dragId) { event.preventDefault(); } });
		entry[0].addEventListener('dragleave', function () { clearTimeout(edgeTimer); });
	});
	dropZone(els.dock, function () { return layout.dock; });

	// Trocar de tela: roda do mouse, arrastar para o lado ou as setas.
	let wheelAt = 0;
	els.pages.addEventListener('wheel', function (event) {
		const delta = Math.abs(event.deltaX) > Math.abs(event.deltaY) ? event.deltaX : event.deltaY;
		if (Math.abs(delta) < 8 || Date.now() - wheelAt < 380) { return; }
		wheelAt = Date.now();
		goPage(page + (delta > 0 ? 1 : -1));
	}, { passive: true });
	let swipeX = null;
	els.pages.addEventListener('mousedown', function (event) { if (!editing && event.button === 0) { swipeX = event.clientX; } });
	window.addEventListener('mouseup', function (event) {
		if (swipeX === null) { return; }
		const dx = event.clientX - swipeX;
		swipeX = null;
		if (Math.abs(dx) > 50) {
			clearTimeout(pressTimer);
			suppressClick = true;
			setTimeout(function () { suppressClick = false; }, 0);
			goPage(page + (dx < 0 ? 1 : -1));
		}
	});

	function paintBadges() {
		document.querySelectorAll('.phone-icon[data-app="messages"]').forEach(function (button) {
			let badge = button.querySelector('.phone-badge');
			if (unread > 0) {
				if (!badge) {
					badge = document.createElement('b');
					badge.className = 'phone-badge';
					button.appendChild(badge);
				}
				badge.textContent = unread > 99 ? '99+' : String(unread);
			} else if (badge) {
				badge.remove();
			}
		});
	}

	// Apps ------------------------------------------------------------------------------------------------

	const api = {
		register: function (id, renderFn) { registry[id] = renderFn; },
		call: call_,
		waypoint: function (x, y) { return post('waypoint', { x: x, y: y }); },
		camera: function () { return post('camera'); },
		upload: function (image) { return post('upload', { image: image }); },
		savePhoto: function (image, thumb) { return post('savePhoto', { image: image, thumb: thumb }); },
		refresh: function () { return post('refresh'); },
		icon: function (node, app) { paintIcon(node, app); },
		svg: svg,
		status: setStatus,
		errorText: errorText,
		device: 'phone',
		// Liga para um número (o servidor responde com o estado da ligação). kind: 'voice' (padrão) ou 'video'.
		dial: function (number, kind) {
			return call_('phone', 'dial', { number: number, kind: kind === 'video' ? 'video' : 'voice' }).then(function (result) {
				if (!result || !result.ok) { setStatus(errorText(result && result.error), 'error'); }
				return result;
			});
		},
		openApp: function (id, args) { render(id, args); },
		on: function (event, fn) { listeners.push({ event: event, fn: fn }); },
		profile: function () { return profile; },
		formatNumber: formatNumber,
		setUnread: function (value) { unread = Math.max(0, Number(value) || 0); paintBadges(); },
		// Ajustes
		settings: function () { return settings; },
		signal: function () { return signal; },
		changeSetting: changeSetting,
		ringtones: function () { return Object.keys(RINGTONES).map(function (id) { return { id: id, label: RINGTONES[id].label }; }); },
		wallpapers: function () { return Object.keys(WALLPAPERS).map(function (id) { return { id: id, label: WALLPAPERS[id] }; }); },
		previewRingtone: function (id) { tone.preview(id, sound()); },
		hasPasscode: function () { return profile.hasPasscode === true; },
		passcodeLimits: limits,
		passcodeChanged: function (data) {
			profile.hasPasscode = data && data.hasPasscode === true;
			if (data && data.settings) {
				settings = Object.assign({}, DEFAULT_SETTINGS, data.settings);
				applySettings();
			}
		},
		editHome: function () { showHome(); setEditing(true); },
		resetHome: resetLayout,
		pageCount: function () { return layout.pages.length; }
	};
	window.CoeTablet = api;
	window.CoePhone = api;

	function render(id, args) {
		const app = findApp(id);
		if (!app) { return; }
		if (editing) { setEditing(false); }
		current = id;
		listeners = [];
		els.app.replaceChildren();
		setStatus('');
		els.title.textContent = app.label;
		paintIcon(els.icon, app);
		els.home.hidden = true;
		els.view.hidden = false;
		els.root.classList.add('is-in-app');
		const renderer = registry[app.id];
		if (renderer) {
			renderer(els.app, api, args || {});
		} else {
			setStatus(errorText('app_unavailable'), 'error');
		}
	}

	function showHome() {
		current = null;
		listeners = [];
		els.app.replaceChildren();
		setStatus('');
		els.view.hidden = true;
		els.home.hidden = false;
		els.root.classList.remove('is-in-app');
	}

	function loadScripts() {
		const scripts = [];
		apps.forEach(function (app) {
			if (app.script && scripts.indexOf(app.script) < 0 && !loaded[app.script]) { scripts.push(app.script); }
		});
		return Promise.all(scripts.map(function (src) {
			return new Promise(function (resolve) {
				const script = document.createElement('script');
				script.src = src;
				script.onload = function () { loaded[src] = true; resolve(); };
				script.onerror = function () { resolve(); };
				document.head.appendChild(script);
			});
		}));
	}

	function tick() {
		const now = new Date();
		const time = String(now.getHours()).padStart(2, '0') + ':' + String(now.getMinutes()).padStart(2, '0');
		const date = now.toLocaleDateString('pt-BR', { weekday: 'long', day: 'numeric', month: 'long' });
		els.heroClock.textContent = time;
		els.heroDate.textContent = date;
		els.lockClock.textContent = time;
		els.lockDate.textContent = date;
	}

	function loadProfile(data) {
		profile = data;
		apps = toArray(data.apps);
		home = Object.assign({ PageSize: 16, MaxPages: 6, DockSize: 4 }, data.home || {});
		settings = Object.assign({}, DEFAULT_SETTINGS, data.settings || {});
		pendingPatch = {};
		layout = readLayout(data.layout);
		layoutDirty = false;
		unread = Number(data.unread) || 0;
		if (typeof data.signal === 'number') { signal = { bars: data.signal, indoor: signal.indoor }; }
	}

	function open(data) {
		loadProfile(data);
		editing = false;
		page = 0;
		paintHome();
		applySettings();
		showHome();
		isOpen = true;
		tick();
		clearInterval(clockTimer);
		clockTimer = setInterval(tick, 15000);
		els.root.classList.add('is-open');
		els.root.setAttribute('aria-hidden', 'false');
		if (data.hasPasscode) { showLock(); } else { unlock(); }
		loadScripts();
		paintCall();
	}

	function refreshed(data) {
		if (!isOpen) { return; }
		const wasEditing = editing;
		loadProfile(data);
		editing = wasEditing && !dragId;
		paintHome();
		applySettings();
		loadScripts();
		if (current && !findApp(current)) { showHome(); }
	}

	function close() {
		isOpen = false;
		editing = false;
		dragId = null;
		clearInterval(clockTimer);
		clearTimeout(hudTimer);
		els.hud.hidden = true;
		els.root.classList.remove('is-open', 'is-editing');
		els.root.setAttribute('aria-hidden', 'true');
		showHome();
		paintCall();
	}

	// Grava o que estiver pendente antes de fechar (com o celular fechado o cliente recusa chamadas).
	function requestClose() {
		Promise.all([flushSettings(), flushLayout()]).then(function () { post('close'); });
	}

	// Ligação ---------------------------------------------------------------------------------------------

	const ENDED = {
		answered: 'Ligação encerrada', missed: 'Não atendida', declined: 'Recusada', busy: 'Ocupado', unavailable: 'Fora de área',
		no_credit: 'Crédito esgotado'
	};

	function duration() {
		if (!call || !call.startedAt) { return '00:00'; }
		const seconds = Math.max(0, Math.floor(Date.now() / 1000) - call.startedAt);
		return String(Math.floor(seconds / 60)).padStart(2, '0') + ':' + String(seconds % 60).padStart(2, '0');
	}

	function actionButton(kind, label, icon, onClick) {
		const button = document.createElement('button');
		button.type = 'button';
		button.className = 'is-' + kind;
		const tile = document.createElement('i');
		tile.innerHTML = svg(icon);
		const text = document.createElement('span');
		text.textContent = label;
		button.append(tile, text);
		button.addEventListener('click', onClick);
		return button;
	}

	function control(action) {
		call_('phone', action).then(function (result) {
			if (!result || !result.ok) { setStatus(errorText(result && result.error), 'error'); }
		});
	}

	function stateText() {
		if (!call) { return ''; }
		const video = call.kind === 'video';
		if (call.state === 'incoming') { return video ? 'Chamada de vídeo recebida' : 'Chamada recebida'; }
		if (call.state === 'outgoing') { return video ? 'Chamada de vídeo...' : 'Chamando...'; }
		if (call.state === 'active') { return (video ? 'Vídeo · ' : '') + duration(); }
		return ENDED[call.reason] || 'Ligação encerrada';
	}

	function paintCall() {
		const has = call !== null;
		const ringing = has && call.state === 'incoming';
		const snd = (has && call.sound) || sound();
		const buzzing = ringing && snd.vibrate && !snd.dnd;
		const showFull = has && isOpen && !(call.state === 'active' && callMinimized);
		els.call.hidden = !showFull;
		els.call.classList.toggle('is-ringing', ringing);
		els.root.classList.toggle('is-buzzing', buzzing && isOpen);
		els.pill.hidden = !(has && isOpen && call.state === 'active' && callMinimized);
		els.pill.textContent = 'Em ligação ' + duration();
		els.peek.hidden = !(has && !isOpen);
		els.peek.classList.toggle('is-ringing', ringing);
		els.peek.classList.toggle('is-buzzing', buzzing);
		if (!has) { return; }

		const label = call.name || call.number || '?';
		els.callName.textContent = label;
		els.callNumber.textContent = call.name && call.name !== call.number ? call.number : '';
		els.callAvatar.textContent = /\d/.test(label.charAt(0)) ? '' : label.charAt(0).toUpperCase();
		if (!els.callAvatar.textContent) { els.callAvatar.innerHTML = svg('contacts'); }
		els.callState.textContent = stateText();

		els.peekName.textContent = label;
		const key = profile.openKey || 'F1';
		els.peekState.textContent = ringing ? 'Chamada recebida · ' + key + ' para atender' : stateText();
		const peekIcon = els.peek.querySelector('i');
		if (!peekIcon.firstChild) { peekIcon.innerHTML = svg('phone'); }

		els.callActions.replaceChildren();
		if (call.state === 'incoming') {
			els.callActions.append(
				actionButton('hangup', 'Recusar', 'phone', function () { control('hangup'); }),
				actionButton('answer', 'Atender', 'phone', function () { control('answer'); })
			);
		} else if (call.state === 'outgoing') {
			els.callActions.append(actionButton('hangup', 'Cancelar', 'phone', function () { control('hangup'); }));
		} else if (call.state === 'active') {
			els.callActions.append(
				actionButton('minimize', 'Ocultar', 'minimize', function () { callMinimized = true; paintCall(); }),
				actionButton('hangup', 'Desligar', 'phone', function () { control('hangup'); })
			);
		}
	}

	function onCall(state) {
		clearTimeout(endedTimer);
		clearInterval(callTimer);
		if (state.state === 'ended') {
			tone.stop();
			if (!call) { return; }
			call = Object.assign({}, call, { state: 'ended', reason: state.reason });
			paintCall();
			emit('call', call);
			endedTimer = setTimeout(function () {
				call = null;
				callMinimized = false;
				paintCall();
			}, 1800);
			return;
		}
		if (!call || call.id !== state.id) { callMinimized = false; }
		call = state;
		const snd = Object.assign(sound(), state.sound || {});
		if (state.state === 'incoming') { tone.ring(snd); }
		else if (state.state === 'outgoing') { tone.ringback(snd); }
		else { tone.stop(); }
		if (state.state === 'active') {
			callTimer = setInterval(paintCall, 1000);
		}
		paintCall();
		emit('call', call);
	}

	// O app Mensagens corrige o total quando lista as conversas ou abre a conversa.
	function onMessage(message) {
		unread += 1;
		paintBadges();
		if (!call) { tone.notify(Object.assign(sound(), message.sound || {})); }
		emit('message', message);
	}

	function onSignal(data) {
		signal = { bars: Math.max(0, Math.min(4, Number(data.bars) || 0)), indoor: data.indoor === true };
		paintBar();
		emit('signal', signal);
	}

	// Eventos ---------------------------------------------------------------------------------------------

	els.back.addEventListener('click', showHome);
	els.homeButton.addEventListener('click', function () {
		if (editing) { setEditing(false); return; }
		if (!current) { goPage(0); }
		showHome();
	});
	els.pill.addEventListener('click', function () { callMinimized = false; paintCall(); });
	els.keyUp.addEventListener('click', function () { volumeStep(1); });
	els.keyDown.addEventListener('click', function () { volumeStep(-1); });
	els.keySilent.addEventListener('click', toggleSilent);
	els.keyPower.addEventListener('click', requestClose);

	document.addEventListener('keydown', function (event) {
		if (!isOpen) { return; }
		if (event.key === 'F1') { event.preventDefault(); requestClose(); return; }
		const typing = /^(INPUT|TEXTAREA|SELECT)$/.test((event.target && event.target.tagName) || '');
		if (locked && !(call && !callMinimized && call.state !== 'ended')) {
			if (event.key === 'Escape') { requestClose(); return; }
			if (/^\d$/.test(event.key) || event.key === 'Backspace' || event.key === 'Enter') { event.preventDefault(); lockKey(event.key); }
			return;
		}
		if (!typing && !current && (event.key === 'ArrowLeft' || event.key === 'ArrowRight')) {
			goPage(page + (event.key === 'ArrowRight' ? 1 : -1));
			return;
		}
		if (event.key !== 'Escape') { return; }
		if (call && call.state === 'active' && !callMinimized) { callMinimized = true; paintCall(); return; }
		if (editing) { setEditing(false); return; }
		if (current) { showHome(); } else { requestClose(); }
	});
	window.addEventListener('message', function (event) {
		const message = event.data || {};
		if (message.action === 'open') { open(message.data || {}); }
		if (message.action === 'close') { close(); }
		if (message.action === 'profile') { refreshed(message.data || {}); }
		if (message.action === 'suspend') { els.root.classList.toggle('is-suspended', message.data === true); }
		if (message.action === 'call') { onCall(message.data || {}); }
		if (message.action === 'message') { onMessage(message.data || {}); }
		if (message.action === 'signal') { onSignal(message.data || {}); }
	});
	window.addEventListener('coe:localeChanged', function () {
		if (window.CoeUI && typeof window.CoeUI.translateDOM === 'function') {
			window.CoeUI.translateDOM(document);
		}
	});

	if (window.CoeUI && typeof window.CoeUI.translateDOM === 'function') {
		window.CoeUI.translateDOM(document);
	}
})();
