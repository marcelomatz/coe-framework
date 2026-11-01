// Aba "Criptomoeda": configurações completas do coe_crypto (moeda, carteiras, transferências, corretora, cotação, mineração e explorador/auditoria).
// Aparece para quem tem manageCrypto (administradores, manageBusinesses, manageBanking ou root); o servidor revalida em cada ação.
if (typeof window.CRYPTO_TABS === 'undefined') {
	window.CRYPTO_TABS = [
		['exchange', 'Mercado e Corretora'],
		['explorer', 'Explorador e Auditoria'],
		['coin', 'Moeda e Rede'],
		['wallets', 'Carteiras e Envios'],
		['mining', 'Mineração']
	];
}

if (typeof window.CRYPTO_TX_KIND === 'undefined') {
	window.CRYPTO_TX_KIND = {
		buy: 'Compra na corretora',
		sell: 'Venda na corretora',
		transfer: 'Transferência',
		mine: 'Mineração',
		refund: 'Estorno'
	};
}

if (!state.crypto) {
	state.crypto = {
		tab: 'exchange',
		draft: null,
		dirty: false,
		priceInput: '',
		inspectAddress: '',
		inspectLoading: false,
		inspectError: null,
		inspectResult: null,
		inspectRequestId: null
	};
}

function cryptoData() {
	return state.data?.crypto || { available: false };
}

function cryptoScale() {
	const decimals = Number(state.crypto.draft?.coin?.decimals ?? cryptoData().settings?.coin?.decimals ?? 4);
	return Math.pow(10, decimals);
}

function cryptoSymbol() {
	return state.crypto.draft?.coin?.symbol || cryptoData().settings?.coin?.symbol || 'NOX';
}

function cryptoFormatUnits(units) {
	const decimals = Number(state.crypto.draft?.coin?.decimals ?? cryptoData().settings?.coin?.decimals ?? 4);
	const scale = Math.pow(10, decimals);
	const num = Math.max(0, Math.floor(Number(units) || 0));
	const whole = Math.floor(num / scale);
	const frac = String(num % scale).padStart(decimals, '0');
	return `${whole.toLocaleString('pt-BR')},${frac} ${cryptoSymbol()}`;
}

function cryptoMoney(value) {
	const num = Math.floor(Number(value) || 0);
	return `${num < 0 ? '-$ ' : '$ '}${Math.abs(num).toLocaleString('pt-BR')}`;
}

function cryptoDate(epoch) {
	if (!epoch) return '—';
	const d = new Date(Number(epoch) * 1000);
	if (Number.isNaN(d.getTime())) return String(epoch);
	const two = (n) => String(n).padStart(2, '0');
	return `${two(d.getDate())}/${two(d.getMonth() + 1)}/${d.getFullYear()} ${two(d.getHours())}:${two(d.getMinutes())}`;
}

function cryptoMessage(text, success) {
	for (const id of ['crypto-message', 'bank-message']) {
		const message = document.getElementById(id);
		if (message) {
			message.textContent = text || '';
			message.classList.toggle('is-success', success === true);
		}
	}
}

function cryptoButton(text, onClick, extra = '') {
	const button = bizEl('button', `biz-small-button ${extra}`.trim(), text);
	button.type = 'button';
	button.addEventListener('click', onClick);
	return button;
}

function cryptoStat(label, value) {
	const box = bizEl('div', 'bank-stat');
	box.append(bizEl('span', '', label), bizEl('strong', '', value));
	return box;
}

function cryptoCloneSettings(source) {
	if (!source) return null;
	return JSON.parse(JSON.stringify(source));
}

async function cryptoAction(action, payload, confirmOptions) {
	if (confirmOptions && !(await CoeUI.confirm(confirmOptions))) return;
	cryptoMessage('Enviando...');
	const result = await postNui('cryptoAction', { action, payload });
	if (!result.ok) cryptoMessage('Não foi possível enviar a ação.', false);
}

