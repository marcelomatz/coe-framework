"""Armas especiais: lançadores, armas de energia, espingardas especiais e pistolas incomuns."""
from lib import arc_points
import parts as P
import firearms as F


def stungun(ic, o):
	ic.poly([(20, -20), (120, -20), (130, -12), (130, 4), (60, 6), (20, 4)], 'yellow', r=[6, 4, 4, 3, 3, 6])
	ic.rect(118, -14, 14, 14, 'polymer', r=2)
	ic.rect(130, -12, 6, 4, 'steel', r=1, sw=1.4)
	ic.rect(130, -4, 6, 4, 'steel', r=1, sw=1.4)
	ic.hl([(26, -17), (118, -17)], w=1.6, opacity=0.6)
	ic.rect(34, -15, 50, 8, 'polymer', r=3)
	ic.text(59, -9, 'TASER', 7, '#f2cc35', 800)
	ic.poly([(26, 2), (56, 4), (50, 50), (22, 52), (14, 30)], 'polymer', r=[3, 3, 6, 6, 8])
	tg = [(56, 4)] + arc_points(68, 8, 12, 11, 160, 20, 8)[1:] + [(80, 5)]
	ic.line(tg, '#0b0d0e', 5, 1)
	ic.line(tg, '#3a3f43', 2.6, 1)
	ic.rect(18, 48, 34, 6, 'yellow', r=2)


def flaregun(ic, o):
	ic.rect(60, -26, 90, 26, 'orange', r=8, kind='cyl')
	ic.ellipse(150, -13, 5, 12, 'orange', kind='h')
	ic.ellipse(151, -13, 3, 8, '#2a1405', stroke='none')
	ic.poly([(30, -24), (66, -26), (66, 2), (40, 6)], 'orange', r=4)
	ic.poly([(32, 0), (62, 2), (54, 50), (22, 52), (16, 30)], 'orange', r=[3, 3, 6, 6, 8])
	ic.hl([(64, -21), (146, -21)], w=2, opacity=0.5)
	ic.poly([(32, -22), (20, -32), (18, -24), (28, -14)], 'darksteel', r=2, sw=1.8)
	tg = [(60, 2)] + arc_points(72, 6, 12, 11, 160, 20, 8)[1:] + [(84, 3)]
	ic.line(tg, '#0b0d0e', 5, 1)
	ic.line(tg, '#a5520f', 2.6, 1)


def raypistol(ic, o):
	ic.poly([(40, -22), (110, -26), (140, -14), (140, -6), (110, 6), (40, 4)], 'chrome', r=[8, 8, 4, 4, 8, 8])
	for i, x in enumerate((70, 84, 98)):
		ic.ellipse(x, -10, 5, 17 - i * 2, 'red', kind='h')
	ic.rect(140, -14, 12, 8, 'chrome', r=3, kind='cyl')
	ic.circle(156, -10, 6, 'cyan', kind='r')
	ic.glow(156, -10, 14, '#7ff3ff', 0.8)
	ic.poly([(46, -28), (60, -40), (76, -40), (70, -24)], 'red', r=4)
	ic.poly([(42, 2), (70, 4), (60, 50), (30, 52), (26, 30)], 'red', r=[3, 3, 6, 6, 8])
	ic.hl([(46, -19), (130, -18)], w=2, opacity=0.6)


def gadgetpistol(ic, o):
	F.pistol(ic, dict(slide='gold', frame='navy', grip='navy', length=130, rail=False, serrations=None, comp=True))


def marksmanpistol(ic, o):
	P.barrel(ic, 60, 186, 5.5, 'blued')
	ic.rect(60, -12, 128, 4, 'blued', r=1)
	ic.rect(180, -16, 4, 6, 'blued', r=1)
	ic.poly([(26, -14), (64, -14), (64, 10), (36, 12), (24, 0)], 'blued', r=3)
	ic.poly([(24, 6), (52, 10), (44, 58), (14, 60), (8, 34)], 'wood', r=[3, 3, 6, 6, 8])
	ic.poly([(28, -10), (16, -22), (14, -14), (24, -4)], 'darksteel', r=2, sw=1.8)
	tg = [(52, 10)] + arc_points(64, 14, 12, 11, 160, 20, 8)[1:] + [(76, 10)]
	ic.line(tg, '#0b0d0e', 5, 1)
	ic.line(tg, '#2c3440', 2.6, 1)


def pistolxm3(ic, o):
	F.pistol(ic, dict(slide='olive', frame='polymer', length=150, slide_cut=True, comp=True, mk2=True))
	ic.glow(60, -8, 6, '#c4df9b', 0.9)


