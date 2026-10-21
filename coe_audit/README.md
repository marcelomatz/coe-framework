# coe_audit

Trilha de auditoria **durável** em MariaDB, independente do console (`coe_logging`). Registra eventos de segurança e de auditoria (ações de staff, ciclo de vida de personagem, entregas/drops de itens e acessos negados) para consulta posterior.

## Como funciona

- Os resources `coe_core`, `coe_inventory` e `coe_admin` já chamam `log(..., 'audit' | 'security', ...)`. Esse helper local também envia o evento para `coe_audit` (best effort, via `pcall`); o log de console continua existindo.
- Export server-side: `exports.coe_audit:Record(severity, category, event, context?)`, com `severity` em `info|warn|error`. Retorna `true` quando o evento foi aceito na fila, ou `false, motivo`.
- O nome do resource vem do runtime (`GetInvokingResource`), nunca do payload; só os resources em `CoeAuditConfig.AllowedResources` podem gravar. Não há evento de rede de escrita nem export de leitura.
- O contexto passa pela allowlist de `config.lua` (escalares, até 16 campos, strings de até 96 bytes).
- No momento do registro, `source`/`player_id` e `target` (IDs de servidor) são resolvidos para `license:` e gravados em `actor_license` / `target_license`, pois IDs de servidor não são estáveis.

## Falhas e limites

- `Record` nunca bloqueia: o evento entra numa fila em memória (máx. 1000) e uma thread grava em lotes de até 50 a cada 1 s.
- Banco indisponível: o lote fica na fila e há novas tentativas com backoff exponencial (1 s até 30 s). O erro é logado uma vez por sequência de falhas (`audit_flush_failed`).
- Fila cheia: novos eventos são descartados e contados (`audit_queue_overflow` no log de console). Por isso o log de console segue como cópia de segurança.
- Limitação conhecida: eventos ainda na fila se perdem se o processo cair. Ao parar o resource há uma tentativa de esvaziar a fila (`audit_events_lost_on_stop` se sobrar algo).

## Schema (`coe_audit_log`, migration v1)

`id`, `occurred_at` (UTC, ms), `severity`, `category`, `event`, `resource`, `actor_license`, `target_license`, `context` (JSON). Índices por data, evento, ator e alvo. Controle de migrations em `coe_audit_schema_migrations`.

Exemplos de consulta:

```sql
SELECT occurred_at, event, actor_license, target_license, context
FROM coe_audit_log WHERE actor_license = 'license:...' ORDER BY id DESC LIMIT 50;

SELECT occurred_at, event, actor_license FROM coe_audit_log
WHERE category = 'security' AND occurred_at > UTC_TIMESTAMP() - INTERVAL 1 DAY;
```

## Retenção e acesso

- Padrão: guarda tudo (`RetentionDays = 0`). `set coe_audit_retention_days 90` remove, ao iniciar o resource, registros mais antigos (em lotes de 5000).
- A tabela é *append-only por convenção*: nenhum código a atualiza; só o purge de retenção apaga. Para imutabilidade real, use um usuário de banco separado para consulta/relatórios com apenas `SELECT`.
- Contém licenses (dados pessoais): restrinja o acesso ao banco e defina a retenção conforme sua política.

## Eventos cobertos

| Origem | Eventos |
|---|---|
| `coe_core` | `character_created`, `character_selected`, `character_archived`, `player_identity_unavailable` |
| `coe_admin` | `admin_item_granted/failed`, `staff_role_assigned/removed/..._failed`, `*_denied`, `admin_panel_access_denied` |
| `coe_inventory` | `inventory_item_given`, `inventory_give_denied`, `world_container_dropped`, `world_container_picked_up` |

Ordem de `ensure`: depois de `coe_core` (usa `@coe_core/lib/migrations.lua`); os consumidores não dependem dela para iniciar.

## Testes

`test/audit_test.lua` (entrada, fila, lote, backoff) e o cenário de integração `coe_database/test/integration/audit_scenario.lua` (migration idempotente, lote atômico, NULLs, retenção).

## Referência da API

[Exports, parâmetros e códigos de erro](../reference/coe_audit.md), gerado de [`types.lua`](types.lua).
