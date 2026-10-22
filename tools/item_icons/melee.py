"""Armas brancas, arremessáveis e objetos usados como arma."""
import math
from lib import arc_points


def _tape(ic, x0, x1, r, color='#1d1f21', step=5):
	x = x0
	while x < x1:
		ic.dark([(x, -r + 1), (x + 2, r - 1)], w=1.2, opacity=0.5)
		x += step


def knife(ic, o):
	ic.poly([(70, -7), (150, -9), (196, -2), (200, 0), (150, 6), (70, 7)], 'steel', r=[1, 2, 3, 1, 3, 1], kind='v')
	ic.hl([(76, -4.5), (150, -6), (190, -1.5)], w=1.4, opacity=0.6)
	ic.dark([(76, 3), (150, 3.5)], w=1, opacity=0.25)
	ic.rect(62, -13, 9, 26, o.get('guard', 'darksteel'), r=2)
	ic.rect(4, -8, 60, 16, o.get('handle', 'rubber'), r=6, kind='cyl')
	_tape(ic, 12, 58, 8)
	ic.circle(6, 0, 7, o.get('guard', 'darksteel'))


def dagger(ic, o):
	ic.poly([(74, -8), (186, -3), (204, 0), (186, 3), (74, 8)], 'steel', r=[1, 2, 1, 2, 1])
	ic.dark([(78, 0), (190, 0)], w=1.2, opacity=0.4)
	ic.hl([(80, -4), (180, -1.5)], w=1.2, opacity=0.6)
	ic.poly([(60, -24), (72, -10), (72, 10), (60, 24), (66, 0)], 'gold', r=3)
	ic.rect(14, -7, 48, 14, 'leather', r=5, kind='cyl')
	for x in range(18, 60, 6):
		ic.dark([(x, -6), (x + 3, 6)], w=1.4, opacity=0.5)
	ic.circle(10, 0, 9, 'gold')
	ic.dot(10, 0, 3.5, '#c0392b')


def switchblade(ic, o):
	ic.poly([(84, -6), (160, -8), (196, -2), (160, 5), (84, 6)], 'steel', r=[1, 3, 1, 3, 1])
	ic.hl([(90, -3.5), (156, -5)], w=1.2, opacity=0.6)
	ic.rect(10, -10, 80, 20, 'blackleather', r=8, kind='cyl')
	ic.rect(16, -7, 68, 6, 'chrome', r=3, kind='cyl', sw=1.2)
	ic.circle(64, 4, 3.5, 'chrome', sw=1.2)


def machete(ic, o):
	ic.poly([(64, -10), (170, -16), (206, -14), (214, -6), (206, 6), (64, 9)], 'darksteel', r=[1, 6, 8, 6, 4, 1])
	ic.poly([(70, 2), (204, -1), (206, 6), (64, 9)], 'steel', r=[0, 3, 3, 0], stroke='none', opacity=0.9)
	ic.hl([(70, -7), (166, -12)], w=1.4, opacity=0.35)
	ic.rect(6, -8, 60, 16, 'darkwood', r=5)
	for x in (20, 46):
		ic.circle(x, 0, 2.6, 'brass', sw=1)


def hatchet(ic, o):
	stone = o.get('stone')
	ic.rect(0, -6, 200, 12, 'wood', r=5, kind='cyl')
	ic.dark([(20, -1), (190, 1)], w=1, opacity=0.25)
	if stone:
		ic.poly([(166, -14), (196, -14), (212, -40), (206, -70), (178, -78), (160, -52)], 'stone', r=[4, 4, 8, 10, 10, 8])
		ic.dark([(182, -60), (198, -30)], w=1.5, opacity=0.35)
		ic.hl([(170, -50), (182, -72)], w=2, opacity=0.3)
		ic.rect(164, -10, 36, 20, 'kraft', r=4)
		for x in range(168, 198, 5):
			ic.dark([(x, -9), (x + 3, 9)], w=1.4, opacity=0.45)
	else:
		ic.rect(4, -7, 56, 14, 'rubber', r=5, kind='cyl')
		ic.poly([(170, -12), (200, -12), (204, 8), (196, 14), (174, 14), (168, 8)], 'darksteel', r=3)
		ic.poly([(172, -12), (198, -12), (214, -44), (210, -62), (160, -62), (158, -44)], 'darksteel', r=[2, 2, 6, 3, 3, 6])
		ic.poly([(160, -62), (210, -62), (213, -52), (157, -52)], 'steel', r=2, stroke='none', opacity=0.95)
		ic.hl([(176, -20), (166, -48)], w=1.6, opacity=0.35)


