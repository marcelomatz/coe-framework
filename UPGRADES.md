# Upgrade do básico para o script avançado (mapa DE > PARA)

Os dois lados estão neste repositório. O build oficial e a recipe já trazem só o avançado; este mapa vale para quem tem um servidor com o básico instalado. Cada script avançado que substitui um básico declara isso no próprio `fxmanifest.lua`:

```lua
coe_supervisor_replaces 'coe_mobile'
```

Com o pacote rodando, o `coe_supervisor` não deixa o básico iniciar. No boot ele segura o básico mesmo que o pacote suba depois na ordem alfabética. Se o pacote parar, ou não subir, o básico volta sozinho. Quem tinha o básico e compra o pacote só faz `ensure` do pacote: nada do básico precisa ser apagado.

No console do servidor, `coe_upgrades` mostra o mapa ao vivo: cada básico, quem o substitui, o estado de cada um e o que o pacote importou do básico.

```
[coe_supervisor] DE (básico) -> PARA (pacote)
  coe_bank (stopped) -> coe_banking (ATIVO)
  coe_mobile (stopped) -> coe_phone (ATIVO)
      dados do básico: calls=12 conflicts=0 contacts=40 kept=1 messages=310 numbers=18
  coe_staff (stopped) -> coe_admin (ATIVO)
  coe_workpad (stopped) -> coe_tablet (ATIVO)
```

| DE (básico) | PARA (avançado) | Grupo |
|---|---|---|
| `coe_mobile` (telefone básico) | `coe_phone` (smartphone COE OS) | COE OS Suite |
| `coe_workpad` (tablet de trabalho) | `coe_tablet` (tablet COE OS) | COE OS Suite |
| `coe_bank` (banco básico) | `coe_banking` (sistema bancário) | Enterprise & Governance |
| `coe_staff` (painel básico da staff) | `coe_admin` (painel administrativo) | Enterprise & Governance |
| `coe_garage` (garagem básica) | `coe_garages` (garagens públicas, privadas e frotas) | Automotive |

---

## `coe_mobile` → `coe_phone`

| | DE `coe_mobile` | PARA `coe_phone` |
|---|---|---|
| Item | `phone` | `phone` (o mesmo item) |
| Tecla e comando | F1, `/telefone` | F1, `/celular` e `/telefone` (`CommandAliases`) |
| Número | `coe_mobile_numbers` (`555-0123`) | chip no aparelho (`coe_phone_sims`, `5550123`): **o mesmo número** |
| Contatos | `coe_mobile_contacts` | contatos do aparelho (`coe_phone_device_contacts`) |
| Mensagens | `coe_mobile_messages` | `coe_phone_messages` (lidas continuam lidas, não lidas continuam não lidas) |
| Ligações | `coe_mobile_calls` | `coe_phone_calls` (`unreachable` vira `unavailable`) |
| Ajustes | silencioso, volume, toque, papel de parede | os mesmos no aparelho (o resto pelos padrões) |
| Voz | `coe_talk` | `coe_talk` |

**Importação automática** (`coe_phone/server/upgrade.lua`, a cada inicialização):

- Cada personagem do básico ganha um aparelho "legado" (serial `MG` + id) com o chip do mesmo número, os contatos e os ajustes. O primeiro celular que ele abrir assume esse aparelho.
- **Quem já tinha linha no smartphone** mantém a linha; as conversas do número antigo passam para ela.
- **Número já usado por outra pessoa no smartphone**: o personagem recebe um número novo, e as conversas e contatos dele apontam para o número novo (`conflicts` no relatório).
- Conversa apagada pelos dois lados no básico não vem. Apagada só de um lado volta a aparecer para esse lado: nada se perde.
- Marca d'água por tabela (`coe_phone_upgrades`). Voltar ao básico e depois ao smartphone traz só o que é novo, sem duplicar.
- As tabelas `coe_mobile_*` não são alteradas nem apagadas.

