"""Gera os ícones de item do coe_inventory.

Uso:
	python tools/item_icons/build.py <saida_svg> <saida_imagens> [nome ...]

Escreve <nome>.svg (fonte) e <nome>.png / <nome>.webp (128×128) para cada item registrado em ``catalog``.
Requer: resvg-py e Pillow.
"""
import io
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import resvg_py  # noqa: E402
from PIL import Image  # noqa: E402

from catalog import ICONS  # noqa: E402

SIZE = 128


def render(name):
	draw, opts = ICONS[name]
	return draw(name, **opts)


def export(name, svg_dir, img_dir):
	svg = render(name)
	with open(os.path.join(svg_dir, name + '.svg'), 'w', encoding='utf-8') as f:
		f.write(svg)
	png = bytes(resvg_py.svg_to_bytes(svg_string=svg, width=SIZE * 2, height=SIZE * 2))
	im = Image.open(io.BytesIO(png)).convert('RGBA').resize((SIZE, SIZE), Image.LANCZOS)
	im.save(os.path.join(img_dir, name + '.png'), optimize=True)
	im.save(os.path.join(img_dir, name + '.webp'), quality=92, method=6)
	return im


def main():
	svg_dir, img_dir = sys.argv[1], sys.argv[2]
	names = sys.argv[3:] or sorted(ICONS)
	os.makedirs(svg_dir, exist_ok=True)
	os.makedirs(img_dir, exist_ok=True)
	for name in names:
		export(name, svg_dir, img_dir)
	print('%d ícones gerados' % len(names))


if __name__ == '__main__':
	main()
