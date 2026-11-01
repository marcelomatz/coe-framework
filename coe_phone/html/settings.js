// App nativo Ajustes: conexões, sons, tela, tela inicial, segurança e informações do aparelho.
(function () {
	'use strict';

	const phone = window.CoePhone;

	function el(tag, className, text) {
		const node = document.createElement(tag);
		if (className) { node.className = className; }
		if (text !== undefined && text !== null) { node.textContent = String(text); }
		return node;
	}

	function button(label, className, onClick) {
		const node = el('button', 'coe-button ' + (className || ''), label);
		node.type = 'button';
		node.addEventListener('click', onClick);
		return node;
	}

	function codeInput(placeholder, max) {
		const node = el('input', 'coe-field st-code');
		node.type = 'password';
		node.inputMode = 'numeric';
		node.maxLength = max;
		node.placeholder = placeholder;
		node.addEventListener('input', function () { node.value = node.value.replace(/\D/g, ''); });
		return node;
	}

	phone.register('settings', function (root, api) {
		const page = el('div', 'st-page');
		root.appendChild(page);
		let securityOpen = false;
		let simPicker = null;

		function section(title) {
			const box = el('section', 'st-section');
			box.appendChild(el('h3', 'st-title', title));
			page.appendChild(box);
			return box;
		}

		function rowBase(icon, label, detail) {
			const row = el('div', 'st-row');
			const tile = el('i', 'st-icon');
			tile.innerHTML = api.svg(icon);
			const body = el('div', 'st-body');
			body.appendChild(el('strong', null, label));
			if (detail) { body.appendChild(el('small', null, detail)); }
			row.append(tile, body);
			return row;
		}

		function toggle(icon, label, detail, key, disabled) {
			const row = rowBase(icon, label, detail);
			const value = api.settings()[key] === true;
			const sw = el('button', 'st-switch' + (value ? ' is-on' : ''));
			sw.type = 'button';
			sw.setAttribute('role', 'switch');
			sw.setAttribute('aria-checked', String(value));
			sw.disabled = disabled === true;
			sw.appendChild(el('span'));
			sw.addEventListener('click', function () {
				const patch = {};
				patch[key] = !value;
				api.changeSetting(patch);
			});
			row.appendChild(sw);
			if (disabled) { row.classList.add('is-disabled'); }
			return row;
		}

		function range(icon, label, key, min, max, suffix) {
			const row = rowBase(icon, label, null);
			row.classList.add('st-row--range');
			const value = el('em', 'st-value', api.settings()[key] + (suffix || ''));
			const slider = el('input', 'st-range');
			slider.type = 'range';
			slider.min = min;
			slider.max = max;
			slider.value = api.settings()[key];
			const fill = function () { slider.style.setProperty('--fill', ((slider.value - min) / (max - min) * 100) + '%'); };
			fill();
			slider.addEventListener('input', function () {
				value.textContent = slider.value + (suffix || '');
				fill();
				const patch = {};
				patch[key] = Number(slider.value);
				api.changeSetting(patch);
			});
			row.append(value, slider);
			return row;
		}

		function security(box) {
			const has = api.hasPasscode();
			const limits = api.passcodeLimits();
			const row = rowBase('lock', 'Senha', has ? 'Ativada' : 'Desativada');
			row.appendChild(button(has ? 'Alterar' : 'Definir', '', function () { securityOpen = !securityOpen; paint(); }));
			box.appendChild(row);
			if (securityOpen) {
				const form = el('div', 'st-form');
				const current = has ? codeInput('Senha atual', limits.MaxLength) : null;
				const code = codeInput('Nova senha (' + limits.MinLength + ' a ' + limits.MaxLength + ' números)', limits.MaxLength);
				const confirm = codeInput('Repita a nova senha', limits.MaxLength);
				if (current) { form.appendChild(current); }
				form.append(code, confirm);
				const send = function (newCode) {
					api.call('settings', 'passcode', { current: current ? current.value : '', code: newCode }).then(function (result) {
						if (result && result.ok) {
							api.passcodeChanged(result.data);
							securityOpen = false;
							api.status(newCode ? 'Senha salva.' : 'Senha removida.', 'ok');
							paint();
						} else if (result && result.error === 'locked_out' && result.data) {
							api.status('Muitas tentativas. Aguarde ' + result.data.wait + ' s.', 'error');
						} else {
							api.status(api.errorText(result && result.error), 'error');
						}
					});
				};
				const actions = el('div', 'st-actions');
				actions.appendChild(button('Salvar', 'coe-button--primary', function () {
					if (code.value.length < limits.MinLength) { api.status(api.errorText('invalid_passcode'), 'error'); return; }
					if (code.value !== confirm.value) { api.status('As senhas não conferem.', 'error'); return; }
					send(code.value);
				}));
				if (has) { actions.appendChild(button('Remover senha', 'coe-button--danger', function () { send(''); })); }
				actions.appendChild(button('Cancelar', '', function () { securityOpen = false; paint(); }));
				form.appendChild(actions);
				box.appendChild(form);
				(current || code).focus();
			}
			const device = api.profile().device || {};
			const faceDetail = !has ? 'Defina uma senha antes'
				: (api.settings().faceId && !device.myFace ? 'Cadastrado com outro rosto' : 'Desbloqueia olhando para a tela');
			box.appendChild(toggle('face', 'Reconhecimento facial', faceDetail, 'faceId', !has));
		}

		// Chips no aparelho: cada um pode ser retirado (volta para o inventário como item) e slot vazio recebe um chip do inventário.
		function simSlots(box) {
			const profile = api.profile();
			const list = profile.sims || [];
			const total = (profile.device && profile.device.simSlots) || 1;
			for (let slot = 1; slot <= total; slot += 1) {
				const sim = list.find(function (entry) { return entry.slot === slot; });
				const label = total > 1 ? 'Chip ' + slot : 'Chip';
				if (!sim) {
					const empty = rowBase('sim', label, 'Vazio');
					empty.appendChild(button(simPicker ? 'Cancelar' : 'Colocar', '', function () {
						if (simPicker) { simPicker = null; paint(); return; }
						api.call('settings', 'simItems', {}).then(function (result) {
							if (!result || !result.ok) { api.status(api.errorText(result && result.error), 'error'); return; }
							simPicker = result.data || [];
							paint();
						});
					}));
					box.appendChild(empty);
					if (simPicker) {
						if (simPicker.length === 0) {
							box.appendChild(rowBase('sim', 'Nenhum chip no inventário', 'Compre um chip ou retire de outro celular'));
						}
						simPicker.forEach(function (item) {
							const option = rowBase('sim', item.display, item.mine ? 'No seu nome' : 'De outro titular');
							option.appendChild(button('Colocar', 'coe-button--primary', function () {
								api.call('settings', 'insertSim', { item: item.item }).then(function (result) {
									simPicker = null;
									if (result && result.ok) { api.status('Chip ' + result.data.display + ' colocado.', 'ok'); }
									else { api.status(api.errorText(result && result.error), 'error'); }
									paint();
								});
							}));
							box.appendChild(option);
						});
					}
					continue;
				}
				const row = rowBase('sim', label, sim.display + ' · ' + (sim.mine ? 'no seu nome' : 'de outro titular'));
				row.appendChild(button('Retirar', '', function () {
					api.call('settings', 'ejectSim', { slot: slot }).then(function (result) {
						if (result && result.ok) { api.status('Chip retirado. Ele está no seu inventário.', 'ok'); }
						else { api.status(api.errorText(result && result.error), 'error'); }
					});
				}));
				box.appendChild(row);
			}
		}

		function paint() {
			const s = api.settings();
			const signal = api.signal();
			const profile = api.profile();
			page.replaceChildren();

			const head = el('div', 'st-head');
			head.appendChild(el('strong', null, profile.display || 'Sem chip'));
			head.appendChild(el('small', null, s.airplane ? 'Modo avião' : (signal.bars > 0 ? 'COE · ' + signal.bars + ' de 4 barras' : 'Sem serviço')));
			page.appendChild(head);

			const net = section('Conexões');
			net.append(
				toggle('airplane', 'Modo avião', 'Sem ligações nem mensagens', 'airplane'),
				toggle('wifi', 'Wi-Fi', s.wifi ? (signal.indoor ? 'Conectado' : 'Nenhuma rede por perto') : 'Desligado', 'wifi'),
				toggle('bluetooth', 'Bluetooth', s.bluetooth ? 'Visível para aparelhos próximos' : 'Desligado', 'bluetooth')
			);

			const sounds = section('Sons e vibração');
			sounds.append(
				toggle('bellOff', 'Modo silencioso', 'Também na chave lateral', 'silent'),
				toggle('vibrate', 'Vibrar', 'Ao receber ligações e mensagens', 'vibrate'),
				toggle('moon', 'Não perturbe', 'Sem toque, vibração nem avisos', 'dnd'),
				range('volume', 'Volume do toque', 'volume', 0, 10, '')
			);
			const tones = rowBase('bell', 'Toque', 'Toque para ouvir');
			tones.classList.add('st-row--wrap');
			const chips = el('div', 'st-chips');
			api.ringtones().forEach(function (ringtone) {
				const chip = el('button', 'st-chip' + (s.ringtone === ringtone.id ? ' is-active' : ''), ringtone.label);
				chip.type = 'button';
				chip.addEventListener('click', function () {
					api.previewRingtone(ringtone.id);
					if (s.ringtone !== ringtone.id) { api.changeSetting({ ringtone: ringtone.id }); }
				});
				chips.appendChild(chip);
			});
			tones.appendChild(chips);
			sounds.appendChild(tones);

			const screen = section('Tela');
			screen.appendChild(range('sun', 'Brilho', 'brightness', 30, 100, '%'));
			const walls = rowBase('home', 'Papel de parede', null);
			walls.classList.add('st-row--wrap');
			const swatches = el('div', 'st-walls');
			api.wallpapers().forEach(function (wall) {
				const swatch = el('button', 'st-wall' + (s.wallpaper === wall.id ? ' is-active' : ''));
				swatch.type = 'button';
				swatch.dataset.wallpaper = wall.id;
				swatch.title = wall.label;
				swatch.appendChild(el('span', null, wall.label));
				swatch.addEventListener('click', function () { api.changeSetting({ wallpaper: wall.id }); });
				swatches.appendChild(swatch);
			});
			walls.appendChild(swatches);
			screen.appendChild(walls);

			const homeBox = section('Tela inicial');
			const homeRow = rowBase('home', 'Organizar apps', api.pageCount() + (api.pageCount() > 1 ? ' telas' : ' tela') + ' · segure um app para editar');
			homeRow.appendChild(button('Editar', '', function () { api.editHome(); }));
			homeBox.appendChild(homeRow);
			const resetRow = rowBase('settings', 'Restaurar padrão', 'Volta os apps para a ordem original');
			resetRow.appendChild(button('Restaurar', '', function () {
				api.resetHome().then(function (result) {
					if (result && result.ok) { api.status('Tela inicial restaurada.', 'ok'); paint(); }
					else { api.status(api.errorText(result && result.error), 'error'); }
				});
			}));
			homeBox.appendChild(resetRow);

			simSlots(section('Chip'));
			security(section('Segurança'));

			const device = profile.device || {};
			const about = section('Sobre');
			const info = el('dl', 'st-about');
			[
				['Sistema', 'COE OS'],
				['Modelo', device.label || '-'],
				['Número de série', device.serial || '-'],
				['Número', profile.display || 'Sem chip'],
				['Operadora', 'COE'],
				['Sinal', s.airplane ? 'Modo avião' : signal.bars + ' de 4'],
				['Apps instalados', String((profile.apps || []).length)]
			].forEach(function (pair) { info.append(el('dt', null, pair[0]), el('dd', null, pair[1])); });
			about.appendChild(info);
		}

		paint();
		// Repinta só fora de digitação para não perder o foco dos campos de senha nem o arrasto do slider.
		const refresh = function () {
			const active = document.activeElement;
			if (securityOpen || (active && active.classList && active.classList.contains('st-range'))) { return; }
			const top = root.scrollTop;
			paint();
			root.scrollTop = top;
		};
		api.on('settings', refresh);
		api.on('signal', refresh);
	});
})();
