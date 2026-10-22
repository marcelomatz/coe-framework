# Ícones de item do inventário

Gerador dos ícones de `coe_inventory/data/images` (semi-realista, perfil com luz de cima à esquerda, sombra projetada,
fundo transparente). Cada item é desenhado em SVG por código e exportado em PNG e WebP 128×128 com o mesmo nome do item.

## Gerar

```
pip install resvg-py pillow
python tools/item_icons/build.py tools/item_icons/svg coe_inventory/data/images
```

Para gerar só alguns itens, passe os nomes no fim: `... coe_inventory/data/images WEAPON_PISTOL burger`.

## Organização

| Arquivo | Conteúdo |
|---|---|
| `lib.py` | Canvas (`Icon`), materiais (gradiente + contorno), formas, enquadramento e sombra |
| `parts.py` | Peças de arma: cano, quebra-chama, trilho, miras, lunetas, punhos, carregadores, bipé |
| `firearms.py` | Montadores paramétricos: fuzil, bullpup, pistola, revólver, submetralhadora, espingardas, precisão |
| `special.py` | Lançadores, armas de energia e armas incomuns |
| `melee.py` | Armas brancas, arremessáveis e objetos usados como arma |
| `ammo.py` | Munições e acessórios (supressor, carregadores, quebra-chamas, lunetas) |
| `items.py` | Comida, bebida, consumíveis, documentos, eletrônicos, peças e lixo |
| `catalog.py` | Registro `nome do item -> desenho + opções` (um por imagem) |

## Item novo

1. Desenhe com as primitivas de `lib.py` (ou reaproveite um montador com outras opções).
2. Registre em `catalog.py` com `reg('nome_do_item', obj(funcao, box, ...))`.
3. Gere só esse item e confira o PNG.

Convenções: materiais de `MATERIALS` (não use cor solta para o corpo do objeto), contorno escuro do próprio material,
reflexo com `ic.hl(...)`, detalhes com `ic.dark(...)`. Objetos longos (facas, tacos, munição de foguete) vão na
diagonal com `rotate=-40`; armas longas usam `stretch` para ganhar leitura em 64 px. Variantes Mk II levam a faixa
na cor de destaque do framework (`#c4df9b`).
