# coe_businesses

Registro em MariaDB dos negócios do servidor (mecânicas, lojinhas, postos, restaurantes, delegacias, hospitais, mídia e outros). Guarda categoria, área, pontos de operação (baús, mesas de craft, showroom) e regras por categoria. A edição é feita pela aba **Negócios** do `coe_admin`.

## Modelo

```lua
{
  id = 'bennys', category = 'mechanic', label = "Benny's", enabled = true,
  area = { kind = 'circle', x, y, z, radius }           -- ou { kind = 'polygon', points = {{x,y}...}, z, height }
  stations = { showroom = {x,y,z,radius}, crafts = {...}, stashes = {...}, clocks = {...} },
  rules = { ownerAccess = true, priceMultiplier = 1.0, clockRequired = true, clockOffsite = false, multiJob = true },
  owner = { characterId = '3', name = 'Fulano' },        -- opcional
  partners = { { characterId = '7', name = 'Sicrano' } } -- sócios (até Limits.MaxPartners)
}
```

As categorias, os pontos aceitos por cada uma e o esquema de regras ficam em `config.lua` (`Categories`, `Rules`, `Limits`).

## Exports (servidor)

- Leitura: `IsReady()`, `Categories()`, `RuleSchema()`, `List(category?)`, `Get(id)`.
- Escrita (só `WriterResources`: `coe_admin`, `coe_mechanic`, `coe_news` e outros pacotes que semeiam negócios): `Save(raw, by)`, `Seed(raw)` (cria só se não existir), `Delete(id, by)`.
- Acesso e equipe: `Access(businessId, characterId)`, `Partners(businessId)`, `Debtors(businessId)`.
- Cargos: `Permissions()`, `RegisterPermissions(list)`, `Grades(businessId)`, `GradeOf(businessId, characterId)`, `Can(businessId, characterId, permission)`, `Salary(businessId, characterId)`, `Payroll(businessId)`.
- Ponto: `Clock(source, businessId, stationId)`, `ClockIn(...)`, `ClockOut(...)`, `IsOnDuty(businessId, characterId)`, `CurrentDuty(source)`, `DutySummary()` (só `coe_admin`).
- Tablet: `TabletInstances(playerId)`, `TabletCall(playerId, appId, action, payload, instance)` (só `TabletResources`).

> **Retorno entre resources:** `Save`, `Seed`, `Delete`, `ClockIn`, `ClockOut`, `Clock` e `TabletCall` retornam um único valor: o resultado ou `{ error = codigo }` (como em `coe_crafting`, `coe_garages` e `coe_factions`).

Eventos de servidor: `coe_businesses:ready`, `coe_businesses:changed` (id) e `coe_businesses:dutyChanged` (source, businessId, onDuty, reason).

## Ponto da equipe

Cada negócio tem pontos de bater cartão (`stations.clocks`) e regras de ponto: `clockRequired` (padrão sim: dono e equipe só operam e administram de ponto batido **naquele negócio**; um dono de vários negócios bate ponto em cada um) e `clockOffsite` (padrão não: sair da área encerra o ponto; ligado, o ponto segue aberto fora dela). A regra `multiJob` (padrão sim; **não** em polícia e EMS) define se a equipe pode ter outros empregos: desligada, é dedicação exclusiva e o `Save` recusa (`multiple_jobs`) quem já é equipe de outro negócio ativo, e vice-versa. O dono não conta como emprego, então pode ser dono de quantos negócios quiser. Seja qual for a regra, o jogador só fica de ponto em um negócio por vez (`on_duty_elsewhere`). O estado fica em memória (`server/duty.lua`) e cai ao sair do servidor. Exports: `ClockIn(source, characterId, businessId, at, atStation)` e `ClockOut(source, reason)` (só `WriterResources`; quem chama valida a equipe e o local), `IsOnDuty(businessId, characterId)` e `CurrentDuty(source)`. Motivos de encerramento: `clock_out`, `left_area`, `business_closed`. Testes: `lua test/duty_test.lua`.

## Observações

