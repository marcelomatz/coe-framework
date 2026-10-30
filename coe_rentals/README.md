# coe_rentals

Aluguel de veículos populares para cidadãos iniciantes: o jogador paga o aluguel mais uma caução no balcão de uma
estação e recebe a caução de volta ao devolver o veículo em qualquer estação.

## Como funciona

- Estações e catálogo em `config.lua` (`RentalsConfig.Stations` e `RentalsConfig.Vehicles`). Cada veículo tem
  `price` (não reembolsável) e `deposit` (caução).
- Estações ficam no banco (`coe_rental_stations`) e são editadas no painel (aba **Aluguel** do `coe_staff`; painéis
  de pacotes usam os exports com a ACE `coe.rentals.admin`): atendente (NPC e balcão), vários pontos de retirada (o veículo sai no primeiro livre), zona de
  devolução, modelos oferecidos e blip. `RentalsConfig.Stations` só semeia o banco na primeira vez.
- Ao alugar, o jogador recebe o **contrato de locação** (`rental_contract`, usar mostra o documento com veículo,
  placa, locatário, data e valores) e a **chave** (`carkey` com `rental = true`; sem ela o veículo não liga nem tranca).
  Os dois itens saem do inventário ao devolver ou encerrar.
- Devolver: dirigindo, na zona de devolução (E) ou a pé, no balcão (menu **Devolver**) com o carro estacionado perto
  (`CounterReturnDistance`) e vazio. Se o carro foi destruído ou sumiu, **Encerrar aluguel** libera alugar de novo e a
  caução fica retida.
- No balcão, `E` abre o menu (`html/`, tema do `coe_ui`): lista os veículos da estação com aluguel, caução e total;
  setas/clique escolhem, `Enter`/Alugar confirma, `Esc` fecha. `vehicles = { ... }` na estação limita o catálogo ali.
- O menu pede `rentals.rent`; o servidor confere o personagem ativo, a estação, o
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