function cryptoInspect(address) {
	const clean = String(address || state.crypto.inspectAddress || '').trim();
	if (!clean) {
		cryptoMessage('Informe um endereço de carteira para inspecionar.', false);
		return;
	}
	state.crypto.inspectAddress = clean;
	state.crypto.inspectLoading = true;
	state.crypto.inspectError = null;
	state.crypto.tab = 'explorer';
	postNui('cryptoInspect', { address: clean }).then((res) => {
		if (res.ok) state.crypto.inspectRequestId = res.requestId;
		else {
			state.crypto.inspectLoading = false;
			state.crypto.inspectError = 'Não foi possível consultar o endereço.';
		}
		renderCrypto();
		if (state.view === 'banking' && state.bank?.tab === 'crypto') renderBankingBody();
	});
	renderCrypto();
	if (state.view === 'banking' && state.bank?.tab === 'crypto') renderBankingBody();
}

function onCryptoInspectResult(data) {
	// Mensagens locais à função: nada de constante global, então recarregar o script na mesma página não quebra.
	const inspectErrors = {
		forbidden: 'Sem permissão para auditar a criptomoeda.',
		not_ready: 'O coe_crypto ainda está iniciando.',
		invalid_address: 'Formato de endereço inválido.',
		unknown_address: 'Carteira não encontrada no banco de dados.',
		database_error: 'Erro ao consultar o banco de dados.',
		busy: 'Aguarde um instante antes de consultar novamente.'
	};
	if (data.requestId !== state.crypto.inspectRequestId) return;
	state.crypto.inspectLoading = false;
	state.crypto.inspectResult = data.result || null;
	state.crypto.inspectError = data.result ? null : (inspectErrors[data.error] || 'Não foi possível inspecionar a carteira.');
	renderCrypto();
	if (state.view === 'banking' && state.bank?.tab === 'crypto') renderBankingBody();
}

function onCryptoResult(data) {
	cryptoMessage(data.message, data.success === true);
	if (data.success === true) {
		state.crypto.dirty = false;
	}
}

function renderCrypto() {
	const tabs = document.getElementById('crypto-tabs');
	if (!tabs) return;
	tabs.replaceChildren();
	for (const [key, label] of window.CRYPTO_TABS) {
		const button = bizEl('button', `biz-tab${key === state.crypto.tab ? ' is-active' : ''}`, label);
		button.type = 'button';
		button.addEventListener('click', () => {
			state.crypto.tab = key;
			renderCrypto();
		});
		tabs.append(button);
	}
	const data = cryptoData();
	if (data.available && data.settings && (!state.crypto.dirty || !state.crypto.draft)) {
		state.crypto.draft = cryptoCloneSettings(data.settings);
		state.crypto.priceInput = String(data.market?.price || data.settings.exchange?.anchorPrice || '');
	}
	renderCryptoBody();
}

function renderCryptoBody(targetContainer) {
	const body = targetContainer || document.getElementById('crypto-body');
	if (!body) return;
	body.replaceChildren();
	const data = cryptoData();
	if (!data.available) {
		appendEmpty(body, 'O resource coe_crypto não está iniciado ou você não possui permissão.');
		return;
	}
	if (!state.crypto.draft && data.settings) {
		state.crypto.draft = cryptoCloneSettings(data.settings);
		state.crypto.priceInput = String(data.market?.price || data.settings.exchange?.anchorPrice || '');
	}
	if (!state.crypto.draft) {
		appendEmpty(body, 'Carregando configurações do coe_crypto...');
		return;
	}
	const tab = state.crypto.tab;
	if (tab === 'exchange') renderCryptoExchange(body, data);
	else if (tab === 'explorer') renderCryptoExplorer(body, data);
	else if (tab === 'coin') renderCryptoCoin(body);
	else if (tab === 'wallets') renderCryptoWallets(body);
	else if (tab === 'mining') renderCryptoMining(body, data);
	if (tab !== 'explorer') {
		body.append(renderCryptoActions(targetContainer));
	}
}

function renderCryptoActions(targetContainer) {
	const box = bizEl('div', 'biz-block');
	const actions = bizEl('div', 'bank-actions');
	actions.append(
		cryptoButton('Descartar alterações', () => {
			state.crypto.dirty = false;
			state.crypto.draft = cryptoCloneSettings(cryptoData().settings);
			cryptoMessage('Alterações locais descartadas.', true);
			renderCryptoBody(targetContainer);
		}),
		cryptoButton('Restaurar padrão (config.lua)', () => cryptoAction('reset', {}, {
			title: 'Restaurar padrão da criptomoeda',
			message: 'Voltar todas as configurações para os valores originais do config.lua? Os saldos e carteiras continuam intactos.',
			confirmLabel: 'Restaurar',
			danger: true
		}), 'biz-danger'),
		cryptoButton('Salvar configurações', () => cryptoAction('save', { settings: state.crypto.draft }, {
			title: 'Salvar configurações de cripto',
			message: 'Aplicar as novas configurações imediatamente em toda a rede e corretora?',
			confirmLabel: 'Salvar'
		}), 'bank-primary')
	);
	box.append(actions);
	return box;
}

