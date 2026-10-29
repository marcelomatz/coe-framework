# coe_talk

Sistema completo de áudio e voz em tempo real do framework **COE**, desenvolvido para o novo padrão nativo do **FiveM Enhanced** (`voice_internal` / OneSync / RAGE Audio).

Substitui integralmente arquiteturas legadas de Mumble externo (Murmur/porta 64738/VoIP de terceiros) por uma pilha de áudio integrada, rápida e com cancelamento nativo de ruído e eco.

---

## Recursos Principais

1. **Pilha de Voz Nativa FiveM Enhanced**:
   - Áudio espacial 3D surround integrado ao motor de som RAGE do GTA V (`voice_useNativeAudio` e `voice_use3dAudio`).
   - Alcance estrito de transmissão sem vazamento de pacotes na rede (`voice_useSendingRangeOnly`).
   - Sem dependência de servidores VoIP externos.

2. **Modos de Proximidade (Alcance de Voz)**:
   - **Sussurrar (Whisper)**: 1.5 metros (privacidade em veículos e interiores).
   - **Normal**: 5.0 metros (conversas do dia a dia).
   - **Gritar (Shout)**: 15.0 metros (situações táticas, confrontos e perseguições).
   - Alternância rápida com feedback sonoro e visual pela tecla **`Z`** (reconfigurável nas configurações do FiveM) ou pelos comandos `/proximidade` e `/voz`.

3. **Rádio Comunicador Tático (Walkie-Talkie)**:
   - Frequências de 1.0 a 999.9 MHz com ajuste de 0.1 MHz.
   - Canais protegidos por profissão/facção (Canais 1 a 3 para Polícia/COE, 4 e 5 para SAMU/Bombeiros).
   - Push-To-Talk tático na tecla **`CAPS LOCK`** com som característico de início/fim de transmissão (*mic clicks*).
   - Animação do personagem segurando o rádio no peito/ombro enquanto transmite.
   - Ajuste de volume do rádio com `/radiovolume [0-100]`.

4. **Filtros Sonoros Autênticos (RAGE Audio Submixes)**:
   - **Efeito de Rádio**: distorção acústica tática e corte de frequências altas/baixas em tempo real.
   - **Efeito de Telefone**: filtro de linha telefônica para chamadas do celular.

5. **Interface NUI & Reatividade Visual**:
   - Widget discreto no canto inferior integrado aos tokens de design do `coe_ui`.
   - Microfone dinâmico com anel de pulso luminoso enquanto o jogador fala.
   - Barras de nível de alcance (1 a 3 barras) com rótulo tático.
   - Badge de frequência de rádio ativa e indicador `TX` em transmissão.
   - Acompanha as cores do tema ou tema do jogador (`--coe-accent`).

---

## Comandos

| Comando | Descrição |
| --- | --- |
| `/voz` ou `/proximidade` | Alterna entre Sussurro, Normal e Grito |
| `/ptt` | Alterna entre Push-To-Talk (tecla N) e ativação contínua por voz |
| `/radio [frequência]` | Sintoniza a frequência (ex: `/radio 101.5` ou `/radio 1` para canal tático) |
| `/radiodesligar` ou `/radio 0` | Desconecta do rádio atual |
| `/radiovolume [0-100]` | Ajusta o volume de recepção do rádio |

---

## Teclas Padrão (Keybinds)

- **`N`**: **Falar no Microfone** (Push-To-Talk de voz local).
- **`Z`**: Alternar alcance da voz (Sussurrar 1.5m, Normal 5.0m, Gritar 15.0m).
- **`CAPS LOCK`**: Push-To-Talk do rádio (falar na frequência).

*(Configuráveis individualmente por cada jogador em **ESC > Configurações > Teclado > FiveM**)*.

---

## Exports

### Cliente

```lua
-- Retorna a distancia, rotulo e id do modo atual (ex: 5.0, "Normal", "normal")
local distance, label, id = exports.coe_talk:GetVoiceRange()

-- Define a distancia ou modo programaticamente ("whisper", "normal", "shout" ou numero em metros)
exports.coe_talk:SetVoiceRange('shout')

-- Retorna a frequencia de radio conectada (ou nil se desligado)
local freq = exports.coe_talk:GetRadioChannel()

-- Sintoniza uma frequencia (ou nil/0 para desligar)
exports.coe_talk:SetRadioChannel(101.5)

-- Retorna se o jogador local esta falando no microfone
local talking = exports.coe_talk:IsTalking()

-- Retorna se o jogador esta transmitindo no radio
local transmitting = exports.coe_talk:IsRadioTransmitting()

-- Chamada atual (definida pelo servidor) e saida da chamada; o client nao escolhe em qual chamada entra
local callId = exports.coe_talk:GetCallChannel()
exports.coe_talk:SetCallChannel(nil)

-- Volume da voz recebida (0-100)
exports.coe_talk:SetVoiceVolume(80)
```

### Servidor

```lua
-- Conecta um jogador a uma frequencia
exports.coe_talk:SetPlayerRadio(source, 911.0)

-- Retorna a frequencia de um jogador
local freq = exports.coe_talk:GetPlayerRadio(source)

-- Retorna a lista de sources em uma frequencia
local members = exports.coe_talk:GetRadioMembers(911.0)

-- Conecta jogadores a uma chamada privada (id: ate 64 caracteres [A-Za-z0-9_:-]; nil encerra)
exports.coe_talk:SetPlayerCall(source, 'chamada_123')

-- Chamada de um jogador e participantes de uma chamada
local callId = exports.coe_talk:GetPlayerCall(source)
local inCall = exports.coe_talk:GetCallMembers(callId)
```

`SetPlayerRadio` e `SetPlayerCall` so aceitam chamadas de `Config.Access.Resources` (padrao: `coe_mobile`) ou de quem tem a ACE `coe.talk` (`add_ace resource.<nome> coe.talk allow`). Para outros resources eles retornam `false, 'forbidden'`. Entrar em chamada so acontece pelo servidor: nao ha evento de rede para o client escolher uma chamada (isso permitiria ouvir chamadas alheias). Eventos de voz e radio vindos do client tem intervalo minimo de `Config.EventCooldownMs`.

Contrato completo em [`types.lua`](types.lua) e na [referencia da API](../reference/coe_talk.md).

---

## Testes Automatizados

Para executar os testes unitários da lógica de regras e roteamento:

```powershell
lua test/rules_test.lua
lua test/server_talk_test.lua
```
