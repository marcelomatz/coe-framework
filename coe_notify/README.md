# coe_notify

Biblioteca de notificações NUI para mensagens curtas destinadas ao jogador. Ela não lê logs nem transforma erros internos automaticamente em mensagens de gameplay.

## API client-side

```lua
local shown, errorCode = exports.coe_notify:Show('success', 'Item recebido.')
```

`Show(type, message, duration?)` aceita `success`, `info`, `warning` ou `error`. A duração opcional deve estar entre 1500 e 10000 ms (padrão: 4000 ms). Mensagens são limitadas a 240 bytes e inseridas na UI como texto, nunca como HTML.

## API server-side

Resources autorizados podem solicitar uma notificação para um jogador online:

```lua
local sent, errorCode = exports.coe_notify:Notify(source, 'info', 'Personagem carregado.')
```

O servidor valida o chamador, o destinatário e os argumentos antes de enviar a mensagem somente ao client alvo. A rota client→server não aceita mensagens de notificação. O client também valida a origem dos eventos recebidos.

Os resources do framework que notificam estão autorizados por padrão (`server.lua`). Pacotes e scripts de terceiros recebem a ACE no `server.cfg`, sem editar o framework: `add_ace resource.<nome> coe.notify allow`.

## Integração com logs

Uma ação de negócio pode emitir um evento estruturado de auditoria e uma notificação contextual, mas são APIs distintas: o log conserva códigos e contexto seguro para diagnóstico; a notificação contém apenas texto apropriado ao jogador. Nunca encaminhe contexto de log, SQL, identificadores privados ou mensagens de exceção à NUI.

## Testes e limites

Arquivos: `client.lua` expõe a API local e valida eventos originados pelo servidor; `server.lua` autoriza resources e direciona mensagens ao jogador; `html/` renderiza a fila visual; `fxmanifest.lua` declara assets e entrypoints. Execute `lua test\client_notify_test.lua` e `lua test\server_notify_test.lua` a partir da pasta do resource. Testes cobrem validação, rejeição de origem/caller não confiável e encaminhamento. Layout e NUI em jogo precisam de smoke test; ver [TEST_COVERAGE.md](../TEST_COVERAGE.md).

## Referência da API

[Exports, parâmetros e códigos de erro](../reference/coe_notify.md), gerado de [`types.lua`](types.lua).
