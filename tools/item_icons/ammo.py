"""Munições e acessórios de arma."""
from lib import arc_points
import parts as P


def _round(ic, x, base, kind, s=1.0):
	"""Cartucho em pé com a base em y=base."""
	if kind == 'pistol':
		ic.rect(x - 7 * s, base - 30 * s, 14 * s, 30 * s, 'brass', r=2, kind='h')
		ic.poly([(x - 7 * s, base - 30 * s), (x - 6 * s, base - 40 * s), (x, base - 46 * s), (x + 6 * s, base - 40 * s),
			(x + 7 * s, base - 30 * s)], 'copper', r=[1, 4, 3, 4, 1], kind='h')
	elif kind == 'hollow':
		ic.rect(x - 7 * s, base - 28 * s, 14 * s, 28 * s, 'chrome', r=2, kind='h')
		ic.poly([(x - 7 * s, base - 28 * s), (x - 6 * s, base - 38 * s), (x + 6 * s, base - 38 * s),
			(x + 7 * s, base - 28 * s)], 'copper', r=[1, 3, 3, 1], kind='h')
		ic.ellipse(x, base - 38 * s, 3 * s, 1.5 * s, '#3a1c0b', stroke='none')
	elif kind == 'rifle':
		ic.poly([(x - 6 * s, base), (x - 6 * s, base - 40 * s), (x - 3.5 * s, base - 46 * s), (x - 3.5 * s, base - 52 * s),
			(x + 3.5 * s, base - 52 * s), (x + 3.5 * s, base - 46 * s), (x + 6 * s, base - 40 * s), (x + 6 * s, base)], 'brass',
			r=[1, 1, 1, 0, 0, 1, 1, 1], kind='h')
		ic.poly([(x - 3.5 * s, base - 52 * s), (x - 3 * s, base - 62 * s), (x, base - 70 * s), (x + 3 * s, base - 62 * s),
			(x + 3.5 * s, base - 52 * s)], 'copper', r=[0, 4, 2, 4, 0], kind='h')
	elif kind == 'shell':
		ic.rect(x - 9 * s, base - 46 * s, 18 * s, 40 * s, o_shell_color(ic), r=2, kind='h')
		for i in range(4):
			ic.dark([(x - 7 * s, base - 40 * s + i * 8 * s), (x + 7 * s, base - 40 * s + i * 8 * s)], w=0.8, opacity=0.2)
		ic.rect(x - 9.5 * s, base - 12 * s, 19 * s, 12 * s, 'brass', r=1.5, kind='h')
		ic.ellipse(x, base - 46 * s, 8 * s, 2.5 * s, '#000000', stroke='none', opacity=0.25)


def o_shell_color(ic):
	return getattr(ic, 'shell', 'red')


def ammo_box(ic, o):
	kind = o.get('round', 'pistol')
	mat = o.get('box', 'navy')
	n = o.get('n', 4)
	s = o.get('s', 1.0)
	ic.shell = o.get('shell', 'red')
	W, H = 150, 92
	x0, y0 = 20, 80
	# tampa aberta atrás
	ic.poly([(x0, y0), (x0 + W, y0), (x0 + W + 18, y0 - 40), (x0 + 18, y0 - 40)], mat, r=2, kind='v')
	ic.fill([(x0, y0), (x0 + W, y0), (x0 + W + 18, y0 - 40), (x0 + 18, y0 - 40)], '#000000', 0.25)
	# cartuchos saindo da caixa
	step = (W - 30) / max(1, n - 1)
	for i in range(n):
		_round(ic, x0 + 22 + step * i + 6, y0 + 8, kind, s)
	# frente da caixa
	ic.rect(x0, y0, W, H, mat, r=3, kind='v')
	ic.poly([(x0 + W, y0), (x0 + W + 18, y0 - 12), (x0 + W + 18, y0 + H - 14), (x0 + W, y0 + H)], mat, r=2)
	ic.fill([(x0 + W, y0), (x0 + W + 18, y0 - 12), (x0 + W + 18, y0 + H - 14), (x0 + W, y0 + H)], '#000000', 0.3)
	ic.rect(x0 + 10, y0 + 22, W - 20, 40, o.get('label_bg', '#f4efe2'), stroke='none', r=3)
	ic.rect(x0 + 10, y0 + 22, 14, 40, o.get('band', '#c4df9b'), stroke='none', r=2)
	ic.text(x0 + W / 2 + 7, y0 + 50, o.get('label', '9mm'), o.get('size', 22), '#151a18', 900)
	ic.hl([(x0 + 4, y0 + 4), (x0 + W - 4, y0 + 4)], w=2, opacity=0.35)
	ic.text(x0 + W / 2, y0 + H - 10, o.get('count', 'x 50'), 11, '#ffffff', 700, opacity=0.6)


