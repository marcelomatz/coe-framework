-- Loja de aplicativos e apps do COE OS. A mesma loja serve o tablet e o smartphone (`devices`).
CoeAppsConfig = {
	-- Pode apagar anúncios e posts de qualquer pessoa.
	ModerateAce = 'coe_apps.moderate',
	CallCooldownMs = 400,

	-- Assinatura dos apps pagos: cobrada no cartão de crédito (coe_banking) a cada `PeriodDays`, com renovação
	-- automática `RenewLeadSeconds` antes de vencer. Cobrança recusada depois do vencimento remove o app.
	Subscriptions = { PeriodDays = 7, RenewLeadSeconds = 300, TickSeconds = 60, BatchSize = 100 },

	-- Catálogo da loja. `builtin`: vem instalado e não sai (a própria loja). `price` 0 é grátis; pago é o valor da
	-- assinatura semanal no cartão de crédito. `devices`: onde o app roda.
	-- Ícone e cor da tela inicial ficam no `coe_tablet/config.lua` (mesmo id); aqui valem para a vitrine da loja.
	Store = {
		store = {
			label = 'Loja', builtin = true, icon = 'store', color = '#3f8f7a', category = 'Sistema',
			description = 'Instale e remova aplicativos.', devices = { tablet = true, phone = true }
		},
		-- E-mail (coe_mail): vem instalado; contas com senha, abertas por aparelho.
		mail = {
			label = 'E-mail', builtin = true, icon = 'mail', color = '#3a7bd5', category = 'Sistema',
			description = 'Crie seu endereço, envie e receba e-mails.', devices = { tablet = true, phone = true }
		},
		-- Elos (coe_elos): rede profissional com perfil, currículo do histórico real e conexões. Vem instalado.
		elos = {
			label = 'Elos', builtin = true, icon = 'jobs', color = '#2f86a6', category = 'Social',
			description = 'Sua rede profissional: perfil, currículo com o que você já trabalhou e conexões.', devices = { tablet = true, phone = true }
		},
		jobs = {
			label = 'Empregos', price = 0, icon = 'jobs', color = '#4f7cac', category = 'Utilidades',
			description = 'Empregos públicos da cidade, cargos e onde se apresentar.', devices = { tablet = true, phone = true }
		},
		classifieds = {
			label = 'Classificados', price = 0, icon = 'news', color = '#c17a3a', category = 'Compras',
			description = 'Anuncie e encontre veículos, imóveis, itens e serviços.', devices = { tablet = true, phone = true }
		},
		-- Loja virtual (coe_amzg): compra no cartão de crédito pela Carteira e entrega em caixa no imóvel.
		amzg = {
			label = 'Amzg', price = 0, icon = 'cart', color = '#e08a2c', category = 'Compras',
			description = 'Compre produtos com o cartão de crédito e receba em casa, na empresa ou no esconderijo.',
			devices = { tablet = true, phone = true }
		},
		-- Portais dos veículos de comunicação (coe_news). O app de cada veículo tem o mesmo id do `Outlets` de lá.
		weazel = {
			label = 'Weazel News', price = 0, icon = 'tv', color = '#c8102e', category = 'Notícias',
			description = 'Notícias, acontecimentos e fofocas de Los Santos. Anuncie também.', devices = { tablet = true, phone = true }
		},
		rebel = {
			label = 'Rebel News', price = 0, icon = 'radio', color = '#4a7c2c', category = 'Notícias',
			description = 'A voz do norte: notícias e acontecimentos do condado de Blaine. Anuncie também.', devices = { tablet = true, phone = true }
		},
		insta = {
			label = 'Insta', price = 0, icon = 'camera', color = '#b5487a', category = 'Social',
			description = 'Fotos da cidade: tire, publique e curta.', devices = { tablet = true, phone = true }
		},
		-- Carteira cripto (coe_crypto): carteiras com chave no aparelho, envio, corretora e explorador da rede.
		crypto = {
			label = 'Cripto', price = 0, icon = 'crypto', color = '#c9973a', category = 'Finanças',
			description = 'Carteira de Noxcoin: guarde chaves, envie, compre e venda na corretora e consulte a rede.',
			devices = { tablet = true, phone = true }
		},
		-- Edita as fotos da Galeria do smartphone (coe_phone); a edição é feita no aparelho e salva como cópia.
		editor = {
			label = 'Estúdio', price = 350, icon = 'editor', color = '#7a5bb5', category = 'Foto e vídeo',
			description = 'Editor de fotos: filtros, ajustes de luz e cor, corte, giro, tamanho, texto e molduras.',
			devices = { phone = true }
		}
	},
	-- Ordem das categorias na vitrine.
	StoreCategories = { 'Social', 'Foto e vídeo', 'Notícias', 'Compras', 'Finanças', 'Utilidades', 'Sistema' },

	-- Empregos: os grupos do tipo `job` do coe_core. Aqui só o texto e onde se apresentar (GPS).
	Jobs = {
		police = { description = 'Patrulha, atendimento de ocorrências e investigação.', place = 'Delegacia de Mission Row', x = 428.9, y = -984.5 },
		ambulance = { description = 'Atendimento de emergência e cuidados no hospital.', place = 'Hospital Pillbox Hill', x = 298.6, y = -584.6 },
		mechanic = { description = 'Reparos, revisões e personalização de veículos.', place = 'Oficina', x = -347.3, y = -133.6 }
	},

	Classifieds = {
		Fee = 50, -- taxa por anúncio, debitada da conta
		DurationHours = 72,
		MaxActive = 3, -- anúncios ativos por personagem
		TitleMax = 60,
		BodyMax = 400,
		PriceMax = 100000000,
		PageSize = 40,
		Categories = {
			{ id = 'vehicles', label = 'Veículos' },
			{ id = 'properties', label = 'Imóveis' },
			{ id = 'items', label = 'Itens' },
			{ id = 'services', label = 'Serviços' },
			{ id = 'jobs', label = 'Vagas' },
			{ id = 'other', label = 'Outros' }
		}
	},

	Insta = {
		CaptionMax = 280,
		PageSize = 12,
		PostCooldownSeconds = 60
	},

	Photos = {
		-- Tamanho máximo da foto já reduzida pelo tablet (data URI JPEG, em caracteres).
		MaxBytes = 400000,
		-- Largura máxima em que o tablet reduz a foto antes de enviar, e a qualidade do JPEG.
		Width = 960,
		Quality = 0.72,
		UploadCooldownSeconds = 8,
		-- Apps que podem enviar fotos (o Insta e os portais de notícias) e resources que guardam fotos pelo export ClaimPhoto.
		Apps = { 'insta', 'weazel', 'rebel' },
		Callers = { coe_news = true },
		PendingSeconds = 600,
		-- Host das fotos. Sem `coe_apps_upload_url`, as fotos ficam no banco (funciona sem configurar nada).
		-- Com ela, o servidor envia a foto em POST form-urlencoded (`<Field>=<base64>` e, se houver
		-- `coe_apps_upload_key`, `<KeyField>=<chave>`) e lê a URL pública da resposta JSON em `ResponsePath`.
		UrlConvar = 'coe_apps_upload_url',
		KeyConvar = 'coe_apps_upload_key',
		Field = 'image',
		KeyField = 'key',
		ResponsePath = 'data.url'
	}
}
