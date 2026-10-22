"""Armas de fogo do GTA (perfil, cano para a direita). Cada função recebe um Icon e opções de variante."""
from lib import arc_points
import parts as P

ACCENT = '#c4df9b'


def _stock(ic, kind, x1, mat, y=0):
	"""Coronha que termina em x1 (encaixe na caixa)."""
	if kind == 'ar':
		ic.rect(x1 - 26, y - 5, 28, 9, 'polymer', r=2, kind='cyl')
		ic.poly([(x1 - 50, y - 9), (x1 - 20, y - 9), (x1 - 14, y - 6), (x1 - 14, y + 7), (x1 - 26, y + 9),
			(x1 - 44, y + 21), (x1 - 50, y + 22)], mat, r=[2, 2, 2, 2, 3, 3, 2])
		ic.rect(x1 - 54, y - 11, 6, 35, 'rubber', r=2)
		ic.rect(x1 - 42, y - 3, 14, 4, '#0b0d0e', stroke='none', r=2, opacity=0.7)
	elif kind == 'rifle':
		ic.poly([(x1 - 64, y - 8), (x1, y - 8), (x1, y + 8), (x1 - 20, y + 12), (x1 - 62, y + 22), (x1 - 66, y + 20)],
			mat, r=[3, 1, 2, 6, 3, 3])
		ic.rect(x1 - 70, y - 9, 6, 32, 'rubber', r=2)
		ic.hl([(x1 - 60, y - 5.5), (x1 - 4, y - 5.5)], w=1.4, opacity=0.35)
	elif kind == 'ak':
		ic.poly([(x1 - 62, y - 6), (x1 - 2, y - 4), (x1, y + 6), (x1 - 8, y + 9), (x1 - 60, y + 24), (x1 - 64, y + 22)],
			mat, r=[3, 1, 2, 5, 3, 3])
		ic.rect(x1 - 67, y - 7, 5, 31, 'darksteel', r=1.5, kind='h')
		ic.hl([(x1 - 58, y - 3.5), (x1 - 6, y - 2)], w=1.4, opacity=0.35)
	elif kind == 'skeleton':
		pts = [(x1, y - 4), (x1 - 46, y - 6), (x1 - 46, y + 18), (x1, y + 6)]
		ic.line(pts + [pts[0]], '#0b0d0e', 6.5, 1)
		ic.line(pts + [pts[0]], '#3c4144' if mat == 'polymer' else '#6a7076', 3.6, 1)
		ic.rect(x1 - 50, y - 8, 6, 28, 'rubber', r=2)
	elif kind == 'wire':
		pts = [(x1, y - 2), (x1 - 40, y - 2), (x1 - 40, y + 14), (x1 - 4, y + 6)]
		ic.line(pts, '#0b0d0e', 5, 1)
		ic.line(pts, '#7c848a', 2.6, 1)
		ic.rect(x1 - 44, y - 4, 6, 21, 'darksteel', r=1.5)
	elif kind == 'folded':
		ic.rect(x1 - 8, y - 4, 10, 8, mat, r=2)
	elif kind == 'thumbhole':
		ic.poly([(x1 - 72, y - 8), (x1, y - 8), (x1, y + 10), (x1 - 10, y + 14), (x1 - 24, y + 30), (x1 - 34, y + 30),
			(x1 - 30, y + 16), (x1 - 44, y + 14), (x1 - 70, y + 24), (x1 - 74, y + 20)], mat, r=[3, 1, 2, 4, 4, 3, 4, 4, 3, 3])
		ic.ellipse(x1 - 30, y + 6, 9, 5, '#0b0d0e', stroke='none', opacity=0.9)
		ic.rect(x1 - 78, y - 9, 6, 34, 'rubber', r=2)
	elif kind == 'thompson':
		ic.poly([(x1 - 58, y - 4), (x1, y - 6), (x1, y + 8), (x1 - 10, y + 12), (x1 - 54, y + 24), (x1 - 60, y + 22)],
			mat, r=[4, 1, 2, 6, 4, 4])
		ic.rect(x1 - 63, y - 5, 5, 28, 'blued', r=1.5, kind='h')


def _grip(ic, x, y, mat):
	P.pistol_grip(ic, x, y, mat, length=28, slant=11, w=14)


