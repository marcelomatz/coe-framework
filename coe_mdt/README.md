# coe_mdt

MDT da polícia, aberto pelo `coe_tablet` (app **MDT**). É a ferramenta mais sensível da polícia: todo acesso é revalidado e consulta a dados é registrada.

## Acesso

- Só abre para quem está **de ponto em um negócio da categoria `police`**. O `coe_tablet` libera o app por categoria (`categories = { police = true }`) e o MDT **revalida a cada ação**: ponto, categoria e permissão de cargo. Sair de serviço ou perder o cargo corta o acesso na hora.
- Permissões de cargo (registradas no `coe_businesses`, definidas por cargo no negócio):

| Permissão | Libera |
|---|---|
| `mdt.access` | Abrir o MDT, ver chamados, mandados e boletins (base de tudo) |
| `mdt.lookup` | Consultar cidadãos e placas |
| `mdt.reports` | Registrar e ler relatórios |
| `mdt.warrant_issue` | Emitir mandados |
| `mdt.warrant_close` | Cumprir ou revogar mandados |
| `mdt.bulletins` | Publicar e encerrar boletins |

## Funções

- **Chamados**: lista, atende e encerra via `coe_dispatch`.
- **Consulta**: cidadão (nome ou ID de 8 caracteres) com mandados, ficha criminal (`coe_police`), veículos e relatórios; placa com proprietário e boletins.
- **Mandados**: emitir, cumprir, revogar. Estados finais não voltam. Limite de mandados ativos por cidadão.
- **Boletins**: avisos com validade (1 a 72 h) e placa opcional.
- **Relatórios**: imutáveis, com envolvido opcional.

## Segurança

- Consultas (`lookup`, `person`, `plate`, `warrants`, `reports`) são **gravadas em `coe_mdt_access_log` antes de devolver dados**; se o registro falhar, a consulta é negada.
- Limite por policial: 20 consultas e 12 escritas por minuto.
- Escritas também vão para o `coe_audit`.
- Texto livre é sanitizado e limitado; a interface usa apenas `textContent`.
- Export `AccessLog(subject, limit)` para a corregedoria (somente `AuditResources`).

## Eventos

- `coe_mdt:warrantIssued (officerSource, subjectCharacterId, charge)`
- `coe_mdt:warrantClosed (officerSource, subjectCharacterId, status)`

## Instalação

`ensure coe_mdt` após `coe_businesses`, `coe_police`, `coe_dispatch` e `coe_tablet`. Dê as permissões `mdt.*` aos cargos do negócio da polícia.