// Aba 1: Mercado e Corretora ----------------------------------------------------------------------

function renderCryptoExchange(body, data) {
	const market = data.market || {};
	const summary = data.summary || {};
	const draft = state.crypto.draft;
	const ex = draft.exchange;
	const markDirty = () => { state.crypto.dirty = true; };

	const live = bizEl('div', 'biz-block');
	const head = bizEl('div', 'biz-block-head');
	head.append(
		bizEl('h3', '', 'Panorama ao vivo da corretora e da rede'),
		cryptoButton('Atualizar', () => postNui('requestRefresh'))
	);
	const changeNum = Number(market.change) || 0;
	const changeText = `${changeNum > 0 ? '+' : ''}${changeNum.toFixed(1)}%`;
	const stats = bizEl('div', 'bank-stats');
	stats.append(
		cryptoStat('Cotação atual', cryptoMoney(market.price)),
		cryptoStat('Compra / Venda', `${cryptoMoney(market.buy)} / ${cryptoMoney(market.sell)}`),
		cryptoStat('Variação (janela)', changeText),
		cryptoStat('Fluxo líquido na rodada', cryptoMoney(market.netFlow)),
		cryptoStat('Carteiras de jogadores', String(summary.wallets ?? 0)),
		cryptoStat('Em circulação', cryptoFormatUnits(summary.circulating)),
		cryptoStat('Reserva da corretora', cryptoFormatUnits(market.reserveBalance)),
		cryptoStat('Total minerado', cryptoFormatUnits(market.minted))
	);
	live.append(head, stats);

	const priceRow = bizEl('div', 'bank-inline');
	priceRow.append(
		bizField(`Fixar cotação agora ($ entre ${cryptoMoney(ex.minPrice)} e ${cryptoMoney(ex.maxPrice)})`, bizInput('number', state.crypto.priceInput, (value) => {
			state.crypto.priceInput = value;
		}, { min: ex.minPrice, max: ex.maxPrice, step: 1 })),
		cryptoButton('Fixar cotação', () => {
			const price = Math.floor(Number(state.crypto.priceInput));
			if (!Number.isInteger(price) || price < ex.minPrice || price > ex.maxPrice) {
				cryptoMessage(`Informe um valor inteiro entre ${cryptoMoney(ex.minPrice)} e ${cryptoMoney(ex.maxPrice)}.`, false);
				return;
			}
			cryptoAction('setPrice', { price }, {
				title: 'Fixar cotação da criptomoeda',
				message: `Alterar imediatamente a cotação para ${cryptoMoney(price)} por ${cryptoSymbol()}?`,
				confirmLabel: 'Fixar'
			});
		})
	);
	live.append(priceRow);
	body.append(live);

	const configBox = bizEl('div', 'biz-block');
	configBox.append(
		bizEl('h3', '', 'Corretora e formação de preço'),
		bizEl('p', 'biz-hint', `A corretora negocia contra a carteira de reserva (${ex.reserveAddress}, reserva inicial de ${cryptoFormatUnits(ex.reserve)}). A cada rodada, a cotação caminha em direção à âncora com ruído e impacto do fluxo líquido de compras e vendas.`),
		garCheck('Corretora aberta (permite compra e venda nos aparelhos)', ex.enabled === true, (checked) => {
			ex.enabled = checked;
			markDirty();
		})
	);

	const spreadHint = bizEl('span', 'biz-hint');
	const updateSpreadHint = () => {
		const pct = ((Number(ex.spreadBps) || 0) / 100).toFixed(2).replace('.', ',');
		spreadHint.textContent = `Spread atual: ${ex.spreadBps} bps (${pct}% de cada lado sobre a cotação).`;
	};
	updateSpreadHint();

	const grid = bizEl('div', 'bank-form');
	grid.append(
		bizField('Nome da corretora (1 a 24 caracteres)', bizInput('text', ex.name, (value) => { ex.name = value; markDirty(); }, { maxlength: 24 })),
		bizField('Cotação inicial ($)', bizInput('number', ex.startPrice, (value) => { ex.startPrice = bizNumber(value, 1); markDirty(); }, { min: 1, max: 100000000, step: 1 })),
		bizField('Preço-âncora ($)', bizInput('number', ex.anchorPrice, (value) => { ex.anchorPrice = bizNumber(value, 1); markDirty(); }, { min: 1, max: 100000000, step: 1 })),
		bizField('Cotação mínima / piso ($)', bizInput('number', ex.minPrice, (value) => { ex.minPrice = bizNumber(value, 1); markDirty(); }, { min: 1, max: 100000000, step: 1 })),
		bizField('Cotação máxima / teto ($)', bizInput('number', ex.maxPrice, (value) => { ex.maxPrice = bizNumber(value, 1); markDirty(); }, { min: 1, max: 100000000, step: 1 })),
		bizField('Intervalo da cotação (minutos, 1 a 1440)', bizInput('number', ex.tickMinutes, (value) => { ex.tickMinutes = bizNumber(value, 1); markDirty(); }, { min: 1, max: 1440, step: 1 })),
		bizField('Volatilidade por rodada (0 a 1)', bizInput('number', ex.volatility, (value) => { ex.volatility = bizNumber(value, 0); markDirty(); }, { min: 0, max: 1, step: 0.001 })),
		bizField('Força de reversão à âncora (0 a 1)', bizInput('number', ex.meanReversion, (value) => { ex.meanReversion = bizNumber(value, 0); markDirty(); }, { min: 0, max: 1, step: 0.005 })),
		bizField('Impacto por $ 1.000.000 de fluxo líquido (0 a 5)', bizInput('number', ex.impactPerMillion, (value) => { ex.impactPerMillion = bizNumber(value, 0); markDirty(); }, { min: 0, max: 5, step: 0.01 })),
		bizField('Spread em pontos-base (0 a 5000, 300 = 3%)', bizInput('number', ex.spreadBps, (value) => { ex.spreadBps = bizNumber(value, 0); markDirty(); updateSpreadHint(); }, { min: 0, max: 5000, step: 10 })),
		bizField('Ordem mínima ($)', bizInput('number', ex.minOrder, (value) => { ex.minOrder = bizNumber(value, 1); markDirty(); }, { min: 1, max: 100000000, step: 1 })),
		bizField('Ordem máxima ($)', bizInput('number', ex.maxOrder, (value) => { ex.maxOrder = bizNumber(value, 1); markDirty(); }, { min: 1, max: 100000000, step: 1 })),
		bizField('Limite diário de compra por personagem ($)', bizInput('number', ex.dailyBuyLimit, (value) => { ex.dailyBuyLimit = bizNumber(value, 1); markDirty(); }, { min: 1, max: 1000000000, step: 100 })),
		bizField('Limite diário de venda por personagem ($)', bizInput('number', ex.dailySellLimit, (value) => { ex.dailySellLimit = bizNumber(value, 1); markDirty(); }, { min: 1, max: 1000000000, step: 100 })),
		bizField('Pontos mantidos no gráfico (12 a 2880)', bizInput('number', ex.historyPoints, (value) => { ex.historyPoints = bizNumber(value, 12); markDirty(); }, { min: 12, max: 2880, step: 1 })),
		bizField('Intervalo entre ordens (segundos, 0 a 3600)', bizInput('number', ex.orderCooldownSeconds, (value) => { ex.orderCooldownSeconds = bizNumber(value, 0); markDirty(); }, { min: 0, max: 3600, step: 1 }))
	);
	configBox.append(grid, spreadHint);
	body.append(configBox);
}

