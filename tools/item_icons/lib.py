"""Primitivas SVG dos ícones de item do Coe (estilo semi-realista, luz vindo de cima à esquerda).

Cada ícone é desenhado num espaço livre de coordenadas; ``Icon.svg()`` enquadra o desenho num canvas
256×256 (exportado em 128×128) com sombra projetada. Os materiais definem gradientes e contorno.
"""
import math

CANVAS = 256

# Material: (luz, base, sombra, contorno). Cores escolhidas para ler bem sobre o painel escuro do framework.
MATERIALS = {
	'gunmetal': ('#6b747b', '#3a4146', '#1b1f22', '#0a0c0d'),
	'polymer': ('#4f5457', '#2a2d30', '#131516', '#050606'),
	'blued': ('#56606e', '#2c3440', '#141920', '#06080b'),
	'steel': ('#eef1f3', '#aab2b8', '#5c656b', '#262b2e'),
	'darksteel': ('#9aa3aa', '#626b72', '#353b40', '#14181a'),
	'chrome': ('#ffffff', '#c3cbd1', '#6a737a', '#2a3034'),
	'brass': ('#ffe9a8', '#dcaa47', '#8a5d1c', '#432c0b'),
	'gold': ('#fff3b8', '#e7bf4a', '#9a6f15', '#4a3407'),
	'copper': ('#f6bf98', '#c77a49', '#7a3d1d', '#3a1c0b'),
	'wood': ('#d39860', '#9b5e2e', '#5a3217', '#2a1508'),
	'darkwood': ('#9a6440', '#653b22', '#38200f', '#180c05'),
	'tan': ('#e2cfa4', '#b8a06f', '#7c6844', '#3a301d'),
	'olive': ('#919c70', '#5f6a47', '#3a4229', '#1a1e11'),
	'accent': ('#e8f6cf', '#c4df9b', '#88a85c', '#3a4f22'),
	'red': ('#ff8f80', '#d6392d', '#8a1a14', '#3a0805'),
	'darkred': ('#c75a52', '#8c2a24', '#521410', '#240705'),
	'orange': ('#ffc58a', '#f28a2e', '#a5520f', '#4a2304'),
	'yellow': ('#fff2a0', '#f2cc35', '#a8840f', '#4a3a04'),
	'green': ('#9fe39a', '#3fae4a', '#1f6a27', '#0c2c0f'),
	'darkgreen': ('#6f9a6a', '#3a6440', '#1f3a23', '#0b190d'),
	'blue': ('#9cc8ff', '#3a7fd6', '#1c4a8c', '#0a1f3d'),
	'navy': ('#6f84a8', '#34466a', '#1a2540', '#0a0f1c'),
	'cyan': ('#b8f4ff', '#46c6e0', '#1d7a8f', '#0a333d'),
	'purple': ('#d3b4ff', '#8a5ad6', '#4f2c8c', '#20103d'),
	'pink': ('#ffb8d8', '#ea5f9f', '#9a2a5e', '#40101f'),
	'white': ('#ffffff', '#e6e9eb', '#a9b0b5', '#4a5054'),
	'paper': ('#fffdf6', '#ece4d2', '#bfb39a', '#5c5242'),
	'cardboard': ('#e4bd86', '#bb8b51', '#7f5a2d', '#3c2911'),
	'kraft': ('#d9b98a', '#b08c5c', '#7a5c35', '#3a2a15'),
	'leather': ('#7a5238', '#4f3220', '#2c1a0f', '#120a05'),
	'blackleather': ('#4a4a4c', '#28282a', '#121213', '#050505'),
	'rubber': ('#4d4f51', '#2b2c2e', '#151617', '#060606'),
	'skin': ('#ffd9b3', '#e8b080', '#a9744a', '#4f321b'),
	'bread': ('#f7cf8a', '#d99a4a', '#9a5f20', '#4a2b0a'),
	'meat': ('#e88a7a', '#b2453a', '#6e1f19', '#2e0b08'),
	'cheese': ('#fff0a0', '#f5c842', '#b38a17', '#4d3a07'),
	'lettuce': ('#c8f58a', '#7cc443', '#3f7a1e', '#183209'),
	'tomato': ('#ff9a84', '#e2402f', '#8e1b12', '#3a0805'),
	'cream': ('#fffbe8', '#f2e6c4', '#c9b88a', '#5e5236'),
	'chocolate': ('#a06a48', '#6a3e24', '#3c2010', '#1a0c05'),
	'glass': ('#e9f7ff', '#a9cde0', '#5d8296', '#22343f'),
	'greenglass': ('#a8e0a0', '#3f8a46', '#1d4d22', '#0b220e'),
	'amberglass': ('#ffd28a', '#c47a20', '#6e3d0a', '#2e1803'),
	'cloth': ('#c9d3d8', '#8e9ba3', '#56626a', '#252c30'),
	'denim': ('#7f9ccc', '#4a68a0', '#2a3e66', '#10182b'),
	'screen': ('#2a3d4a', '#14222c', '#0a1218', '#050a0d'),
	'money': ('#c9efb4', '#86c46a', '#4a8238', '#1e3a15'),
	'redmoney': ('#f0b4a8', '#c46a5a', '#82382c', '#3a1510'),
	'snow': ('#ffffff', '#e8f2fa', '#b4c6d6', '#5a6a78'),
	'stone': ('#b7b2a6', '#827d71', '#4f4b43', '#22201c'),
}