def rifle(ic, o):
	"""Fuzil/carabina genérico configurável."""
	mat = o.get('mat', 'polymer')
	furn = o.get('furniture', mat)
	rx0, rx1 = o.get('receiver', (52, 118))
	hx1 = o.get('handguard_end', 176)
	bx1 = o.get('barrel_end', 206)
	top = o.get('top', -12)
	if o.get('stock', 'ar') != 'none':
		_stock(ic, o.get('stock', 'ar'), rx0 + 2, furn)
	# cano
	P.barrel(ic, hx1 - 4, bx1, r=o.get('barrel_r', 3.2))
	if o.get('gas_tube'):
		ic.rect(hx1 - 4, -9, o['gas_tube'], 3.5, 'darksteel', r=1, kind='cyl', sw=1.6)
		P.sight_post(ic, hx1 - 4 + o['gas_tube'] - 4, -18, 9, 'darksteel')
	P.muzzle(ic, bx1, o.get('muzzle', 'flash'))
	# guarda-mão
	hg = o.get('handguard', 'rail')
	hmat = o.get('handguard_mat', furn)
	if hg == 'rail':
		ic.rect(rx1 - 2, top + 1, hx1 - rx1 + 2, 18, hmat, r=2)
		P.vents(ic, rx1 + 6, hx1 - 6, top + 9, h=3.5, step=8, opacity=0.6)
	elif hg == 'round':
		ic.rect(rx1 - 2, top + 3, hx1 - rx1 + 2, 15, hmat, r=7, kind='cyl')
		P.vents(ic, rx1 + 6, hx1 - 8, top + 9, h=3, step=7, opacity=0.6)
	elif hg == 'wood':
		ic.poly([(rx1 - 2, top + 3), (hx1, top + 5), (hx1, top + 16), (rx1 - 2, top + 20)], hmat, r=3)
		ic.hl([(rx1 + 2, top + 5.5), (hx1 - 4, top + 7)], w=1.3, opacity=0.35)
	elif hg == 'slim':
		ic.rect(rx1 - 2, top + 4, hx1 - rx1 + 2, 13, hmat, r=3, kind='cyl')
	# caixa da culatra
	ic.poly([(rx0, top + 2), (rx0 + 4, top), (rx1, top), (rx1, top + 19), (rx0 + 14, top + 19), (rx0, top + 16)],
		mat, r=[2, 2, 1, 1, 2, 3])
	ic.hl([(rx0 + 6, top + 2), (rx1 - 2, top + 2)], w=1.4, opacity=0.35)
	P.ejection_port(ic, rx0 + 26, top + 7, 16, 4)
	if o.get('bolt', True):
		P.bolt(ic, rx0 + 40, top + 13)
	# punho, guarda-mato e carregador
	gx = o.get('grip_x', rx0 + 12)
	_grip(ic, gx, top + 18, o.get('grip_mat', furn))
	P.trigger_guard(ic, gx + 14, top + 19, 17, 11)
	mx = o.get('mag_x', gx + 33)
	mag = o.get('mag', 'straight')
	if mag == 'straight':
		P.mag_straight(ic, mx, top + 19, o.get('mag_len', 34), 12, o.get('mag_mat', 'polymer'), slant=5)
	elif mag == 'curved':
		P.mag_curved(ic, mx, top + 19, o.get('mag_len', 38), 12, o.get('mag_mat', 'polymer'), curve=14)
	elif mag == 'drum':
		ic.rect(mx, top + 19, 12, 6, 'polymer', r=1)
		P.mag_drum(ic, mx + 6, top + 36, 15, o.get('mag_mat', 'polymer'))
	elif mag == 'box':
		P.mag_box(ic, mx - 4, top + 19, 26, 26, o.get('mag_mat', 'olive'))
	# topo
	if o.get('rail', True):
		P.rail(ic, rx0 + 4, (hx1 - 6) if hg == 'rail' else rx1, top)
	optic = o.get('optic')
	ox = o.get('optic_x', rx0 + 14)
	if optic == 'reddot':
		P.reddot(ic, ox, top - 2)
	elif optic == 'holo':
		P.holo(ic, ox, top - 2)
	elif optic == 'scope':
		P.scope(ic, ox - 8, top - 2, o.get('scope_len', 60), 6, bell=9)
	elif optic == 'bigscope':
		P.scope(ic, ox - 8, top - 2, 74, 7, bell=11)
	elif optic == 'carry':
		P.carry_handle(ic, rx0 + 10, top, 40)
	elif optic == 'irons':
		P.sight_post(ic, rx0 + 10, top - 8, 8)
	if o.get('front_post', hg == 'rail' and optic in (None, 'irons')):
		P.sight_post(ic, hx1 - 10, top - 8, 8)
	if o.get('bipod'):
		P.bipod(ic, hx1 - 14, top + 18, 24)
	if o.get('mk2'):
		P.accent_band(ic, rx0 + 6, top + 14, 18, 3, ACCENT)
		P.accent_band(ic, hx1 - 16, top + 3, 10, 3, ACCENT)