def battleaxe(ic, o):
	ic.rect(0, -5, 210, 10, 'darkwood', r=4, kind='cyl')
	_tape(ic, 6, 60, 5)
	ic.poly([(170, -6), (160, -40), (180, -46), (192, -12), (200, -12), (212, -46), (232, -40), (222, -6), (222, 6),
		(232, 40), (212, 46), (200, 12), (192, 12), (180, 46), (160, 40), (170, 6)], 'darksteel', r=4)
	ic.poly([(160, -40), (180, -46), (184, -34), (166, -28)], 'steel', r=2, stroke='none')
	ic.poly([(212, 46), (232, 40), (226, 28), (210, 34)], 'steel', r=2, stroke='none')


def bat(ic, o):
	ic.poly([(0, -6), (60, -6), (200, -14), (214, -12), (218, 0), (214, 12), (200, 14), (60, 6), (0, 6)], 'wood',
		r=[3, 30, 12, 6, 6, 6, 12, 30, 3], kind='cyl')
	ic.ellipse(2, 0, 4, 9, 'wood', kind='h')
	_tape(ic, 8, 58, 6)
	ic.rect(8, -6.5, 50, 13, '#1d1f21', stroke='none', opacity=0.75, r=4)
	ic.hl([(70, -5), (206, -10)], w=2, opacity=0.4)


def golfclub(ic, o):
	ic.rect(0, -5, 60, 10, 'rubber', r=4, kind='cyl')
	ic.rect(56, -2.5, 140, 5, 'chrome', r=2, kind='cyl')
	ic.poly([(192, -6), (204, -6), (226, 10), (224, 20), (196, 20), (188, 8)], 'chrome', r=4)
	for y in (8, 12, 16):
		ic.dark([(198, y), (218, y)], w=1, opacity=0.5)


def poolcue(ic, o):
	ic.poly([(0, -6), (120, -4), (230, -2.5), (230, 2.5), (120, 4), (0, 6)], 'wood', r=[3, 0, 1, 1, 0, 3], kind='cyl')
	ic.poly([(0, -6), (70, -5), (70, 5), (0, 6)], 'darkwood', r=[3, 0, 0, 3], kind='cyl')
	ic.poly([(70, -5), (90, -4.8), (80, 0), (90, 4.8), (70, 5), (76, 0)], 'darkwood', stroke='none')
	ic.rect(226, -3, 6, 6, 'white', r=1, sw=1)
	ic.rect(232, -2.5, 3, 5, 'blue', r=1, sw=1)


def crowbar(ic, o):
	pts = [(14, 16), (6, 6), (12, -2), (30, 0)]
	ic.line(pts, '#0b0d0e', 12, 1)
	ic.line(pts, '#a8261d', 7.6, 1)
	ic.line([(30, 0), (196, 0)], '#0b0d0e', 12, 1)
	ic.line([(30, 0), (196, 0)], '#a8261d', 7.6, 1)
	ic.line([(196, 0), (214, -8), (222, -4)], '#0b0d0e', 12, 1)
	ic.line([(196, 0), (214, -8), (222, -4)], '#a8261d', 7.6, 1)
	ic.hl([(34, -2), (192, -2)], w=1.6, opacity=0.4)
	ic.line([(212, -8), (224, -4)], '#c3cbd1', 3, 1)


