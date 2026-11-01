# coe_garages

Garagens independentes de negócios, cadastradas na aba **Garagens** do admin (`coe_garage_registry`). Cada garagem tem de 1 a 8 vagas (ponto de abertura, de saída e de guarda; a direção marcada é o heading de saída) e um blip opcional.

Tipos:

- **Pública** (`public`): guarda os veículos pessoais do jogador. Nível 1: 1 carro + 1 moto (`config.lua`, `Levels`); o nível é o gancho para upgrades futuros. Blip ligado por padrão.
- **Negócio** (`business`): frota de um negócio. O dono definido no negócio libera cada veículo para pessoas (por stateId) e/ou para a equipe. "Equipe" é quem está na equipe do negócio e pode operar segundo o `coe_businesses` (`Access`: ponto batido quando `clockRequired`).
- Compra de frota por outro resource (`FleetResources`, hoje o `coe_fuel`): `AddBusinessFleet(businessId, modelo, equipe)` cria o veículo na primeira garagem de negócio do negócio (sem garagem: `no_fleet_garage`) e, com `equipe = true`, libera para a equipe.
- Tablet de negócios: provedor `fleet` registrado com `coe_businesses:RegisterProvider` (de novo quando o `coe_businesses` reinicia). `BusinessFleet(businessId)` e `SetFleetStaffAccess(businessId, vehicleId, enabled)` atendem só `BusinessResources` (`coe_businesses`), que confere ponto e a permissão `business.fleet`.
- **Corporação** (`job`): frota de polícia, hospital, bombeiros etc. Todos com um dos empregos informados usam todos os veículos.

Garagem de residência fica para depois: entra como um novo tipo.

Uso: a pé, `E` abre a garagem; dentro do veículo, `E` guarda. Retirar dá a chave ao jogador; guardar na frota revoga as chaves.

Frota pelo admin: na garagem de negócio ou corporação (já salva), a seção "Frota" lista os veículos e adiciona pelo catálogo (com foto de docs.fivem.net; veículos addon sem foto mostram o modelo) ou remove os que estão guardados. Não dá para mudar o tipo nem apagar uma garagem que ainda tem frota.

Comando (ACE `command.coe_fleet_add`): `coe_fleet_add <garagem> <modelo> [placa]`.

Tabelas: `coe_garage_registry`, `coe_garage_slots`, `coe_fleet` (`garage_id`), `coe_fleet_access`.

## COE OS

App **Veículos** do `coe_tablet` (`html/tablet_app.js`, `server/tablet.lua`, export `TabletCall`, só leitura): veículos do personagem com estado, placa, km e a garagem onde está guardado ou a posição atual, com botão de GPS. Testes: `lua test/registry_test.lua`, `test/rules_test.lua` e `test/tablet_test.lua`.
