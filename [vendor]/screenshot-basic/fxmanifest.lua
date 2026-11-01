-- Build pré-compilado de https://github.com/citizenfx/screenshot-basic (MIT, Cfx.re), commit 5e89d4a.
-- As dependências de build (yarn/webpack) foram removidas porque dist/ já vem compilado.
fx_version 'bodacious'
game 'common'

client_script 'dist/client.js'
server_script 'dist/server.js'

files {
    'dist/ui.html'
}

ui_page 'dist/ui.html'