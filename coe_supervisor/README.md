# coe_supervisor

Reinício ordenado dos resources do framework, sem reiniciar o servidor.

Não declara `dependencies`: precisa continuar de pé quando qualquer resource gerenciado é parado. Adicione `ensure coe_supervisor` ao `server.cfg`, antes dos demais `coe_*`.

## Como funciona

1. Lê o grafo de dependências (`dependency` e `dependencies` do `fxmanifest`) de todos os resources.
2. O alvo e todos os resources **iniciados** que dependem dele (direta ou indiretamente) formam o conjunto afetado.
3. Para os dependentes primeiro e a base por último (ordem inversa).
4. Inicia da base para os dependentes (ordenação topológica estável) e espera cada um chegar a `started`; timeout ou falha aborta e registra no console.

O plano é puro (`plan.lua`) e testado em `test/plan_test.lua`. Dependências circulares são recusadas (`dependency_cycle`).

## Exports (só resources com a ACE `coe.supervisor`; padrão: `coe_staff`)

- `List()`: resources gerenciados com `state`, `description`/`version` (do fxmanifest), `dependencies`, `dependents`, `restart` (ordem que será seguida) e `replacedBy` (pacote que substitui o básico, quando houver).
- `Restart(name, requesterSource)`: `true` ou código de erro (`forbidden`, `restart_in_progress`, `resource_not_managed`, `dependency_cycle`, `resource_replaced`). Um reinício por vez.
- `GetUpdateStatus()`, `CheckForUpdates()`: estado da verificação de versão (`nil` para chamador sem ACE).
- `ApplyUpdate(requesterSource)`: aplica a atualização verificada; `false, 'forbidden'` para chamador sem ACE.

A autorização do operador é de quem chama (o painel F10 do `coe_staff` confere as ACEs `coe.staff.*` do jogador). Outro painel entra pelo `server.cfg`: `add_ace resource.meu_painel coe.supervisor allow`. O resultado final é notificado ao solicitante via `coe_notify`.

Exports internos do `fs_writer.js` (`WriteFile`, `ReadFile`, `HashFile`, `DownloadFile`, `CommitFile`, `DiscardFile`, `VerifySignature`) só aceitam chamadas do próprio `coe_supervisor`, recebem `(resource, caminho relativo)` e recusam qualquer caminho fora da pasta do resource.

## Atualização e integridade

`coe_update apply` (console) ou o painel F10 aplicam a release anunciada no `version.json` do repositório:

1. O manifesto só é buscado por HTTPS. Com `Updater.PublicKey` configurada, o `version.json.sig` (Ed25519) precisa ser válido; `RequireSignature = true` recusa atualizar sem chave.
2. Os arquivos vêm da **tag** da release (`RawRepoUrl/<tag>/<resource>/<arquivo>`), nunca de um branch.
3. Só entram resources gerenciados (`Managed`, os do `version.json` instalado e o próprio supervisor); qualquer outro nome no manifesto é ignorado.
4. **Fase 1**: cada arquivo é baixado e conferido contra o SHA-256 do manifesto. Um arquivo adulterado, ausente ou sem hash aborta a atualização inteira sem gravar nada.
5. **Fase 2**: com tudo conferido, os arquivos são gravados. Uma `config.lua` editada pelo dono (diferente da versão instalada) é mantida e a nova vai para `config.dist.lua`; uma config apenas antiga recebe a versão nova.

### Assinatura do manifesto

1. `node tools/sign_manifest.js --keygen` gera `coe-manifest.key` (privada; nunca versionar) e mostra a pública.
2. Cole a pública em `SupervisorConfig.Updater.PublicKey` e guarde a privada como segredo `COE_MANIFEST_KEY`.
3. Depois de `lua tools/bump_version.lua <versão>`, rode `node tools/sign_manifest.js` (com `COE_MANIFEST_KEY` ou `COE_MANIFEST_KEY_FILE`) e versione `version.json.sig` junto do `version.json`: o supervisor busca a assinatura ao lado do manifesto (`ManifestUrl .. '.sig'`). O `release.yml` anexa o `.sig` à release quando ele existe.

Testes: `test/updater_test.lua` (plano, SHA-256, config), `test/apply_test.lua` (fluxo de verificar e aplicar com HTTP e disco simulados) e `node --test test/fs_writer.test.js` (confinamento de caminho, HTTPS, hash e assinatura).

## Configuração

`config.lua`: `Managed` (resources do framework), `Catalog` (categoria e criticidade de cada um; fora dele vira `other`), `StopTimeoutMs`, `StartTimeoutMs` e `Updater` (`ManifestUrl`, `RawRepoUrl`, `PublicKey`, `RequireSignature`, `TimeoutMs`). As convars `coe_updater_manifest_url` e `coe_updater_raw_repo_url` sobrepõem as URLs.

Pacotes e scripts de terceiros entram sem editar o framework, declarando no próprio `fxmanifest.lua`:

```lua
coe_supervisor 'business'          -- categoria (infrastructure, core, interface, gameplay, business, administration...)
coe_supervisor_critical 'yes'      -- opcional: reiniciar pode derrubar o servidor
```

Dependentes fora de `Managed` (ex.: scripts de terceiros que dependem do core) também são reiniciados, para não ficarem quebrados.

## Substituição de básicos por pacotes

Os básicos que um pacote completo pode assumir declaram no `fxmanifest.lua` `coe_supervisor_replaceable 'yes'`
(`coe_bank`, `coe_mobile`, `coe_staff`, `coe_workpad`). O pacote declara no fxmanifest dele quem substitui:

```lua
coe_supervisor_replaces 'coe_mobile'
```

- **Boot**: com o pacote instalado, o supervisor cancela o início do básico (`onResourceStarting`), mesmo que o
  pacote suba depois na ordem alfabética. O console mostra `resource_replaced resource=<básico> by=<pacote>`.
- **Pacote não subiu** (não está no `ensure` ou falhou): quando o servidor assenta (`Replacements.SettleMs` sem
  resources iniciando ou parando), o básico é iniciado (`resource_restored`).
- **Em execução**: pacote que sobe depois para o básico; pacote que para traz o básico de volta. `ensure` manual do
  básico com o pacote rodando é recusado e `Restart` responde `resource_replaced`. `List()` informa `replacedBy`.
- Só básicos com `coe_supervisor_replaceable` podem ser substituídos: um pacote não consegue derrubar o core.
- O framework não cita o pacote; quem declara é ele. Os exports `Yield` dos básicos continuam como alternativa.

As regras ficam em `replace.lua` e são testadas em `test/replace_test.lua`. `Replacements.Enabled = false` desliga.

No console, `coe_upgrades` mostra o mapa DE > PARA ao vivo: cada básico, quem o substitui e o estado de cada um. Se o
pacote ativo expõe `UpgradeStatus()`, a linha seguinte mostra o que ele importou do básico. Jogadores precisam da ACE
`command.coe_upgrades`.

## Limitações

Reiniciar `coe_core` descarrega sessões e personagens dos jogadores online; teste em jogo antes de usar com jogadores conectados. Os logs deste resource usam `print` porque o `coe_logging` pode estar parado.

## Refresh antes de iniciar

Por padrão o supervisor roda `refresh` entre parar e iniciar (`RefreshBeforeStart`, espera `RefreshWaitMs`), para o servidor reler o `fxmanifest` de resources que ganharam ou renomearam arquivos. Sem isso o cliente carregava scripts novos sem os arquivos novos.

## Referência da API

[Exports, parâmetros e códigos de erro](../reference/coe_supervisor.md), gerado de [`types.lua`](types.lua).