def bullpup(ic, o):
	"""Bullpup: carregador atrás do punho, coronha integrada à caixa."""
	mat = o.get('mat', 'polymer')
	x0, x1 = 6, o.get('body_end', 150)
	bx1 = o.get('barrel_end', 200)
	P.barrel(ic, x1 - 6, bx1, 3.2)
	P.muzzle(ic, bx1, o.get('muzzle', 'flash'))
	body = [(x0, -8), (x0 + 10, -12), (x1 - 4, -12), (x1, -6), (x1, 6), (x1 - 30, 10), (x1 - 34, 10),
		(x0 + 60, 12), (x0 + 14, 14), (x0 + 2, 22), (x0 - 4, 22)]
	ic.poly(body, mat, r=[3, 3, 3, 3, 3, 3, 2, 3, 4, 3, 2])
	ic.rect(x0 - 8, -10, 7, 34, 'rubber', r=2)
	ic.hl([(x0 + 12, -9.5), (x1 - 6, -9.5)], w=1.4, opacity=0.35)
	P.ejection_port(ic, x0 + 30, -6, 16, 4)
	# carregador atrás do punho
	mx = o.get('mag_x', x0 + 34)
	if o.get('mag', 'straight') == 'curved':
		P.mag_curved(ic, mx, 12, 34, 12, o.get('mag_mat', 'polymer'), curve=10)
	elif o.get('mag') != 'none':
		P.mag_straight(ic, mx, 12, 30, 12, o.get('mag_mat', 'polymer'), slant=4)
	gx = x1 - 54
	P.pistol_grip(ic, gx, 10, o.get('grip_mat', mat), length=26, slant=10, w=13)
	P.trigger_guard(ic, gx + 12, 10, 18, 11)
	P.rail(ic, x0 + 30, x1 - 8, -12)
	if o.get('optic') == 'reddot':
		P.reddot(ic, x0 + 50, -14)
	elif o.get('optic') == 'scope':
		P.scope(ic, x0 + 30, -14, 62, 6, bell=9)
	elif o.get('optic') == 'carry':
		P.carry_handle(ic, x0 + 36, -12, 52)
	else:
		P.sight_post(ic, x1 - 16, -20, 8)
		P.sight_post(ic, x0 + 36, -20, 8)
	if o.get('mk2'):
		P.accent_band(ic, x0 + 14, 2, 20, 3, ACCENT)