def hammer(ic, o):
	ic.rect(0, -7, 160, 14, 'wood', r=6, kind='cyl')
	ic.rect(4, -8, 60, 16, 'rubber', r=6, kind='cyl')
	ic.poly([(150, -22), (176, -22), (176, -6), (186, -6), (196, -2), (196, 8), (186, 12), (176, 12), (176, 30),
		(166, 40), (160, 30), (150, 10)], 'darksteel', r=3)
	ic.rect(186, -8, 14, 22, 'steel', r=2, kind='h')
	ic.poly([(150, -22), (176, -22), (176, -14), (150, -14)], 'steel', r=2, stroke='none', opacity=0.7)


def wrench(ic, o):
	ic.rect(0, -8, 160, 16, 'red', r=6, kind='cyl')
	ic.ellipse(10, 0, 5, 4, '#0b0d0e', stroke='none')
	ic.rect(150, -10, 44, 20, 'darksteel', r=3)
	ic.poly([(186, -40), (222, -40), (226, -22), (204, -18), (200, -10), (186, -10)], 'darksteel', r=3)
	ic.poly([(196, 0), (226, 2), (228, 22), (194, 18)], 'darksteel', r=3)
	for x in (206, 213, 220):
		ic.dark([(x, -36), (x, -24)], w=1.4, opacity=0.5)
		ic.dark([(x, 6), (x, 18)], w=1.4, opacity=0.5)
	ic.rect(186, -14, 10, 18, 'steel', r=2, kind='cyl', sw=1.6)
	ic.circle(172, 0, 6, 'steel', kind='r', sw=1.4)


def nightstick(ic, o):
	ic.rect(0, -7, 200, 14, 'polymer', r=7, kind='cyl')
	ic.rect(40, 6, 10, 26, 'polymer', r=3)
	ic.rect(36, 28, 18, 8, 'polymer', r=3)
	_tape(ic, 6, 36, 4)
	ic.hl([(60, -3), (194, -3)], w=2, opacity=0.4)


def knuckle(ic, o):
	ic.poly([(20, 0), (180, 0), (190, 10), (184, 40), (150, 66), (50, 66), (16, 40), (10, 10)], 'brass',
		r=[8, 8, 10, 14, 14, 14, 14, 10])
	for i in range(4):
		cx = 44 + i * 38
		ic.ellipse(cx, 22, 15, 14, '#0c1110', stroke='#5a3e10', sw=2.4)
		ic.hl(arc_points(cx, 22, 17, 16, 200, 290, 6), w=1.5, opacity=0.5)
	ic.ellipse(100, 52, 40, 7, '#0c1110', stroke='#5a3e10', sw=2.4)
	ic.hl([(30, 4), (170, 4)], w=2, opacity=0.6)


def flashlight(ic, o):
	ic.glow(220, 0, 40, '#fff4c2', 0.55)
	ic.rect(10, -10, 150, 20, 'polymer', r=6, kind='cyl')
	ic.poly([(156, -11), (180, -18), (206, -18), (206, 18), (180, 18), (156, 11)], 'polymer', r=3, kind='cyl')
	ic.rect(204, -16, 6, 32, '#fff6cf', stroke='#4a4f53', sw=1.6, r=2)
	for x in range(30, 140, 8):
		ic.dark([(x, -9), (x, 9)], w=1.2, opacity=0.4)
	ic.rect(120, -15, 18, 6, 'rubber', r=2)
	ic.rect(4, -8, 8, 16, 'darksteel', r=2)