def assaultshotgun(ic, o):
	ic.rect(120, -6, 90, 7, 'darksteel', r=2, kind='cyl')
	P.muzzle(ic, 208, 'brake', 3.5)
	ic.poly([(20, -14), (140, -14), (150, -8), (150, 10), (20, 10), (10, 0)], 'polymer', r=3)
	ic.rect(4, -12, 18, 30, 'polymer', r=3)
	ic.rect(0, -14, 6, 34, 'rubber', r=2)
	ic.hl([(24, -11), (146, -11)], w=1.4, opacity=0.35)
	P.carry_handle(ic, 40, -14, 60)
	P.pistol_grip(ic, 50, 10, 'polymer', length=30, slant=10, w=15)
	P.trigger_guard(ic, 65, 10, 17, 11)
	P.mag_drum(ic, 104, 30, 18)
	ic.rect(98, 10, 12, 6, 'polymer', r=1)
	P.vents(ic, 112, 146, -2, h=4, step=8, opacity=0.6)


def bullpupshotgun(ic, o):
	ic.rect(116, -10, 82, 7, 'darksteel', r=2, kind='cyl')
	ic.rect(116, -2, 74, 7, 'darksteel', r=2, kind='cyl')
	ic.rect(116, 6, 74, 7, 'darksteel', r=2, kind='cyl')
	ic.rect(134, 2, 40, 16, 'polymer', r=6, kind='cyl')
	F.bullpup(ic, dict(mat='polymer', body_end=124, barrel_end=124, optic='reddot', mag='none'))


def heavyshotgun(ic, o):
	F.rifle(ic, dict(stock='ar', furniture='polymer', handguard='rail', handguard_end=160, barrel_end=196, mag='drum',
		mat='gunmetal', muzzle='brake', optic='holo', receiver=(52, 116)))


def autoshotgun(ic, o):
	P.barrel(ic, 120, 200, 4)
	ic.rect(120, 4, 70, 7, 'darksteel', r=3, kind='cyl')
	ic.rect(130, 8, 36, 14, 'polymer', r=4)
	ic.poly([(40, -12), (124, -12), (124, 12), (40, 12)], 'gunmetal', r=3)
	ic.circle(92, 6, 28, 'gunmetal', kind='r')
	ic.circle(92, 6, 18, 'darksteel', kind='r')
	for a in range(0, 360, 45):
		p = arc_points(92, 6, 22, 22, a, a, 1)[0]
		ic.dot(p[0], p[1], 3, '#0b0d0e', 0.8)
	ic.dot(92, 6, 4, '#0b0d0e')
	F._stock(ic, 'wire', 42, 'polymer')
	P.pistol_grip(ic, 46, 12, 'polymer', length=30, slant=10, w=15)
	P.sight_post(ic, 196, -12, 8, 'steel')


def minigun(ic, o):
	for i, y in enumerate((-12, -4, 4, 12)):
		ic.rect(80, y - 3, 132, 6, 'darksteel', r=2, kind='cyl')
	ic.rect(150, -18, 10, 36, 'gunmetal', r=2, kind='h')
	ic.rect(196, -18, 8, 36, 'gunmetal', r=2, kind='h')
	ic.rect(30, -24, 54, 48, 'gunmetal', r=8)
	ic.hl([(36, -20), (80, -20)], w=1.6, opacity=0.4)
	ic.rect(36, -36, 40, 10, 'polymer', r=3)
	ic.rect(10, -10, 22, 30, 'polymer', r=4)
	P.mag_box(ic, 40, 24, 40, 30, 'olive')
	ic.line([(60, 24), (78, 14)], '#b08a3a', 4, 1)


def rpg(ic, o):
	ic.rect(30, -9, 150, 18, 'olive', r=4, kind='cyl')
	ic.rect(20, -12, 14, 24, 'darksteel', r=3, kind='cyl')
	ic.poly([(176, -10), (196, -14), (216, -6), (226, 0), (216, 6), (196, 14), (176, 10)], 'olive', r=3, kind='cyl')
	ic.poly([(196, -14), (216, -6), (226, 0), (216, 6), (196, 14)], 'darkgreen', r=3, kind='cyl')
	ic.rect(90, -12, 30, 24, 'wood', r=4, kind='cyl')
	P.pistol_grip(ic, 70, 9, 'polymer', length=26, slant=6, w=13)
	P.pistol_grip(ic, 120, 9, 'polymer', length=26, slant=6, w=13)
	ic.rect(96, -26, 22, 14, 'polymer', r=3)
	ic.rect(116, -23, 3, 8, '#6fc6ff', stroke='none')


def hominglauncher(ic, o):
	ic.rect(20, -16, 180, 30, 'olive', r=6, kind='cyl')
	ic.rect(14, -18, 10, 34, 'darksteel', r=3)
	ic.rect(198, -18, 10, 34, 'darksteel', r=3)
	ic.rect(80, -38, 46, 22, 'polymer', r=4)
	ic.rect(122, -34, 4, 14, '#ff6b5e', stroke='none', r=1)
	ic.dot(90, -27, 3, '#ff3b30')
	P.pistol_grip(ic, 90, 13, 'polymer', length=28, slant=8, w=14)
	ic.hl([(28, -10), (190, -10)], w=2, opacity=0.35)