def pistol(ic, o):
	"""Pistola semiautomática: ferrolho em cima, armação e punho."""
	slide = o.get('slide', 'gunmetal')
	frame = o.get('frame', 'polymer')
	grip = o.get('grip', frame)
	L = o.get('length', 150)
	sh = o.get('slide_h', 24)
	x0 = 20
	# ferrolho
	if o.get('barrel_out'):
		P.barrel(ic, x0 + L - 6, x0 + L + o['barrel_out'], 4)
	ic.poly([(x0, 0), (x0 + 4, -sh), (x0 + L, -sh), (x0 + L, -2), (x0 + L - 6, 0)], slide, r=[2, 3, 3, 2, 1])
	ic.hl([(x0 + 8, -sh + 3), (x0 + L - 4, -sh + 3)], w=1.6, opacity=0.45)
	ss = o.get('serrations', 'rear')
	if ss:
		for i in range(6):
			xx = x0 + 10 + i * 4.4
			ic.dark([(xx, -sh + 6), (xx + 2, -4)], w=1.5, opacity=0.5)
	P.ejection_port(ic, x0 + L * 0.42, -sh + 6, L * 0.22, 6)
	if o.get('slide_cut'):
		ic.rect(x0 + L * 0.68, -sh + 5, L * 0.22, 7, '#0d1012', stroke='none', r=2, opacity=0.9)
		P.barrel(ic, x0 + L * 0.68, x0 + L * 0.9, 2.6, 'steel', y=-sh + 8.5)
	# miras
	ic.rect(x0 + 8, -sh - 5, 10, 5, 'polymer', r=1, sw=1.6)
	ic.rect(x0 + L - 10, -sh - 4, 5, 4, 'polymer', r=1, sw=1.6)
	if o.get('optic') == 'reddot':
		ic.poly([(x0 + 28, -sh), (x0 + 30, -sh - 13), (x0 + 50, -sh - 13), (x0 + 54, -sh)], 'polymer', r=2)
		ic.rect(x0 + 31, -sh - 11, 18, 8, '#6fc6ff', stroke='none', r=1.5, opacity=0.6)
	# armação
	fy = 0
	ic.poly([(x0 + 2, fy - 1), (x0 + L - 18, fy - 1), (x0 + L - 18, fy + 10), (x0 + 52, fy + 12), (x0 + 30, fy + 12)],
		frame, r=2)
	if o.get('rail', True):
		P.vents(ic, x0 + L - 46, x0 + L - 22, fy + 5, h=3, step=6, opacity=0.6)
	if o.get('comp'):
		ic.rect(x0 + L, -sh + 2, 18, sh - 2, slide, r=3)
		ic.rect(x0 + L + 5, -sh + 4, 4, 6, '#0d1012', stroke='none', r=1)
		ic.rect(x0 + L + 11, -sh + 4, 4, 6, '#0d1012', stroke='none', r=1)
	# punho
	gl = o.get('grip_len', 66)
	gw = o.get('grip_w', 34)
	gs = o.get('grip_slant', 22)
	gpts = [(x0 + 4, fy + 4), (x0 + 4 + gw, fy + 6), (x0 + 4 + gw - gs * 0.4, fy + gl * 0.6), (x0 + gw - gs, fy + gl),
		(x0 - gs + 2, fy + gl), (x0 - gs * 0.5, fy + gl * 0.45), (x0 - 4, fy + 6)]
	ic.poly(gpts, grip, r=[3, 3, 6, 4, 4, 8, 3])
	if grip in ('wood', 'darkwood', 'tan', 'chrome', 'gold', 'white', 'cream'):
		ic.poly([(x0 + 4, fy + 12), (x0 + gw - 2, fy + 13), (x0 + gw - gs * 0.4 - 2, fy + gl * 0.6),
			(x0 + gw - gs - 2, fy + gl - 8), (x0 - gs + 8, fy + gl - 8), (x0 - gs * 0.45 + 4, fy + gl * 0.45)],
			o.get('panel', grip), r=4, sw=1.4)
		ic.dot(x0 + gw * 0.42 - gs * 0.35, fy + gl * 0.45, 2.2, '#c9b07a')
	else:
		for i in range(5):
			t = 0.25 + i * 0.13
			ic.dark([(x0 - gs * t + 2, fy + gl * t), (x0 + gw - gs * t - 4, fy + gl * t + 1)], w=1.2, opacity=0.4)
	# base do carregador
	mag_out = o.get('mag_out', 0)
	if mag_out:
		ic.poly([(x0 - gs + 6, fy + gl - 2), (x0 + gw - gs - 4, fy + gl - 2), (x0 + gw - gs - 8, fy + gl + mag_out),
			(x0 - gs + 4, fy + gl + mag_out)], o.get('mag_mat', 'polymer'), r=1.5)
	ic.rect(x0 - gs + 1, fy + gl + mag_out - 3, gw + 3, 5, o.get('mag_mat', 'polymer'), r=1.5)
	# guarda-mato e gatilho
	tg = [(x0 + gw + 2, fy + 10)] + arc_points(x0 + gw + 13, fy + 13, 14, 12, 160, 15, 8)[1:] + [(x0 + gw + 30, fy + 10)]
	ic.line(tg, '#0b0d0e', 5, 1)
	ic.line(tg, '#3a3f43' if frame in ('polymer', 'gunmetal', 'blued') else MATERIALS_hint(frame), 2.6, 1)
	ic.line([(x0 + gw + 12, fy + 10), (x0 + gw + 9, fy + 20)], '#0b0d0e', 3, 1)
	# cão
	if o.get('hammer'):
		ic.poly([(x0 - 2, -sh + 6), (x0 - 9, -sh + 2), (x0 - 8, -sh + 9), (x0 + 1, -sh + 13)], 'darksteel', r=1.5, sw=1.6)
	if o.get('mk2'):
		P.accent_band(ic, x0 + 10, -6, 26, 3, ACCENT)
	if o.get('two_tone'):
		ic.fill([(x0 + 4, -sh + 1), (x0 + L - 1, -sh + 1), (x0 + L - 1, -sh + 4), (x0 + 4, -sh + 4)], '#ffffff', 0.15)