def fmt(v):
	return ('%.2f' % v).rstrip('0').rstrip('.')


def shade(hex_color, factor):
	"""Escurece (factor<1) ou clareia (factor>1) uma cor #rrggbb."""
	h = hex_color.lstrip('#')
	r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
	if factor >= 1:
		r, g, b = (int(c + (255 - c) * (factor - 1)) for c in (r, g, b))
	else:
		r, g, b = (int(c * factor) for c in (r, g, b))
	return '#%02x%02x%02x' % (max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)))


def rounded_path(points, radius):
	"""Polígono fechado com cantos arredondados (raio por vértice: número ou lista)."""
	n = len(points)
	radii = radius if isinstance(radius, (list, tuple)) else [radius] * n
	parts = []
	for i in range(n):
		p0, p1, p2 = points[i - 1], points[i], points[(i + 1) % n]
		r = radii[i]
		if r <= 0:
			parts.append(('L', p1, None, None))
			continue
		d1 = math.dist(p0, p1)
		d2 = math.dist(p1, p2)
		r = min(r, d1 / 2, d2 / 2)
		a = (p1[0] + (p0[0] - p1[0]) * r / d1, p1[1] + (p0[1] - p1[1]) * r / d1) if d1 else p1
		b = (p1[0] + (p2[0] - p1[0]) * r / d2, p1[1] + (p2[1] - p1[1]) * r / d2) if d2 else p1
		parts.append(('Q', a, p1, b))
	d = []
	first = parts[0]
	start = first[3] if first[0] == 'Q' else first[1]
	d.append('M%s,%s' % (fmt(start[0]), fmt(start[1])))
	for kind, a, c, b in parts[1:] + parts[:1]:
		if kind == 'L':
			d.append('L%s,%s' % (fmt(a[0]), fmt(a[1])))
		else:
			d.append('L%s,%sQ%s,%s %s,%s' % (fmt(a[0]), fmt(a[1]), fmt(c[0]), fmt(c[1]), fmt(b[0]), fmt(b[1])))
	return ''.join(d) + 'Z'


def arc_points(cx, cy, rx, ry, a0, a1, steps=16):
	return [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * i / steps)),
		cy + ry * math.sin(math.radians(a0 + (a1 - a0) * i / steps))) for i in range(steps + 1)]


