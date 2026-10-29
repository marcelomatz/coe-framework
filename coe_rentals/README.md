# coe_rentals

Aluguel de veículos populares para cidadãos iniciantes: o jogador paga o aluguel mais uma caução no balcão de uma
estação e recebe a caução de volta ao devolver o veículo em qualquer estação.

## Como funciona

- Estações e catálogo em `config.lua` (`RentalsConfig.Stations` e `RentalsConfig.Vehicles`). Cada veículo tem
  `price` (não reembolsável) e `deposit` (caução).
- O client mostra o balcão a 2 m de `coords` e pede `rentals.rent`; o servidor confere o personagem ativo, a estação, o
  modelo, a distância (`InteractRadius`, 6 m) e o intervalo entre pedidos (`CooldownMs`, 2 s), e só então cobra.
- **Cobrança fail-closed**: sem `coe_economy` no ar o aluguel é recusado (`economy_unavailable`); nada sai de graça.
  Se o veículo não puder ser criado, o valor é estornado.
- Devolução (`rentals.return`): o jogador precisa estar dirigindo o veículo alugado dentro da `returnZone` de uma
  estação. A caução volta pela economia; se o crédito falhar, o erro é registrado no log e o jogador é avisado.
- Um aluguel ativo por personagem. Ao sair do servidor, o veículo é removido e a caução fica retida.

## Acesso a outros resources

`coe_rentals` está no `AllowedResources` do `coe_economy` (débito do aluguel e crédito da caução). Nenhuma ACE a
configurar; `ensure coe_rentals` já está no `recipe.yaml`.

## Exports (servidor)

| Export | Retorno |
| --- | --- |
| `GetActiveRental(characterId)` | aluguel ativo (`entity`, `netId`, `plate`, `model`, `deposit`, `stationId`, `rentedAt`) ou `nil` |

Contrato em [`types.lua`](types.lua) e na [referência da API](../reference/coe_rentals.md).

## Testes

```powershell
cd coe_rentals
lua test/rentals_test.lua
lua test/server_test.lua
```

`rentals_test.lua` cobre as regras puras (catálogo, estação, valores, placa, distância); `server_test.lua` cobre o
fluxo do servidor com economia simulada (economia fora do ar, distância, cooldown, saldo insuficiente e devolução).
