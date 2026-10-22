# coe_database

`coe_database` é o provider de transporte MariaDB do framework Coe. Mantém conexão/pool, consultas preparadas e transações fora das regras de domínio.

## Arquitetura e limites

- Só resources autorizados chamam os exports SQL; o nome vem do runtime (`GetInvokingResource`). Padrão do framework (`server/access.js`): `coe_core`, `coe_inventory`, `coe_audit`, `coe_vehicles`, `coe_vehicle_catalog`, `coe_businesses`, `coe_needs`, `coe_economy`, `coe_spawn`, `coe_jobs`, `coe_shops` e `coe_bank`. Pacotes e scripts de terceiros com persistência recebem a ACE no `server.cfg`, sem editar o framework: `add_ace resource.<nome> coe.database allow`. Cada resource é responsável pelo schema e pelas regras de persistência do seu módulo.
- `coe_database` depende de `coe_logging` para registrar erros operacionais; o logger não depende do provider nem do banco.
- `Query`, `Execute` e `Transaction` usam prepared statements; `multipleStatements` permanece desabilitado.
- `Transaction` executa as statements em sequência na mesma conexão e tenta rollback antes de informar falha.
- Core/repositórios continuam responsáveis pelo SQL de identidade e migrations versionadas do Core. `coe_inventory` e `coe_admin` mantêm seus próprios adapters e aplicam migrations versionadas próprias por `CoeMigrations` (`coe_core/lib/migrations.lua`), cada uma com sua tabela de controle (`coe_inventory_schema_migrations`, `coe_admin_schema_migrations`). Nenhum client acessa o provider.
- Resultados de banco não são enviados automaticamente ao client. O resource chamador deve filtrar e projetar qualquer resposta.
- Falha de configuração ou conexão mantém o provider indisponível e retorna erro explícito; não existe fallback silencioso. Erros operacionais são enviados ao `coe_logging` com códigos de erro, sem SQL, parâmetros ou credenciais; se o logger estiver indisponível, o provider escreve uma linha JSON de fallback no console.

## Requisitos de runtime

- FXServer com runtime server-side Node.js 22.
- Dependências JavaScript instaladas na pasta do resource antes de iniciar o servidor. `package-lock.json` fixa a árvore usada por npm; `yarn` não é um resource do FXServer e não é dependência de runtime.
- MariaDB acessível pelo processo do FXServer.
- `mysql2` fica restrito ao transporte e está fixado em `package.json`.

Instale ou restaure as dependências a partir da pasta do resource com `npm ci --omit=dev`. Não instale um resource `yarn` de terceiros nem declare `yarn` como dependência FXServer. A suíte unitária local não requer conexão MariaDB; compatibilidade do runtime Node.js 22, do driver e do bridge entre JavaScript e Lua ainda precisa ser verificada no FXServer Enhanced alvo.

## Configuração

Configure convars server-only fora de arquivos versionados sempre que possível:

| Convar | Obrigatório | Padrão | Descrição |
|---|---:|---|---|
| `coe_database_host` | não | `127.0.0.1` | Host MariaDB |
| `coe_database_port` | não | `3306` | Porta TCP |
| `coe_database_user` | sim | vazio | Usuário dedicado do framework |
| `coe_database_password` | sim | vazio | Senha do usuário |
| `coe_database_name` | sim | vazio | Schema do framework |
| `coe_database_connection_limit` | não | `10` | Pool de conexões, entre 1 e 50 |
| `coe_database_ssl` | não | `false` | Define `true` para exigir TLS com certificado validado |

Use um usuário MariaDB dedicado, com privilégios mínimos sobre o schema Coe; não use `root`. Para hosts remotos, configure TLS.

## Exports server-side

Os exports recebem callback porque o I/O do banco é assíncrono. O callback recebe `(success, result, errorCode)`:

```lua
exports.coe_database:Query(
	'SELECT player_id FROM coe_players WHERE identifier = ?',
	{ identifier },
	function(success, rows, errorCode)
		if not success then
			print(('Consulta falhou: %s'):format(errorCode))
			return
		end

		-- Validar/projetar os dados antes de usá-los ou enviá-los ao client.
	end
)
```

- `Query(sql, parameters, callback)` retorna linhas/resultados da consulta.
- `Execute(sql, parameters, callback)` retorna metadados de escrita.
- `Transaction(statements, callback)` recebe uma lista `{ sql = '...', parameters = {...} }` e retorna metadados na mesma ordem.
- `IsReady()` informa se o pool foi conectado e permanece disponível.

### Mapa dos scripts

- `server/index.js`: exports FiveM, verificação do resource chamador, lifecycle do provider e integração com `coe_logging`. Os `require()` locais usam caminhos a partir da raiz do resource (`./server/provider`), porque o FXServer não resolve relativo à pasta do arquivo; `provider.js` e `validation.js` não podem importar irmãos com `./`.
- `server/provider.js`: pool, execução parametrizada, transações, rollback e ciclo de vida sem APIs FiveM.
- `server/validation.js`: allowlist de comandos SQL e validação de parâmetros/statements.
- `package.json` e `package-lock.json`: dependências Node fixadas para instalação com npm.
- `fxmanifest.lua`: runtime Node 22 e dependência de logging.

Códigos de erro incluem `caller_not_allowed`, `invalid_sql`, `invalid_parameters`, `database_not_ready`, `query_failed`, `transaction_failed` e `transaction_rollback_failed`. Logs não incluem SQL, parâmetros, identificadores ou credenciais.

## Inicialização

Inicie `coe_database` antes de `coe_core`. O Core verifica `IsReady()` e só publica seu próprio estado `ready` após a conexão e as migrações obrigatórias. Configure as convars de banco pelo mecanismo de segredos do ambiente, não neste arquivo ou no `server.cfg` versionado.

## Testes

Execute `npm test` a partir da pasta do resource. `test/validation.test.js` cobre statements/argumentos; `test/provider.test.js` usa um driver dublê para testar inicialização, retry, execução, transação, rollback e encerramento. Esses testes não substituem MariaDB real. O bridge de exports Lua↔Node, autorização via `GetInvokingResource()`, credenciais, constraints reais e runtime Node 22 do FXServer Enhanced ainda não têm teste de integração local; ver [TEST_COVERAGE.md](../TEST_COVERAGE.md).

## Referência da API

[Exports, parâmetros e códigos de erro](../reference/coe_database.md), gerado de [`types.lua`](types.lua).