## `coe_workpad` → `coe_tablet`

| | DE `coe_workpad` | PARA `coe_tablet` |
|---|---|---|
| Item | `business_tablet` | `business_tablet` (o mesmo item) |
| Tecla e comando | F3, `/trabalho` | F3, `/tablet` e `/trabalho` (`CommandAliases`) |
| Ponto | app Ponto | app **Ponto** (grupo Trabalho; o mesmo app: locais de trabalho, cargo, salário, GPS e encerrar o ponto) |
| Empregos livres | app Empregos livres (`coe_jobs`) | app **Empregos livres** (grupo Trabalho; o mesmo app) |
| Carreira | app Carreira (`coe_jobs`) | app Carreira |
| Negócios | um app por negócio (`coe_businesses`) | app Negócio (um por negócio) |
| Dados | nenhum próprio | — |

ACEs: `coe.businesses.tablet`, `coe.businesses.clock` e `coe.jobs.tablet` para o `coe_tablet` (concedidas por padrão: `CoeAccess.FirstParty`).

## `coe_bank` → `coe_banking`

| | DE `coe_bank` | PARA `coe_banking` |
|---|---|---|
| Conta | saldo do `coe_economy` | o mesmo saldo do `coe_economy` |
| Espécie | item `money` | item `money` |
| Agências | balcão com "E" e blip | as mesmas agências, com balcão e blip |
| Extrato | `bank_withdraw`, `bank_deposit`, `bank_transfer`, `bank_refund` | os mesmos motivos: o histórico continua coerente |
| Transferência | por ID de cidadão | por ID de cidadão |
| Caixa eletrônico | sem cartão | **com cartão `card_bank` e senha**: o cliente pede o cartão na agência |
| Dados | nenhum próprio | — |

Não há o que importar: o dinheiro e o extrato ficam no `coe_economy`, que os dois usam.

## `coe_staff` → `coe_admin`

| | DE `coe_staff` | PARA `coe_admin` |
|---|---|---|
| Abrir | F10, `/staff` | F10 (painel), `/coeadmin` e `/staff` (ferramentas). Quem só tem ACE de ferramentas abre direto nelas pelo F10 |
| Pessoal | noclip, invisível, invencível, coordenadas, curar, reviver, marcador, teleporte | **Ferramentas da staff** > Pessoal (as mesmas, `/noclip` incluído) |
| Jogadores | ir até, trazer, congelar, curar, reviver, expulsar, item, dinheiro, grupos | Ferramentas > Jogadores (as mesmas) |
| Veículos | temporário, registrado, consertar, abastecer, limpar, desvirar, apagar | Ferramentas > Veículos (as mesmas) |
| Mundo | hora, clima, aviso | Ferramentas > Mundo (as mesmas) |
| Negócios | criar e editar | Ferramentas > Negócios e a aba Negócios do painel |
| Permissões | `coe.staff.all`, `coe.staff.<módulo>` | **as mesmas continuam valendo**, mais `coe_admin.tools.all`, `coe_admin.tools.<módulo>` e `coe_admin.root` |
| txAdmin | admin do txAdmin libera tudo | o mesmo |
| Auditoria | `staff_*` em `coe_audit` | os mesmos eventos |

Quem era staff no básico continua com as mesmas ferramentas sem mudar o `server.cfg`. O botão "Ferramentas da staff" aparece no painel para quem tem alguma ferramenta.

---

## Checklist de quem faz o upgrade

1. Copie o script avançado (as capacidades dele já vêm concedidas pelo framework).
2. `ensure` do pacote. Não precisa tirar o básico do `server.cfg` nem apagar tabelas.
3. Reinicie o servidor e rode `coe_upgrades` no console: o básico aparece `stopped` e o pacote `ATIVO`, com o relatório do que foi importado.
4. Para voltar ao básico, pare o pacote: o básico sobe sozinho com os dados dele.
