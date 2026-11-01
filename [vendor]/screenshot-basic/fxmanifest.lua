-- Build pré-compilado de https://github.com/citizenfx/screenshot-basic (MIT, Cfx.re), commit 5e89d4a.
-- As dependências de build (yarn/webpack) foram removidas porque dist/ já vem compilado.
-- Patch COE: o retorno da foto à página NUI usa https://<resource>/screenshot_created (era http://). O CEF serve a
-- página em https://cfx-nui-screenshot-basic, e o CEF mais novo (FiveM Enhanced) pode bloquear o POST para http:// (conteúdo misto).
fx_version 'bodacious'
game 'common'

client_script 'dist/client.js'
server_script 'dist/server.js'

files {
    'dist/ui.html'
}

ui_page 'dist/ui.html'