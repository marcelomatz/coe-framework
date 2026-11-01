Config = {
	Command = 'coeadmin',
	-- Tecla de atalho para abrir o painel (só abre para quem tem permissão ACE); nil/false desativa.
	OpenKey = 'F10',
	Permissions = {
		root = 'coe_admin.root',
		open = 'coe_admin.open',
		giveItems = 'coe_admin.items.give',
		manageStaff = 'coe_admin.staff.manage',
		manageGroups = 'coe_admin.groups.manage',
		manageResources = 'coe_admin.resources.manage',
		manageTheme = 'coe_admin.theme.manage',
		manageBusinesses = 'coe_admin.businesses.manage',
		viewPlayers = 'coe_admin.players.view',
		-- Banco: níveis de cartão, limites, pontos e empréstimos. Alto nível apenas: root ou ACE explícita (nenhum cargo recebe).
		manageBanking = 'coe_admin.banking.manage',
		-- Criptomoeda: parâmetros da moeda, carteiras, taxas, corretora, cotação e mineração (coe_crypto).
		manageCrypto = 'coe_admin.crypto.manage',
		-- Imprensa: Weazel News e Rebel News (negócio, equipe, equipamentos, anúncios e matérias).
		manageNews = 'coe_admin.news.manage',
		-- DeepWeb: sites por blocos, fornecedores NPC do Deep Market, disputas de pedidos, moderação do Rabbit e contatos dos perfis (coe_deepweb).
		manageDeepweb = 'coe_admin.deepweb.manage'
	},
	Roles = {
		administrator = {
			label = 'Administrador',
			permissions = {
				open = true,
				giveItems = true,
				manageStaff = true,
				manageGroups = true,
				manageResources = false,
				manageTheme = false,
				manageBusinesses = true,
				viewPlayers = true,
				manageCrypto = true,
				manageNews = true,
				manageDeepweb = true
			}
		},
		moderator = {
			label = 'Moderador',
			permissions = {
				open = true,
				giveItems = true,
				manageStaff = false,
				manageGroups = false,
				manageResources = false,
				manageTheme = false,
				manageBusinesses = false,
				viewPlayers = true,
				manageCrypto = false,
				manageNews = false,
				manageDeepweb = false
			}
		}
	}
}