// Aba 2: Explorador e Auditoria -------------------------------------------------------------------

function renderCryptoExplorer(body, data) {
	const summary = data.summary || {};
	const market = data.market || {};
	const topWallets = data.topWallets || [];
	const recentTx = data.recentTx || [];

	const netBox = bizEl('div', 'biz-block');
	const netHead = bizEl('div', 'biz-block-head');
	netHead.append(bizEl('h3', '', 'Panorama da rede e auditoria'), cryptoButton('Atualizar rede', () => postNui('requestRefresh')));
	const stats = bizEl('div', 'bank-stats');
	stats.append(
		cryptoStat('Carteiras de jogadores', String(summary.wallets ?? 0)),
		cryptoStat('Em circulação', cryptoFormatUnits(summary.circulating)),
		cryptoStat('Reserva da corretora', cryptoFormatUnits(market.reserveBalance)),
		cryptoStat('Total minerado', cryptoFormatUnits(market.minted)),
		cryptoStat('Transações registradas', String(summary.txCount ?? 0))
	);
	netBox.append(netHead, stats);

	const searchRow = bizEl('div', 'bank-inline');
	searchRow.append(
		bizField('Inspecionar endereço de carteira (saldo, criador, aparelhos com chave e extrato)', bizInput('text', state.crypto.inspectAddress, (value) => {
			state.crypto.inspectAddress = value;
		}, { maxlength: 48, placeholder: 'Ex.: nx...' })),
		cryptoButton('Inspecionar', () => cryptoInspect(state.crypto.inspectAddress), 'bank-primary')
	);
	netBox.append(searchRow);

	if (state.crypto.inspectLoading) {
		netBox.append(bizEl('p', 'biz-hint', 'Consultando carteira...'));
	} else if (state.crypto.inspectError) {
		netBox.append(bizEl('p', 'biz-hint', state.crypto.inspectError));
	} else if (state.crypto.inspectResult?.wallet) {
		const w = state.crypto.inspectResult.wallet;
		const devices = state.crypto.inspectResult.devices || [];
		const history = state.crypto.inspectResult.history || [];
		const inspectCard = bizEl('div', 'biz-block');
		const inspectHead = bizEl('div', 'biz-block-head');
		inspectHead.append(
			bizEl('h3', '', `Carteira ${w.address}`),
			cryptoButton('Fechar inspeção', () => {
				state.crypto.inspectResult = null;
				renderCrypto();
			})
		);
		const wStats = bizEl('div', 'bank-stats');
		const creatorText = w.characterName
			? `${w.characterName}${w.stateId ? ' · ' + w.stateId : ''} (#${w.createdBy})`
			: (w.createdBy ? `Personagem #${w.createdBy}` : 'Sistema / Reserva');
		wStats.append(
			cryptoStat('Saldo atual', cryptoFormatUnits(w.balance)),
			cryptoStat('Valor em $ (cotação atual)', cryptoMoney(Math.floor((Number(w.balance) || 0) / cryptoScale() * (Number(market.price) || 0)))),
			cryptoStat('Criada por', creatorText),
			cryptoStat('Criada em', cryptoDate(w.createdAt)),
			cryptoStat('Aparelhos com chave', String(devices.length))
		);
		inspectCard.append(inspectHead, wStats);
		if (w.createdBy && state.data?.permissions?.viewPlayers) {
			const actions = bizEl('div', 'bank-actions');
			actions.append(cryptoButton('Abrir perfil do criador', () => openProfile(String(w.createdBy))));
			inspectCard.append(actions);
		}
		if (devices.length) {
			const devList = bizEl('div', 'bank-list');
			for (const dev of devices) {
				const row = bizEl('div', 'bank-row');
				const info = bizEl('div', 'bank-row-info');
				info.append(
					bizEl('strong', '', `${dev.deviceKey}${dev.label ? ' · "' + dev.label + '"' : ''}`),
					bizEl('span', 'biz-hint', `Adicionada em ${cryptoDate(dev.addedAt)}`)
				);
				row.append(info);
				devList.append(row);
			}
			inspectCard.append(bizEl('h3', 'bank-subtitle', 'Aparelhos com a chave salva'), devList);
		}
		if (history.length) {
			const txList = bizEl('div', 'bank-list');
			for (const tx of history) {
				txList.append(renderCryptoTxRow(tx));
			}
			inspectCard.append(bizEl('h3', 'bank-subtitle', `Movimentações da carteira (${history.length})`), txList);
		} else {
			inspectCard.append(bizEl('p', 'biz-hint', 'Nenhuma movimentação registrada para este endereço.'));
		}
		netBox.append(inspectCard);
	}
	body.append(netBox);

	const topBox = bizEl('div', 'biz-block');
	topBox.append(
		bizEl('h3', '', `Maiores carteiras da rede (${topWallets.length})`),
		bizEl('p', 'biz-hint', 'Carteiras de jogadores ordenadas por saldo (exclui a carteira de reserva da corretora).')
	);
	if (!topWallets.length) {
		topBox.append(bizEl('p', 'biz-hint', 'Nenhuma carteira de jogador criada ainda.'));
	} else {
		const list = bizEl('div', 'bank-list');
		for (const w of topWallets) {
			const row = bizEl('div', 'bank-row');
			const info = bizEl('div', 'bank-row-info');
			const owner = w.characterName
				? `Criada por ${w.characterName}${w.stateId ? ' (' + w.stateId + ')' : ''}`
				: (w.createdBy ? `Criada pelo personagem #${w.createdBy}` : 'Sem criador registrado');
			info.append(
				bizEl('strong', '', `${w.address} · ${cryptoFormatUnits(w.balance)}`),
				bizEl('span', 'biz-hint', `${owner} · em ${cryptoDate(w.createdAt)}`)
			);
			const actions = bizEl('div', 'bank-row-actions');
			actions.append(cryptoButton('Inspecionar', () => cryptoInspect(w.address)));
			if (w.createdBy && state.data?.permissions?.viewPlayers) {
				actions.append(cryptoButton('Perfil', () => openProfile(String(w.createdBy))));
			}
			row.append(info, actions);
			list.append(row);
		}
		topBox.append(list);
	}
	body.append(topBox);

	const txBox = bizEl('div', 'biz-block');
	txBox.append(
		bizEl('h3', '', `Últimas movimentações da rede (${recentTx.length})`),
		bizEl('p', 'biz-hint', 'Compras, vendas, envios e rodadas de mineração mais recentes em todo o servidor.')
	);
	if (!recentTx.length) {
		txBox.append(bizEl('p', 'biz-hint', 'Nenhuma movimentação registrada ainda.'));
	} else {
		const list = bizEl('div', 'bank-list');
		for (const tx of recentTx) {
			list.append(renderCryptoTxRow(tx));
		}
		txBox.append(list);
	}
	body.append(txBox);
}