def candycane(ic, o):
	pts = [(0, 0), (150, 0)] + arc_points(170, 0, 26, 26, 180, 360, 14)[1:] + [(196, 20)]
	ic.line(pts, '#5a1610', 18, 1)
	ic.line(pts, '#ffffff', 14, 1)
	d = 0
	# listras: segmentos curtos ao longo do trajeto
	segs = []
	for a, b in zip(pts, pts[1:]):
		segs.append((a, b))
	total = sum(math.dist(a, b) for a, b in segs)
	t = 6
	while t < total:
		acc = 0
		for a, b in segs:
			L = math.dist(a, b)
			if acc + L >= t:
				f = (t - acc) / L
				p = (a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f)
				nx, ny = (b[1] - a[1]) / L, -(b[0] - a[0]) / L
				ic.line([(p[0] - nx * 6 - 4, p[1] - ny * 6), (p[0] + nx * 6 + 4, p[1] + ny * 6)], '#d6392d', 4.5, 1)
				break
			acc += L
		t += 14
	ic.hl([(10, -4), (150, -4)], w=2, opacity=0.5)
	d += 1


def bottle_broken(ic, o):
	ic.poly([(0, -6), (50, -6), (70, -14), (140, -18), (150, -24), (160, -10), (172, -20), (178, -4), (190, -14),
		(186, 4), (176, 0), (172, 18), (160, 10), (146, 20), (70, 14), (50, 6), (0, 6)], 'greenglass',
		r=[2, 8, 6, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 6, 8, 2], opacity=0.92)
	ic.hl([(56, -4), (138, -12)], w=3, opacity=0.5)
	ic.rect(0, -7, 14, 14, 'greenglass', r=2)


def bread(ic, o):
	ic.poly([(6, 0), (30, -18), (180, -20), (214, -6), (214, 8), (180, 20), (30, 18)], 'bread', r=[16, 18, 18, 12, 12,
		18, 18])
	for x in (50, 90, 130, 170):
		ic.line([(x - 10, 6), (x + 10, -8)], '#f7dca6', 5, 1)
		ic.dark([(x - 10, 8), (x + 10, -6)], w=1.4, opacity=0.25)


def handcuffs(ic, o):
	for cx, cy in ((60, 30), (150, 30)):
		ic.ellipse(cx, cy, 38, 36, 'chrome', kind='r')
		ic.ellipse(cx, cy, 27, 25, '#0c1110', stroke='#2a3034', sw=2)
		ic.rect(cx - 10, cy - 46, 20, 14, 'chrome', r=3)
	for x in (92, 104, 116):
		ic.ellipse(x, -14, 7, 4, 'chrome', kind='r', sw=1.6)
	ic.hl(arc_points(60, 30, 33, 31, 200, 290, 6), w=2, opacity=0.7)
	ic.hl(arc_points(150, 30, 33, 31, 200, 290, 6), w=2, opacity=0.7)


def metaldetector(ic, o):
	ic.line([(10, -10), (190, 20)], '#0b0d0e', 9, 1)
	ic.line([(10, -10), (190, 20)], '#a7afb5', 5, 1)
	ic.ellipse(206, 26, 26, 10, 'polymer')
	ic.ellipse(206, 24, 16, 5, '#0c1110', stroke='none')
	ic.rect(56, -12, 44, 20, 'polymer', r=4)
	ic.rect(62, -8, 18, 9, 'screen', r=2, sw=1.2)
	ic.dot(90, -3, 3, '#7cff7c')
	ic.rect(0, -20, 34, 16, 'rubber', r=5)


def digiscanner(ic, o):
	ic.rect(0, 0, 90, 150, 'polymer', r=14)
	ic.rect(10, 12, 70, 70, 'screen', r=6, sw=1.4)
	for r in (12, 22, 32):
		ic.raw('<circle cx="45" cy="47" r="%d" fill="none" stroke="#5bd16a" stroke-width="1.5" opacity="0.7"/>' % r)
	ic.dot(58, 36, 3.5, '#9cff8a')
	ic.line([(45, 47), (70, 30)], '#9cff8a', 1.6, 0.9)
	for i in range(3):
		ic.circle(24 + i * 21, 104, 7, 'darksteel', sw=1.4)
	ic.rect(30, 124, 30, 10, 'darksteel', r=3, sw=1.4)
	ic.rect(36, -16, 8, 18, 'polymer', r=3)


