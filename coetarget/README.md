# coetarget

Resource client-side de mira contextual para interagir com entidades e expor ações fornecidas por outros resources. Não implementa regras server-authoritative nem executa requests de rede.

## Arquivos e responsabilidades

- `config.lua`: comando de alternância, tecla de ativação por pressão e distância máxima da mira.
- `client.lua`: raycast da câmera, filtragem de opções, navegação, execução local da ação selecionada e exports para registrar/remover opções.
- `html/`: indicador e lista de opções; labels são inseridas como texto.
- `fxmanifest.lua`: inicializa NUI e scripts client.

## Configuração e uso

Em `config.lua`, `Config.Command` alterna a mira, `Config.DefaultKey` define a tecla para mantê-la ativa e `Config.MaxDistance` define o alcance do raycast. Enquanto ativa, a mira desabilita ataque e mira padrão e lista as opções do alvo. Um clique esquerdo ativa o modo de escolha: as opções ficam congeladas, o cursor do mouse é liberado e um clique na opção a executa; `Esc`, botão direito ou clique fora cancelam.

Um consumidor declara dependência de `coetarget` e usa o adapter do seu resource. No inventário, `Inventory.Target` em `coe_inventory/client/target_adapter.lua` encapsula os exports:

```lua
exports.coetarget:AddTargetEntity(entity, {
	{
		label = 'Abrir',
		canInteract = function(target) return DoesEntityExist(target) end,
		onSelect = function(target) print(target) end
	}
})
```

As opções recebem callbacks e predicados locais; não são serializáveis nem podem ser registradas pelo servidor. `AddTargetEntity` exige entidade existente e lista de opções; `AddTargetModel` aceita hash ou nome de modelo. Cada opção válida precisa de `label` e função `onSelect`; `canInteract` é opcional.

Registros: `AddTargetEntity(entidade, opções)`, `AddTargetModel(modelo, opções)` (qualquer entidade do modelo, ex.: portas) e `AddTargetGlobal(tipo, opções)` com tipo `player`, `ped`, `vehicle` ou `object`; cada um tem o `Remove...` correspondente (`RemoveTargetEntity`, `RemoveTargetModel`, `RemoveTargetGlobal`). Para qualquer superfície mirada (inclusive o mapa, com `entity = 0`) use `AddTargetSurface(opções)` e `RemoveTargetSurface(opções)`. Registros são por resource dono: dois resources podem registrar no mesmo alvo e as opções se somam; ao parar o resource, seus registros somem. Opções aceitam `label`, `onSelect(entidade, opção)`, `canInteract(entidade, distância)` e `distance` (padrão `Config.DefaultOptionDistance`, medido a partir do jogador). Erros nos callbacks são isolados.

Sem opção registrada para o alvo, o target mostra apenas o indicador, sem nenhuma opção (não há ações padrão). Clique para entrar no modo de escolha e escolha a opção com o mouse; antes de executar, o target revalida alcance, `canInteract` e o registro da opção. Essas ações são UX local e não substituem validação de servidor.

## Dependências e segurança

Resource standalone client-side, sem dependência de `coe_core`. Os exports permitem que outros resources adicionem ações, por isso callbacks devem tratar estado local e nunca confiar em dados do alvo como autorização.

## Testes e limites

Execute `lua test\client_test.lua` a partir da pasta do resource. O teste cobre registro/remoção, validações básicas, configuração da tecla e estado ocioso da UI. Raycast real, natives, navegação com controles, interação em Enhanced e compatibilidade NUI precisam de smoke test no FXServer.

## Referência da API

[Exports, parâmetros e códigos de erro](../reference/coetarget.md), gerado de [`types.lua`](types.lua).
