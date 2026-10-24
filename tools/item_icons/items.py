"""Itens gerais: comida, bebida, consumíveis, documentos, eletrônicos, peças e lixo."""
import math
from lib import arc_points


# ---------------------------------------------------------------- comida
def burger(ic, o):
	chicken = o.get('chicken')
	ic.poly([(20, 140), (180, 140), (176, 170), (24, 170)], 'bread', r=[6, 6, 14, 14])
	if chicken:
		ic.poly([(10, 118), (190, 114), (196, 132), (180, 146), (20, 146), (6, 132)], 'orange', r=10)
		for x in (40, 80, 120, 160):
			ic.dark([(x, 122), (x + 8, 136)], w=2, opacity=0.25)
	else:
		ic.rect(14, 118, 172, 26, 'chocolate', r=12)
		ic.poly([(14, 112), (186, 112), (196, 122), (170, 124), (150, 132), (130, 122), (100, 132), (70, 122), (40, 130),
			(4, 122)], 'cheese', r=4)
	ic.poly([(8, 104), (40, 96), (70, 106), (100, 96), (130, 106), (160, 96), (192, 104), (190, 116), (10, 116)],
		'lettuce', r=6)
	ic.rect(30, 94, 140, 10, 'tomato', r=4)
	ic.raw('<path d="M14,96 C14,30 186,30 186,96 Z" fill="url(#bun)" stroke="#4a2b0a" stroke-width="2.2"/>',
		[(14, 40), (186, 96)])
	ic.defs['bun'] = ('<radialGradient id="bun" cx="0.38" cy="0.25" r="0.85"><stop offset="0" stop-color="#ffd99a"/>'
		'<stop offset="0.5" stop-color="#e19a45"/><stop offset="1" stop-color="#9a5418"/></radialGradient>')
	for x, y in ((60, 60), (90, 50), (120, 58), (140, 72), (80, 76), (110, 78)):
		ic.ellipse(x, y, 4, 2.2, '#fff4d6', stroke='none')


def donut(ic, o):
	ic.ellipse(100, 108, 90, 70, 'bread', kind='r')
	ic.raw('<path d="M18,100 C20,40 180,40 182,100 C186,120 170,118 160,130 C150,140 140,128 128,140 C116,150 100,136 '
		'88,148 C74,156 66,138 52,142 C36,146 30,128 18,126 Z" fill="url(#icing)" stroke="#7a1f4a" stroke-width="2"/>',
		[(18, 40), (182, 150)])
	ic.defs['icing'] = ('<radialGradient id="icing" cx="0.4" cy="0.3" r="0.8"><stop offset="0" stop-color="#ffc2df"/>'
		'<stop offset="0.6" stop-color="#ea5f9f"/><stop offset="1" stop-color="#a02a62"/></radialGradient>')
	ic.ellipse(100, 98, 26, 18, '#0c1110', stroke='#7a1f4a', sw=2)
	cols = ('#fff', '#ffd23f', '#5bd1ff', '#7cff7c', '#fff')
	for i, (x, y, a) in enumerate(((50, 80, 20), (140, 74, -30), (70, 120, 60), (130, 118, 10), (100, 60, -50),
			(160, 100, 80), (40, 104, -20))):
		dx, dy = 6 * math.cos(math.radians(a)), 6 * math.sin(math.radians(a))
		ic.line([(x - dx, y - dy), (x + dx, y + dy)], cols[i % len(cols)], 4, 1)


def fries(ic, o):
	cols = [(48, 20), (66, 8), (84, 14), (102, 4), (120, 12), (138, 6), (154, 22), (74, 28), (112, 24), (130, 30)]
	for x, y in cols:
		ic.rect(x - 7, y, 14, 110, 'cheese', r=3, kind='h')
	ic.poly([(30, 80), (170, 80), (156, 196), (44, 196)], 'red', r=[4, 4, 10, 10])
	ic.raw('<path d="M30,80 Q100,110 170,80" fill="none" stroke="#3a0805" stroke-width="2.2"/>')
	ic.circle(100, 140, 22, 'yellow', kind='r', sw=1.8)
	ic.hl([(40, 90), (50, 186)], w=3, opacity=0.3)


def pizza(ic, o):
	ic.circle(100, 100, 92, 'bread', kind='r')
	ic.circle(100, 100, 78, 'tomato', kind='r', sw=1.4)
	ic.raw('<circle cx="100" cy="100" r="74" fill="#ffe08a" opacity="0.85"/>')
	for x, y in ((70, 60), (130, 70), (60, 120), (110, 110), (140, 130), (90, 150), (100, 80)):
		ic.circle(x, y, 11, 'meat', sw=1.2)
	for a in range(0, 360, 60):
		p = arc_points(100, 100, 86, 86, a, a, 1)[0]
		ic.line([(100, 100), p], '#9a5f20', 1.4, 0.5)


def pizza_slice(ic, o):
	ic.poly([(20, 40), (180, 40), (100, 196)], 'cheese', r=[10, 10, 6])
	ic.raw('<path d="M14,48 Q100,10 186,48 L180,30 Q100,-6 20,30 Z" fill="url(#bread-v)" stroke="#4a2b0a" '
		'stroke-width="2.2"/>', [(14, 0), (186, 48)])
	ic.grad('bread', 'v')
	for x, y in ((70, 70), (120, 80), (96, 120), (86, 90)):
		ic.circle(x, y, 10, 'meat', sw=1.2)
	ic.line([(130, 110), (128, 150)], '#f5c842', 7, 1)


def pizza_box(ic, o):
	ic.poly([(10, 80), (110, 40), (196, 80), (96, 120)], 'cardboard', r=3)
	ic.poly([(10, 80), (96, 120), (96, 150), (10, 110)], 'cardboard', r=2)
	ic.fill([(10, 80), (96, 120), (96, 150), (10, 110)], '#000000', 0.15)
	ic.poly([(96, 120), (196, 80), (196, 110), (96, 150)], 'cardboard', r=2)
	ic.fill([(96, 120), (196, 80), (196, 110), (96, 150)], '#000000', 0.3)
	ic.ellipse(103, 80, 36, 18, 'red', kind='r', sw=1.6)
	ic.text(103, 86, 'PIZZA', 13, '#ffffff', 900)


