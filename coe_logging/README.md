# coe_logging

`coe_logging` fornece logs estruturados server-side para os resources Coe. Os registros são emitidos no console do FXServer em formato legível (padrão) ou como uma linha JSON; o resource não grava logs no MariaDB nem envia logs aos clients.

## Contrato

Use o export server-side `Log(level, category, event, context?)`:

```lua
exports.coe_logging:Log('info', 'audit', 'character_selected', {
	player_id = source,
	character_id = characterId
})
```

Cada linha inclui `timestamp` UTC, `level`, `category`, `event`, `resource` e `context`. Os níveis aceitos são `debug`, `info`, `warn` e `error`. Categorias recomendadas incluem `lifecycle`, `persistence`, `database`, `security`, `audit` e `notification`.

`event` deve ser um código estável, em formato `snake_case`; não use texto de UI, SQL, exceções ou dados arbitrários como nome. Contexto é limitado a uma allowlist em `config.lua`, valores escalares e até 16 campos. Campos sensíveis e estruturas aninhadas não são registrados.

Podem chamar o export os padrões de `AllowedResources` (resources do framework) e quem tem a ACE `coe.logging` (`add_ace resource.<nome> coe.logging allow`). `resource` é obtido do chamador pelo servidor, não aceito pelo payload. Não há evento de rede para escrita de logs.

## Configuração

O nível fallback e os níveis iniciais por resource ficam em `config.lua`. A convar global define o mínimo para todos os resources; uma convar específica sobrescreve o nível global:

```cfg
set coe_logging_level "info"
set coe_logging_level_coe_inventory "debug"
```

A precedência é: convar por resource, convar global, nível do resource em `config.lua` e, por fim, o nível fallback. Valores inválidos de convar são ignorados. Níveis abaixo do mínimo configurado são filtrados. Use `debug` temporariamente durante diagnóstico; evite deixá-lo habilitado sem necessidade.

## Formato de saída

O padrão (`pretty`) imprime `hora NÍVEL resource categoria evento chave=valor ...`, com colunas alinhadas, contexto em ordem alfabética e cor por nível (debug azul, info verde, warn amarelo, error vermelho):

```text
17:35:42 INFO  coe_core       lifecycle    database_waiting
17:35:42 ERROR coe_admin      persistence  database_initialization_failed  error_code=database_error retry_ms=5000
```

Para coletores de log, use uma linha JSON por evento (`timestamp` UTC, `level`, `category`, `event`, `resource`, `context`). Convars (sobrescrevem `DefaultFormat` e `DefaultColor` de `config.lua`):

```cfg
set coe_logging_format "json"   # pretty (padrão) ou json
set coe_logging_color "0"       # desliga as cores no formato pretty
```

Valores de contexto são saneados no formato legível: controles e `^` viram `?`, para um texto não injetar cor nem quebrar a linha. Formato desconhecido cai em `pretty`.

## Logs e notificações

Logs operacionais/auditoria não são encaminhados automaticamente ao jogador. O caso de uso deve chamar `coe_logging` para observabilidade e `coe_notify` separadamente quando uma mensagem fizer sentido durante a gameplay. Assim, falhas técnicas e dados internos não vazam para a UI.

## Limitações

A saída atual depende do console/collector do FXServer. Armazenamento durável, rotação, retenção e consulta de auditoria são etapas futuras. Os eventos de auditoria existentes são parciais e não cobrem todas as ações de gameplay; consulte o [catálogo e histórico](https://docs.coeroleplay.app/#doc=CHANGELOG.md). `coe_logging` não pode depender do banco, para continuar funcional quando o banco estiver indisponível.

## Testes

Arquivos: `config.lua` define níveis, allowlist de chamadores e campos seguros; `server.lua` valida, filtra e emite JSON; `fxmanifest.lua` carrega somente scripts server-side. Execute `lua test\logging_test.lua` a partir da pasta do resource. O teste cobre níveis, override por resource, allowlist e sanitização. Volume alto, collector/rotação, armazenamento persistente e permissões reais de exports são validações operacionais futuras; ver [TEST_COVERAGE.md](../TEST_COVERAGE.md).

## Referência da API

[Exports, parâmetros e códigos de erro](../reference/coe_logging.md), gerado de [`types.lua`](types.lua).