- Categorias e quem as consome: `mechanic` (`coe_mechanic`), `shop`, `restaurant` e `other` (bancadas e baús via `coe_crafting`), `gas_station` (só baús e ponto por enquanto), `police` (`coe_police`, `coe_mdt`, `coe_dispatch`), `ems` (`coe_ems`, `coe_dispatch`) e `media` (`coe_news`). `ruleDefaults` muda o padrão por categoria: polícia e EMS nascem com `multiJob = false`; mídia, com `clockOffsite = true`.
- A categoria `media` (Mídia: baús e ponto, ponto segue aberto fora da área) é usada pelos veículos de comunicação do `coe_news` (Weazel News e Rebel News), com as permissões `news.*`.
- O dono faz parte do negócio: `owner = { characterId, name }` (opcional), definido pelo `coe_admin` a partir do ID (`stateId`) do personagem, online ou não. O `coe_mechanic` concede acesso completo ao tablet da oficina ao dono.
- Tabela `coe_businesses` (equipe, cargos, sócios e regras ficam no JSON `data`), migrações em `coe_businesses_schema_migrations`.
- Testes: `lua test/registry_test.lua`, `access_test.lua`, `duty_test.lua`, `grades_test.lua` e `tablet_test.lua`.

## Estações de craft e isolamento entre negócios

As estações `crafts` de `restaurant`, `shop` e `other` viram bancadas do `coe_crafting` (ponte em `coe_crafting\server\bridge.lua`). A oficina continua com o fluxo do `coe_mechanic`.
Cada acesso é por negócio: dono (`ownerAccess`) ou funcionário cadastrado **na equipe daquele negócio** (`staff`, aba Equipe do `coe_admin`) e de ponto (um ponto por jogador, ver `IsOnDuty`; `clockRequired = false` dispensa o ponto, mas só vale para a equipe do próprio negócio). O emprego não concede acesso. Dono ou equipe de um negócio não operam outro; receitas, bancadas e baús são separados por negócio e por categoria. Detalhes e limitações em `coe_crafting\README.md`.
## Equipe e ponto (todos os negócios)

- `staff`: lista `{characterId, name}` por negócio (máx. `Limits.MaxStaff`), editada na aba **Equipe** do `coe_admin`. Dois negócios nunca compartilham equipe, mesmo com o mesmo emprego. Migração: quem era equipe por emprego deve ser recadastrado na equipe.
- Export `Access(businessId, characterId)` → `{ owner, staff, partner, canClock, canWork }`; é a única fonte de decisão usada por `coe_mechanic` e `coe_crafting`.
- Sócios (`partners`): respondem pelas dívidas do negócio junto com o dono (empréstimos empresariais do `coe_banking`). Ser sócio não dá acesso de trabalho nem conta como emprego. Entram só por convite do dono no tablet, com aceite; o dono remove. Exports `Partners(businessId)` e `Debtors(businessId)` (dono primeiro, depois os sócios; vazio sem dono). O `coe_admin` preserva a lista ao salvar e a limpa quando o dono muda.
- Export `Clock(source, businessId, stationId)` (restrito a `ClockResources`), comando `/ponto` e prompt (E) nos pontos de ponto dos negócios que não são oficina. Nesses negócios, os baús (`stashes`) também têm prompt (E, "Abrir baú"): só dono e equipe, perto do ponto, abertos pelo `OpenStash` do `coe_inventory` com id `stash:business:<negócio>:<baú>`; a bancada do `coe_crafting` usa o baú mais próximo como fonte de ingredientes. Quem sai da equipe tem o ponto encerrado (`not_staff`).

## Cargos, salários e permissões

Empregos, cargos e salários vivem **dentro do negócio** (não há `coe_jobs`). Cada negócio tem `grades` (até `Limits.MaxGrades`): `{ id, label, level 0..99, salary, permissions[] }`; ids e níveis são únicos e o menor nível é o cargo de entrada. Cada membro da equipe tem `grade`; sem cargo informado recebe o de entrada, e um cargo inexistente é recusado (`invalid_staff_grade`). Dados inválidos retornam `invalid_grades`. Editado na aba **Cargos** e na aba **Equipe** do `coe_admin`. Nada é compartilhado entre negócios, nem os cargos.