def sandwich(ic, o):
	# fatia triangular vista de lado: pão, recheios e pão
	ic.poly([(10, 150), (190, 150), (190, 176), (10, 176)], 'bread', r=8)
	ic.poly([(14, 156), (186, 156), (186, 170), (14, 170)], 'cream', r=5, sw=1)
	ic.poly([(4, 140), (40, 130), (70, 144), (100, 128), (130, 144), (160, 130), (196, 140), (192, 154), (8, 154)],
		'lettuce', r=6)
	ic.rect(14, 118, 172, 18, 'meat', r=6)
	ic.poly([(10, 112), (190, 112), (196, 122), (170, 124), (150, 134), (130, 122), (100, 132), (70, 122), (40, 130),
		(4, 122)], 'cheese', r=4)
	ic.circle(60, 104, 16, 'tomato', sw=1.6)
	ic.circle(140, 104, 16, 'tomato', sw=1.6)
	ic.poly([(10, 100), (100, 20), (190, 100), (190, 112), (10, 112)], 'bread', r=[10, 14, 10, 4, 4])
	ic.poly([(24, 100), (100, 34), (176, 100)], 'cream', r=[6, 10, 6], sw=1)
	ic.hl([(30, 98), (98, 40)], w=3, opacity=0.45)


def wrapper_bar(ic, o):
	mat = o.get('mat', 'chocolate')
	ic.poly([(10, 60), (190, 60), (196, 70), (190, 80), (196, 90), (190, 100), (196, 110), (190, 120), (10, 120),
		(4, 110), (10, 100), (4, 90), (10, 80), (4, 70)], mat, r=2)
	ic.rect(30, 66, 140, 48, o.get('label_mat', 'red'), r=4)
	ic.text(100, 98, o.get('label', 'CHOCO'), 18, '#ffffff', 900)
	ic.hl([(16, 66), (184, 66)], w=2, opacity=0.4)
	if o.get('bite'):
		ic.poly([(150, 60), (190, 60), (190, 120), (176, 120), (170, 104), (160, 98), (166, 84), (156, 72)], '#0c1110',
			stroke='none', opacity=0)


def chips(ic, o):
	ic.poly([(30, 20), (170, 20), (164, 40), (176, 100), (166, 166), (172, 186), (28, 186), (34, 166), (24, 100),
		(36, 40)], 'yellow', r=[2, 2, 6, 20, 6, 2, 2, 6, 20, 6])
	for x in range(36, 168, 10):
		ic.dark([(x, 20), (x, 28)], w=1.2, opacity=0.4)
		ic.dark([(x, 178), (x, 186)], w=1.2, opacity=0.4)
	ic.ellipse(100, 96, 54, 36, 'red', kind='r')
	ic.text(100, 104, 'CHIPS', 22, '#ffffff', 900)
	ic.ellipse(80, 146, 16, 10, 'cheese', sw=1.4)
	ic.ellipse(116, 150, 16, 10, 'cheese', sw=1.4)
	ic.hl([(46, 40), (40, 160)], w=4, opacity=0.35)


def can(ic, o):
	mat = o.get('mat', 'red')
	ic.rect(50, 24, 100, 168, mat, r=8, kind='h')
	ic.rect(56, 10, 88, 18, 'chrome', r=4, kind='h')
	ic.rect(56, 186, 88, 12, 'chrome', r=4, kind='h')
	ic.ellipse(100, 12, 44, 6, 'chrome', kind='r', sw=1.6)
	ic.rect(86, 6, 20, 6, 'darksteel', r=3, sw=1)
	if o.get('wave'):
		ic.raw('<path d="M50,110 C80,90 120,140 150,110 L150,130 C120,160 80,110 50,130Z" fill="%s" opacity="0.9"/>'
			% o['wave'])
	ic.text(100, o.get('label_y', 92), o.get('label', ''), o.get('size', 22), o.get('label_color', '#ffffff'), 900,
		rotate=-90 if o.get('vertical') else 0)
	ic.hl([(70, 32), (70, 184)], w=6, opacity=0.25)


def bottle(ic, o):
	glass = o.get('glass', 'greenglass')
	h = o.get('h', 1.0)
	ic.poly([(84, 4), (116, 4), (116, 50 * h), (140, 80 * h), (146, 100 * h), (146, 196), (54, 196), (54, 100 * h),
		(60, 80 * h), (84, 50 * h)], glass, r=[2, 2, 10, 20, 8, 8, 8, 8, 20, 10], kind='h', opacity=o.get('op', 1))
	if o.get('liquid'):
		ic.rect(58, o.get('fill_y', 110), 84, 196 - o.get('fill_y', 110) - 4, o['liquid'], stroke='none', r=6,
			opacity=0.55)
	ic.rect(82, 0, 36, 14, o.get('cap', 'gold'), r=3, kind='h')
	ic.rect(56, o.get('label_top', 120), 88, o.get('label_h', 50), o.get('label_mat', 'paper'), r=3, kind='h')
	ic.text(100, o.get('label_top', 120) + o.get('label_h', 50) / 2 + 7, o.get('label', ''), o.get('size', 16),
		o.get('label_color', '#1a1a1a'), 900)
	ic.hl([(66, 110), (66, 186)], w=5, opacity=0.35)


def water(ic, o):
	ic.poly([(80, 30), (120, 30), (124, 50), (140, 70), (140, 196), (60, 196), (60, 70), (76, 50)], 'glass',
		r=[2, 2, 8, 14, 8, 8, 14, 8], kind='h', opacity=0.75)
	ic.rect(62, 90, 76, 104, '#7fc6f2', stroke='none', r=6, opacity=0.45)
	for y in (110, 150):
		ic.dark([(62, y), (138, y)], w=2, opacity=0.18)
	ic.rect(82, 12, 36, 20, 'blue', r=4, kind='h')
	ic.rect(60, 120, 80, 36, 'blue', r=2, kind='h')
	ic.text(100, 144, 'ÁGUA', 15, '#ffffff', 900)
	ic.hl([(70, 80), (70, 186)], w=5, opacity=0.5)