def ammo_rocket(ic, o):
	ic.poly([(10, -10), (130, -10), (150, -16), (190, -10), (220, 0), (190, 10), (150, 16), (130, 10), (10, 10)],
		'olive', r=[2, 2, 4, 6, 4, 6, 4, 2, 2], kind='cyl')
	ic.poly([(150, -16), (190, -10), (220, 0), (190, 10), (150, 16)], 'darkgreen', r=4, kind='cyl')
	for y in (-1, 1):
		ic.poly([(10, 8 * y), (34, 8 * y), (20, 26 * y), (4, 26 * y)], 'darksteel', r=2)
	ic.rect(60, -11, 20, 22, 'yellow', stroke='none', kind='cyl', opacity=0.9)


def ammo_grenade40(ic, o):
	for i, x in enumerate((40, 100, 160)):
		ic.rect(x - 22, 70, 44, 50, 'brass', r=3, kind='h')
		ic.poly([(x - 22, 70), (x - 20, 40), (x - 8, 26), (x + 8, 26), (x + 20, 40), (x + 22, 70)], o.get('head', 'olive'),
			r=[1, 10, 6, 6, 10, 1], kind='h')
		ic.rect(x - 23, 66, 46, 6, 'gold', stroke='none', opacity=0.9)


def ammo_flare(ic, o):
	for x in (60, 130):
		ic.rect(x - 24, 30, 48, 120, 'orange', r=6, kind='h')
		ic.rect(x - 25, 130, 50, 20, 'brass', r=3, kind='h')
		ic.ellipse(x, 30, 22, 6, '#d6392d', stroke='#4a2304')
		ic.rect(x - 24, 70, 48, 14, 'white', stroke='none', opacity=0.85)


def ammo_firework(ic, o):
	cols = ('red', 'blue', 'yellow')
	for i, x in enumerate((50, 100, 150)):
		ic.line([(x, 150), (x, 210)], '#7a5c35', 4, 1)
		ic.rect(x - 16, 40, 32, 110, cols[i], r=4, kind='h')
		ic.poly([(x - 18, 40), (x, 10), (x + 18, 40)], 'gold', r=3, kind='h')
		ic.rect(x - 16, 90, 32, 10, 'white', stroke='none', opacity=0.7)


def ammo_cell(ic, o):
	glow = o.get('glow', '#46c6e0')
	ic.glow(100, 100, 90, glow, 0.35)
	ic.rect(50, 20, 100, 170, 'gunmetal', r=14, kind='h')
	ic.rect(70, 4, 60, 20, 'darksteel', r=4, kind='h')
	ic.rect(62, 40, 76, 120, glow, stroke='none', r=8, opacity=0.9)
	ic.rect(62, 40, 76, 120, '#ffffff', stroke='none', r=8, opacity=0.15)
	for y in (64, 92, 120):
		ic.rect(50, y, 100, 8, 'darksteel', stroke='#0b0d0e', sw=1.2)
	ic.hl([(58, 30), (58, 180)], w=3, opacity=0.3)


def ammo_rail(ic, o):
	ic.glow(100, 100, 90, '#46c6e0', 0.3)
	ic.poly([(30, 80), (150, 80), (190, 100), (150, 120), (30, 120)], 'darksteel', r=[4, 2, 6, 2, 4], kind='cyl')
	for x in (50, 80, 110):
		ic.rect(x, 74, 14, 52, 'copper', r=3, kind='h')
	ic.rect(30, 96, 150, 6, '#46c6e0', stroke='none', opacity=0.85)


def ammo_musket(ic, o):
	ic.poly([(30, 60), (170, 60), (180, 180), (20, 180)], 'leather', r=[12, 12, 20, 20])
	ic.poly([(40, 60), (100, 20), (160, 60)], 'leather', r=6)
	ic.line([(50, 70), (150, 70)], '#c9a46a', 4, 1)
	for x, y in ((70, 50), (100, 42), (130, 50), (86, 30), (116, 30)):
		ic.circle(x, y, 13, 'darksteel')


