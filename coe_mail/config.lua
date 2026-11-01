-- E-mail do COE OS (smartphone e tablet). Cada conta é um endereço com senha: quem sabe a senha entra em qualquer
-- aparelho. A sessão fica presa ao aparelho (o smartphone pelo número de série; o tablet pelo personagem).
MailConfig = {
	-- Domínio público e gratuito: qualquer pessoa cria contas nele.
	PublicDomain = 'correio.coe',

	-- Contas: quantas cada personagem pode criar, tamanho do nome antes do @ (letras minúsculas, números, . _ -),
	-- da senha, do nome de exibição e da assinatura.
	Accounts = { MaxPerCharacter = 3, LocalMin = 3, LocalMax = 24, PasswordMin = 6, PasswordMax = 32, NameMax = 40, SignatureMax = 200 },

	-- Nomes que ninguém pode registrar no domínio público.
	Reserved = {
		admin = true, administrador = true, postmaster = true, root = true, suporte = true, abuse = true,
		noreply = true, ['no-reply'] = true, sistema = true, contato = true, governo = true, policia = true
	},

	-- Entrada: tentativas erradas seguidas antes do bloqueio da conta e quanto dura. Contas abertas por aparelho.
	Login = { MaxFailures = 5, LockSeconds = 60, MaxSessionsPerDevice = 5 },

	-- Mensagens: destinatários (Para + Cc + Cco), tamanho do assunto e do texto, intervalo entre envios da mesma conta,
	-- mensagens guardadas por conta (cheia, a conta não recebe mais), dias na Lixeira e mensagens por página.
	Messages = {
		MaxRecipients = 10, SubjectMax = 120, BodyMax = 4000, DraftListMax = 400,
		SendCooldownSeconds = 10, MaxPerAccount = 500, TrashDays = 7, PageSize = 30, SearchMax = 40
	},

	-- Resources que podem enviar e-mails do sistema pelo export Send (ex.: avisos do banco).
	SystemCallers = {},

	-- Limpeza da Lixeira vencida e das mensagens sem dono.
	PurgeMinutes = 30
}
