-- Rabbit (rabbit.onion): comunidades, posts, comentários em árvore e votos, tudo pelo apelido anônimo.
-- Ler é livre (com o navegador); escrever exige apelido conectado no aparelho. Quem cria a comunidade modera ela.
local config = DeepwebConfig
local forum = config.Forum
local App = DeepwebApp
local S = DeepwebServer

local function fail(code, extra)
	local result = extra or {}
	result.ok = false
	result.error = code
	return result
end

-- Apelido conectado no aparelho, ou nil + erro.
local function signedIn(context)
	local session = DeepwebPersistence.Session(context.key)
	if session == nil then
		return nil, 'database_error'
	end
	if not session then
		return nil, 'not_signed_in'
	end
	return session
end

-- Apelido conectado (sem erro quando não há): para marcar votos e permissões na leitura.
local function viewer(context)
	local session = DeepwebPersistence.Session(context.key)
	return session or nil
end

local function page(value)
	local number = math.tointeger(tonumber(value)) or 1
	return math.max(1, math.min(number, 50))
end

local function sortOf(value)
	return (value == 'new' or value == 'top') and value or 'hot'
end

local function markVotes(session, target, list)
	if not session or #list == 0 then
		return
	end
	local ids = {}
	for _, entry in ipairs(list) do
		ids[#ids + 1] = entry.id
	end
	local votes = DeepwebPersistence.VotesOf(session.id, target, ids) or {}
	for _, entry in ipairs(list) do
		entry.vote = votes[entry.id] or 0
	end
end

-- Posts de uma comunidade (ou de todas): "em alta" ordena no servidor os da última semana.
local function listPosts(filter, sort, pageNumber)
	local size = forum.PageSize
	if sort == 'hot' then
		local now = os.time()
		local candidates = DeepwebPersistence.Posts({ communityId = filter.communityId, sort = 'new', since = now - 7 * 86400, limit = 300 })
		if not candidates then
			return nil
		end
		for _, entry in ipairs(candidates) do
			entry.hot = DeepwebRules.Hot(entry.score, entry.createdAt, now)
		end
		table.sort(candidates, function(a, b)
			if a.hot ~= b.hot then return a.hot > b.hot end
			return a.id > b.id
		end)
		local list = {}
		for index = (pageNumber - 1) * size + 1, math.min(#candidates, pageNumber * size) do
			candidates[index].hot = nil
			list[#list + 1] = candidates[index]
		end
		-- Semana parada: completa com os mais novos.
		if #list == 0 and pageNumber == 1 then
			return DeepwebPersistence.Posts({ communityId = filter.communityId, sort = 'new', limit = size }), false
		end
		return list, #candidates > pageNumber * size
	end
	local list = DeepwebPersistence.Posts({ communityId = filter.communityId, handleId = filter.handleId, sort = sort, offset = (pageNumber - 1) * size, limit = size + 1 })
	if not list then
		return nil
	end
	local more = #list > size
	if more then
		list[#list] = nil
	end
	return list, more
end

local function stripPrivate(list)
	for _, entry in ipairs(list) do
		entry.handleId = nil
		entry.communityId = nil
	end
	return list
end

function App.forumHome(context, payload)
	local denied = S.RequireFeature(context, 'forum')
	if denied then
		return fail(denied)
	end
	local communities = DeepwebPersistence.Communities()
	local sort, pageNumber = sortOf(payload.sort), page(payload.page)
	local posts, more = listPosts({}, sort, pageNumber)
	if not communities or not posts then
		return fail('database_error')
	end
	local session = viewer(context)
	markVotes(session, 'p', posts)
	for _, entry in ipairs(communities) do
		entry.createdBy = nil
	end
	return {
		ok = true, communities = communities, posts = stripPrivate(posts), sort = sort, page = pageNumber, more = more == true,
		me = session and session.handle or nil, canCreate = DeepwebRules.Allows(config, config.Tiers[context.kind].level, 'forum_create')
	}
end

function App.forumCommunity(context, payload)
	local denied = S.RequireFeature(context, 'forum')
	if denied then
		return fail(denied)
	end
	local slug = DeepwebRules.Slug(config, payload.slug)
	if not slug then
		return fail('not_found')
	end
	local community = DeepwebPersistence.CommunityBySlug(slug)
	if community == nil then
		return fail('database_error')
	end
	if not community then
		return fail('not_found')
	end
	local sort, pageNumber = sortOf(payload.sort), page(payload.page)
	local posts, more = listPosts({ communityId = community.id }, sort, pageNumber)
	if not posts then
		return fail('database_error')
	end
	local session = viewer(context)
	markVotes(session, 'p', posts)
	local moderating = session ~= nil and community.createdBy ~= nil and community.createdBy == session.id
	community.createdBy = nil
	return {
		ok = true, community = community, posts = stripPrivate(posts), sort = sort, page = pageNumber, more = more == true,
		me = session and session.handle or nil, moderating = moderating
	}
end

local function communityOfPost(post)
	local community = DeepwebPersistence.CommunityBySlug(post.community)
	return community or nil
end

-- Pode remover: autor ou moderador (quem criou a comunidade).
local function canRemove(session, authorHandleId, community)
	if not session then
		return false
	end
	return authorHandleId == session.id or (community ~= nil and community.createdBy ~= nil and community.createdBy == session.id)
end

function App.forumPost(context, payload)
	local denied = S.RequireFeature(context, 'forum')
	if denied then
		return fail(denied)
	end
	local id = math.tointeger(tonumber(payload.id))
	if not id then
		return fail('not_found')
	end
	local post = DeepwebPersistence.PostById(id)
	if post == nil then
		return fail('database_error')
	end
	if not post or post.removed then
		return fail('not_found')
	end
	local comments = DeepwebPersistence.Comments(id, forum.MaxCommentsShown)
	if not comments then
		return fail('database_error')
	end
	local session = viewer(context)
	local community = communityOfPost(post)
	markVotes(session, 'p', { post })
	markVotes(session, 'c', comments)
	for _, comment in ipairs(comments) do
		comment.mine = session ~= nil and comment.handleId == session.id
		comment.canRemove = not comment.removed and canRemove(session, comment.handleId, community)
		if comment.removed then
			comment.body = ''
			comment.author = nil
		end
		comment.handleId = nil
	end
	post.canRemove = canRemove(session, post.handleId, community)
	post.mine = session ~= nil and post.handleId == session.id
	post.handleId = nil
	post.communityId = nil
	return {
		ok = true, post = post, comments = DeepwebRules.Thread(comments, forum.MaxDepth),
		community = community and { slug = community.slug, title = community.title, description = community.description, moderator = community.moderator } or nil,
		me = session and session.handle or nil
	}
end

function App.forumSubmit(context, payload)
	local denied = S.RequireFeature(context, 'forum')
	if denied then
		return fail(denied)
	end
	local session, errorCode = signedIn(context)
	if not session then
		return fail(errorCode)
	end
	local slug = DeepwebRules.Slug(config, payload.slug)
	local title = DeepwebRules.Text(payload.title, forum.TitleMax, false, forum.TitleMin)
	local body = payload.body == nil and '' or DeepwebRules.Text(payload.body, forum.BodyMax, true, 0)
	if not slug then
		return fail('invalid_community')
	end
	if not title then
		return fail('invalid_title')
	end
	if not body then
		return fail('invalid_body')
	end
	return S.WithLock('handle:' .. session.id, function()
		local now = os.time()
		local last = DeepwebPersistence.LastPostAt(session.id)
		if last == nil then
			return fail('database_error')
		end
		if now - last < forum.PostCooldownSeconds then
			return fail('post_cooldown', { seconds = forum.PostCooldownSeconds - (now - last) })
		end
		local community = DeepwebPersistence.CommunityBySlug(slug)
		if not community then
			return fail(community == false and 'invalid_community' or 'database_error')
		end
		local id = DeepwebPersistence.InsertPost({ communityId = community.id, handleId = session.id, title = title, body = body }, now)
		if not id then
			return fail('database_error')
		end
		S.Log('info', 'gameplay', 'deepweb_post_created', { character_id = context.character, target = slug })
		return { ok = true, id = id, slug = slug }
	end)
end

function App.forumComment(context, payload)
	local denied = S.RequireFeature(context, 'forum')
	if denied then
		return fail(denied)
	end
	local session, errorCode = signedIn(context)
	if not session then
		return fail(errorCode)
	end
	local postId = math.tointeger(tonumber(payload.postId))
	local parentId = payload.parentId ~= nil and math.tointeger(tonumber(payload.parentId)) or nil
	local body = DeepwebRules.Text(payload.body, forum.CommentMax, true)
	if not postId then
		return fail('not_found')
	end
	if not body then
		return fail('invalid_body')
	end
	return S.WithLock('handle:' .. session.id, function()
		local now = os.time()
		local last = DeepwebPersistence.LastCommentAt(session.id)
		if last == nil then
			return fail('database_error')
		end
		if now - last < forum.CommentCooldownSeconds then
			return fail('comment_cooldown', { seconds = forum.CommentCooldownSeconds - (now - last) })
		end
		local post = DeepwebPersistence.PostById(postId)
		if not post or post.removed then
			return fail(post == nil and 'database_error' or 'not_found')
		end
		if parentId then
			local parent = DeepwebPersistence.CommentById(parentId)
			if not parent or parent.postId ~= postId then
				return fail(parent == nil and 'database_error' or 'not_found')
			end
		end
		local id = DeepwebPersistence.InsertComment({ postId = postId, parentId = parentId, handleId = session.id, body = body }, now)
		if not id then
			return fail('database_error')
		end
		return { ok = true, id = id }
	end)
end

function App.forumVote(context, payload)
	local denied = S.RequireFeature(context, 'forum')
	if denied then
		return fail(denied)
	end
	local session, errorCode = signedIn(context)
	if not session then
		return fail(errorCode)
	end
	local target = payload.target == 'c' and 'c' or (payload.target == 'p' and 'p' or nil)
	local id = math.tointeger(tonumber(payload.id))
	local value = DeepwebRules.VoteValue(payload.value)
	if not target or not id or not value then
		return fail('invalid_vote')
	end
	return S.WithLock('vote:' .. session.id, function()
		local entry
		if target == 'p' then
			entry = DeepwebPersistence.PostById(id)
		else
			entry = DeepwebPersistence.CommentById(id)
		end
		if not entry or entry.removed then
			return fail(entry == nil and 'database_error' or 'not_found')
		end
		if entry.handleId == session.id then
			return fail('own_content')
		end
		local previous = DeepwebPersistence.VoteOf(target, id, session.id)
		if previous == nil then
			return fail('database_error')
		end
		local delta = DeepwebRules.VoteDelta(previous, value)
		if delta ~= 0 and not DeepwebPersistence.SetVote(target, id, session.id, value, delta) then
			return fail('database_error')
		end
		return { ok = true, vote = value, delta = delta }
	end)
end

function App.forumRemove(context, payload)
	local session, errorCode = signedIn(context)
	if not session then
		return fail(errorCode)
	end
	local target = payload.target == 'c' and 'c' or 'p'
	local id = math.tointeger(tonumber(payload.id))
	if not id then
		return fail('not_found')
	end
	local post, authorId
	if target == 'p' then
		post = DeepwebPersistence.PostById(id)
		authorId = post and post.handleId
	else
		local comment = DeepwebPersistence.CommentById(id)
		if not comment then
			return fail(comment == nil and 'database_error' or 'not_found')
		end
		authorId = comment.handleId
		post = DeepwebPersistence.PostById(comment.postId)
	end
	if not post then
		return fail(post == nil and 'database_error' or 'not_found')
	end
	if not canRemove(session, authorId, communityOfPost(post)) then
		return fail('forbidden')
	end
	local removed = target == 'p' and DeepwebPersistence.RemovePost(id) or DeepwebPersistence.RemoveComment(id)
	if not removed then
		return fail('database_error')
	end
	S.Log('info', 'gameplay', 'deepweb_content_removed', { character_id = context.character, target = target .. ':' .. id })
	return { ok = true }
end

function App.forumCreate(context, payload)
	local denied = S.RequireFeature(context, 'forum_create')
	if denied then
		return fail(denied)
	end
	local session, errorCode = signedIn(context)
	if not session then
		return fail(errorCode)
	end
	local slug
	slug, errorCode = DeepwebRules.Slug(config, payload.slug)
	if not slug then
		return fail(errorCode)
	end
	local title = DeepwebRules.Text(payload.title, forum.CommunityTitleMax, false, 3)
	local description = payload.description == nil and '' or DeepwebRules.Text(payload.description, forum.CommunityDescriptionMax, false, 0)
	if not title then
		return fail('invalid_title')
	end
	if not description then
		return fail('invalid_description')
	end
	return S.WithLock('handle:' .. session.id, function()
		local count = DeepwebPersistence.CommunitiesCreatedBy(session.id)
		if count == nil then
			return fail('database_error')
		end
		if count >= forum.MaxCommunitiesPerHandle then
			return fail('community_limit')
		end
		local id
		id, errorCode = DeepwebPersistence.InsertCommunity({ slug = slug, title = title, description = description, handleId = session.id }, os.time())
		if not id then
			return fail(errorCode == 'slug_taken' and errorCode or 'database_error')
		end
		S.Log('info', 'gameplay', 'deepweb_community_created', { character_id = context.character, target = slug })
		return { ok = true, slug = slug }
	end)
end

-- Perfil público de um apelido no Rabbit (e, se vender, as avaliações no Deep Market).
function App.forumUser(context, payload)
	local denied = S.RequireFeature(context, 'forum')
	if denied then
		return fail(denied)
	end
	local name = DeepwebRules.Handle(config, payload.handle)
	if not name then
		return fail('not_found')
	end
	local entry = DeepwebPersistence.HandleByName(name)
	if entry == nil then
		return fail('database_error')
	end
	if not entry then
		return fail('not_found')
	end
	local stats = DeepwebPersistence.HandleStats(entry.id)
	local posts = DeepwebPersistence.Posts({ handleId = entry.id, sort = 'new', limit = 15 })
	local reviews = DeepwebPersistence.SellerReviews(entry.id, 5)
	if not stats or not posts or not reviews then
		return fail('database_error')
	end
	return {
		ok = true, handle = entry.handle, createdAt = entry.createdAt, reputation = entry.reputation, karma = stats.karma,
		postCount = stats.posts, commentCount = stats.comments, posts = stripPrivate(posts), reviews = reviews
	}
end

for _, action in ipairs({ 'forumHome', 'forumCommunity', 'forumPost', 'forumUser' }) do
	S.ReadOnly(action)
end

-- Comunidades iniciais (só as que ainda não existem).
S.OnReady(function()
	local now = os.time()
	for _, entry in ipairs(forum.Communities) do
		if DeepwebPersistence.CommunityBySlug(entry.slug) == false then
			DeepwebPersistence.InsertCommunity({ slug = entry.slug, title = entry.title, description = entry.description }, now)
		end
	end
end)
