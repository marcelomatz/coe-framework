(function () {
	'use strict';

	const ERRORS = {
		forbidden: 'Você não pode usar esta bancada agora.', missing_items: 'Faltam materiais.',
		craft_busy: 'Você já está produzindo algo.', recipe_not_found: 'Receita não encontrada.',
		inventory_unavailable: 'Inventário indisponível.', inventory_full: 'Sem espaço na mochila.',
		no_container: 'Bancada sem baú configurado.', no_craft_in_progress: 'Nada em produção.',
		off_duty: 'Bata o ponto neste negócio para usar a bancada.', not_staff: 'Só a equipe deste negócio usa esta bancada.',
		too_far: 'Chegue mais perto da bancada.', unavailable: 'Negócios indisponíveis no momento. Tente de novo.'
	};

	const craft = document.getElementById('craft');
	const title = document.getElementById('cr-title');
	const recipesEl = document.getElementById('cr-recipes');
	const progress = document.getElementById('cr-progress');
	const statusEl = document.getElementById('cr-status');
	const closeButton = document.getElementById('cr-close');

	let producing = false;

	function post(name, data) {
		fetch('https://' + GetParentResourceName() + '/' + name, {
			method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data || {})
		}).catch(function () {});
	}

	function setStatus(text, isError) {
		statusEl.textContent = text || '';
		statusEl.classList.toggle('is-error', isError === true);
	}

	function stopProgress() {
		producing = false;
		progress.classList.remove('is-running');
	}

	function renderRecipes(recipes) {
		recipesEl.replaceChildren();
		(recipes || []).forEach(function (recipe) {
			const ready = recipe.inputs.every(function (input) { return input.have >= input.need; });
			const row = document.createElement('div');
			row.className = 'cr-recipe' + (ready ? ' is-ready' : '');
			const info = document.createElement('div');
			const heading = document.createElement('h4');
			heading.textContent = recipe.label;
			const time = document.createElement('span');
			time.className = 'cr-time';
			time.textContent = (recipe.timeMs / 1000).toFixed(0) + ' s';
			heading.append(time);
			const inputs = document.createElement('div');
			inputs.className = 'cr-inputs';
			recipe.inputs.forEach(function (input) {
				const chip = document.createElement('span');
				chip.className = 'cr-input ' + (input.have >= input.need ? 'is-ok' : 'is-missing');
				chip.textContent = (input.label || input.item) + ' ' + input.have + '/' + input.need;
				inputs.append(chip);
			});
			const output = document.createElement('div');
			output.className = 'cr-output';
			output.textContent = 'Produz: ' + (recipe.outputs || []).map(function (entry) {
				return entry.count + '× ' + (entry.label || entry.item);
			}).join(', ');
			info.append(heading, inputs, output);
			const button = document.createElement('button');
			button.type = 'button';
			button.className = 'coe-button coe-button--primary';
			button.textContent = 'Produzir';
			button.disabled = !ready || producing;
			button.addEventListener('click', function () {
				if (!producing) { post('craft', { recipe: recipe.id }); }
			});
			row.append(info, button);
			recipesEl.append(row);
		});
	}

	closeButton.addEventListener('click', function () { post('close'); });
	document.addEventListener('keydown', function (event) {
		if (event.key === 'Escape' && !craft.hidden) { post('close'); }
	});

	window.addEventListener('message', function (event) {
		const message = event.data || {};
		if (message.action === 'open') {
			const data = message.data || {};
			title.textContent = data.label || 'Bancada';
			stopProgress();
			setStatus('');
			renderRecipes(data.recipes);
			craft.hidden = false;
		} else if (message.action === 'close') {
			craft.hidden = true;
			stopProgress();
		} else if (message.action === 'recipes') {
			stopProgress();
			renderRecipes(message.data);
		} else if (message.action === 'started') {
			producing = true;
			setStatus('Produzindo ' + (message.data.label || '') + '...');
			progress.style.setProperty('--cr-ms', message.data.timeMs + 'ms');
			progress.classList.remove('is-running');
			void progress.offsetWidth;
			progress.classList.add('is-running');
			recipesEl.querySelectorAll('button').forEach(function (button) { button.disabled = true; });
		} else if (message.action === 'done') {
			setStatus('Pronto!');
		} else if (message.action === 'error') {
			stopProgress();
			setStatus(ERRORS[message.data] || ('Falha: ' + message.data), true);
			if (!craft.hidden) { setTimeout(function () { post('refresh'); }, 500); }
		}
	});
})();
