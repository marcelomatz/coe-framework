# coe_vehicle_catalog

Catálogo único de veículos para o framework: nativos do GTA V e addons transmitidos como resource. Usado por concessionária (#141), mecânica (#140), handling (#139) e garagens.

## Fontes

- **Nativos:** `data/native_vehicles.lua` (modelo, nome, marca, classe, tipo, assentos). O servidor não consegue consultar o jogo, então esta lista é a fonte; amplie conforme necessário.
- **Addons:** a cada start/stop de resource o catálogo lê os `data_file` `VEHICLE_METADATA_FILE` (vehicles.meta) e `HANDLING_FILE` (handling.meta) declarados no `fxmanifest` e reconstrói o índice (com debounce). Caminhos com `*` não são suportados e geram aviso.
- **Overrides:** preço, estoque, categoria e ocultar, gravados em `coe_vehicle_overrides`, sem editar o resource do addon.

Limites conhecidos: addons não têm classe (ficam `unknown`) nem assentos até receberem override/seed; o parser lê só campos escalares do handling e espera `<modelName>` como primeiro campo de cada veículo.

## Validação

`GetIssues()` / `coe_catalog_issues` listam: `duplicate_model`, `duplicate_handling`, `replaces_native`, `handling_missing`, `unknown_vehicle_type`, `invalid_model_name`, `meta_file_not_found`, `glob_not_supported`.

Para checar arquivos fora do servidor (CI/CLI):

```
cd coe_vehicle_catalog
lua tools/check.lua caminho/vehicles.meta caminho/handling.meta
```

Sai com código 1 se houver erros.

## Exports (servidor)

`GetVehicleInfo(model)`, `ListVehicles(filtro)`, `GetBaseHandling(model)`, `GetIssues()`, `IsReady()` (qualquer resource); `SetOverride(model, campos)`, `ClearOverride(model)`, `Rescan()` (somente quem tem a ACE `coe.vehicles.catalog`, ex.: `add_ace resource.coe_admin coe.vehicles.catalog allow`). Contrato completo em `types.lua`.

## Comandos (ACE)

`coe_catalog_rescan`, `coe_catalog_issues`, `coe_catalog_info <modelo>`.

## Testes

```
cd coe_vehicle_catalog
lua test/catalog_test.lua
```

## Fora do escopo

Validação de que o modelo existe no jogo (exige client), convenção de empacotamento e licenças de modelos de terceiros (pesquisa pendente em #138).