function renderCryptoTxRow(tx) {
	const row = bizEl('div', 'bank-row');
	const info = bizEl('div', 'bank-row-info');
	const kindLabel = window.CRYPTO_TX_KIND[tx.kind] || tx.kind;
	const fiatText = tx.fiat ? ` · ${cryptoMoney(tx.fiat)}` : '';
	const feeText = tx.fee > 0 ? ` (taxa ${cryptoFormatUnits(tx.fee)})` : '';
	const actor = tx.characterName
		? `${tx.characterName}${tx.stateId ? ' (' + tx.stateId + ')' : ''}`
		: (tx.characterId ? `Personagem #${tx.characterId}` : '');
	const details = [
		cryptoDate(tx.at),
		tx.from ? `De: ${tx.from}` : 'Emissão',
		`Para: ${tx.to}`,
		actor,
		tx.deviceKey ? `Aparelho: ${tx.deviceKey}` : '',
		tx.memo ? `Memo: "${tx.memo}"` : ''
	].filter(Boolean).join(' · ');
	info.append(
		bizEl('strong', '', `#${tx.id} · ${kindLabel} · ${cryptoFormatUnits(tx.amount)}${feeText}${fiatText}`),
		bizEl('span', 'biz-hint', details)
	);
	const actions = bizEl('div', 'bank-row-actions');
	if (tx.to) actions.append(cryptoButton('Destino', () => cryptoInspect(tx.to)));
	if (tx.from) actions.append(cryptoButton('Origem', () => cryptoInspect(tx.from)));
	if (tx.characterId && state.data?.permissions?.viewPlayers) {
		actions.append(cryptoButton('Perfil', () => openProfile(String(tx.characterId))));
	}
	row.append(info, actions);
	return row;
}

