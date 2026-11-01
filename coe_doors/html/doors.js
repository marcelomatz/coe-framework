(() => {
	const $ = (id) => document.getElementById(id);
	const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'coe_doors';
	const MAX = 8;
	let doorId = null;
	let digits = '';

	const post = (name, body) => fetch(`https://${resource}/${name}`, {
		method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body || {})
	}).catch(() => {});

	const draw = () => {
		const display = $('display');
		display.classList.remove('is-wrong');
		display.textContent = digits ? '•'.repeat(digits.length) : '—';
	};

	const press = (key) => {
		if (!doorId) return;
		if (key === 'clear') digits = digits.slice(0, -1);
		else if (key === 'ok') {
			if (digits.length >= 4) post('pin', { id: doorId, pin: digits });
			return;
		} else if (digits.length < MAX) digits += key;
		draw();
	};

	const keys = $('keys');
	for (const key of ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'clear', '0', 'ok']) {
		const button = document.createElement('button');
		button.type = 'button';
		button.textContent = key === 'clear' ? '⌫' : key === 'ok' ? 'OK' : key;
		if (key === 'ok') button.className = 'confirm';
		button.addEventListener('click', () => press(key));
		keys.append(button);
	}

	window.addEventListener('message', ({ data }) => {
		if (data.type === 'pin') {
			doorId = data.id;
			digits = '';
			$('title').textContent = data.label || 'Porta';
			$('subtitle').textContent = `Digite a senha para ${data.locked ? 'destrancar' : 'trancar'}`;
			draw();
			$('pin').hidden = false;
		} else if (data.type === 'pinWrong' && data.id === doorId) {
			digits = '';
			draw();
			$('display').classList.add('is-wrong');
		} else if (data.type === 'pinClose') {
			doorId = null;
			digits = '';
			$('pin').hidden = true;
		}
	});

	$('close').onclick = () => post('close');
	document.addEventListener('keydown', (event) => {
		if ($('pin').hidden) return;
		if (event.key === 'Escape') post('close');
		else if (/^[0-9]$/.test(event.key)) press(event.key);
		else if (event.key === 'Backspace') press('clear');
		else if (event.key === 'Enter') press('ok');
	});
})();
