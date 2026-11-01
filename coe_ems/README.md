# coe_ems

Saúde e EMS. Pacote separado da polícia; plug-and-play sobre `coe_businesses`. **Equipe, cargos e salários vivem no negócio** da categoria `ems` (Hospitais): o médico precisa estar de ponto num negócio `ems` e ter a permissão no cargo. O pagamento sai da conta de sociedade (`coe_economy`).

## Permissões de cargo

Registradas no `coe_businesses` ao iniciar (`RegisterPermissions`): `ems.revive` (reanimar), `ems.treat` (tratar), `ems.records` (consultar prontuários). O dono do negócio tem todas. Marque-as na aba **Cargos** do `coe_admin`.

## Estados do paciente

`healthy` → `injured` → `unconscious` → `dead`. O cliente só reporta o que o jogo mostra (saudável/ferido/inconsciente, ver `EmsRules.CanReport`); morrer por sangramento (`BleedoutSeconds`) e reviver são decisões do servidor. Reanimar exige `unconscious` (`dead` só com `ReviveDead`); tratar exige `injured`. O morto usa `/respawn` e volta ao primeiro negócio `ems` com área circular (ou `Respawn`).

## API (servidor)

Valor único ou `{ error = codigo }` (`forbidden`, `not_on_duty`, `not_ems`, `invalid_state`, `too_far`, `unknown_patient`...).

- `State(source)`; `SetState(source, estado)` (só `StateResources`).
- `Revive(medico, paciente, detalhe?)`, `Treat(...)`, `Records(medico, characterId, limite?)` (só `ActionResources`). O servidor valida personagem, ponto, categoria, cargo, estado e distância (`ActionRange`).
- Comandos: `/reanimar <id>`, `/tratar <id>`, `/respawn`.
- Eventos de servidor: `coe_ems:stateChanged` (source, characterId, de, para) e `coe_ems:treated` (médico, paciente, ação, businessId). Eventos de cliente: `coe_ems:state`, `coe_ems:revive`, `coe_ems:heal`, `coe_ems:respawn`.

## Prontuário

Tabela `coe_ems_records` (paciente, médico, negócio, tipo `revive|treat|respawn`, detalhe curto `[a-z0-9_]`), sem texto livre. Cada ação é gravada antes de aplicada e vai para a auditoria.

## Fora desta fase

Maca, ambulância, leitos, farmácia/itens médicos, ferimentos por região, chamado de socorro e integração com `coe_needs`/HUD ficam para as próximas fases (#125). Testes: `lua test/rules_test.lua`.