def MATERIALS_hint(mat):
	from lib import MATERIALS
	return MATERIALS.get(mat, MATERIALS['polymer'])[1]


def revolver(ic, o):
	frame = o.get('frame', 'steel')
	grip = o.get('grip', 'wood')
	bl = o.get('barrel_len', 80)
	x0 = 40
	# cano (com costela)
	ic.rect(x0 + 36, -24, bl, 14, frame, r=2, kind='cyl')
	if o.get('rib', True):
		ic.rect(x0 + 36, -27, bl, 4, frame, r=1)
		ic.rect(x0 + 34 + bl - 6, -32, 5, 6, frame, r=1, sw=1.6)
	ic.rect(x0 + 36, -10, bl * 0.75, 7, frame, r=2, kind='cyl')
	if o.get('comp'):
		ic.rect(x0 + 36 + bl - 2, -27, 14, 18, frame, r=2)
		ic.rect(x0 + 36 + bl + 3, -24, 4, 6, '#0d1012', stroke='none', r=1)
	# armação
	ic.poly([(x0 - 6, -26), (x0 + 38, -28), (x0 + 38, 2), (x0 + 12, 6), (x0 - 2, 8), (x0 - 10, -10)], frame,
		r=[4, 2, 2, 3, 3, 4])
	# tambor
	ic.rect(x0 + 2, -24, 34, 26, frame, r=5, kind='cyl')
	for i in range(3):
		ic.rect(x0 + 6 + i * 10, -20, 6, 18, '#000000', stroke='none', r=3, opacity=0.25)
	ic.hl([(x0 + 4, -21), (x0 + 34, -21)], w=1.4, opacity=0.5)
	# cão
	ic.poly([(x0 - 4, -22), (x0 - 16, -32), (x0 - 18, -26), (x0 - 8, -14)], 'darksteel', r=2, sw=1.8)
	# punho
	gpts = [(x0 - 10, -10), (x0 + 6, 2), (x0 + 2, 26), (x0 - 6, 50), (x0 - 30, 50), (x0 - 30, 30), (x0 - 18, -2)]
	ic.poly(gpts, grip, r=[4, 4, 6, 6, 6, 8, 4])
	ic.poly([(x0 - 12, 0), (x0 - 1, 6), (x0 - 4, 26), (x0 - 10, 44), (x0 - 25, 44), (x0 - 24, 30), (x0 - 16, 4)],
		o.get('panel', grip), r=4, sw=1.2)
	ic.dot(x0 - 12, 20, 2, '#d9c08a')
	# guarda-mato
	tg = [(x0 + 4, 4)] + arc_points(x0 + 14, 6, 11, 11, 160, 20, 8)[1:] + [(x0 + 26, 2)]
	ic.line(tg, '#0b0d0e', 5, 1)
	ic.line(tg, MATERIALS_hint(frame), 2.6, 1)
	ic.line([(x0 + 13, 4), (x0 + 10, 12)], '#0b0d0e', 3, 1)
	if o.get('mk2'):
		P.accent_band(ic, x0 + 40, -9, 20, 3, ACCENT)
	if o.get('octagonal'):
		ic.dark([(x0 + 40, -17), (x0 + 34 + bl, -17)], w=1, opacity=0.35)