Permissões usam o formato `prefixo.acao`. O catálogo base é `business.funds`, `business.staff`, `business.fleet` e `business.remote` (gerenciar a distância pelo tablet); pacotes em `PermissionResources` (`coe_police`, `coe_ems`, `coe_mechanic`, `coe_economy`, `coe_mdt`, `coe_news`, `coe_banking`) registram as suas com `RegisterPermissions({ { name = 'police.arrest', label = 'Prender' } })` (o prefixo é o nome do resource sem `coe_`).

- Leitura: `Permissions()`, `Grades(businessId)`, `GradeOf(businessId, characterId)`, `Can(businessId, characterId, permission)` (o dono tem tudo se tiver `ownerAccess`; a equipe só pelo cargo e em serviço quando `clockRequired`).
- Folha (só `PayrollResources`: `coe_economy`, `coe_admin`, `coe_banking`): `Salary(businessId, characterId)` e `Payroll(businessId)`.
- Eventos de servidor: `coe_businesses:staffChanged` (id, characterId, change `added|removed|grade`, grade) e `coe_businesses:gradesChanged` (id).
- Categorias `police` (Delegacias) e `ems` (Hospitais), consumidas por `coe_police` e `coe_ems`. Testes: `lua test/grades_test.lua`.

## Tablet de negócios

App `business` do `coe_tablet` (`html/tablet_app.js`, lógica em `server/tablet.lua`, export `TabletCall` restrito a `TabletResources`). No COE OS cada negócio de que o personagem é dono ou funcionário vira um app (export `TabletInstances`). O negócio é a instância do app, revalidada a cada ação: o **dono** e os cargos com a permissão `business.remote` (gerentes) gerenciam a distância, cada um com as permissões do próprio cargo; o restante da equipe precisa estar **de ponto** naquele negócio (salvo negócio sem ponto obrigatório). Quem não é dono nem funcionário recebe `forbidden`.

- Resumo: cargo, proprietário, equipe, caixa (só com `business.funds`) e regras.
- Loja: só para negócios que são lojas do `coe_shops` (`IsStore`); a ação `shop` encaminha ao export `BusinessTablet` das lojas (prateleira, preços e vendas; preço com `shops.prices`). A tela é carregada de `nui://coe_shops/html/business.js`.
- Banco: conta empresarial do `coe_banking` (resumo, extrato com quem fez cada operação, transferências, cartões, folha, bônus e empréstimos), com as permissões de cargo `banking.*`; a ação `bank` encaminha a operação ao export `BusinessTablet` do banco com o negócio do app. Sem o `coe_banking`, volta a aba Financeiro (`business.funds`: saldo da sociedade, folha, lançamentos, depósito e saque via `coe_economy`).
- Equipe: lista (salários só com `business.staff` ou `business.funds`); contratar por ID de cidadão online, trocar cargo e demitir exigem `business.staff`. Quem não é dono só mexe em cargos abaixo do próprio. A contratação é uma proposta: o cidadão recebe a confirmação na tela e tem `OfferSeconds` (60 s) para aceitar; uma proposta pendente por pessoa. No aceite tudo é revalidado e gravado por `Save`, que aplica `multiJob`.
- Sócios: lista para toda a equipe de ponto; só o dono convida (ID de cidadão online, mesma proposta com aceite e prazo da contratação, avisando que sócios respondem pelas dívidas do negócio) e remove. Dívidas já contratadas continuam com quem era sócio na contratação.
- Acessos (`business.staff`): matriz de cargos e permissões, somente leitura.
- Estrutura: área e pontos (ponto, baús, bancadas, showroom) com botão de GPS. Toda a equipe de ponto vê.
- Frota: veículos das garagens `business` do negócio (`coe_garages`), estado e quem usa. Liberar/bloquear para a equipe exige `business.fleet`.
- Propriedades: imóveis comerciais do negócio (`coe_housing:BusinessProperties`, alugados ou cedidos pelo admin) e garagens de frota.
- Próximas fases: apps de Polícia e EMS no COE OS (#229), níveis de negócio (#172) e maquininha de cartão (#262). Testes: `lua test/tablet_test.lua`.