// Aba 3: Moeda e Rede -----------------------------------------------------------------------------

function renderCryptoCoin(body) {
	const draft = state.crypto.draft;
	const coin = draft.coin;
	const address = draft.address || {};
	const net = draft.network;
	const markDirty = () => { state.crypto.dirty = true; };

	const box = bizEl('div', 'biz-block');
	box.append(
		bizEl('h3', '', 'Identidade da moeda e parâmetros de rede'),
		bizEl('p', 'biz-hint', 'O nome e o símbolo aparecem no smartphone, no tablet e nos computadores da DeepWeb. Casas decimais e formato de endereço são estruturais (somente leitura) para preservar os saldos e carteiras já existentes.')
	);

	const stats = bizEl('div', 'bank-stats');
	stats.append(
		cryptoStat('Casas decimais', `${coin.decimals} (1 ${coin.symbol} = ${cryptoScale().toLocaleString('pt-BR')} un.)`),
		cryptoStat('Prefixo de endereço', address.prefix || 'nx'),
		cryptoStat('Tamanho do endereço', `${address.length || 30} caracteres`)
	);
	box.append(stats);

	const grid = bizEl('div', 'bank-form');
	grid.append(
		bizField('Nome da moeda (1 a 24 caracteres)', bizInput('text', coin.name, (value) => { coin.name = value; markDirty(); }, { maxlength: 24 })),
		bizField('Símbolo / Ticker (2 a 6 letras/números)', bizInput('text', coin.symbol, (value) => { coin.symbol = value.toUpperCase(); markDirty(); }, { maxlength: 6 })),
		bizField('Movimentações por página no Explorador (5 a 100)', bizInput('number', net.historyPageSize, (value) => { net.historyPageSize = bizNumber(value, 30); markDirty(); }, { min: 5, max: 100, step: 1 })),
		bizField('Intervalo mínimo entre chamadas do app (50 a 5000 ms)', bizInput('number', net.callCooldownMs, (value) => { net.callCooldownMs = bizNumber(value, 250); markDirty(); }, { min: 50, max: 5000, step: 10 }))
	);
	box.append(grid);
	body.append(box);
}