def smg_boxy(ic, o):
	"""Submetralhadora compacta tipo Uzi/Tec: carregador no punho ou à frente do gatilho."""
	mat = o.get('mat', 'polymer')
	L = o.get('length', 120)
	x0 = 40
	P.barrel(ic, x0 + L - 4, x0 + L + o.get('barrel_out', 14), 3.4)
	if o.get('shroud'):
		ic.rect(x0 + L - 40, -10, 50, 14, 'gunmetal', r=6, kind='cyl')
		P.vents(ic, x0 + L - 36, x0 + L + 6, -5, h=4, step=7, opacity=0.9)
	ic.poly([(x0, -16), (x0 + L, -16), (x0 + L, 6), (x0, 6)], mat, r=[3, 2, 2, 3])
	ic.hl([(x0 + 4, -13.5), (x0 + L - 4, -13.5)], w=1.4, opacity=0.4)
	P.ejection_port(ic, x0 + 28, -9, 22, 5)
	ic.rect(x0 + 8, -20, 8, 5, mat, r=1)
	ic.rect(x0 + L - 14, -20, 6, 5, mat, r=1)
	if o.get('stock') == 'wire':
		_stock(ic, 'wire', x0 + 2, mat)
	elif o.get('stock') == 'folded':
		ic.line([(x0 + 2, -12), (x0 + 60, -12)], '#0b0d0e', 5, 1)
		ic.line([(x0 + 2, -12), (x0 + 60, -12)], '#7c848a', 2.6, 1)
	mp = o.get('mag_pos', 'grip')
	if mp == 'grip':
		gx = x0 + 34
		ic.poly([(gx, 6), (gx + 18, 6), (gx + 14, 52), (gx - 4, 52)], mat, r=3)
		P.mag_straight(ic, gx + 1, 50, o.get('mag_len', 20), 13, 'polymer', slant=-1)
		P.trigger_guard(ic, gx + 18, 6, 18, 11)
	else:
		gx = x0 + 12
		P.pistol_grip(ic, gx, 6, mat, length=34, slant=8, w=15)
		P.trigger_guard(ic, gx + 15, 6, 18, 11)
		mx = gx + 40
		if o.get('curved'):
			P.mag_curved(ic, mx, 6, o.get('mag_len', 42), 12, 'polymer', curve=16)
		else:
			P.mag_straight(ic, mx, 6, o.get('mag_len', 46), 12, 'polymer', slant=3)


def shotgun_pump(ic, o):
	mat = o.get('mat', 'polymer')
	furn = o.get('furniture', mat)
	x0 = 60
	bl = o.get('barrel_end', 214)
	# cano e tubo de carregador
	P.barrel(ic, x0 + 40, bl, 4)
	ic.rect(x0 + 40, 5, o.get('tube_end', bl - 10) - x0 - 40, 8, 'darksteel', r=3, kind='cyl')
	ic.rect(bl - 4, -5, 6, 9, 'darksteel', r=1)
	# telha (pump)
	fx = o.get('pump_x', x0 + 66)
	ic.rect(fx, 1, 52, 16, o.get('pump_mat', furn), r=5, kind='cyl')
	for i in range(6):
		ic.dark([(fx + 6 + i * 7, 3), (fx + 6 + i * 7, 15)], w=1.4, opacity=0.4)
	# caixa
	ic.poly([(x0 - 4, -8), (x0 + 42, -8), (x0 + 42, 14), (x0 + 6, 14), (x0 - 4, 6)], mat, r=2)
	ic.hl([(x0, -6), (x0 + 40, -6)], w=1.4, opacity=0.35)
	P.ejection_port(ic, x0 + 12, -3, 18, 5)
	P.sight_post(ic, bl - 6, -11, 7, 'steel')
	# coronha/punho
	if o.get('stock', 'rifle') == 'grip':
		P.pistol_grip(ic, x0 - 6, 4, furn, length=34, slant=14, w=16)
	elif o.get('stock') == 'sawn':
		ic.poly([(x0 - 4, -6), (x0 - 18, -6), (x0 - 30, 6), (x0 - 34, 24), (x0 - 18, 28), (x0 - 2, 12)], furn,
			r=[2, 4, 6, 4, 6, 3])
		ic.dark([(x0 - 32, 20), (x0 - 18, 24)], w=1.5, opacity=0.4)
	else:
		_stock(ic, o.get('stock', 'rifle'), x0 - 2, furn, y=-1)
	P.trigger_guard(ic, x0 + 10, 14, 18, 11)
	if o.get('heatshield'):
		ic.rect(x0 + 44, -9, 70, 8, 'gunmetal', r=3, kind='cyl')
		P.vents(ic, x0 + 48, x0 + 110, -7, h=3, step=7, opacity=0.95)
	if o.get('optic') == 'holo':
		P.holo(ic, x0 + 8, -8)
	if o.get('mk2'):
		P.accent_band(ic, x0 + 4, 8, 24, 3, ACCENT)