def extinguisher(ic, o):
	ic.rect(30, 30, 64, 150, 'red', r=26, kind='h')
	ic.rect(48, 8, 28, 26, 'darksteel', r=4, kind='h')
	ic.poly([(40, 4), (100, -6), (104, 4), (46, 14)], 'polymer', r=3)
	ic.line([(70, 16), (112, 30), (120, 100), (108, 136)], '#0b0d0e', 8, 1)
	ic.line([(70, 16), (112, 30), (120, 100), (108, 136)], '#2b2c2e', 5, 1)
	ic.rect(100, 134, 14, 18, 'polymer', r=3)
	ic.rect(38, 80, 48, 48, 'white', r=4)
	ic.rect(44, 88, 36, 6, '#d6392d', stroke='none', r=1)
	ic.rect(44, 100, 28, 4, '#555', stroke='none', r=1)
	ic.rect(44, 108, 32, 4, '#555', stroke='none', r=1)


def jerrycan(ic, o):
	mat = o.get('mat', 'red')
	ic.poly([(10, 30), (24, 14), (140, 14), (150, 24), (150, 170), (140, 180), (20, 180), (10, 170)], mat, r=8)
	ic.poly([(24, 14), (100, 14), (100, -6), (30, -6)], mat, r=6)
	ic.rect(42, -2, 46, 10, '#0c1110', stroke='none', r=4)
	ic.rect(116, -4, 26, 20, 'darksteel', r=4, kind='h')
	ic.poly([(26, 40), (134, 40), (80, 98)], '#000000', stroke='none', opacity=0.18)
	ic.poly([(26, 160), (134, 160), (80, 102)], '#000000', stroke='none', opacity=0.18)
	ic.poly([(26, 40), (80, 98), (26, 156)], '#ffffff', stroke='none', opacity=0.08)
	ic.hl([(16, 34), (16, 166)], w=3, opacity=0.35)
	if o.get('hazard'):
		ic.poly([(80, 70), (110, 120), (50, 120)], 'yellow', r=3, sw=2)
		ic.text(80, 116, '!', 30, '#1a1a1a', 900)


def fertilizercan(ic, o):
	ic.poly([(20, 20), (130, 20), (140, 160), (10, 160)], 'green', r=10)
	ic.line([(130, 60), (190, 20)], '#0c2c0f', 12, 1)
	ic.line([(130, 60), (190, 20)], '#3fae4a', 8, 1)
	ic.rect(186, 8, 18, 18, 'green', r=4)
	ic.line([(40, 20), (60, -20), (100, -20), (118, 20)], '#0c2c0f', 12, 1)
	ic.line([(40, 20), (60, -20), (100, -20), (118, 20)], '#3fae4a', 7, 1)
	ic.rect(30, 70, 90, 50, 'white', r=4)
	ic.raw('<path d="M60,105 C60,85 75,78 90,80 C88,96 78,105 60,105Z" fill="#3fae4a"/>')


def briefcase(ic, o):
	mat = o.get('mat', 'leather')
	ic.poly([(70, 20), (74, -4), (126, -4), (130, 20)], '#0c1110', stroke='none')
	ic.line([(76, 22), (80, 2), (120, 2), (124, 22)], '#0b0d0e', 12, 1)
	ic.line([(76, 22), (80, 2), (120, 2), (124, 22)], '#2b2c2e' if mat != 'chrome' else '#3a4146', 7, 1)
	ic.rect(0, 20, 200, 130, mat, r=10)
	ic.rect(0, 20, 200, 26, mat, r=10)
	ic.hl([(8, 26), (192, 26)], w=2, opacity=0.4)
	for x in (40, 150):
		ic.rect(x - 10, 38, 20, 16, 'gold' if mat == 'leather' else 'darksteel', r=2)
	if mat == 'chrome':
		for y in (70, 100, 130):
			ic.dark([(6, y), (194, y)], w=1.4, opacity=0.25)