def coffee(ic, o):
	ic.raw('<path d="M154,80 C190,80 190,140 150,140" fill="none" stroke="#3c2911" stroke-width="10"/>'
		'<path d="M154,80 C190,80 190,140 150,140" fill="none" stroke="#e6e9eb" stroke-width="6"/>', [(150, 76), (186, 144)])
	ic.poly([(40, 40), (160, 40), (146, 196), (54, 196)], 'white', r=[4, 4, 10, 10], kind='h')
	ic.poly([(46, 90), (154, 90), (148, 150), (52, 150)], 'cardboard', r=2, kind='h')
	ic.rect(32, 26, 136, 18, 'white', r=6, kind='h')
	ic.raw('<path d="M80,20 C70,0 100,-6 90,-26 M110,20 C100,0 130,-6 120,-26" fill="none" stroke="#ffffff" '
		'stroke-width="4" stroke-linecap="round" opacity="0.5"/>', [(70, -26), (130, 20)])
	ic.circle(100, 120, 14, 'chocolate', sw=1.4)


def mustard(ic, o):
	ic.poly([(60, 60), (140, 60), (150, 196), (50, 196)], 'yellow', r=[10, 10, 8, 8], kind='h')
	ic.rect(76, 30, 48, 34, 'red', r=6, kind='h')
	ic.poly([(90, 30), (96, 4), (104, 4), (110, 30)], 'red', r=2, kind='h')
	ic.rect(62, 110, 76, 50, 'red', r=4)
	ic.text(100, 141, 'MOSTARDA', 11, '#ffffff', 900)
	ic.hl([(64, 76), (60, 186)], w=5, opacity=0.35)


def cereal_bar(ic, o):
	ic.rect(10, 70, 180, 60, 'kraft', r=6)
	for x, y in ((30, 86), (60, 104), (90, 82), (120, 110), (150, 90), (170, 112), (44, 116), (104, 96), (140, 78)):
		ic.ellipse(x, y, 8, 5, 'bread', sw=1)
	ic.rect(60, 64, 80, 72, 'green', r=4)
	ic.text(100, 106, 'CEREAL', 15, '#ffffff', 900)


# ---------------------------------------------------------------- ingredientes
def meat(ic, o):
	ic.raw('<path d="M30,120 C10,60 80,20 140,40 C200,60 196,140 150,170 C100,200 46,170 30,120Z" fill="url(#meat-r)" '
		'stroke="#2e0b08" stroke-width="2.2"/>', [(14, 30), (196, 190)])
	ic.grad('meat', 'r')
	ic.raw('<path d="M60,90 C90,70 130,80 150,100 M50,130 C90,110 130,130 160,140" fill="none" stroke="#ffe0d6" '
		'stroke-width="6" stroke-linecap="round" opacity="0.7"/>')
	ic.ellipse(140, 70, 14, 10, 'cream', sw=1.4)


def potato(ic, o):
	ic.raw('<path d="M30,110 C20,60 90,40 140,56 C190,72 192,140 150,160 C100,184 40,160 30,110Z" fill="url(#bread-r)" '
		'stroke="#4a2b0a" stroke-width="2.2"/>', [(20, 44), (194, 176)])
	ic.grad('bread', 'r')
	for x, y in ((70, 90), (120, 80), (140, 130), (90, 140)):
		ic.ellipse(x, y, 4, 3, '#7a4a1a', stroke='none', opacity=0.7)


def dough(ic, o):
	ic.raw('<path d="M20,140 C10,90 60,60 100,62 C150,60 196,90 184,140 C176,170 30,176 20,140Z" fill="url(#cream-r)" '
		'stroke="#5e5236" stroke-width="2.2"/>', [(12, 60), (194, 172)])
	ic.grad('cream', 'r')
	ic.raw('<path d="M60,110 C80,96 110,100 130,110" fill="none" stroke="#c9b88a" stroke-width="3" opacity="0.6"/>')
	for x, y in ((50, 160), (160, 150), (110, 168)):
		ic.dot(x, y, 3, '#ffffff', 0.8)


def cheese(ic, o):
	ic.poly([(10, 140), (150, 60), (196, 100), (196, 160), (10, 190)], 'cheese', r=4)
	ic.poly([(10, 140), (150, 60), (196, 100), (56, 170)], 'cheese', r=4)
	ic.fill([(10, 140), (56, 170), (196, 100), (196, 160), (10, 190)], '#000000', 0.12)
	for x, y, r in ((60, 176, 7), (120, 160, 9), (170, 140, 6), (100, 120, 8), (140, 100, 6)):
		ic.ellipse(x, y, r, r * 0.8, '#b38a17', stroke='none', opacity=0.7)


def cloth(ic, o):
	ic.poly([(20, 70), (180, 50), (190, 150), (30, 170)], 'cloth', r=8)
	ic.poly([(20, 70), (180, 50), (176, 80), (24, 100)], 'cloth', r=6)
	ic.fill([(24, 100), (176, 80), (190, 150), (30, 170)], '#000000', 0.15)
	for i in range(6):
		ic.dark([(30 + i * 28, 104 - i * 3), (40 + i * 28, 162 - i * 3)], w=1, opacity=0.2)


# ---------------------------------------------------------------- consumíveis
def cigarette(ic, o):
	ic.rect(10, -9, 160, 18, 'white', r=4, kind='cyl')
	ic.rect(10, -9, 50, 18, 'orange', r=4, kind='cyl')
	for x in range(16, 58, 7):
		ic.dot(x, -2 + (x % 3), 1.4, '#7a3d1d', 0.6)
	ic.rect(166, -9, 14, 18, 'stone', r=3, kind='cyl')
	ic.glow(180, 0, 16, '#ff6a2e', 0.9)
	ic.raw('<path d="M184,-12 C176,-30 196,-40 186,-60" fill="none" stroke="#ffffff" stroke-width="3" opacity="0.4"/>',
		[(176, -60), (196, -12)])


def cig_pack(ic, o):
	ic.rect(30, 30, 140, 170, 'white', r=6)
	ic.rect(30, 30, 140, 50, 'red', r=6)
	ic.poly([(30, 80), (100, 110), (170, 80), (170, 120), (30, 120)], 'red', r=2)
	for x in (66, 92, 118):
		ic.rect(x, 4, 20, 36, 'orange', r=3, kind='h')
	ic.rect(30, 30, 140, 16, 'paper', stroke='none', opacity=0.0)
	ic.text(100, 160, 'REDWOOD', 18, '#8a1a14', 900)
	ic.hl([(36, 36), (36, 192)], w=4, opacity=0.3)


