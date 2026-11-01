-- Amzg: loja virtual do COE OS (tablet e smartphone). O catálogo é editado no painel admin (aba Amzg).
-- A compra é paga no cartão de crédito pela Carteira do smartphone e chega numa caixa dentro do imóvel escolhido.
AmzgConfig = {
	-- Resources que podem editar o catálogo (exports Admin*).
	AdminCallers = { coe_admin = true },

	-- Categorias do catálogo, na ordem da vitrine.
	Categories = {
		{ id = 'food', label = 'Alimentos' },
		{ id = 'drinks', label = 'Bebidas' },
		{ id = 'electronics', label = 'Eletrônicos' },
		{ id = 'tools', label = 'Ferramentas' },
		{ id = 'health', label = 'Saúde' },
		{ id = 'home', label = 'Casa' },
		{ id = 'other', label = 'Outros' }
	},

	-- Opções de frete: prazo em minutos reais e taxa somada ao pedido.
	Shipping = {
		{ id = 'standard', label = 'Padrão', minutes = 30, fee = 0 },
		{ id = 'express', label = 'Expressa', minutes = 5, fee = 150 }
	},

	-- Catálogo: limite de produtos, preço máximo por unidade e tamanho máximo do nome.
	Products = { Max = 300, PriceMax = 100000, LabelMax = 48 },

	-- Promoções e banners: tamanho do selo do banner, troca do banner de destaque (segundos) e de quantos em quantos
	-- produtos entra um banner no meio da vitrine.
	Promo = { BannerTextMax = 24, RotateSeconds = 6, InlineEvery = 6 },

	-- Carrinho: produtos diferentes, unidades por produto e espaços da caixa (cada pilha do item ocupa um).
	-- O total (com frete) respeita o teto da Carteira e do banco (100000).
	Cart = { MaxLines = 10, MaxQuantity = 50, MaxSlots = 20, MaxTotal = 100000 },

	-- Pedidos ainda a caminho por personagem e quantos aparecem no histórico do app.
	Orders = { MaxPending = 10, History = 15 },

	-- Caixa da entrega: aparece no ponto interior do imóvel, em fileiras de `Columns` à frente do ponto.
	-- `Reach`: distância para abrir. Vazia, a caixa some; o conteúdo só é apagado `CollectDelaySeconds` depois.
	Box = { Model = 'prop_cs_cardbox_01', Columns = 3, Spacing = 0.75, Forward = 1.2, Reach = 2.5, WatchSeconds = 600, CollectDelaySeconds = 60 },

	-- Intervalo da entrega dos pedidos vencidos.
	DeliveryTickSeconds = 15
}
