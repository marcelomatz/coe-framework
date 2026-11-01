# coe_housing — referência da API

> Gerado de `coe_housing/types.lua` por `tools/gen_reference.lua`. Não edite à mão.

Gerado a partir dos exports registrados no código; refine descrições e tipos ao mexer em cada export.

## Exports

### `AddressActive(propertyId, owner)`

O endereço ainda existe (contrato ativo ou imóvel ilegal com mundo)? Devolve o interior para posicionar a entrega.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `propertyId` | `any` |  |
| `owner` | `any` |  |

**Retorno**

- `any`

### `BeginPreview(playerId)`

Prévia: o admin vai para um mundo só dele enquanto visita interiores; EndPreview o devolve ao mundo comum.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `any` |  |

**Retorno**

- `any`

### `BusinessProperties(businessId)`

Imóveis comerciais de um negócio (alugados ou cedidos), para o tablet de negócios.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `businessId` | `any` |  |

**Retorno**

- `any`

### `CurrentSpace(playerId)`

Espaço em que o jogador está agora: { propertyId, owner, interior }, ou nil fora de um imóvel.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `any` |  |

**Retorno**

- `any`

### `DeleteProperty(propertyId)`

Export server `DeleteProperty` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `propertyId` | `any` |  |

**Retorno**

- `any`

### `DeliveryAddresses(playerId)`

Endereços em que o personagem pode receber: moradias, comerciais dos negócios em que trabalha e imóveis ilegais com acesso. Contratos vencidos (fora da carência) ficam de fora.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `any` |  |

**Retorno**

- `any`

### `EndContract(kind, contractId)`

Imobiliária (admin): encerra um contrato. O inicial e o cedido a um negócio não são encerrados por aqui.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `kind` | `any` |  |
| `contractId` | `any` |  |

**Retorno**

- `any`

### `EndPreview(playerId)`

Export server `EndPreview` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `any` |  |

**Retorno**

- `any`

### `InteriorThumbs()`

Miniaturas capturadas no jogo: mapa id do interior -> data URL JPEG.

**Retorno**

- `any`

### `Interiors()`

Catálogo de interiores nativos (shared/interiors.lua), para o admin escolher o interior de cada imóvel.

**Retorno**

- `any`

### `IsReady()`

Export server `IsReady` (server/main.lua).

**Retorno**

- `any`

### `ListProperties()`

Export server `ListProperties` (server/main.lua).

**Retorno**

- `any`

### `PlayersInSpace(propertyId, owner)`

Jogadores dentro de um espaço (para mostrar entregas a quem já está lá).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `propertyId` | `any` |  |
| `owner` | `any` |  |

**Retorno**

- `any`

### `PropertyContracts(propertyId)`

Imobiliária (admin): contratos de um imóvel, com quem está dentro agora.

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `propertyId` | `any` |  |

**Retorno**

- `any`

### `SaveInteriorThumb(interiorId, image)`

Export server `SaveInteriorThumb` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `interiorId` | `any` |  |
| `image` | `any` |  |

**Retorno**

- `any`

### `SaveProperty(raw)`

Export server `SaveProperty` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `raw` | `any` |  |

**Retorno**

- `any`

### `TabletCall(playerId, appId, action, payload)`

Export server `TabletCall` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `any` |  |
| `appId` | `any` |  |
| `action` | `any` |  |
| `payload` | `any` |  |

**Retorno**

- `any`

### `TabletVisible(playerId, appId)`

Export server `TabletVisible` (server/main.lua).

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `playerId` | `any` |  |
| `appId` | `any` |  |

**Retorno**

- `any`