def armour(ic, o):
	ic.poly([(40, 20), (76, 20), (88, 50), (112, 50), (124, 20), (160, 20), (170, 70), (176, 180), (100, 196),
		(24, 180), (30, 70)], o.get('mat', 'navy'), r=[6, 6, 10, 10, 6, 6, 10, 14, 10, 14, 10])
	ic.rect(56, 90, 88, 40, 'polymer', r=4)
	for y in (100, 112, 124):
		ic.dark([(60, y), (140, y)], w=2, opacity=0.4)
	ic.rect(60, 146, 80, 26, 'white', r=3)
	ic.text(100, 166, 'POLÍCIA' if o.get('police') else 'KEVLAR', 13, '#1a2540', 900)
	ic.hl([(34, 76), (32, 176)], w=4, opacity=0.25)


def medikit(ic, o):
	ic.rect(20, 50, 160, 130, 'white', r=12)
	ic.poly([(70, 50), (74, 26), (126, 26), (130, 50)], '#0c1110', stroke='none')
	ic.line([(76, 52), (80, 30), (120, 30), (124, 52)], '#4a5054', 10, 1)
	ic.line([(76, 52), (80, 30), (120, 30), (124, 52)], '#d6392d', 6, 1)
	ic.rect(20, 50, 160, 22, 'red', r=8)
	ic.rect(86, 92, 28, 72, 'red', r=4, stroke='none')
	ic.rect(64, 114, 72, 28, 'red', r=4, stroke='none')
	ic.hl([(28, 80), (28, 172)], w=4, opacity=0.4)


def advancedkit(ic, o):
	ic.rect(10, 60, 180, 120, 'red', r=8)
	ic.rect(10, 60, 180, 30, 'darkred', r=8)
	ic.line([(70, 60), (76, 30), (124, 30), (130, 60)], '#0b0d0e', 12, 1)
	ic.line([(70, 60), (76, 30), (124, 30), (130, 60)], '#2b2c2e', 7, 1)
	for x in (40, 160):
		ic.rect(x - 10, 82, 20, 16, 'chrome', r=2)
	ic.rect(50, 112, 100, 46, 'darksteel', r=4)
	ic.raw('<path d="M70,135 L86,118 L94,126 L116,104 L130,118" fill="none" stroke="#e6e9eb" stroke-width="6" '
		'stroke-linecap="round"/>')


def repair_kit(ic, o):
	ic.rect(14, 70, 172, 110, 'yellow', r=8)
	ic.rect(14, 70, 172, 30, 'darksteel', r=6)
	ic.line([(66, 70), (72, 40), (128, 40), (134, 70)], '#0b0d0e', 12, 1)
	ic.line([(66, 70), (72, 40), (128, 40), (134, 70)], '#2b2c2e', 7, 1)
	ic.rect(30, 116, 140, 46, 'polymer', r=4)
	ic.line([(46, 150), (110, 124)], '#c3cbd1', 8, 1)
	ic.circle(118, 120, 10, 'steel', sw=1.4)
	ic.line([(130, 150), (160, 126)], '#d6392d', 8, 1)


def bandage(ic, o):
	ic.ellipse(100, 140, 80, 40, 'white', kind='r')
	ic.rect(20, 80, 160, 60, 'white', kind='h', stroke='none')
	ic.line([(20, 80), (20, 140)], '#4a5054', 2.2, 1)
	ic.line([(180, 80), (180, 140)], '#4a5054', 2.2, 1)
	ic.ellipse(100, 80, 80, 40, 'white', kind='r')
	ic.ellipse(100, 80, 26, 12, '#9aa3aa', stroke='#4a5054', kind='flat')
	ic.poly([(176, 120), (196, 170), (170, 196), (150, 150)], 'white', r=4)
	for i in range(5):
		ic.dark([(30 + i * 34, 96), (30 + i * 34, 130)], w=1, opacity=0.15)


def painkillers(ic, o):
	ic.rect(50, 50, 100, 146, 'orange', r=10, kind='h', opacity=0.9)
	ic.rect(42, 20, 116, 36, 'white', r=6, kind='h')
	for x in range(50, 152, 8):
		ic.dark([(x, 24), (x, 52)], w=1.2, opacity=0.3)
	ic.rect(50, 96, 100, 60, 'white', r=2, kind='h')
	ic.text(100, 122, 'Rx', 18, '#d6392d', 900)
	ic.text(100, 144, '500 mg', 11, '#333333', 700)
	ic.hl([(60, 62), (60, 186)], w=5, opacity=0.35)


def baggie(ic, o):
	"""Saquinho zip com conteúdo (cocaína, metanfetamina, maconha)."""
	ic.poly([(30, 30), (170, 30), (176, 190), (24, 190)], 'glass', r=8, opacity=0.6)
	ic.rect(28, 30, 144, 14, 'red', r=3)
	c = o.get('content')
	if c == 'coke':
		ic.raw('<path d="M34,190 L36,120 C60,100 140,104 166,124 L170,190Z" fill="url(#snow-r)" stroke="#5a6a78" '
			'stroke-width="1.8"/>')
		ic.grad('snow', 'r')
	elif c == 'meth':
		for x, y in ((50, 150), (80, 130), (110, 150), (140, 130), (70, 170), (120, 172), (150, 166), (96, 110),
				(60, 110), (136, 104)):
			ic.poly([(x, y - 14), (x + 12, y - 4), (x + 8, y + 12), (x - 10, y + 10), (x - 12, y - 4)], 'cyan', r=1,
				sw=1.4)
	elif c == 'weed':
		for x, y, r in ((70, 140, 30), (130, 146, 32), (100, 110, 28), (100, 166, 24)):
			ic.circle(x, y, r, 'green', kind='r')
			for a in range(0, 360, 60):
				p = arc_points(x, y, r * 0.6, r * 0.6, a, a, 1)[0]
				ic.dot(p[0], p[1], 3, '#d1a24a', 0.9)
	ic.hl([(36, 52), (34, 184)], w=5, opacity=0.5)
	ic.hl([(150, 54), (156, 90)], w=3, opacity=0.4)


# ---------------------------------------------------------------- dinheiro e documentos
def money(ic, o):
	mat = o.get('mat', 'money')
	for i in range(4):
		ic.rect(20 + i * 4, 70 - i * 12, 170, 90, mat, r=4)
	x0, y0 = 32, 34
	ic.rect(x0 - 2, y0 + 2, 166, 82, mat, r=3, stroke='none', opacity=0.0)
	ic.ellipse(x0 + 84, y0 + 46, 22, 26, '#000000', stroke='none', opacity=0.15)
	ic.text(x0 + 84, y0 + 56, '$', 30, '#1e3a15' if mat == 'money' else '#3a1510', 900)
	ic.text(x0 + 18, y0 + 24, '100', 13, '#1e3a15' if mat == 'money' else '#3a1510', 900)
	ic.rect(x0 + 60, 10, 48, 150, o.get('band', 'white'), r=2)
	if o.get('dirty'):
		for x, y in ((50, 120), (150, 70), (130, 140)):
			ic.dot(x, y, 8, '#3a1c0b', 0.35)