class Icon:
	"""Acumula elementos SVG e a caixa envolvente do desenho."""

	def __init__(self, name='icon'):
		self.name = name
		self.items = []
		self.defs = {}
		self.minx = self.miny = math.inf
		self.maxx = self.maxy = -math.inf
		self.uid = 0

	# --- caixa envolvente ---
	def _bound(self, pts, pad=0):
		for x, y in pts:
			self.minx = min(self.minx, x - pad)
			self.maxx = max(self.maxx, x + pad)
			self.miny = min(self.miny, y - pad)
			self.maxy = max(self.maxy, y + pad)

	# --- gradientes ---
	def grad(self, mat, kind='v'):
		"""kind: v (painel iluminado por cima), h (cilindro vertical), cyl (cilindro deitado), r (esfera), flat."""
		key = '%s-%s' % (mat, kind)
		if key in self.defs:
			return 'url(#%s)' % key
		hi, base, lo, _ = MATERIALS[mat]
		if kind == 'v':
			body = ('<linearGradient id="%s" x1="0" y1="0" x2="0.25" y2="1">'
				'<stop offset="0" stop-color="%s"/><stop offset="0.45" stop-color="%s"/><stop offset="1" stop-color="%s"/>'
				'</linearGradient>') % (key, hi, base, lo)
		elif kind == 'h':
			body = ('<linearGradient id="%s" x1="0" y1="0" x2="1" y2="0">'
				'<stop offset="0" stop-color="%s"/><stop offset="0.22" stop-color="%s"/><stop offset="0.38" stop-color="%s"/>'
				'<stop offset="0.75" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>') % (
				key, lo, base, hi, base, lo)
		elif kind == 'cyl':
			body = ('<linearGradient id="%s" x1="0" y1="0" x2="0" y2="1">'
				'<stop offset="0" stop-color="%s"/><stop offset="0.3" stop-color="%s"/><stop offset="0.55" stop-color="%s"/>'
				'<stop offset="1" stop-color="%s"/></linearGradient>') % (key, base, hi, base, lo)
		elif kind == 'r':
			body = ('<radialGradient id="%s" cx="0.36" cy="0.32" r="0.75">'
				'<stop offset="0" stop-color="%s"/><stop offset="0.45" stop-color="%s"/><stop offset="1" stop-color="%s"/>'
				'</radialGradient>') % (key, hi, base, lo)
		else:
			return base
		self.defs[key] = body
		return 'url(#%s)' % key

	def outline(self, mat):
		return MATERIALS[mat][3]

	# --- formas ---
	def _shape(self, tag, attrs, mat, kind, stroke, sw, opacity, pts, extra=''):
		fill = self.grad(mat, kind) if mat in MATERIALS else mat
		st = stroke if stroke is not None else (self.outline(mat) if mat in MATERIALS else '#0a0c0d')
		a = ' '.join('%s="%s"' % (k, v) for k, v in attrs.items())
		op = '' if opacity == 1 else ' opacity="%s"' % fmt(opacity)
		sline = '' if st == 'none' else ' stroke="%s" stroke-width="%s" stroke-linejoin="round"' % (st, fmt(sw))
		self.items.append('<%s %s fill="%s"%s%s%s/>' % (tag, a, fill, sline, op, extra))
		self._bound(pts, sw / 2)

	def poly(self, pts, mat, r=0, kind='v', stroke=None, sw=2.2, opacity=1):
		self._shape('path', {'d': rounded_path(pts, r)}, mat, kind, stroke, sw, opacity, pts)

	def rect(self, x, y, w, h, mat, r=0, kind='v', stroke=None, sw=2.2, opacity=1):
		pts = [(x, y), (x + w, y), (x + w, y + h), (x, y + h)]
		self.poly(pts, mat, r, kind, stroke, sw, opacity)

	def ellipse(self, cx, cy, rx, ry, mat, kind='r', stroke=None, sw=2.2, opacity=1):
		self._shape('ellipse', {'cx': fmt(cx), 'cy': fmt(cy), 'rx': fmt(rx), 'ry': fmt(ry)}, mat, kind, stroke, sw,
			opacity, [(cx - rx, cy - ry), (cx + rx, cy + ry)])

	def circle(self, cx, cy, r, mat, kind='r', stroke=None, sw=2.2, opacity=1):
		self.ellipse(cx, cy, r, r, mat, kind, stroke, sw, opacity)

	def path(self, d, mat, pts, kind='v', stroke=None, sw=2.2, opacity=1):
		"""Path livre; ``pts`` informa a caixa envolvente."""
		self._shape('path', {'d': d}, mat, kind, stroke, sw, opacity, pts)

	# --- detalhes (sem contorno, não alteram muito a caixa) ---
	def line(self, pts, color='#000000', w=2, opacity=0.35, cap='round'):
		d = 'M' + ' L'.join('%s,%s' % (fmt(x), fmt(y)) for x, y in pts)
		self.items.append('<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="%s" '
			'stroke-linejoin="round" opacity="%s"/>' % (d, color, fmt(w), cap, fmt(opacity)))
		self._bound(pts, w / 2)

	def hl(self, pts, w=2, opacity=0.45):
		"""Reflexo especular (linha clara)."""
		self.line(pts, '#ffffff', w, opacity)

	def dark(self, pts, w=2, opacity=0.4):
		self.line(pts, '#000000', w, opacity)

	def fill(self, pts, color, opacity=1, r=0):
		self.items.append('<path d="%s" fill="%s" opacity="%s"/>' % (rounded_path(pts, r), color, fmt(opacity)))
		self._bound(pts)

	def dot(self, cx, cy, r, color, opacity=1):
		self.items.append('<circle cx="%s" cy="%s" r="%s" fill="%s" opacity="%s"/>' % (
			fmt(cx), fmt(cy), fmt(r), color, fmt(opacity)))
		self._bound([(cx - r, cy - r), (cx + r, cy + r)])

	def glow(self, cx, cy, r, color, opacity=0.7):
		key = 'glow-%s' % color.lstrip('#')
		if key not in self.defs:
			self.defs[key] = ('<radialGradient id="%s"><stop offset="0" stop-color="%s" stop-opacity="1"/>'
				'<stop offset="1" stop-color="%s" stop-opacity="0"/></radialGradient>') % (key, color, color)
		self.items.append('<circle cx="%s" cy="%s" r="%s" fill="url(#%s)" opacity="%s"/>' % (
			fmt(cx), fmt(cy), fmt(r), key, fmt(opacity)))
		self._bound([(cx - r * 0.7, cy - r * 0.7), (cx + r * 0.7, cy + r * 0.7)])

	def text(self, x, y, s, size, color='#1a1a1a', weight=800, anchor='middle', opacity=1, rotate=0, family='DejaVu Sans'):
		tr = ' transform="rotate(%s %s %s)"' % (fmt(rotate), fmt(x), fmt(y)) if rotate else ''
		self.items.append('<text x="%s" y="%s" font-family="%s" font-size="%s" font-weight="%s" fill="%s" '
			'text-anchor="%s" opacity="%s"%s>%s</text>' % (fmt(x), fmt(y), family, fmt(size), weight, color, anchor,
			fmt(opacity), tr, s))

	def raw(self, svg, pts=None):
		self.items.append(svg)
		if pts:
			self._bound(pts)

	def group(self, transform):
		"""Abre um grupo transformado; chame ``end()`` depois."""
		self.items.append('<g transform="%s">' % transform)

	def end(self):
		self.items.append('</g>')

	# --- saída ---
	def svg(self, box=224, rotate=0, dy=0, stretch=1.0):
		w = self.maxx - self.minx
		h = (self.maxy - self.miny) * stretch
		cx = (self.minx + self.maxx) / 2
		cy = (self.miny + self.maxy) / 2
		if rotate:
			a = math.radians(rotate)
			rw = abs(w * math.cos(a)) + abs(h * math.sin(a))
			rh = abs(w * math.sin(a)) + abs(h * math.cos(a))
		else:
			rw, rh = w, h
		s = min(box / rw, box / rh)
		tf = 'translate(%s %s) rotate(%s) scale(%s %s) translate(%s %s)' % (
			fmt(CANVAS / 2), fmt(CANVAS / 2 - 4 + dy), fmt(rotate), '%.4f' % s, '%.4f' % (s * stretch), fmt(-cx), fmt(-cy))
		sw = 1 / s * 2.2  # mantém o contorno com espessura visual constante
		body = '\n'.join(self.items)
		defs = ''.join(self.defs.values())
		return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d">'
			'<defs>%s<filter id="ds" x="-20%%" y="-20%%" width="140%%" height="150%%">'
			'<feDropShadow dx="0" dy="5" stdDeviation="4.5" flood-color="#000" flood-opacity="0.55"/></filter></defs>'
			'<g filter="url(#ds)"><g transform="%s" data-stroke-scale="%s">\n%s\n</g></g></svg>') % (
			CANVAS, CANVAS, CANVAS, CANVAS, defs, tf, '%.3f' % sw, body)
