"""Peças de armas de fogo, desenhadas de perfil com o cano para a direita.

Convenção: eixo do cano em y=0, comprimento total ~220 unidades (o enquadramento final escala o desenho).
"""
from lib import arc_points


def barrel(ic, x0, x1, r=3.2, mat='darksteel', y=0):
	ic.rect(x0, y - r, x1 - x0, r * 2, mat, r=1, kind='cyl')
	ic.hl([(x0 + 2, y - r * 0.35), (x1 - 2, y - r * 0.35)], w=1, opacity=0.35)


def muzzle(ic, x, kind='plain', r=3.2, mat='darksteel', y=0):
	if kind == 'plain':
		ic.rect(x - 2, y - r - 0.8, 6, r * 2 + 1.6, mat, r=1, kind='cyl')
	elif kind == 'brake':
		ic.rect(x - 2, y - r - 2.5, 16, r * 2 + 5, mat, r=1.5, kind='cyl')
		for i in range(3):
			ic.rect(x + 1.5 + i * 4.3, y - r - 1.2, 2.2, r * 2 + 2.4, '#0d1012', stroke='none')
	elif kind == 'bigbrake':
		ic.rect(x - 2, y - r - 5, 22, r * 2 + 10, mat, r=2, kind='cyl')
		ic.rect(x + 3, y - r - 3.5, 4, r * 2 + 7, '#0d1012', stroke='none', r=1)
		ic.rect(x + 11, y - r - 3.5, 4, r * 2 + 7, '#0d1012', stroke='none', r=1)
	elif kind == 'flash':
		ic.rect(x - 2, y - r - 1.2, 12, r * 2 + 2.4, mat, r=1, kind='cyl')
		for i in range(3):
			ic.dark([(x + 2 + i * 3, y - r), (x + 2 + i * 3, y + r)], w=1.2, opacity=0.6)
	elif kind == 'comp':
		ic.rect(x - 2, y - r - 2, 12, r * 2 + 4, mat, r=1.5, kind='cyl')
		ic.rect(x + 2, y - r - 2.5, 5, 3, '#0d1012', stroke='none')
	elif kind == 'suppressor':
		ic.rect(x - 2, y - r - 3.5, 40, r * 2 + 7, 'polymer', r=3, kind='cyl')
		ic.hl([(x + 3, y - r - 1.5), (x + 33, y - r - 1.5)], w=1.2, opacity=0.25)


def sight_post(ic, x, ytop, h=6, mat='polymer'):
	ic.poly([(x - 2, ytop), (x + 2, ytop), (x + 3, ytop + h), (x - 3, ytop + h)], mat, r=0.5)


def rail(ic, x0, x1, y, mat='polymer'):
	"""Trilho picatinny sobre a caixa (y = base do trilho)."""
	ic.rect(x0, y - 4, x1 - x0, 4, mat, r=0.5)
	x = x0 + 3
	while x < x1 - 3:
		ic.rect(x, y - 6, 3.2, 2.4, mat, stroke='none')
		x += 6


def reddot(ic, x, y, mat='polymer', glass='#7fd0ff'):
	"""Mira de ponto vermelho tubular; y = base."""
	ic.rect(x, y - 4, 22, 4, mat, r=1)
	ic.rect(x + 2, y - 15, 18, 12, mat, r=4, kind='cyl')
	ic.rect(x + 18, y - 13.5, 3, 9, glass, stroke='none', r=1, opacity=0.9)
	ic.dot(x + 19.5, y - 9, 1.2, '#ff3b30')


def holo(ic, x, y, mat='polymer'):
	ic.rect(x, y - 4, 24, 4, mat, r=1)
	ic.poly([(x + 2, y - 4), (x + 2, y - 15), (x + 6, y - 17), (x + 24, y - 17), (x + 24, y - 4)], mat, r=1.5)
	ic.rect(x + 7, y - 14, 15, 8, '#5fc9ff', stroke='none', r=1, opacity=0.55)
	ic.hl([(x + 9, y - 12), (x + 15, y - 12)], w=1, opacity=0.6)


def scope(ic, x, y, length=58, r=6, mat='polymer', bell=9, lens='#6fc6ff'):
	"""Luneta; y = base dos anéis."""
	cy = y - 8 - r
	ic.rect(x + length * 0.22, y - 8, 6, 8, mat, r=1)
	ic.rect(x + length * 0.68, y - 8, 6, 8, mat, r=1)
	ic.poly([(x, cy - bell * 0.85), (x + 12, cy - bell * 0.85), (x + 18, cy - r), (x + length - 18, cy - r),
		(x + length - 12, cy - bell), (x + length, cy - bell), (x + length, cy + bell), (x + length - 12, cy + bell),
		(x + length - 18, cy + r), (x + 18, cy + r), (x + 12, cy + bell * 0.85), (x, cy + bell * 0.85)],
		mat, r=1.5, kind='cyl')
	ic.rect(x + length * 0.45, cy - r - 5, 7, 5, mat, r=1)
	ic.rect(x + length - 2.5, cy - bell + 1.5, 3, bell * 2 - 3, lens, stroke='none', r=1)
	ic.hl([(x + 20, cy - r + 1.5), (x + length - 20, cy - r + 1.5)], w=1.4, opacity=0.4)