def card(ic, o):
	ic.rect(10, 40, 180, 116, o.get('mat', 'navy'), r=12)
	if o.get('kind') == 'id':
		ic.rect(10, 40, 180, 26, 'accent', r=10)
		ic.text(100, 59, 'IDENTIDADE', 13, '#1a2510', 900)
		ic.rect(24, 76, 50, 62, 'paper', r=4)
		ic.circle(49, 98, 12, 'skin', sw=1.4)
		ic.poly([(30, 138), (34, 118), (64, 118), (68, 138)], 'navy', r=6, sw=1.4)
		for i, w in enumerate((90, 70, 80, 50)):
			ic.rect(86, 82 + i * 14, w, 6, '#ffffff', stroke='none', r=2, opacity=0.55)
	else:
		ic.rect(28, 76, 34, 26, 'gold', r=4)
		ic.dark([(28, 89), (62, 89)], w=1, opacity=0.4)
		ic.dark([(45, 76), (45, 102)], w=1, opacity=0.4)
		ic.text(100, 128, '4532  ••••  ••••  9010', 11, '#e6edf5', 700, family='DejaVu Sans Mono')
		ic.circle(156, 72, 12, 'red', sw=1.2, opacity=0.9)
		ic.circle(170, 72, 12, 'yellow', sw=1.2, opacity=0.9)
	ic.hl([(22, 46), (178, 46)], w=2, opacity=0.4)


def paper_wallet(ic, o):
	ic.poly([(20, 30), (180, 20), (186, 176), (14, 186)], 'paper', r=4)
	ic.rect(36, 52, 64, 64, 'white', r=2, sw=1.4)
	import random
	rnd = random.Random(7)
	for i in range(7):
		for j in range(7):
			if rnd.random() < 0.5 or (i < 2 and j < 2) or (i > 4 and j < 2) or (i < 2 and j > 4):
				ic.rect(40 + i * 8, 56 + j * 8, 8, 8, '#1a1a1a', stroke='none')
	ic.text(140, 74, '₿', 34, '#e7bf4a', 900)
	for i, w in enumerate((130, 110, 120)):
		ic.rect(36, 134 + i * 12, w, 5, '#555555', stroke='none', r=2, opacity=0.6)


# ---------------------------------------------------------------- chaves e ferramentas
def key(ic, o):
	mat = o.get('mat', 'steel')
	ic.circle(50, 100, 40, mat)
	ic.circle(50, 100, 14, '#0c1110', stroke=None if False else '#262b2e', sw=2)
	ic.poly([(84, 90), (196, 90), (196, 110), (186, 110), (186, 122), (172, 122), (172, 110), (160, 110), (160, 126),
		(146, 126), (146, 110), (84, 110)], mat, r=1)
	ic.hl([(90, 94), (190, 94)], w=2, opacity=0.5)
	if o.get('old'):
		ic.circle(50, 100, 40, 'brass')
		ic.circle(50, 100, 18, '#0c1110', stroke='#432c0b', sw=2)
		ic.dark(arc_points(50, 100, 30, 30, 0, 360, 24), w=1.4, opacity=0.4)


def carkey(ic, o):
	ic.rect(20, 50, 100, 110, 'polymer', r=24)
	ic.circle(70, 84, 12, 'darksteel', sw=1.4)
	ic.circle(70, 126, 12, 'darksteel', sw=1.4)
	ic.dot(70, 84, 4, '#c4df9b')
	ic.poly([(114, 94), (196, 94), (196, 104), (186, 104), (186, 114), (170, 114), (170, 108), (114, 112)], 'steel', r=1)
	ic.circle(40, 60, 14, '#0c1110', stroke='#2a3034', sw=4)


def lockpick(ic, o):
	ic.line([(20, 150), (170, 40), (186, 46), (180, 30)], '#262b2e', 7, 1)
	ic.line([(20, 150), (170, 40), (186, 46), (180, 30)], '#c3cbd1', 4, 1)
	ic.line([(30, 170), (176, 80), (196, 80)], '#262b2e', 7, 1)
	ic.line([(30, 170), (176, 80), (196, 80)], '#c3cbd1', 4, 1)
	ic.rect(4, 140, 56, 22, 'rubber', r=8)
	ic.rect(14, 162, 56, 22, 'red', r=8)


def ziptie(ic, o):
	ic.raw('<path d="M40,140 C10,80 60,30 110,40 C170,52 190,120 150,156" fill="none" stroke="#0b0d0e" '
		'stroke-width="14" stroke-linecap="round"/><path d="M40,140 C10,80 60,30 110,40 C170,52 190,120 150,156" '
		'fill="none" stroke="#e6e9eb" stroke-width="9" stroke-linecap="round"/>', [(14, 30), (190, 160)])
	ic.rect(30, 132, 30, 26, 'white', r=4)
	ic.line([(60, 146), (196, 176)], '#0b0d0e', 14, 1)
	ic.line([(60, 146), (196, 176)], '#e6e9eb', 9, 1)
	for x in range(76, 190, 10):
		ic.dark([(x, 146 + (x - 60) * 0.22 - 3), (x, 146 + (x - 60) * 0.22 + 3)], w=1, opacity=0.4)


# ---------------------------------------------------------------- eletrônicos
def phone(ic, o):
	ic.rect(50, 4, 100, 196, 'polymer', r=18)
	ic.rect(56, 12, 88, 180, 'screen', r=12, sw=1.2)
	ic.raw('<defs><linearGradient id="wall" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#2d4a3a"/>'
		'<stop offset="1" stop-color="#c4df9b"/></linearGradient></defs>'
		'<rect x="60" y="16" width="80" height="172" rx="10" fill="url(#wall)" opacity="0.85"/>')
	for i in range(3):
		for j in range(4):
			ic.rect(68 + i * 24, 40 + j * 26, 16, 16, '#ffffff', stroke='none', r=4, opacity=0.35)
	ic.rect(86, 18, 28, 6, '#0b0d0e', stroke='none', r=3)
	ic.hl([(60, 20), (60, 180)], w=2, opacity=0.25)


