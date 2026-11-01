# coe_elos

**Elos**, a rede profissional do COE OS, no smartphone e no tablet. Vem instalada em todo aparelho (`coe_apps`,
categoria Social). Fase 1: perfil, currículo e conexões. Vagas, perfil das empresas e candidaturas chegam na fase 2,
quando o Elos substitui o app Empregos.

## Perfil

- Nome e ID (o mesmo do `/id`) vêm do personagem; o jogador escreve a **apresentação** (até 80 caracteres) e o
  **Sobre** (até 600).
- **Aberto**: qualquer pessoa vê o perfil completo. **Fechado**: só as conexões; os outros veem nome, apresentação e
  número de conexões.
- **Mostrar carreira**: nível de carreira, reputação e habilidades dos empregos livres (`coe_jobs`).
- **Mostrar ganhos**: quanto ganhou em cada experiência (desligado por padrão).

## Currículo

O currículo sai do histórico real do personagem; o jogador só escolhe o que mostra e escreve um comentário.

| Fonte | O que entra |
| --- | --- |
| Empregos livres (`coe_jobs:GetCareer`) | Cada emprego com pelo menos uma tarefa: tempo trabalhado, tarefas, nível, ganhos, primeira e última vez. |
| Negócios (`coe_businesses`) | Horas de ponto somadas a cada fim de turno (`coe_businesses:dutyChanged` e saída do jogo), turnos, último cargo e primeira/última vez; vínculos atuais (equipe ou dono) aparecem como **Atual**, mesmo sem horas. |

- Turnos com menos de `Resume.MinShiftSeconds` (60 s) não contam.
- Até `Resume.MaxItems` experiências no currículo. Horas, tarefas e cargos não são editáveis.
- Quem já estava de ponto quando o Elos iniciou começa a contar naquele momento.
- O tempo dos empregos livres é somado pelo `coe_jobs` (migração 4) a partir de quando a atualização entrou; os
  trabalhos já registrados em `coe_jobs_sessions` foram somados na migração.

## Conexões

- Busca por nome (3 letras ou mais) ou pelo ID completo, entre quem já abriu o Elos.
- Pedido com aceite: a outra pessoa recebe um aviso (se online) e aceita ou recusa na aba **Rede**. Pedir a quem já
  tinha pedido para você conecta na hora.
- Cancelar um pedido enviado ou remover uma conexão a qualquer momento.
- Limites: `Network.MaxConnections` (300) e `Network.MaxPendingOut` (30) pedidos aguardando.

## Banco

| Tabela | Conteúdo |
| --- | --- |
| `coe_elos_profiles` | Perfil (nome e ID copiados para busca e visitas offline, apresentação, sobre, visibilidade, opções). |
| `coe_elos_items` | Experiências no currículo (`job`/`business` + id) com o comentário. |
| `coe_elos_work` | Horas e turnos por personagem e negócio, último cargo, primeira e última vez. |
| `coe_elos_connections` | Uma linha por par: quem pediu, quem recebeu, `pending` ou `accepted`. |

Migrações em `coe_elos_schema_migrations`.

## Exports (servidor)

`IsReady`, `GetProfile(characterId)` (perfil público com o currículo, base das candidaturas), `TabletVisible` e
`TabletCall` (só `coe_tablet` e `coe_phone`). Referência: [reference/coe_elos.md](../reference/coe_elos.md).

## Testes

`lua test\rules_test.lua` (perfil, currículo montado do histórico, visibilidade, pedidos) e `lua test\server_test.lua`
(estado, perfil, currículo só com experiências reais, horas de ponto, busca, conexões, perfil fechado e
`GetProfile`, com natives e banco simulados).

## Dependências e allowlists

`coe_core`, `coe_database`, `coe_logging`; usa `coe_jobs`, `coe_businesses`, `coe_apps` e `coe_notify` quando
iniciados. Está em `ALLOWED_CALLERS` do `coe_database`, no `coe_logging`, no `coe_notify` e no `coe_supervisor`.
