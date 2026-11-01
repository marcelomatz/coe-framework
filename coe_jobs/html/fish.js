// Pesca (coe_jobs): só desenha o que o Lua manda. Dica com a vara na mão, força do arremesso, aviso da mordida
// (com o tempo para fisgar) e a briga: faixa da vara, peixe e progresso. Sem foco do mouse: o jogo segue no teclado.
(function () {
	'use strict';

	const root = document.getElementById('fish');
	const prompt = document.getElementById('fish-prompt');
	const hintText = document.getElementById('fish-hint');
	const power = document.querySelector('#fish-power i');
	const track = document.getElementById('fish-track');
	const zone = document.getElementById('fish-zone');
	const dot = document.getElementById('fish-dot');
	const progress = document.querySelector('#fish-progress i');
	const MODES = ['is-power', 'is-hook', 'is-fight', 'is-hit', 'is-miss', 'is-rare'];
	let hideTimer = null;
	let hookTimer = null;

	function show(mode) {
		clearTimeout(hideTimer);
		MODES.forEach(function (name) { root.classList.remove(name); });
		if (mode) { root.classList.add(mode); }
		root.classList.remove('is-hidden');
		root.setAttribute('aria-hidden', 'false');
	}

	function hide() {
		cancelAnimationFrame(hookTimer);
		root.classList.add('is-hidden');
		root.setAttribute('aria-hidden', 'true');
	}

	function pct(value) {
		return (Math.max(0, Math.min(1, value)) * 100) + '%';
	}

	// Barra do tempo para fisgar esvaziando.
	function hookCountdown(ms) {
		const started = performance.now();
		function frame() {
			const left = 1 - (performance.now() - started) / ms;
			progress.style.width = pct(left);
			if (left > 0 && root.classList.contains('is-hook')) { hookTimer = requestAnimationFrame(frame); }
		}
		hookTimer = requestAnimationFrame(frame);
	}

	window.addEventListener('message', function (event) {
		const data = event.data || {};
		switch (data.action) {
			case 'fish:hint':
				show(null);
				prompt.textContent = '';
				hintText.textContent = data.text || '';
				break;
			case 'fish:power':
				if (!root.classList.contains('is-power')) {
					show('is-power');
					prompt.textContent = 'Força do arremesso';
				}
				power.style.width = pct(data.power);
				break;
			case 'fish:hook':
				show('is-hook');
				if (data.rare) { root.classList.add('is-rare'); }
				prompt.textContent = data.text || 'Mordeu! Aperte E.';
				hintText.textContent = '';
				hookCountdown(data.ms || 1500);
				break;
			case 'fish:fight':
				if (!root.classList.contains('is-fight')) {
					cancelAnimationFrame(hookTimer);
					const rare = root.classList.contains('is-rare');
					show('is-fight');
					if (rare) { root.classList.add('is-rare'); }
					prompt.textContent = 'Segure e solte E para manter o peixe na faixa';
				}
				zone.style.left = pct(data.bar);
				zone.style.width = pct(data.size);
				dot.style.left = pct(data.fish);
				progress.style.width = pct(data.progress);
				track.classList.toggle('is-inside', data.inside === true);
				break;
			case 'fish:end':
				root.classList.remove('is-power', 'is-hook');
				root.classList.add(data.hit ? 'is-hit' : 'is-miss');
				prompt.textContent = data.hit ? 'Fisgou!' : 'O peixe escapou...';
				clearTimeout(hideTimer);
				hideTimer = setTimeout(function () {
					MODES.forEach(function (name) { root.classList.remove(name); });
				}, 1300);
				break;
			case 'fish:hide':
				hide();
				break;
		}
	});
})();