def radio(ic, o):
	ic.rect(86, 4, 12, 60, 'rubber', r=5)
	ic.rect(110, 20, 10, 40, 'polymer', r=3)
	ic.rect(50, 50, 100, 150, 'polymer', r=14)
	ic.rect(60, 64, 80, 36, 'screen', r=4)
	ic.rect(64, 68, 72, 28, '#7cc443', stroke='none', r=2, opacity=0.6)
	ic.text(100, 89, 'CH 01', 14, '#0f2a0a', 900, family='DejaVu Sans Mono')
	for j in range(4):
		ic.dark([(64, 120 + j * 12), (136, 120 + j * 12)], w=4, opacity=0.5)
	ic.rect(40, 90, 12, 40, 'rubber', r=3)


def laptop(ic, o):
	ic.poly([(40, 20), (170, 20), (170, 130), (40, 130)], 'darksteel', r=8)
	ic.rect(48, 28, 114, 94, 'screen', r=3, sw=1.2)
	ic.raw('<rect x="52" y="32" width="106" height="86" rx="2" fill="%s" opacity="0.8"/>' % o.get('screen', '#1d6f8f'))
	if o.get('onion'):
		ic.text(105, 86, '🧅', 30, '#b06ad6', 400)
	ic.poly([(20, 140), (190, 140), (200, 170), (10, 170)], 'steel', r=6)
	ic.poly([(40, 144), (170, 144), (176, 158), (34, 158)], 'darksteel', r=3, sw=1)
	ic.rect(80, 160, 50, 6, 'darksteel', r=2, sw=1)


def desktop_pc(ic, o):
	ic.rect(110, 20, 80, 170, 'polymer', r=8)
	ic.rect(120, 34, 60, 10, 'darksteel', r=2, sw=1)
	ic.rect(120, 52, 60, 10, 'darksteel', r=2, sw=1)
	ic.circle(150, 160, 8, 'darksteel', sw=1.4)
	ic.glow(150, 160, 14, '#c4df9b', 0.8)
	ic.rect(118, 80, 64, 60, '#2a1a4a', stroke='none', r=3, opacity=0.6)
	for i, c in enumerate(('#ff4a8a', '#4ad6ff', '#c4df9b')):
		ic.circle(132 + i * 18, 110, 7, c, stroke='#0b0d0e', sw=1.2)
	ic.rect(4, 40, 110, 80, 'polymer', r=6)
	ic.rect(10, 46, 98, 68, 'screen', r=2, sw=1)
	ic.raw('<rect x="13" y="49" width="92" height="62" rx="2" fill="#1d6f8f" opacity="0.8"/>')
	ic.rect(46, 120, 26, 30, 'darksteel', r=2)
	ic.rect(26, 150, 66, 10, 'darksteel', r=3)


def home_server(ic, o):
	for i in range(4):
		y = 20 + i * 44
		ic.rect(20, y, 160, 40, 'polymer', r=4)
		for x in range(34, 120, 12):
			ic.rect(x, y + 12, 8, 16, 'darksteel', r=2, sw=1)
		ic.dot(150, y + 14, 4, '#7cff7c')
		ic.dot(164, y + 14, 4, '#ffbf3f' if i % 2 else '#7cff7c')
		ic.rect(140, y + 24, 30, 6, '#0b0d0e', stroke='none', r=2)


def race_tablet(ic, o):
	# Tablet de corridas: capa emborrachada, cantos com faixa de perigo e bandeira quadriculada na tela.
	ic.rect(8, 40, 184, 124, 'rubber', r=16)
	ic.rect(20, 50, 160, 104, 'polymer', r=8)
	ic.rect(26, 56, 148, 92, 'screen', r=4, sw=1.2)
	ic.raw('<rect x="29" y="59" width="142" height="86" rx="3" fill="#0b0b0d"/>')
	cells = []
	for row in range(4):
		for col in range(6):
			if (row + col) % 2 == 0:
				cells.append('<rect x="%d" y="%d" width="12" height="12" fill="#f2f2f0"/>' % (64 + col * 12, 70 + row * 12))
	ic.raw('<g transform="skewX(-12) translate(18 0)">' + ''.join(cells) + '</g>')
	ic.raw('<rect x="56" y="70" width="4" height="62" fill="#9a9aa3"/>')
	ic.raw('<rect x="29" y="128" width="142" height="5" fill="#ffd400"/><rect x="29" y="134" width="90" height="4" fill="#ff2e88"/>')
	for x0, y0 in ((26, 41), (114, 154)):
		stripes = ''.join('<path d="M%d %d l8 0 l-3 8 l-8 0 z" fill="#ffd400"/>' % (x0 + i * 14, y0) for i in range(5))
		ic.raw('<g opacity="0.95">' + stripes + '</g>')
	ic.glow(160, 66, 10, '#ff2e88', 0.7)
	ic.hl([(30, 60), (30, 140)], w=2, opacity=0.25)


def usb(ic, o):
	mat = o.get('mat', 'polymer')
	ic.rect(30, 70, 120, 60, mat, r=12)
	ic.rect(146, 80, 46, 40, 'chrome', r=3, kind='cyl')
	ic.rect(160, 90, 10, 8, '#0b0d0e', stroke='none')
	ic.rect(176, 90, 10, 8, '#0b0d0e', stroke='none')
	ic.circle(48, 100, 9, '#0c1110', stroke='#2a3034', sw=3)
	if o.get('glow'):
		ic.dot(126, 100, 5, o['glow'])
		ic.glow(126, 100, 14, o['glow'], 0.8)
	if o.get('label'):
		ic.text(96, 106, o['label'], 16, o.get('label_color', '#c4df9b'), 900)


def hw_wallet(ic, o):
	ic.rect(30, 50, 140, 100, 'darksteel', r=14)
	ic.rect(50, 66, 90, 50, 'screen', r=4, sw=1.2)
	ic.text(95, 99, '₿ 0.42', 14, '#e7bf4a', 900)
	ic.circle(156, 80, 8, 'chrome', sw=1.2)
	ic.circle(156, 116, 8, 'chrome', sw=1.2)
	ic.rect(166, 86, 30, 24, 'chrome', r=2)


