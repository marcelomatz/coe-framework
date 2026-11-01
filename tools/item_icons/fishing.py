"""Equipamento de pesca (coe_jobs / pescador): varas e iscas."""


def rod(ic, o):
	"""Vara deitada (gira no catálogo): cabo, molinete, vara afinando, passadores e linha com anzol."""
	blank = o.get('blank', 'tan')
	grip = o.get('grip', 'wood')
	# Vara: afina do cabo (x=70) até a ponta (x=300).
	ic.poly([(70, 92), (300, 98.5), (300, 101.5), (70, 108)], blank, kind='cyl', sw=1.6)
	if o.get('nodes'):
		# Bambu: gomos.
		for x in (120, 170, 220, 262):
			t = 8 - (x - 70) / 230 * 6
			ic.dark([(x, 100 - t), (x, 100 + t)], w=2.2, opacity=0.45)
	if o.get('stripe'):
		ic.line([(84, 100), (288, 100)], o['stripe'], 1.6, 0.9)
	ic.hl([(76, 95), (292, 99)], w=1.6, opacity=0.4)
	# Passadores.
	for x in (130, 190, 245, 292):
		ic.circle(x, 92 - (300 - x) * 0.01, 3.4, 'steel', kind='flat', sw=1)
	# Cabo e trava.
	ic.rect(4, 89, 70, 22, grip, r=8, kind='cyl')
	for x in (16, 30, 44, 58):
		ic.dark([(x, 91), (x, 109)], w=1, opacity=0.18)
	ic.rect(70, 90, 10, 20, 'darksteel', r=2, kind='cyl', sw=1.4)
	# Molinete embaixo do cabo.
	ic.rect(56, 108, 8, 14, 'darksteel', r=2)
	ic.circle(60, 134, 15, o.get('reel', 'darksteel'), kind='r')
	ic.circle(60, 134, 6, 'steel', kind='r', sw=1.2)
	ic.line([(74, 134), (88, 140)], '#1b1f22', 4, 1)
	ic.circle(90, 141, 3.5, 'polymer', sw=1)
	# Linha e anzol na ponta.
	ic.line([(300, 100), (306, 150)], '#e6e9eb', 1.2, 0.85)
	ic.line([(306, 150), (306, 160), (300, 166), (294, 160)], '#c3cbd1', 2.4, 1)


def bread_bait(ic, o):
	"""Iscas de pão: miolo em cubos."""
	for x, y, s in ((40, 120, 46), (96, 96, 52), (150, 126, 44), (100, 150, 40)):
		ic.rect(x, y, s, s * 0.86, 'bread', r=10, kind='v')
		ic.rect(x + 5, y + 5, s - 10, s * 0.86 - 10, 'cream', r=7, kind='flat', stroke='none', opacity=0.85)
		ic.dot(x + s * 0.35, y + s * 0.4, 2.2, '#c9b88a', 0.9)
		ic.dot(x + s * 0.62, y + s * 0.55, 1.8, '#c9b88a', 0.9)


def worm_can(ic, o):
	"""Lata de minhocas com terra e minhoca saindo."""
	ic.rect(40, 92, 120, 96, 'steel', r=8, kind='h')
	ic.rect(48, 118, 104, 46, 'kraft', r=3, kind='flat')
	ic.text(100, 148, 'ISCA', 16, '#3a2a15', 900)
	ic.ellipse(100, 92, 60, 14, 'chocolate', kind='r')
	path = 'M70,92 C70,60 100,48 112,66 C122,82 140,70 146,52 C150,40 162,40 164,52'
	ic.path(path, 'pink', [(64, 40), (170, 96)], stroke='#40101f')
	ic.raw('<path d="%s" fill="none" stroke="#9a2a5e" stroke-width="13" stroke-linecap="round"/>' % path)
	ic.raw('<path d="%s" fill="none" stroke="#ea5f9f" stroke-width="9" stroke-linecap="round"/>' % path)
	ic.raw('<path d="M72,84 C74,64 98,54 110,68" fill="none" stroke="#ffb8d8" stroke-width="2.4" stroke-linecap="round" opacity="0.7"/>')


def shrimp(ic, o):
	"""Camarão curvado com gomos e antenas."""
	segs = [(150, 70, 24), (126, 60, 26), (100, 62, 27), (76, 76, 26), (60, 100, 24), (58, 126, 21), (70, 148, 17)]
	for cx, cy, r in reversed(segs):
		ic.circle(cx, cy, r, 'orange', kind='r', sw=1.8)
	for cx, cy, r in segs[1:]:
		ic.dark([(cx - r * 0.6, cy - r * 0.6), (cx + r * 0.6, cy + r * 0.6)], w=1.6, opacity=0.25)
	ic.poly([(70, 160), (54, 186), (78, 178), (98, 188), (86, 160)], 'orange', r=3)
	ic.dot(162, 62, 4, '#1a0c05')
	ic.line([(170, 58), (206, 30)], '#a5520f', 2, 1)
	ic.line([(170, 64), (210, 50)], '#a5520f', 2, 1)
	for x in (100, 120, 140):
		ic.line([(x, 84), (x - 6, 104)], '#a5520f', 2, 0.9)


def lure(ic, o):
	"""Isca artificial (plug): corpo de peixe pintado, olho, barbela e garatéias."""
	ic.ellipse(100, 96, 74, 30, 'white', kind='r')
	ic.raw('<path d="M40,96 C60,70 140,66 172,90 L172,96 Z" fill="#d6392d" opacity="0.9"/>', [(40, 66), (172, 96)])
	ic.poly([(26, 96), (8, 78), (12, 96), (8, 114)], 'red', r=3)
	ic.poly([(172, 102), (204, 120), (198, 128), (166, 110)], 'glass', r=3, opacity=0.9)
	ic.circle(150, 88, 9, 'yellow', kind='r', sw=1.2)
	ic.dot(152, 88, 4, '#1a1a1a')
	ic.hl([(60, 80), (130, 74)], w=3, opacity=0.5)
	for x in (72, 128):
		ic.line([(x, 124), (x, 140)], '#aab2b8', 2.2, 1)
		for dx in (-9, 0, 9):
			ic.line([(x, 140), (x + dx, 156), (x + dx * 1.6, 150)], '#c3cbd1', 2.4, 1)
