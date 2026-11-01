# [vendor] — dependências de terceiros

Resources de terceiros que algum script do COE exige e que não têm build pronto para baixar. Ficam numa categoria
própria (`[vendor]`) para não se misturarem aos resources do framework: o FXServer os encontra dentro de
`[coe-framework]`, mas as ferramentas do repositório (contratos, referência, fronteira, version.json) os ignoram.

| Resource | Origem | Licença | Usado por |
|---|---|---|---|
| `screenshot-basic` | [citizenfx/screenshot-basic](https://github.com/citizenfx/screenshot-basic), build pré-compilado (`dist/`) | MIT (Cfx.re) | `coe_apps` (câmera e galeria) |

Atualizar: compile o repositório oficial (`yarn && yarn build`) e substitua `dist/`, anotando o commit no `fxmanifest.lua`.
