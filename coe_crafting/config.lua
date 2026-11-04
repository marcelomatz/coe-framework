CraftingConfig = {
	-- Capacidade ACE (`add_ace resource.<nome> coe.crafting allow`) e resources padrão que registram bancadas e executam craft.
	Ace = 'coe.crafting',
	AllowedResources = {
		coe_mechanic = true,
		coe_businesses = true,
		coe_factions = true,
		coe_admin = true,
		-- Bancada dos computadores da DeepWeb (gravar o navegador onion em pen drive).
		coe_deepweb = true
	},
	MaxInputs = 8,
	MaxOutputs = 4,
	MaxCount = 1000,
	MinTimeMs = 500,
	MaxTimeMs = 120000,
	MaxIllegalBenches = 32,
	MaxCoordinate = 10000.0,
	Sources = { player = true, stash = true, both = true },

	-- Bancadas dos negócios (estação `crafts`), por categoria. O tipo da bancada é `business_<categoria>`.
	-- source: de onde saem os insumos (player, stash ou both); output: para onde vai o produto.
	-- O baú usado é `stash:business:<negócio>:<estação>`; sem baú com itens, a origem `both` cai só no jogador.
	BusinessBenches = {
		restaurant = { label = 'Cozinha', categories = { 'kitchen' }, source = 'both', output = 'player',
			animation = { dict = 'mini@repair', name = 'fixing_a_ped' } },
		shop = { label = 'Bancada da loja', categories = { 'retail' }, source = 'both', output = 'player',
			animation = { dict = 'mini@repair', name = 'fixing_a_ped' } },
		other = { label = 'Bancada', categories = { 'workshop' }, source = 'both', output = 'player',
			animation = { dict = 'mini@repair', name = 'fixing_a_ped' } }
	},

	-- Bancada das facções (estação `crafts` do grupo). As receitas liberadas e o cargo mínimo vêm do coe_factions.
	-- O baú usado é `stash:faction:<facção>:<estação>`; sem baú com itens, a origem `both` cai só no jogador.
	FactionBench = {
		label = 'Bancada da facção',
		categories = { 'illegal', 'workshop', 'mechanic', 'kitchen', 'retail' },
		source = 'both',
		output = 'player',
		animation = { dict = 'mini@repair', name = 'fixing_a_ped' }
	},

	-- Bancadas clandestinas livres (sem vínculo com negócio ou facção): abertas a qualquer jogador.
	-- Consomem apenas da mochila do jogador (`source = 'player'`) e entregam na mochila.
	IllegalBench = {
		label = 'Bancada clandestina',
		categories = { 'illegal' },
		source = 'player',
		output = 'player',
		animation = { dict = 'mini@repair', name = 'fixing_a_ped' }
	},

	-- Quem pode registrar receitas em cada categoria. Categoria fora da lista aceita qualquer resource permitido.
	-- Evita que o craft de um negócio apareça na bancada de outro.
	CategoryOwners = {
		mechanic = 'coe_mechanic',
		kitchen = 'coe_crafting',
		retail = 'coe_crafting',
		workshop = 'coe_crafting',
		illegal = 'coe_crafting',
		hacking = 'coe_deepweb'
	},

	-- Menu próprio de cada negócio: { [idDoNegocio] = { 'id_da_receita', ... } }. Sem entrada, vale toda receita das
	-- categorias da bancada. Receitas de categorias que a bancada não aceita nunca aparecem, mesmo listadas aqui.
	BusinessRecipes = {},

	-- Receitas e tipos de cardápio cadastrados no painel (Negócios > Receitas) ficam no banco. Categorias de receita que o
	-- painel pode criar e limites do catálogo. Cada negócio escolhe um tipo de cardápio e pode ajustar a própria lista.
	EditableCategories = { kitchen = true, retail = true, workshop = true, illegal = true },
	MaxCustomRecipes = 300,
	MaxMenus = 60,
	MaxMenuRecipes = 60,

	-- Receitas versionadas. As demais vêm dos resources que registram bancadas.
	-- { id, label, category, timeMs, inputs = { { item, count } }, outputs = { { item, count } } }
	Recipes = {
		{ id = 'kitchen_burger', label = 'Hambúrguer', category = 'kitchen', timeMs = 5000,
			inputs = { { item = 'bread', count = 1 }, { item = 'ingredient_meat', count = 1 }, { item = 'ingredient_cheese', count = 1 } },
			outputs = { { item = 'burger', count = 1 } } },
		{ id = 'kitchen_fries', label = 'Batata frita', category = 'kitchen', timeMs = 4000,
			inputs = { { item = 'ingredient_potato', count = 2 } }, outputs = { { item = 'fries', count = 1 } } },
		{ id = 'kitchen_pizza', label = 'Pizza de presunto', category = 'kitchen', timeMs = 8000,
			inputs = { { item = 'ingredient_dough', count = 1 }, { item = 'ingredient_cheese', count = 1 }, { item = 'ingredient_meat', count = 1 } },
			outputs = { { item = 'pizza_ham', count = 1 } } },
		{ id = 'retail_bandage', label = 'Bandagem', category = 'retail', timeMs = 3000,
			inputs = { { item = 'cloth', count = 2 } }, outputs = { { item = 'bandage', count = 2 } } },
		{ id = 'retail_repairkit', label = 'Kit de reparo básico', category = 'retail', timeMs = 6000,
			inputs = { { item = 'scrapmetal', count = 3 }, { item = 'plastic', count = 1 } }, outputs = { { item = 'repairkit', count = 1 } } },
		{ id = 'illegal_lockpick', label = 'Gazua', category = 'illegal', timeMs = 5000,
			inputs = { { item = 'scrapmetal', count = 2 }, { item = 'plastic', count = 1 } }, outputs = { { item = 'lockpick', count = 1 } } },
		{ id = 'illegal_ziptie', label = 'Abraçadeira', category = 'illegal', timeMs = 4000,
			inputs = { { item = 'plastic', count = 2 } }, outputs = { { item = 'ziptie', count = 2 } } },
		{ id = 'illegal_armour', label = 'Colete clandestino', category = 'illegal', timeMs = 10000,
			inputs = { { item = 'cloth', count = 4 }, { item = 'scrapmetal', count = 2 }, { item = 'rubber', count = 2 } },
			outputs = { { item = 'armour', count = 1 } } }
	}
}