// Aba 4: Carteiras e Envios -----------------------------------------------------------------------

function renderCryptoWallets(body) {
	const draft = state.crypto.draft;
	const wallets = draft.wallets;
	const transfer = draft.transfer;
	const markDirty = () => { state.crypto.dirty = true; };

	const walletBox = bizEl('div', 'biz-block');
	walletBox.append(
		bizEl('h3', '', 'Carteiras e proteção de importação'),
		bizEl('p', 'biz-hint', 'Controla quantas chaves cabem em cada aparelho (celular, tablet ou computador), quantas carteiras novas cada personagem pode gerar por dia e o bloqueio contra força bruta na importação de chave privada.')
	);
	const walletGrid = bizEl('div', 'bank-form');
	walletGrid.append(
		bizField('Máx. de carteiras por aparelho (1 a 32)', bizInput('number', wallets.maxPerDevice, (value) => { wallets.maxPerDevice = bizNumber(value, 8); markDirty(); }, { min: 1, max: 32, step: 1 })),
		bizField('Máx. de carteiras criadas por dia por personagem (1 a 100)', bizInput('number', wallets.maxCreatedPerDay, (value) => { wallets.maxCreatedPerDay = bizNumber(value, 5); markDirty(); }, { min: 1, max: 100, step: 1 })),
		bizField('Tamanho máximo do rótulo (4 a 48 caracteres)', bizInput('number', wallets.labelMax, (value) => { wallets.labelMax = bizNumber(value, 24); markDirty(); }, { min: 4, max: 48, step: 1 })),
		bizField('Erros seguidos de chave antes do bloqueio (1 a 50)', bizInput('number', wallets.importFailures, (value) => { wallets.importFailures = bizNumber(value, 5); markDirty(); }, { min: 1, max: 50, step: 1 })),
		bizField('Tempo de bloqueio na importação (segundos, 10 a 86400)', bizInput('number', wallets.importLockSeconds, (value) => { wallets.importLockSeconds = bizNumber(value, 120); markDirty(); }, { min: 10, max: 86400, step: 10 }))
	);
	walletBox.append(walletGrid);
	body.append(walletBox);

	const transferBox = bizEl('div', 'biz-block');
	const preview = bizEl('p', 'biz-hint');
	const updatePreview = () => {
		preview.textContent = `Conversão atual: taxa = ${cryptoFormatUnits(transfer.fee)} · mínimo = ${cryptoFormatUnits(transfer.minAmount)} · máximo = ${cryptoFormatUnits(transfer.maxAmount)}.`;
	};
	updatePreview();
	transferBox.append(
		bizEl('h3', '', 'Transferências na rede'),
		bizEl('p', 'biz-hint', `Valores de moeda em unidades inteiras (1 ${cryptoSymbol()} = ${cryptoScale().toLocaleString('pt-BR')} unidades). A taxa de envio é queimada a cada transferência.`)
	);
	const transferGrid = bizEl('div', 'bank-form');
	transferGrid.append(
		bizField('Taxa da rede por envio (em unidades)', bizInput('number', transfer.fee, (value) => { transfer.fee = bizNumber(value, 0); markDirty(); updatePreview(); }, { min: 0, max: 1000000000, step: 1 })),
		bizField('Quantia mínima por envio (em unidades)', bizInput('number', transfer.minAmount, (value) => { transfer.minAmount = bizNumber(value, 1); markDirty(); updatePreview(); }, { min: 1, max: 100000000000000, step: 1 })),
		bizField('Quantia máxima por envio (em unidades)', bizInput('number', transfer.maxAmount, (value) => { transfer.maxAmount = bizNumber(value, 1); markDirty(); updatePreview(); }, { min: 1, max: 100000000000000, step: 10000 })),
		bizField('Tamanho máximo do memo público (0 a 120 caracteres)', bizInput('number', transfer.memoMax, (value) => { transfer.memoMax = bizNumber(value, 60); markDirty(); }, { min: 0, max: 120, step: 1 })),
		bizField('Intervalo entre envios da mesma carteira (segundos, 0 a 3600)', bizInput('number', transfer.cooldownSeconds, (value) => { transfer.cooldownSeconds = bizNumber(value, 3); markDirty(); }, { min: 0, max: 3600, step: 1 }))
	);
	transferBox.append(transferGrid, preview);
	body.append(transferBox);
}