def carry_handle(ic, x, y, w=34, mat='polymer'):
	ic.poly([(x, y), (x + 3, y - 12), (x + w, y - 12), (x + w + 2, y)], mat, r=1.5)
	ic.rect(x + 7, y - 8, w - 12, 6, '#0d1012', stroke='none', r=2)


def trigger_guard(ic, x, y, w=16, h=11, mat='polymer'):
	pts = [(x, y)] + arc_points(x + w / 2, y + h * 0.35, w / 2 + 1, h * 0.75, 180, 0, 10)[1:-1] + [(x + w, y)]
	ic.line(pts, '#0b0d0e', 4.6, 1)
	ic.line(pts, '#3a3f43' if mat in ('polymer', 'gunmetal', 'blued') else '#7a6a50', 2.4, 1)
	ic.line([(x + w * 0.45, y), (x + w * 0.38, y + h * 0.6)], '#0b0d0e', 2.6, 1)


def pistol_grip(ic, x, y, mat='polymer', length=30, slant=12, w=15, stipple=True):
	pts = [(x, y), (x + w, y), (x + w - slant * 0.35, y + length * 0.55), (x + w - slant, y + length),
		(x - slant, y + length), (x - slant * 0.65, y + length * 0.45)]
	ic.poly(pts, mat, r=[1, 2, 3, 4, 4, 3])
	if stipple:
		for i in range(4):
			t = 0.25 + i * 0.17
			ic.dark([(x - slant * t + 3, y + length * t), (x + w - slant * t - 3, y + length * t)], w=1, opacity=0.35)


def mag_straight(ic, x, y, length=34, w=11, mat='polymer', slant=4):
	ic.poly([(x, y), (x + w, y), (x + w + slant, y + length), (x + slant, y + length)], mat, r=1.2)
	ic.rect(x + slant - 1, y + length - 3, w + 2, 4, mat, r=1)
	ic.hl([(x + 2, y + 3), (x + slant + 2, y + length - 5)], w=1, opacity=0.3)


def mag_curved(ic, x, y, length=38, w=11, mat='polymer', curve=14):
	pts = [(x, y), (x + w, y)]
	pts += [(x + w + curve * (t / 6) ** 1.6 * 0.9, y + length * t / 6) for t in range(1, 7)]
	pts += [(x + curve * (t / 6) ** 1.6 * 0.9 - 2, y + length * t / 6) for t in range(6, 0, -1)]
	ic.poly(pts, mat, r=1.5)
	for t in (2, 3, 4):
		ic.dark([(x + curve * (t / 6) ** 1.6 * 0.9, y + length * t / 6), (x + w + curve * (t / 6) ** 1.6 * 0.9 - 2,
			y + length * t / 6 - 1)], w=1, opacity=0.3)


def mag_drum(ic, cx, cy, r=15, mat='polymer'):
	ic.circle(cx, cy, r, mat)
	ic.circle(cx, cy, r * 0.55, mat, kind='r')
	ic.dot(cx, cy, r * 0.18, '#0d1012')
	ic.hl(arc_points(cx, cy, r - 2.5, r - 2.5, 200, 280, 8), w=1.5, opacity=0.4)


def mag_box(ic, x, y, w=22, h=22, mat='olive'):
	ic.rect(x, y, w, h, mat, r=2)
	ic.dark([(x + 3, y + h * 0.4), (x + w - 3, y + h * 0.4)], w=1, opacity=0.4)
	ic.rect(x + w * 0.3, y + h * 0.55, w * 0.4, h * 0.2, '#000000', stroke='none', opacity=0.25)


def bipod(ic, x, y, length=26, mat='polymer'):
	ic.line([(x, y), (x - 8, y + length)], '#0b0d0e', 4.5, 1)
	ic.line([(x, y), (x - 8, y + length)], '#4a4f53', 2.4, 1)
	ic.line([(x + 4, y), (x + 12, y + length)], '#0b0d0e', 4.5, 1)
	ic.line([(x + 4, y), (x + 12, y + length)], '#4a4f53', 2.4, 1)
	ic.rect(x - 2, y - 3, 9, 5, mat, r=1)


def vents(ic, x0, x1, y, h=3, step=7, color='#0b0d0e', opacity=0.85):
	x = x0
	while x + 4 <= x1:
		ic.rect(x, y, 4, h, color, stroke='none', r=1, opacity=opacity)
		x += step


def bolt(ic, x, y, mat='steel'):
	ic.rect(x, y - 1.5, 8, 3, mat, r=1, sw=1.6)
	ic.circle(x + 9, y, 2.6, mat, sw=1.6)


def ejection_port(ic, x, y, w=14, h=4):
	ic.rect(x, y, w, h, '#0d1012', stroke='none', r=1)
	ic.hl([(x + 1, y + h + 1), (x + w - 1, y + h + 1)], w=0.8, opacity=0.25)


def accent_band(ic, x, y, w, h, color='#c4df9b'):
	ic.rect(x, y, w, h, color, stroke='none', r=0.8, opacity=0.95)