def garbagebag(ic, o):
	ic.poly([(80, 20), (100, 0), (120, 20)], 'blackleather', r=4)
	ic.poly([(70, 30), (130, 30), (180, 80), (190, 150), (170, 180), (30, 180), (10, 150), (20, 80)], 'blackleather',
		r=[10, 10, 40, 30, 20, 20, 30, 40])
	ic.hl([(40, 70), (30, 140)], w=4, opacity=0.25)
	ic.hl([(120, 60), (150, 90)], w=3, opacity=0.2)
	ic.dark([(100, 40), (90, 120)], w=2, opacity=0.4)
	ic.rect(86, 22, 28, 10, '#d6392d', r=3, sw=1.6)


def acidpackage(ic, o):
	ic.poly([(20, 30), (180, 20), (190, 160), (10, 170)], 'glass', r=12, opacity=0.85)
	ic.rect(36, 50, 128, 100, 'kraft', r=4)
	ic.line([(36, 100), (164, 100)], '#c9a46a', 6, 1)
	ic.line([(100, 50), (100, 150)], '#c9a46a', 6, 1)
	ic.poly([(70, 64), (96, 64), (96, 90), (70, 90)], 'yellow', r=2, sw=1.6)
	ic.text(83, 84, '☣', 20, '#1a1a1a', 400)
	ic.hl([(30, 36), (176, 28)], w=3, opacity=0.5)


def baseball(ic, o):
	ic.circle(100, 100, 80, 'white')
	ic.raw('<path d="M48,38 C80,70 80,130 48,162" fill="none" stroke="#d6392d" stroke-width="3" stroke-dasharray="5 4"/>')
	ic.raw('<path d="M152,38 C120,70 120,130 152,162" fill="none" stroke="#d6392d" stroke-width="3" stroke-dasharray="5 4"/>')


def snowball(ic, o):
	ic.circle(100, 100, 80, 'snow')
	for x, y, r in ((70, 70, 10), (120, 120, 14), (130, 70, 8), (80, 130, 9)):
		ic.dot(x, y, r, '#b4c6d6', 0.5)


# --- arremessáveis ---
def frag(ic, o):
	ic.ellipse(100, 120, 60, 74, 'olive', kind='r')
	for y in (80, 110, 140, 170):
		ic.dark([(48, y), (152, y)], w=2, opacity=0.35)
	for x in (70, 100, 130):
		ic.dark([(x, 52), (x, 190)], w=2, opacity=0.3)
	ic.rect(80, 34, 40, 22, 'darksteel', r=4)
	ic.poly([(118, 38), (150, 50), (158, 120), (148, 122), (140, 58), (116, 50)], 'darksteel', r=3)
	ic.raw('<circle cx="70" cy="34" r="16" fill="none" stroke="#0b0d0e" stroke-width="7"/>'
		'<circle cx="70" cy="34" r="16" fill="none" stroke="#c3cbd1" stroke-width="3.5"/>', [(50, 14), (90, 54)])


def canister(ic, o):
	mat = o.get('mat', 'darksteel')
	ic.rect(40, 30, 120, 170, mat, r=14, kind='h')
	ic.rect(54, 6, 92, 28, 'darksteel', r=6, kind='h')
	ic.poly([(140, 12), (176, 26), (178, 110), (166, 112), (164, 34), (138, 26)], 'darksteel', r=3)
	ic.raw('<circle cx="66" cy="8" r="13" fill="none" stroke="#0b0d0e" stroke-width="7"/>'
		'<circle cx="66" cy="8" r="13" fill="none" stroke="#c3cbd1" stroke-width="3.5"/>', [(50, -8), (82, 24)])
	ic.rect(40, o.get('band_y', 70), 120, 20, o.get('band', '#f2cc35'), stroke='none', opacity=0.95)
	if o.get('label'):
		ic.text(100, 150, o['label'], 26, o.get('label_color', '#f2f2f2'), 900)