def news_camera(ic, o):
	ic.rect(30, 60, 140, 80, 'polymer', r=10)
	ic.rect(166, 70, 30, 60, 'darksteel', r=6, kind='cyl')
	ic.circle(190, 100, 22, 'polymer')
	ic.circle(190, 100, 14, '#3a7fd6', kind='r')
	ic.rect(40, 30, 90, 32, 'polymer', r=6)
	ic.dot(60, 76, 5, '#ff3b30')
	ic.rect(4, 70, 30, 50, 'rubber', r=6)
	ic.rect(60, 90, 70, 30, 'white', r=3)
	ic.text(95, 110, 'NEWS', 14, '#d6392d', 900)


def news_mic(ic, o):
	ic.rect(80, 70, 40, 130, 'polymer', r=8, kind='h')
	ic.rect(70, 70, 60, 40, 'red', r=4)
	ic.text(100, 96, 'TV', 16, '#ffffff', 900)
	ic.circle(100, 44, 34, 'darksteel', kind='r')
	for a in range(-24, 25, 8):
		ic.dark([(100 + a, 16), (100 + a, 72)], w=1, opacity=0.4)


def news_boom(ic, o):
	ic.line([(10, 190), (150, 60)], '#0b0d0e', 10, 1)
	ic.line([(10, 190), (150, 60)], '#a7afb5', 6, 1)
	ic.rect(130, 24, 70, 50, 'cloth', r=24, kind='cyl')
	for x in range(140, 196, 8):
		ic.dark([(x, 28), (x, 70)], w=1.2, opacity=0.25)


# ---------------------------------------------------------------- roupas e equipamentos
def panties(ic, o):
	ic.poly([(20, 50), (180, 50), (170, 80), (120, 150), (80, 150), (30, 80)], 'pink', r=[6, 6, 30, 10, 10, 30])
	ic.rect(20, 46, 160, 14, 'pink', r=6)
	ic.circle(100, 66, 7, 'red', sw=1.2)
	ic.hl([(30, 52), (170, 52)], w=2, opacity=0.5)


def parachute(ic, o):
	ic.rect(30, 30, 140, 160, 'olive', r=26)
	ic.rect(50, 50, 100, 60, 'olive', r=12)
	ic.line([(40, 20), (40, 200)], '#1a1e11', 10, 1)
	ic.line([(160, 20), (160, 200)], '#1a1e11', 10, 1)
	ic.rect(30, 130, 140, 14, 'polymer', r=4)
	ic.rect(86, 126, 28, 22, 'chrome', r=3)
	ic.rect(100, 160, 30, 16, 'red', r=4)


# ---------------------------------------------------------------- peças automotivas
def oil(ic, o):
	ic.poly([(40, 50), (150, 50), (160, 60), (160, 196), (40, 196)], 'yellow', r=8)
	ic.rect(56, 20, 40, 34, 'darksteel', r=4, kind='h')
	ic.poly([(120, 50), (150, 50), (160, 60), (160, 120), (120, 120)], '#000000', stroke='none', opacity=0.0)
	ic.rect(120, 56, 30, 70, '#0c1110', stroke='none', r=10, opacity=0.8)
	ic.rect(48, 110, 70, 70, 'darksteel', r=4)
	ic.text(83, 140, '5W30', 14, '#f2cc35', 900)
	ic.raw('<path d="M83,148 C76,160 76,168 83,172 C90,168 90,160 83,148Z" fill="#c47a20"/>')


def air_filter(ic, o):
	ic.ellipse(100, 150, 90, 34, 'polymer', kind='r')
	ic.rect(10, 70, 180, 80, 'red', stroke='none', kind='cyl')
	ic.line([(10, 70), (10, 150)], '#3a0805', 2.2, 1)
	ic.line([(190, 70), (190, 150)], '#3a0805', 2.2, 1)
	for x in range(18, 186, 9):
		ic.dark([(x, 72), (x, 148)], w=2, opacity=0.35)
	ic.ellipse(100, 70, 90, 34, 'chrome', kind='r')
	ic.ellipse(100, 70, 40, 15, '#0c1110', stroke='#2a3034')


def spark_plugs(ic, o):
	for i, x in enumerate((60, 140)):
		ic.rect(x - 8, 10, 16, 24, 'steel', r=3, kind='h')
		ic.rect(x - 18, 30, 36, 70, 'white', r=10, kind='h')
		for y in (40, 52, 64):
			ic.dark([(x - 16, y), (x + 16, y)], w=1.4, opacity=0.25)
		ic.poly([(x - 22, 100), (x + 22, 100), (x + 24, 116), (x + 22, 132), (x - 22, 132), (x - 24, 116)], 'steel', r=2,
			kind='h')
		ic.rect(x - 14, 132, 28, 36, 'darksteel', r=2, kind='h')
		for y in range(136, 168, 6):
			ic.dark([(x - 13, y), (x + 13, y + 2)], w=1.2, opacity=0.5)
		ic.line([(x, 168), (x, 184), (x + 10, 184)], '#262b2e', 3, 1)


def brake_pads(ic, o):
	for dy, dx in ((0, 0), (40, 30)):
		ic.raw('', None)
		pts = [(20 + dx, 40 + dy)] + arc_points(110 + dx, 220 + dy, 150, 150, 230, 310, 10) + [(200 + dx, 40 + dy),
			(170 + dx, 110 + dy)] + arc_points(110 + dx, 220 + dy, 110, 110, 310, 230, 10)
		ic.poly([(20 + dx, 60 + dy), (40 + dx, 30 + dy), (170 + dx, 30 + dy), (190 + dx, 60 + dy), (176 + dx, 100 + dy),
			(34 + dx, 100 + dy)], 'darksteel', r=10)
		ic.poly([(32 + dx, 64 + dy), (48 + dx, 42 + dy), (162 + dx, 42 + dy), (178 + dx, 64 + dy), (166 + dx, 92 + dy),
			(44 + dx, 92 + dy)], 'stone', r=8)


def brake_disc(ic, o):
	ic.circle(100, 100, 92, 'steel', kind='r')
	ic.circle(100, 100, 50, 'darksteel', kind='r')
	ic.circle(100, 100, 18, '#0c1110', stroke='#14181a')
	for a in range(0, 360, 72):
		p = arc_points(100, 100, 34, 34, a, a, 1)[0]
		ic.circle(p[0], p[1], 6, '#0c1110', stroke='#14181a', sw=1.4)
	for a in range(0, 360, 24):
		p = arc_points(100, 100, 72, 72, a, a, 1)[0]
		ic.dot(p[0], p[1], 3.5, '#5c656b', 0.9)
	ic.hl(arc_points(100, 100, 84, 84, 200, 280, 10), w=3, opacity=0.6)


