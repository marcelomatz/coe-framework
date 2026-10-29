# Plano: identidade e ciclo de vida

## Objetivo

Definir e implementar uma identidade persistente de jogador, personagens independentes, persistência MariaDB e o ciclo de vida autoritativo do servidor. O desenho mantém as regras de negócio em Lua e não depende de ox_core, oxmysql ou de IDs transitórios do FiveM como identidade persistente.

## Estado da execução

- **Concluído nesta etapa:** provider MariaDB próprio, migrations iniciais, repositórios Player/Character, serviços de sessão e seleção, validação server-side, cache/rate limit de requests, UI inicial e spawn condicionado à confirmação do Core. O inventário resolve a chave `character:<character_id>` no servidor, persiste snapshots no MariaDB e nega operações sem personagem ativo. Os cargos customizados do admin também usam MariaDB.
- **Validado localmente:** testes unitários do provider Node e testes Lua de identidade, sessões, lifecycle, migrations e operações de inventário com provider dublê.
- **Observabilidade atual:** `coe_logging` emite eventos JSON no console/collector e `coe_notify` apresenta feedback explícito ao jogador. O histórico de auditoria ainda é parcial e não é persistido pelo framework; não usar os logs atuais como trilha durável/compliance.
- **Pendente antes de uso real:** teste de integração em FXServer Enhanced com Node 22, bridge assíncrona JS/Lua e MariaDB; configuração das convars de banco no ambiente; confirmação de que a chave Cfx configurada está ativa no Keymaster.
- **Próximas etapas:** validar no FXServer Enhanced/Node 22 e MariaDB real; cobrir integration tests com constraints/transações; adicionar estado e aparência do personagem se definidos no escopo do MVP; desenvolver save/load de gameplay e revisar operação/rollback.
- A cobertura por resource e as lacunas atuais estão consolidadas em [TEST_COVERAGE.md](../TEST_COVERAGE.md); o histórico desta revisão e o catálogo parcial de eventos de auditoria ficam em o [changelog](https://docs.coeroleplay.app/#doc=CHANGELOG.md).

## Decisões de domínio confirmadas

- **Sessão FiveM:** `source` é somente um identificador transitório de conexão. Pode ser reutilizado após a desconexão e nunca será chave de jogador, personagem ou inventário.
- **Player:** cada conta Coe recebe um `player_id` interno, persistente e imutável. Um identificador Cfx obtido no servidor localiza a conta, mas não é a chave primária nem é enviado ao cliente.
- **Identificadores externos:** serão armazenados separadamente de `player_id`, com unicidade por tipo/valor. Vincular ou substituir identificadores será uma operação explícita; identificadores não serão mesclados automaticamente.
- **Character:** cada personagem recebe `character_id` próprio e imutável, com `player_id` como proprietário. Dados, estado e inventário pertencem ao personagem.
- **Seleção:** uma sessão autenticada pode estar sem personagem ativo durante a seleção e pode ter no máximo um personagem ativo. A seleção valida no servidor que o personagem pertence ao jogador autenticado; criar ou selecionar personagem é obrigatório antes do gameplay.
- **Limites e exclusão:** limite padrão de cinco personagens, configurável server-side; nomes são compostos por primeiro nome e sobrenome; remoção é arquivamento lógico. Nenhum personagem ou inventário será apagado como efeito colateral de desconexão.
- **Inventário:** a chave persistente é `character_id`, não license, `source` ou `player_id`. O MVP parte de schema e dados novos; não oferece compatibilidade com armazenamento KVP anterior.

## Arquitetura proposta

```text
coe_admin / outros resources
              |
          coe_core
   (domínio e casos de uso Lua)
              |
        coe_database
 (transporte MariaDB e migrações)
              |
           MariaDB

coe_inventory ---> contratos de identidade do coe_core
```

- `coe_core` será dono do domínio Player, Character e Session, dos casos de uso do ciclo de vida e das portas de repositório.
- `coe_database` será um resource próprio, limitado ao pool/conexão, consultas parametrizadas, transações, migrações e normalização de erros de banco. Não conterá regras de gameplay nem de identidade.
- A conexão usará credenciais de convars server-only; segredos não serão colocados em manifests, documentação, logs ou repositório.
- A camada de persistência será assíncrona e terá limites de timeout, pool e concorrência definidos. Um callback de banco só poderá concluir uma operação para a mesma geração de sessão que a iniciou.
- Decisão aprovada: usar o runtime Node.js 22 server-side do FiveM e `mysql2` como dependência de transporte, mantendo API, repositórios, schema e migrações próprios. O Core e seus módulos de domínio continuam em Lua; o protocolo MariaDB não será implementado manualmente.
- As dependências do provider são instaladas com `npm ci --omit=dev` na pasta de `coe_database`; não há dependência de um resource `yarn`. Ainda é necessário validar a integração em FXServer Enhanced compatível.

## Fases de execução

### 0. Contratos e ameaças

**Entregas**

- Fechar formato e origem do identificador externo principal, limite de personagens, política de exclusão e driver MariaDB.
- Definir estados e transições, payloads de eventos e invariantes de sessão.
- Classificar eventos como locais (server-server/client-client) ou de rede; eventos internos não serão registrados como eventos de rede.
- Definir validação server-side para todos os requests: `source`, estado da sessão, ownership, tipos/limites dos argumentos, permissões, frequência e estado autoritativo de entidades.

**Aceite**

- Nenhum request do cliente escolhe `player_id`, `character_id`, proprietário ou ID de inventário para operações privilegiadas.
- Dados derivados do cliente, como quantidade, posição e entidade, são verificados no servidor; nenhuma regra de segurança depende da UI/client.
- Eventos client-side destinados exclusivamente a mensagens do servidor verificam o remetente de acordo com a orientação oficial (`source == 65535`).

### 1. Persistência MariaDB própria

**Entregas**

- Resource `coe_database` com configuração segura, pool, consultas parametrizadas, transações e erros observáveis; repositórios do Core já usam o provider.
- Migrações versionadas e idempotentes para `players`, `player_identifiers`, `characters` e controle de versões.
- Testes unitários do provider e da orquestração das migrations.
- **Pendente:** validação de conexão, constraints, transação e encerramento contra MariaDB real no runtime FiveM/Enhanced.

**Aceite**

- Chaves estrangeiras e índices garantem unicidade do identificador vinculado e propriedade dos personagens.
- Falha de conexão/migração impede o Core de declarar o serviço pronto; não há fallback silencioso para KVP.
- Nenhum segredo de banco é exposto ao client.

### 2. Domínio e ciclo de vida no Core

**Estados**

```text
connecting -> identifying -> player_loaded -> character_selection
                                      -> character_loaded -> disconnecting -> disconnected
```

**Entregas**

- Serviços e modelos testáveis para localizar/criar player, listar/criar/selecionar personagem e limpar uma sessão.
- Mapeamento em memória `source -> session`, com token/geração por conexão; invalidação no disconnect e após restart/stop.
- Eventos locais para player carregado, seleção necessária, personagem carregado/descarregado e sessão encerrada.
- Interface inicial de criação/seleção; spawnmanager bloqueado até o evento server-originated de personagem carregado.
- Operações idempotentes e ordenadas; o estado `ready` do Core só é publicado depois da inicialização das dependências.

**Aceite**

- Um jogador nunca observa estado de outro após reutilização de `source`.
- Um personagem alheio, inexistente, arquivado ou incompatível com o estado atual não pode ser carregado.
- Falha ou desconexão durante consulta/criação não deixa sessão parcialmente carregada nem envia respostas tardias à conexão que reutilizou o mesmo `source`.

### 3. Inventário por personagem e migração

**Entregas**

- A API do inventário obtém o personagem ativo pelo contexto de sessão do Core; requests do client não escolhem o ID do inventário de jogador.
- Inventários e containers usam registros próprios em MariaDB; os inventários de personagem usam `character:<character_id>`.
- Transferências entre inventários salvam os dois snapshots numa transação única. Os snapshots são JSON no MVP e a normalização pode ser avaliada conforme os requisitos de consulta e escala.
- Não há ferramenta de importação KVP legada; os dados do protótipo anterior estão fora do escopo de compatibilidade.

**Aceite**

- Falha na transferência deixa ambos os inventários consistentes, inclusive após crash/restart.
- Inventário legado sem associação inequívoca não é atribuído silenciosamente: é colocado em relatório/quarentena para decisão operacional.
- Dados antigos permanecem recuperáveis até a validação explícita da migração.

### 4. Segurança e integração dos resources

**Entregas**

- Migrar `coe_admin` e demais consumidores para APIs de player/personagem; a concessão de itens já usa a API do inventário por personagem. A licença segue somente como identificador interno da lista de staff até a política de contas administrativas ser substituída.
- Aplicar autorização no servidor para ações administrativas e ownership para ações de inventário.
- Rate limit por sessão/ação, validação estrita dos payloads e limites de tamanho.
- Auditar state bags e eventos: somente estado público mínimo será replicado; estado privado fica no servidor.

**Aceite**

- Testes demonstram rejeição de chamadas sem sessão/personagem, IDs forjados, payloads inválidos e spam.
- Não há dependência circular entre Core, inventário, admin e database.

### 5. Testes, Enhanced e operação

**Entregas**

- Testes unitários das regras de domínio com repositórios falsos; testes de integração usando MariaDB real e fixtures isoladas.
- Cenários de sessão reutilizada, dois jogadores simultâneos, dois personagens do mesmo player, seleção indevida, disconnect durante I/O, concorrência e rollback.
- Testes do inventário para slots, pilhas, metadata, peso, transferência, falha e reinício.
- Guia de instalação, configuração, migração/rollback, eventos e exports; logs sem PII/segredos e métricas operacionais.

**Aceite**

- Suite unitária e de integração passa em ambiente de CI/execução definido.
- O servidor Enhanced alvo inicia os resources na ordem documentada, aplica schema e executa o fluxo completo sem fallback para estado de teste.
- O processo de migração foi ensaiado com backup e restauração antes de ser considerado pronto para produção.

## Riscos e controles

| Risco | Controle |
|---|---|
| Reutilização de `source` e respostas assíncronas atrasadas | Token de geração por sessão, validação antes de cada efeito e limpeza em `playerDropped` |
| Cliente forja eventos ou IDs | Derivar identidade e ownership do contexto server-side; validar argumentos, permissões e estado atual |
| Falha parcial em movimentação de itens | Transação MariaDB para alterações relacionadas |
| Dados do protótipo anterior | Sem compatibilidade ou importação; o MVP inicia com armazenamento novo |
| Credenciais expostas | Convars server-only, segredo fora do workspace e rotação se já tiver sido versionado |
| Runtime Enhanced ou driver incompatível | Fixar versão suportada, validar no FXServer alvo e não promover sem teste de integração |

## Referências

- [Cfx.re: Secure your events](https://docs.fivem.net/docs/developers/server-security/)
- [Cfx.re: Network and local IDs](https://docs.fivem.net/docs/scripting-manual/networking/ids/)
- [Cfx.re: JavaScript runtime](https://docs.fivem.net/docs/scripting-manual/runtimes/javascript/)
- [Cfx.re: OneSync](https://docs.fivem.net/docs/scripting-reference/onesync/)
- [Cfx.re: Legacy vs Enhanced](https://docs.fivem.net/docs/developers/legacy-vs-enhanced/)
- [mysql2](https://github.com/sidorares/node-mysql2)