# --- acessórios ---
def suppressor(ic, o):
	ic.rect(10, -22, 200, 44, 'polymer', r=10, kind='cyl')
	ic.rect(0, -12, 16, 24, 'darksteel', r=3, kind='cyl')
	for x in (14, 202):
		ic.rect(x, -23, 8, 46, 'gunmetal', r=3, kind='h')
	ic.hl([(30, -12), (190, -12)], w=3, opacity=0.35)
	ic.ellipse(212, 0, 3, 8, '#0b0d0e', stroke='none')


def barrel_part(ic, o):
	ic.rect(0, -14, 210, 28, 'darksteel', r=6, kind='cyl')
	for x in range(30, 170, 20):
		ic.rect(x, -8, 14, 16, '#0d1012', stroke='none', r=6, opacity=0.6)
	ic.rect(186, -18, 24, 36, 'gunmetal', r=4, kind='cyl')
	ic.rect(0, -18, 20, 36, 'gunmetal', r=3, kind='cyl')


def clip_drum(ic, o):
	ic.rect(78, 0, 40, 40, 'polymer', r=3)
	P.mag_drum(ic, 100, 110, 80)
	ic.circle(100, 110, 30, 'gunmetal', kind='r')


def clip_ext(ic, o):
	if o.get('curved'):
		P.mag_curved(ic, 0, 0, 160, 44, 'polymer', curve=50)
	else:
		P.mag_straight(ic, 0, 0, 170, 40, 'polymer', slant=14)
	ic.rect(4, 6, 10, 10, '#c4df9b', stroke='none', r=2)


def weapon_light(ic, o):
	ic.glow(200, 0, 50, '#fff4c2', 0.5)
	ic.rect(20, -24, 150, 48, 'polymer', r=10, kind='cyl')
	ic.rect(160, -30, 34, 60, 'polymer', r=6, kind='cyl')
	ic.rect(192, -26, 6, 52, '#fff6cf', stroke='#4a4f53', sw=1.6, r=2)
	ic.rect(40, -36, 80, 14, 'polymer', r=3)
	ic.rect(0, -12, 24, 24, 'rubber', r=4)


def fore_grip(ic, o):
	ic.rect(0, 0, 120, 24, 'polymer', r=4)
	ic.rect(30, 20, 46, 130, 'polymer', r=12, kind='h')
	for y in range(50, 140, 16):
		ic.dark([(34, y), (72, y)], w=2, opacity=0.4)
	ic.rect(26, 144, 54, 12, 'polymer', r=4)


def muzzle_dev(ic, o):
	k = o.get('k')
	ic.rect(0, -14, 40, 28, 'darksteel', r=3, kind='cyl')
	for x in range(6, 40, 6):
		ic.dark([(x, -13), (x, 13)], w=1.2, opacity=0.4)
	if k == 'bell':
		ic.poly([(36, -20), (130, -28), (180, -50), (190, -50), (190, 50), (180, 50), (130, 28), (36, 20)], 'gunmetal',
			r=4, kind='cyl')
	elif k == 'fat':
		ic.rect(36, -40, 150, 80, 'gunmetal', r=12, kind='cyl')
		for x in (70, 110, 150):
			ic.rect(x, -24, 18, 48, '#0d1012', stroke='none', r=6)
	elif k == 'flat':
		ic.rect(36, -26, 150, 52, 'gunmetal', r=4, kind='cyl')
		for x in (60, 92, 124, 156):
			ic.rect(x, -30, 10, 60, '#0d1012', stroke='none', r=2)
	elif k == 'heavy':
		ic.rect(36, -46, 150, 92, 'gunmetal', r=6, kind='cyl')
		for x in (60, 110):
			ic.rect(x, -50, 28, 100, '#0d1012', stroke='none', r=4)
	elif k == 'precision':
		ic.rect(36, -24, 160, 48, 'gunmetal', r=10, kind='cyl')
		for x in range(54, 190, 16):
			ic.circle(x, -8, 4, '#0d1012', stroke='none')
	elif k == 'slanted':
		ic.poly([(36, -30), (170, -30), (196, 30), (36, 30)], 'gunmetal', r=4, kind='cyl')
		for x in (70, 110, 150):
			ic.poly([(x, -26), (x + 10, -26), (x + 22, 26), (x + 12, 26)], '#0d1012', stroke='none')
	elif k == 'split':
		ic.rect(36, -26, 70, 52, 'gunmetal', r=4, kind='cyl')
		ic.poly([(100, -26), (196, -22), (196, -6), (100, -6)], 'gunmetal', r=4, kind='cyl')
		ic.poly([(100, 6), (196, 6), (196, 22), (100, 26)], 'gunmetal', r=4, kind='cyl')
	elif k == 'squared':
		ic.rect(36, -36, 150, 72, 'gunmetal', r=2, kind='v')
		for x in (64, 100, 136):
			ic.rect(x, -24, 22, 22, '#0d1012', stroke='none', r=2)
			ic.rect(x, 2, 22, 22, '#0d1012', stroke='none', r=2)
	elif k == 'tactical':
		ic.rect(36, -24, 70, 48, 'gunmetal', r=6, kind='cyl')
		for y in (-22, -8, 6):
			ic.poly([(100, y), (196, y + 2), (196, y + 12), (100, y + 14)], 'gunmetal', r=3, kind='cyl')
	ic.hl([(44, -10), (100, -10)], w=2, opacity=0.25)


