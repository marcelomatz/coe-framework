const targetEye = document.getElementById('target-eye');
const targetAction = document.getElementById('target-action');
const targetActionOptions = document.getElementById('target-action-options');
const targetActionHint = document.getElementById('target-action-hint');

let interactive = false;

function post(endpoint, payload) {
	return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json; charset=UTF-8' },
		body: JSON.stringify(payload || {})
	}).catch(() => {});
}

function setHint(isInteractive) {
	targetActionHint.replaceChildren();
	const key = document.createElement('kbd');
	key.textContent = isInteractive ? 'Esc' : 'Clique';
	targetActionHint.append(key, isInteractive ? ' cancelar' : ' para escolher');
}

window.addEventListener('message', (event) => {
	const data = event.data;
	if (!data || data.action !== 'targetState') return;

	interactive = data.interactive === true;
	document.body.classList.toggle('is-interactive', interactive);
	targetAction.classList.toggle('is-interactive', interactive);
	targetEye.classList.toggle('is-visible', data.visible === true);
	targetEye.classList.toggle('has-target', data.hasTarget === true);
	targetEye.setAttribute('aria-hidden', String(data.visible !== true));
	const options = Array.isArray(data.options) ? data.options : [];
	targetActionOptions.replaceChildren();
	options.forEach((label, index) => {
		const option = document.createElement(interactive ? 'button' : 'div');
		option.className = 'coe-callout__item';
		option.style.setProperty('--i', index);
		option.setAttribute('role', 'option');
		if (interactive) {
			option.type = 'button';
			option.addEventListener('click', () => post('menuSelect', { index: index + 1 }));
		}
		option.textContent = label;
		targetActionOptions.append(option);
	});
	setHint(interactive);
	targetAction.classList.toggle('is-visible', data.visible === true && data.hasTarget === true && options.length > 0);
	targetAction.setAttribute('aria-hidden', String(data.visible !== true || data.hasTarget !== true || options.length === 0));
});

// Parallax: o palco inclina levemente conforme o mouse se afasta do centro.
const targetStage = document.getElementById('target-stage');
document.addEventListener('mousemove', (event) => {
	if (!interactive) return;
	const dx = (event.clientX / window.innerWidth - 0.5) * 2;
	const dy = (event.clientY / window.innerHeight - 0.5) * 2;
	targetStage.style.setProperty('--ry', `${(dx * 14).toFixed(1)}deg`);
	targetStage.style.setProperty('--rx', `${(12 - dy * 10).toFixed(1)}deg`);
});

// Clique fora das opções, botão direito ou Esc cancelam o modo de escolha.
document.addEventListener('mousedown', (event) => {
	if (interactive && !event.target.closest('.coe-callout__item')) post('menuClose');
});
document.addEventListener('contextmenu', (event) => {
	event.preventDefault();
	if (interactive) post('menuClose');
});
document.addEventListener('keydown', (event) => {
	if (interactive && event.key === 'Escape') post('menuClose');
});