def grenadelauncher(ic, o):
	mat = o.get('mat', 'olive')
	P.barrel(ic, 120, 196, 9, mat)
	ic.ellipse(196, 0, 3, 9, '#0b0d0e', stroke='none')
	ic.rect(76, -24, 48, 48, mat, r=10)
	for y in (-14, 0, 14):
		ic.rect(80, y - 5, 40, 10, 'darksteel', r=5, kind='cyl')
	ic.rect(122, 10, 40, 14, 'polymer', r=4)
	F._stock(ic, 'ar', 78, 'polymer')
	P.pistol_grip(ic, 84, 24, 'polymer', length=28, slant=10, w=14)
	if o.get('smoke'):
		P.accent_band(ic, 150, -10, 8, 20, '#9ec7e6')


def compactlauncher(ic, o):
	P.barrel(ic, 60, 160, 10, 'gunmetal')
	ic.ellipse(160, 0, 3, 10, '#0b0d0e', stroke='none')
	ic.poly([(30, -12), (70, -12), (70, 14), (40, 16)], 'polymer', r=4)
	P.pistol_grip(ic, 30, 12, 'polymer', length=34, slant=10, w=16)
	P.trigger_guard(ic, 46, 14, 17, 11)
	ic.rect(90, 10, 46, 10, 'polymer', r=4)


def emplauncher(ic, o):
	ic.rect(60, -18, 140, 30, 'gunmetal', r=8, kind='cyl')
	for x in (80, 110, 140, 170):
		ic.rect(x, -20, 14, 34, 'darksteel', r=3, kind='h')
		ic.rect(x + 4, -18, 6, 30, '#46c6e0', stroke='none', r=2, opacity=0.8)
	ic.glow(196, -3, 20, '#7ff3ff', 0.7)
	ic.circle(200, -3, 9, 'cyan')
	F._stock(ic, 'ar', 62, 'polymer')
	P.pistol_grip(ic, 70, 10, 'polymer', length=30, slant=10, w=15)
	ic.rect(110, 12, 40, 12, 'polymer', r=4)


def firework(ic, o):
	ic.rect(30, -14, 170, 28, 'red', r=6, kind='cyl')
	for x in (60, 100, 140):
		ic.rect(x, -15, 16, 30, 'yellow', r=2, kind='cyl')
	ic.rect(196, -16, 10, 32, 'gold', r=3)
	ic.poly([(206, -10), (224, 0), (206, 10)], 'blue', r=2)
	P.pistol_grip(ic, 84, 12, 'polymer', length=28, slant=8, w=14)
	ic.rect(20, -16, 12, 32, 'darksteel', r=3)


def railgun(ic, o):
	glow = o.get('glow', '#46c6e0')
	ic.rect(30, -22, 150, 36, o.get('mat', 'gunmetal'), r=6)
	ic.rect(176, -12, 50, 8, 'darksteel', r=2, kind='cyl')
	ic.rect(176, 2, 50, 8, 'darksteel', r=2, kind='cyl')
	for x in range(60, 170, 18):
		ic.rect(x, -26, 10, 44, 'copper', r=3, kind='h')
	ic.rect(56, -6, 120, 6, glow, stroke='none', r=2, opacity=0.9)
	ic.glow(226, -2, 16, glow, 0.8)
	ic.rect(4, -18, 30, 30, 'polymer', r=6)
	P.pistol_grip(ic, 60, 14, 'polymer', length=30, slant=10, w=15)
	ic.rect(70, -40, 50, 16, 'polymer', r=4)
	ic.rect(116, -36, 4, 8, glow, stroke='none')


def raycarbine(ic, o):
	ic.poly([(40, -16), (170, -18), (196, -8), (196, 4), (170, 12), (40, 12)], 'chrome', r=6)
	for x in (90, 110, 130, 150):
		ic.ellipse(x, -3, 6, 20, 'red', kind='h')
	ic.rect(196, -8, 20, 12, 'chrome', r=4, kind='cyl')
	ic.circle(220, -2, 7, 'cyan')
	ic.glow(220, -2, 16, '#7ff3ff', 0.8)
	ic.poly([(40, -14), (6, -8), (2, 20), (40, 12)], 'red', r=4)
	P.pistol_grip(ic, 56, 12, 'red', length=30, slant=10, w=15, stipple=False)
	ic.hl([(46, -12), (186, -12)], w=2, opacity=0.6)


def rayminigun(ic, o):
	for y in (-10, 0, 10):
		ic.rect(110, y - 4, 110, 8, 'chrome', r=3, kind='cyl')
	for x in (140, 180):
		ic.ellipse(x, 0, 6, 22, 'red', kind='h')
	ic.glow(222, 0, 18, '#7ff3ff', 0.8)
	ic.rect(30, -26, 86, 52, 'chrome', r=14)
	ic.circle(70, 0, 16, 'red')
	ic.circle(70, 0, 8, 'cyan')
	ic.rect(44, -40, 40, 12, 'red', r=4)