def scope_part(ic, o):
	k = o.get('k')
	if k in ('small', 'medium', 'large', 'advanced', 'nv'):
		L, r, bell = {'small': (130, 18, 26), 'medium': (160, 17, 28), 'large': (190, 17, 32),
			'advanced': (176, 18, 30), 'nv': (150, 22, 30)}[k]
		lens = '#7cff7c' if k == 'nv' else '#6fc6ff'
		P.scope(ic, 0, 60, L, r, bell=bell, mat='olive' if k == 'nv' else 'polymer', lens=lens)
		ic.rect(L * 0.18, 60, L * 0.64, 10, 'polymer', r=2)
		ic.ellipse(L, 60 - 8 - r, 7, bell - 2, lens, kind='h', stroke='#0a333d')
		if k == 'nv':
			ic.glow(L, 60 - 8 - r, 40, '#7cff7c', 0.45)
			ic.rect(L * 0.3, 60 - 8 - r * 2 - 18, 50, 18, 'olive', r=4)
		ic.hl([(L + 2, 60 - 8 - r - bell + 8), (L + 2, 60 - 8 - r - 4)], w=2, opacity=0.6)
		if k == 'advanced':
			ic.rect(L * 0.3, 60 - 8 - r * 2 - 22, 60, 20, 'polymer', r=4)
			ic.rect(L * 0.3 + 54, 60 - 8 - r * 2 - 18, 6, 12, '#ff6b5e', stroke='none', r=1)
	elif k == 'holo':
		ic.rect(0, 40, 170, 18, 'polymer', r=3)
		ic.rect(150, 10, 26, 40, 'polymer', r=4)
		ic.poly([(6, 42), (6, -20), (20, -44), (150, -44), (150, -20), (138, -20), (138, -32), (24, -32), (18, -20),
			(18, 42)], 'polymer', r=4)
		ic.rect(18, -32, 120, 74, '#5fc9ff', stroke='none', r=4, opacity=0.25)
		ic.rect(130, -32, 20, 74, 'polymer', r=3)
		ic.raw('<circle cx="74" cy="4" r="16" fill="none" stroke="#ff4a3a" stroke-width="3"/>'
			'<circle cx="74" cy="4" r="3" fill="#ff4a3a"/>')
		ic.hl([(24, -26), (90, -26)], w=2, opacity=0.5)
	elif k == 'thermal':
		ic.rect(0, 0, 190, 70, 'polymer', r=10)
		ic.rect(186, 6, 18, 58, 'polymer', r=4)
		ic.rect(20, 10, 70, 50, 'screen', r=4, sw=1.4)
		ic.raw('<defs><linearGradient id="th" x1="0" x2="1"><stop offset="0" stop-color="#2a1a6e"/>'
			'<stop offset="0.5" stop-color="#e2402f"/><stop offset="1" stop-color="#ffe066"/></linearGradient></defs>'
			'<rect x="26" y="16" width="58" height="38" rx="3" fill="url(#th)"/>')
		ic.rect(40, 66, 30, 14, 'polymer', r=3)
		ic.rect(120, 66, 30, 14, 'polymer', r=3)
	ic.hl([(10, 0), (10, 0)], w=0.1, opacity=0)
