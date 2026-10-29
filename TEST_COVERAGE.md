# Mapa de testes

O que cada resource tem de teste automatizado, o que o CI roda e o que ainda depende de teste em jogo.
Atualize esta página ao criar ou remover um arquivo de teste.

## O que o CI roda

| Etapa | Comando | Onde |
| --- | --- | --- |
| Testes unitários Lua (83 arquivos) | `lua test/<arquivo>.lua` dentro de cada resource | `ci.yml` e `release.yml` |
| Contratos, acesso, HAL e i18n | `lua tools/check_contracts.lua --strict --audit-natives --audit-locales` | `ci.yml` e `release.yml` |
| Referência da API em dia | `lua tools/gen_reference.lua --check` | `ci.yml` e `release.yml` |
| Smoke boot (chunks de runtime e locales) | `lua tools/smoke_boot_test.lua` | `ci.yml` e `release.yml` |
| Fronteira open-core | `lua tools/check_boundary.lua` | `ci.yml` e `release.yml` |
| Banco (Node) | `node --test test/access.test.js test/provider.test.js test/validation.test.js` em `coe_database` | `ci.yml` e `release.yml` |
| Supervisor (Node) | `node --test test/fs_writer.test.js` em `coe_supervisor` | `ci.yml` e `release.yml` |
| DOM da UI e do HUD (jsdom) | `node --test test/*.test.js` em `coe_ui` e `coe_hud` | `ci.yml` |
| Integração MariaDB | `node --test test/integration/integration.test.js` em `coe_database` (serviço MariaDB 11.4) | `ci.yml` |
| Versão, tag e hashes do manifesto | `lua tools/bump_version.lua --check --tag <tag>` | `release.yml` |

O `check_contracts` também falha quando:

- um resource com exports não tem `types.lua`, ou um export não está anotado nele;
- um resource do framework chama um export protegido sem estar na allowlist padrão do alvo (`coe_database`,
  `coe_vehicles`, `coe_economy`, `coe_talk`, `coe_supervisor`);
- um arquivo declarado no `fxmanifest.lua` não existe;
- falta paridade de chaves entre `locales/pt-br.lua` e `locales/en-us.lua`, em qualquer direção.

## Por resource

| Resource | Lua (`test/`) | Node (`test/`) | Integração MariaDB |
| --- | --- | --- | --- |
| `coe_appearance` | `schema_test`, `thumbs_server_test` | | |
| `coe_audit` | `audit_test` | | `audit_scenario` |
| `coe_bank` | `rules_test`, `server_test` | | |
| `coe_businesses` | `access_test`, `duty_test`, `extensions_test`, `grades_test`, `registry_test`, `tablet_test` | | `jobs_businesses_scenario` |
| `coe_characters` | `client_test` | | |
| `coe_core` | 15 arquivos (identidade, perfil, grupos, lifecycle, migrations, platform, locale, semver, hash, access) | | `core_scenario` |
| `coe_database` | | `access.test`, `provider.test`, `validation.test` | `integration.test` (executor dos cenários) |
| `coe_economy` | `rules_test`, `server_test` | | `commerce_scenario`, `jobs_businesses_scenario` |
| `coe_garage` | `domain_test`, `service_test` | | `garage_mobile_scenario` |
| `coe_hud` | `client_hud_test`, `logo_test`, `prefs_test`, `route_test` | `editor.test`, `speedo.test` | |
| `coe_inventory` | 9 arquivos (serviço, containers, stash, armas, persistência, concorrência do mundo, apresentação) | | `inventory_scenario`, `commerce_scenario` |
| `coe_jobs` | `career_test`, `guide_test`, `jobs_test`, `rules_test`, `server_test` | | `jobs_businesses_scenario` |
| `coe_loadscreen` | `client_test` | | |
| `coe_logging` | `logging_test` | | |
| `coe_map` | `client_map_test` | | |
| `coe_mobile` | `persistence_test`, `rules_test`, `server_test` | | `garage_mobile_scenario` |
| `coe_needs` | `needs_test`, `service_test` | | `needs_scenario` |
| `coe_notify` | `client_notify_test`, `server_notify_test` | | |
| `coe_rentals` | `rentals_test`, `server_test` | | |
| `coe_shops` | `client_test`, `rules_test`, `server_test` | | `commerce_scenario` |
| `coe_spawn` | `client_test`, `positions_test` | | |
| `coe_staff` | `rules_test`, `server_test` | | |
| `coe_supervisor` | `ansi_test`, `apply_test`, `plan_test`, `replace_test`, `updater_test` | `fs_writer.test` | |
| `coe_talk` | `client_talk_test`, `rules_test`, `server_main_test`, `server_talk_test` | | |
| `coe_ui` | | `components.test` | |
| `coe_vehicle_catalog` | `catalog_test` | | `vehicles_scenario` |
| `coe_vehicles` | `keys_test`, `vehicles_test` | | `vehicles_scenario` |
| `coe_workpad` | `rules_test`, `server_test` | | |
| `coetarget` | `client_test` | | |

`all_migrations_scenario` roda as migrations de todos os resources com banco duas vezes num banco novo e falha se
um arquivo `migrations.lua` do repositório ficar fora dele.

## Lacunas conhecidas

- Natives, NUI e rede reais só são exercitados em jogo: siga o `INGAME_CHECKLIST` do portal de docs antes de cada
  release.
- O bridge de exports Lua ↔ Node do FXServer e o `GetInvokingResource()` real são simulados nos testes; a autorização
  é conferida estaticamente pelo `check_contracts` (contrato de acesso) e por stubs nos testes de servidor.
- `coe_appearance`, `coe_characters`, `coe_loadscreen`, `coe_map` e `coetarget` têm só testes de regras/cliente;
  o comportamento visual depende do jogo.
- A integração MariaDB ainda não cobre `coe_staff`, `coe_bank` (usa a economia), `coe_spawn` (só migrations) e
  `coe_vehicle_catalog` além das migrations.