// Aba 5: Mineração --------------------------------------------------------------------------------

function renderCryptoMining(body, data) {
	const draft = state.crypto.draft;
	const mining = draft.mining;
	const minted = Number(data.market?.minted) || 0;
	const markDirty = () => { state.crypto.dirty = true; };

	const box = bizEl('div', 'biz-block');
	const preview = bizEl('p', 'biz-hint');
	const updatePreview = () => {
		const remaining = Math.max(0, (Number(mining.maxMined) || 0) - minted);
		preview.textContent = `Emissão por rodada: até ${cryptoFormatUnits(mining.emissionPerTick)} a cada ${mining.tickMinutes} min · Teto: ${cryptoFormatUnits(mining.maxMined)} (restam ${cryptoFormatUnits(remaining)}).`;
	};
	updatePreview();

	box.append(
		bizEl('h3', '', 'Emissão por mineração'),
		bizEl('p', 'biz-hint', `Cada rodada divide a emissão pelo poder de hash das máquinas ativas (coe_deepweb). Quando o hash total da rede é menor que o hash de referência, a emissão é proporcionalmente menor. Valores em unidades inteiras (1 ${cryptoSymbol()} = ${cryptoScale().toLocaleString('pt-BR')} unidades).`)
	);

	const grid = bizEl('div', 'bank-form');
	grid.append(
		bizField('Intervalo entre rodadas (minutos, 1 a 1440)', bizInput('number', mining.tickMinutes, (value) => { mining.tickMinutes = bizNumber(value, 10); markDirty(); updatePreview(); }, { min: 1, max: 1440, step: 1 })),
		bizField('Emissão máxima por rodada (em unidades)', bizInput('number', mining.emissionPerTick, (value) => { mining.emissionPerTick = bizNumber(value, 0); markDirty(); updatePreview(); }, { min: 0, max: 100000000000, step: 1000 })),
		bizField('Poder de hash de referência da rede (1 a 1.000.000)', bizInput('number', mining.referenceHash, (value) => { mining.referenceHash = bizNumber(value, 200); markDirty(); }, { min: 1, max: 1000000, step: 10 })),
		bizField('Teto total de mineração (em unidades)', bizInput('number', mining.maxMined, (value) => { mining.maxMined = bizNumber(value, 0); markDirty(); updatePreview(); }, { min: 0, max: 1000000000000000, step: 10000 }))
	);
	box.append(grid, preview);
	body.append(box);
}