def pipebomb(ic, o):
	ic.rect(20, 60, 180, 70, 'darksteel', r=10, kind='cyl')
	ic.rect(10, 52, 28, 86, 'gunmetal', r=6, kind='cyl')
	ic.rect(182, 52, 28, 86, 'gunmetal', r=6, kind='cyl')
	for x in (70, 120):
		ic.rect(x, 58, 24, 74, '#c9c2a6', r=3, kind='cyl')
	ic.line([(196, 52), (210, 20), (180, 6)], '#d6392d', 4, 1)
	ic.line([(190, 52), (196, 24), (170, 16)], '#3a7fd6', 4, 1)
	ic.rect(150, 10, 34, 24, 'polymer', r=4)
	ic.dot(176, 22, 4, '#ff3b30')


def proxmine(ic, o):
	ic.ellipse(100, 120, 90, 44, 'olive', kind='r')
	ic.ellipse(100, 108, 70, 30, 'olive', kind='r')
	ic.ellipse(100, 100, 26, 12, 'darksteel')
	ic.glow(100, 96, 24, '#ff3b30', 0.8)
	ic.dot(100, 98, 6, '#ff5b4a')
	for x in (40, 160):
		ic.rect(x - 4, 116, 8, 12, 'darksteel', r=2)


def stickybomb(ic, o):
	ic.rect(10, 40, 180, 120, 'tan', r=8)
	for y in (80, 120):
		ic.dark([(14, y), (186, y)], w=2, opacity=0.3)
	ic.rect(50, 30, 16, 140, 'polymer', stroke='#0b0d0e', r=2)
	ic.rect(134, 30, 16, 140, 'polymer', stroke='#0b0d0e', r=2)
	ic.rect(70, 66, 60, 44, 'polymer', r=4)
	ic.rect(76, 72, 48, 20, 'screen', r=2, sw=1.2)
	ic.text(100, 88, '00:30', 13, '#ff4a3a', 700, family='DejaVu Sans Mono')
	ic.dot(118, 102, 3.5, '#ff3b30')
	ic.line([(90, 110), (80, 140), (60, 150)], '#d6392d', 3.5, 1)
	ic.line([(110, 110), (120, 142), (140, 150)], '#3a7fd6', 3.5, 1)


def molotov(ic, o):
	ic.glow(70, -10, 50, '#ffb340', 0.9)
	ic.raw('<path d="M70,-50 C90,-30 96,-10 84,6 C80,-6 74,-8 70,4 C64,-8 56,-6 54,6 C44,-12 54,-34 70,-50Z" '
		'fill="#ffb02e" stroke="#a5520f" stroke-width="2"/>'
		'<path d="M70,-30 C78,-18 80,-6 74,4 C70,-2 66,-2 64,4 C60,-8 62,-20 70,-30Z" fill="#fff1a8"/>',
		[(44, -50), (96, 6)])
	ic.poly([(56, 40), (84, 40), (84, 70), (110, 96), (114, 200), (26, 200), (30, 96), (56, 70)], 'greenglass',
		r=[3, 3, 8, 14, 10, 10, 14, 8], opacity=0.95)
	ic.rect(30, 110, 82, 70, 'amberglass', r=6, opacity=0.6, stroke='none')
	ic.poly([(58, 0), (82, 0), (88, 46), (52, 46)], 'cloth', r=4)
	ic.line([(60, 10), (80, 30)], '#56626a', 2, 0.6)
	ic.hl([(38, 104), (36, 190)], w=4, opacity=0.45)


def roadflare(ic, o):
	ic.glow(190, 0, 44, '#ff4a2e', 0.9)
	ic.rect(0, -12, 180, 24, 'red', r=6, kind='cyl')
	ic.rect(176, -10, 16, 20, '#ffd2b0', stroke='#a5520f', r=4)
	ic.rect(40, -13, 50, 26, 'white', r=2, kind='cyl')
	ic.text(65, 5, 'FLARE', 11, '#d6392d', 900)
	ic.rect(0, -13, 14, 26, 'darkred', r=4, kind='cyl')