def double_barrel(ic, o):
	furn = o.get('furniture', 'wood')
	x0 = 70
	bl = o.get('barrel_end', 180)
	ic.rect(x0 + 20, -10, bl - x0 - 20, 9, 'blued', r=3, kind='cyl')
	ic.rect(x0 + 20, -1, bl - x0 - 20, 9, 'blued', r=3, kind='cyl')
	ic.rect(x0 + 30, 4, 46, 10, furn, r=4)
	ic.poly([(x0 - 6, -12), (x0 + 24, -12), (x0 + 24, 10), (x0 + 4, 12), (x0 - 6, 6)], 'steel', r=3)
	ic.dark([(x0 + 2, -4), (x0 + 18, -4)], w=1, opacity=0.4)
	ic.circle(x0 + 6, -2, 2.5, 'darksteel', sw=1.2)
	ic.poly([(x0 - 4, -14), (x0 - 12, -20), (x0 - 10, -12)], 'darksteel', r=1, sw=1.6)
	if o.get('stock') == 'grip':
		P.pistol_grip(ic, x0 - 8, 2, furn, length=34, slant=16, w=16, stipple=False)
	else:
		ic.poly([(x0 - 4, -8), (x0 - 56, -4), (x0 - 64, 18), (x0 - 54, 22), (x0 - 4, 10)], furn, r=[2, 4, 4, 4, 3])
	P.trigger_guard(ic, x0 + 4, 12, 16, 10, 'blued')


def sniper(ic, o):
	mat = o.get('mat', 'olive')
	x0 = 74
	bl = o.get('barrel_end', 222)
	P.barrel(ic, x0 + 50, bl, o.get('barrel_r', 3.2))
	P.muzzle(ic, bl, o.get('muzzle', 'brake'), r=o.get('barrel_r', 3.2))
	# chassi/coronha
	if o.get('stock', 'thumbhole') == 'thumbhole':
		_stock(ic, 'thumbhole', x0 + 2, mat)
		ic.poly([(x0, -8), (x0 + 96, -6), (x0 + 96, 6), (x0, 10)], mat, r=3)
	elif o['stock'] == 'chassis':
		_stock(ic, 'skeleton', x0 + 2, mat)
		ic.rect(x0, -10, 110, 18, mat, r=2)
		P.vents(ic, x0 + 56, x0 + 104, -4, h=4, step=8, opacity=0.7)
		P.pistol_grip(ic, x0 + 4, 8, 'polymer', length=28, slant=11, w=14)
	else:
		_stock(ic, 'rifle', x0 + 2, mat)
		ic.poly([(x0, -8), (x0 + 96, -6), (x0 + 96, 6), (x0, 10)], mat, r=3)
		P.pistol_grip(ic, x0 + 4, 8, mat, length=26, slant=10, w=14)
	ic.rect(x0 + 2, -14, 50, 9, 'gunmetal', r=3, kind='cyl')
	P.bolt(ic, x0 + 20, -4, 'steel')
	P.trigger_guard(ic, x0 + 20, 9, 18, 10)
	P.mag_straight(ic, x0 + 38, 8, o.get('mag_len', 16), 16, 'polymer', slant=0)
	P.scope(ic, x0 - 6, -14, o.get('scope_len', 66), o.get('scope_r', 6), bell=o.get('bell', 10))
	if o.get('bipod'):
		P.bipod(ic, x0 + 86, 6, 24)
	if o.get('mk2'):
		P.accent_band(ic, x0 + 60, -2, 22, 3, ACCENT)