def clutch(ic, o):
	ic.circle(100, 100, 92, 'stone', kind='r')
	ic.circle(100, 100, 72, 'darksteel', kind='r')
	ic.circle(100, 100, 30, 'steel', kind='r')
	ic.circle(100, 100, 12, '#0c1110', stroke='#262b2e')
	for a in range(0, 360, 60):
		p = arc_points(100, 100, 52, 52, a, a, 1)[0]
		ic.rect(p[0] - 8, p[1] - 6, 16, 12, 'copper', r=3, sw=1.4)
	for a in range(0, 360, 30):
		p = arc_points(100, 100, 82, 82, a, a, 1)[0]
		ic.dot(p[0], p[1], 3, '#4f4b43', 0.9)


def suspension(ic, o):
	ic.rect(84, 10, 32, 160, 'darksteel', r=6, kind='h')
	ic.rect(60, 30, 80, 14, 'steel', r=4, kind='h')
	ic.rect(60, 150, 80, 14, 'steel', r=4, kind='h')
	for i in range(8):
		y = 44 + i * 13.5
		ic.line([(62, y), (138, y + 7)], '#3a0805', 11, 1)
		ic.line([(62, y), (138, y + 7)], '#e2402f', 7, 1)
	ic.circle(100, 186, 12, 'steel', sw=1.6)
	ic.circle(100, 186, 5, '#0c1110', stroke='none')


def rubber(ic, o):
	ic.circle(100, 100, 90, 'rubber', kind='r')
	ic.circle(100, 100, 48, '#0c1110', stroke='#060606')
	for a in range(0, 360, 20):
		p0 = arc_points(100, 100, 72, 72, a, a, 1)[0]
		p1 = arc_points(100, 100, 88, 88, a + 8, a + 8, 1)[0]
		ic.line([p0, p1], '#000000', 3, 0.5)
	ic.hl(arc_points(100, 100, 82, 82, 200, 270, 10), w=3, opacity=0.25)


def plastic(ic, o):
	for i, (x, y, c) in enumerate(((60, 130, 'blue'), (130, 140, 'white'), (100, 90, 'yellow'))):
		ic.poly([(x - 40, y), (x - 20, y - 36), (x + 30, y - 40), (x + 44, y - 4), (x + 20, y + 30), (x - 30, y + 26)], c,
			r=8, opacity=0.95)


def scrapmetal(ic, o):
	ic.poly([(20, 140), (70, 60), (130, 70), (110, 160)], 'darksteel', r=4)
	ic.poly([(80, 150), (120, 50), (190, 80), (170, 170)], 'steel', r=4)
	ic.poly([(40, 180), (60, 120), (150, 130), (140, 190)], 'copper', r=4)
	for x, y in ((100, 90), (150, 120), (80, 160)):
		ic.circle(x, y, 4, 'darksteel', sw=1)
	ic.dot(160, 100, 10, '#7a3d1d', 0.4)


def jerry_small(ic, o):
	from melee import jerrycan
	jerrycan(ic, o)


# ---------------------------------------------------------------- recipientes e lixo
def paperbag(ic, o):
	ic.poly([(30, 50), (170, 50), (180, 196), (20, 196)], 'kraft', r=[2, 2, 6, 6])
	ic.poly([(30, 50), (50, 30), (70, 50), (90, 30), (110, 50), (130, 30), (150, 50), (170, 30), (170, 50)], 'kraft',
		r=2)
	ic.dark([(100, 60), (100, 190)], w=1.6, opacity=0.2)
	ic.hl([(36, 60), (28, 188)], w=4, opacity=0.3)


def trash(ic, o):
	k = o.get('k')
	if k == 'can':
		ic.group('rotate(70 100 100)')
		can(ic, dict(mat='red', label='', wave='#ffffff'))
		ic.end()
		ic.poly([(60, 70), (100, 60), (120, 80), (90, 100)], '#000000', stroke='none', opacity=0.0)
	elif k == 'bread':
		ic.poly([(20, 120), (60, 70), (120, 66), (170, 90), (180, 130), (150, 150), (60, 150)], 'bread', r=12)
		ic.poly([(120, 66), (170, 90), (180, 130), (150, 120), (140, 90)], 'cream', r=6)
		for x, y in ((60, 110), (100, 120), (140, 106)):
			ic.dot(x, y, 7, '#5f7a3a', 0.7)
	elif k == 'burger':
		ic.poly([(20, 160), (180, 150), (196, 186), (10, 190)], 'paper', r=4)
		ic.raw('<path d="M30,150 C30,90 150,80 160,140 Z" fill="url(#bread-r)" stroke="#4a2b0a" stroke-width="2.2"/>',
			[(30, 90), (160, 150)])
		ic.grad('bread', 'r')
		ic.poly([(100, 100), (130, 120), (110, 150)], '#0c1110', stroke='none', opacity=0.4)
	elif k == 'chips':
		ic.group('rotate(-24 100 100)')
		chips(ic, {})
		ic.end()
		ic.dark([(60, 60), (140, 150)], w=4, opacity=0.3)
	else:
		ic.poly([(40, 60), (160, 60), (150, 196), (50, 196)], 'darksteel', r=[4, 4, 8, 8], kind='h')
		for x in (70, 100, 130):
			ic.dark([(x, 72), (x - 2, 186)], w=3, opacity=0.4)
		ic.rect(30, 40, 140, 22, 'gunmetal', r=6, kind='h')
		ic.rect(80, 26, 40, 16, 'gunmetal', r=6)
		ic.poly([(70, 50), (90, 20), (110, 46)], 'paper', r=3)
	if o.get('flies'):
		pass


def garbage(ic, o):
	ic.poly([(20, 190), (30, 130), (70, 100), (130, 96), (170, 120), (186, 190)], 'blackleather', r=16)
	ic.poly([(40, 130), (70, 70), (100, 60)], 'paper', r=4)
	ic.poly([(120, 110), (150, 60), (176, 80), (150, 120)], 'cardboard', r=4)
	ic.rect(76, 76, 26, 50, 'greenglass', r=6, opacity=0.9)
	ic.hl([(36, 150), (40, 180)], w=4, opacity=0.25)
