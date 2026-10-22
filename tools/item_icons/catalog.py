"""Registro nome do item -> (função de desenho, opções)."""
from lib import Icon
import firearms as F

ICONS = {}


def reg(names, fn, **opts):
	for name in names.split():
		ICONS[name] = (fn, opts)


def gun(builder, box=232, rotate=0, dy=0, stretch=1.0):
	def draw(name, **o):
		ic = Icon(name)
		builder(ic, o)
		return ic.svg(box=box, rotate=rotate, dy=dy, stretch=stretch)
	return draw


RIFLE = gun(F.rifle, box=236, stretch=1.2)
BULLPUP = gun(F.bullpup, box=234, stretch=1.15)
PISTOL = gun(F.pistol, box=206)
REVOLVER = gun(F.revolver, box=206)
SMG = gun(F.smg_boxy, box=214)
PUMP = gun(F.shotgun_pump, box=236, stretch=1.15)
DOUBLE = gun(F.double_barrel, box=226, stretch=1.1)
SNIPER = gun(F.sniper, box=240, stretch=1.15)

# --- pistolas ---
reg('WEAPON_PISTOL', PISTOL)
reg('WEAPON_PISTOL_MK2', PISTOL, slide_cut=True, mk2=True, optic='reddot', comp=False)
reg('WEAPON_COMBATPISTOL', PISTOL, slide='polymer', length=142)
reg('WEAPON_APPISTOL', PISTOL, slide='polymer', mag_out=18, length=146)
reg('WEAPON_PISTOL50', PISTOL, slide='chrome', frame='chrome', grip='rubber', length=170, slide_h=28, serrations='rear',
	hammer=True, rail=False)
reg('WEAPON_HEAVYPISTOL', PISTOL, slide='steel', frame='steel', grip='wood', hammer=True, length=156, rail=False)
reg('WEAPON_SNSPISTOL', PISTOL, slide='steel', frame='steel', grip='wood', length=110, grip_len=50, grip_w=30,
	rail=False, hammer=True)
reg('WEAPON_SNSPISTOL_MK2', PISTOL, slide='tan', frame='polymer', length=112, grip_len=52, grip_w=30, mk2=True,
	slide_cut=True)
reg('WEAPON_VINTAGEPISTOL', PISTOL, slide='blued', frame='blued', grip='darkwood', length=132, serrations=None,
	rail=False, slide_h=22)
reg('WEAPON_CERAMICPISTOL', PISTOL, slide='white', frame='white', grip='white', length=130, rail=False)

# --- revólveres ---
reg('WEAPON_REVOLVER', REVOLVER, frame='steel', grip='rubber', barrel_len=86)
reg('WEAPON_REVOLVER_MK2', REVOLVER, frame='blued', grip='rubber', barrel_len=80, comp=True, mk2=True)
reg('WEAPON_DOUBLEACTION', REVOLVER, frame='blued', grip='gold', panel='gold', barrel_len=62, rib=False)
reg('WEAPON_NAVYREVOLVER', REVOLVER, frame='brass', grip='darkwood', barrel_len=104, octagonal=True)

# --- fuzis ---
reg('WEAPON_CARBINERIFLE', RIFLE, optic=None, muzzle='flash')
reg('WEAPON_CARBINERIFLE_MK2', RIFLE, optic='scope', muzzle='brake', mk2=True, furniture='tan')
reg('WEAPON_ASSAULTRIFLE', RIFLE, stock='ak', furniture='wood', handguard='wood', handguard_end=150, barrel_end=204,
	gas_tube=44, mag='curved', mat='gunmetal', rail=False, muzzle='comp', optic='irons', bolt=True)
reg('WEAPON_ASSAULTRIFLE_MK2', RIFLE, stock='ak', furniture='polymer', handguard='rail', handguard_end=158,
	barrel_end=204, mag='curved', mat='gunmetal', muzzle='brake', optic='reddot', mk2=True)
reg('WEAPON_SPECIALCARBINE', RIFLE, stock='skeleton', optic='carry', mag_mat='glass', handguard='round', muzzle='flash',
	rail=False, furniture='polymer')
reg('WEAPON_SPECIALCARBINE_MK2', RIFLE, stock='skeleton', optic='holo', mag_mat='glass', handguard='rail',
	muzzle='brake', furniture='olive', mk2=True)
reg('WEAPON_COMPACTRIFLE', RIFLE, stock='none', furniture='wood', handguard='wood', handguard_end=146, barrel_end=170,
	gas_tube=30, mag='curved', mat='gunmetal', rail=False, muzzle='plain', optic='irons')
reg('WEAPON_ADVANCEDRIFLE', BULLPUP, mat='polymer', optic='reddot')
reg('WEAPON_BULLPUPRIFLE', BULLPUP, mat='olive', optic='carry', mag='curved')
reg('WEAPON_BULLPUPRIFLE_MK2', BULLPUP, mat='olive', optic='reddot', mag='curved', mk2=True, muzzle='brake')
reg('WEAPON_MILITARYRIFLE', BULLPUP, mat='darkgreen', optic='scope', mag_mat='glass')
reg('WEAPON_HEAVYRIFLE', RIFLE, stock='rifle', furniture='tan', handguard='rail', mat='polymer', optic='holo',
	mag_len=40, muzzle='brake', barrel_end=212)

# --- submetralhadoras ---
reg('WEAPON_MICROSMG', SMG, stock='folded', length=96, barrel_out=12)
reg('WEAPON_MACHINEPISTOL', SMG, mag_pos='front', length=96, shroud=True, barrel_out=18)
reg('WEAPON_TECPISTOL', SMG, mag_pos='front', length=86, shroud=True, barrel_out=14, mag_len=34)
reg('WEAPON_MINISMG', SMG, mag_pos='front', length=92, stock='wire', curved=True, mag_len=36)
reg('WEAPON_SMG', RIFLE, stock='ar', handguard='round', handguard_end=150, barrel_end=164, mag='curved', mag_len=34,
	optic='irons', rail=False, muzzle='plain', receiver=(52, 108))
reg('WEAPON_SMG_MK2', RIFLE, stock='ar', handguard='rail', handguard_end=150, barrel_end=164, mag='curved', mag_len=34,
	optic='reddot', muzzle='comp', receiver=(52, 108), mk2=True)
reg('WEAPON_COMBATPDW', RIFLE, stock='skeleton', handguard='rail', handguard_end=144, barrel_end=160, mag_len=30,
	optic='reddot', muzzle='flash', receiver=(52, 104))
reg('WEAPON_ASSAULTSMG', BULLPUP, mat='polymer', body_end=136, barrel_end=170, optic='reddot', muzzle='flash')
reg('WEAPON_GUSENBERG', RIFLE, stock='thompson', furniture='wood', handguard='wood', handguard_end=150, barrel_end=184,
	mag='drum', mat='blued', rail=False, optic='irons', muzzle='comp', grip_mat='wood')

# --- metralhadoras ---
reg('WEAPON_MG', RIFLE, stock='skeleton', furniture='wood', handguard='slim', handguard_end=164, barrel_end=214,
	mag='box', mat='gunmetal', rail=False, optic='irons', bipod=True, muzzle='flash', gas_tube=40)
reg('WEAPON_COMBATMG', RIFLE, stock='ar', handguard='rail', handguard_end=164, barrel_end=214, mag='box',
	mag_mat='olive', mat='polymer', optic='carry', bipod=True, muzzle='flash', receiver=(52, 124))
reg('WEAPON_COMBATMG_MK2', RIFLE, stock='ar', handguard='rail', handguard_end=164, barrel_end=214, mag='box',
	mag_mat='tan', mat='polymer', optic='holo', bipod=True, muzzle='brake', receiver=(52, 124), mk2=True)

# --- espingardas ---
reg('WEAPON_PUMPSHOTGUN', PUMP, stock='grip', furniture='polymer')
reg('WEAPON_PUMPSHOTGUN_MK2', PUMP, stock='rifle', furniture='polymer', optic='holo', mk2=True)
reg('WEAPON_SAWNOFFSHOTGUN', PUMP, stock='sawn', furniture='wood', barrel_end=176, tube_end=170, mat='blued',
	pump_mat='wood')
reg('WEAPON_COMBATSHOTGUN', PUMP, stock='wire', furniture='polymer', heatshield=True)
reg('WEAPON_DBSHOTGUN', DOUBLE, stock='grip', furniture='wood', barrel_end=170)
reg('WEAPON_MUSKET', DOUBLE, stock='rifle', furniture='wood', barrel_end=260)

# --- precisão ---
reg('WEAPON_SNIPERRIFLE', SNIPER, mat='darkgreen', stock='thumbhole')
reg('WEAPON_MARKSMANRIFLE', SNIPER, mat='tan', stock='rifle', mag_len=22, muzzle='flash', scope_len=56)
reg('WEAPON_MARKSMANRIFLE_MK2', SNIPER, mat='polymer', stock='chassis', mag_len=22, muzzle='brake', mk2=True)
reg('WEAPON_HEAVYSNIPER', SNIPER, mat='gunmetal', stock='chassis', mag_len=22, muzzle='bigbrake', barrel_r=4.2,
	bipod=True, scope_len=74, scope_r=7, bell=12)
reg('WEAPON_HEAVYSNIPER_MK2', SNIPER, mat='tan', stock='chassis', mag_len=22, muzzle='bigbrake', barrel_r=4.2,
	bipod=True, scope_len=74, scope_r=7, bell=12, mk2=True)
reg('WEAPON_PRECISIONRIFLE', SNIPER, mat='olive', stock='chassis', mag_len=18, muzzle='flash', scope_len=60)

# --- especiais ---
import special as S  # noqa: E402
import melee as M  # noqa: E402


def obj(fn, box=212, rotate=0, dy=0, stretch=1.0, **fixed):
	def draw(name, **o):
		ic = Icon(name)
		fn(ic, {**fixed, **o})
		return ic.svg(box=box, rotate=rotate, dy=dy, stretch=stretch)
	return draw


reg('WEAPON_STUNGUN', obj(S.stungun, 200))
reg('WEAPON_FLAREGUN', obj(S.flaregun, 200))
reg('WEAPON_RAYPISTOL', obj(S.raypistol, 200))
reg('WEAPON_GADGETPISTOL', obj(S.gadgetpistol, 206))
reg('WEAPON_MARKSMANPISTOL', obj(S.marksmanpistol, 210))
reg('WEAPON_PISTOLXM3', obj(S.pistolxm3, 206))
reg('WEAPON_ASSAULTSHOTGUN', obj(S.assaultshotgun, 230, stretch=1.12))
reg('WEAPON_BULLPUPSHOTGUN', obj(S.bullpupshotgun, 226, stretch=1.12))
reg('WEAPON_HEAVYSHOTGUN', obj(S.heavyshotgun, 232, stretch=1.12))
reg('WEAPON_AUTOSHOTGUN', obj(S.autoshotgun, 226, stretch=1.12))
reg('WEAPON_MINIGUN', obj(S.minigun, 232, stretch=1.12))
reg('WEAPON_RPG', obj(S.rpg, 236, stretch=1.12))
reg('WEAPON_HOMINGLAUNCHER', obj(S.hominglauncher, 232, stretch=1.12))
reg('WEAPON_GRENADELAUNCHER', obj(S.grenadelauncher, 226))
reg('WEAPON_GRENADELAUNCHER_SMOKE', obj(S.grenadelauncher, 226, mat='darksteel', smoke=True))
reg('WEAPON_COMPACTLAUNCHER', obj(S.compactlauncher, 214))
reg('WEAPON_EMPLAUNCHER', obj(S.emplauncher, 230, stretch=1.12))
reg('WEAPON_FIREWORK', obj(S.firework, 234, stretch=1.12))
reg('WEAPON_RAILGUN', obj(S.railgun, 234, stretch=1.12))
reg('WEAPON_RAILGUNXM3', obj(S.railgun, 234, stretch=1.12, mat='olive', glow='#c4df9b'))
reg('WEAPON_RAYCARBINE', obj(S.raycarbine, 232, stretch=1.12))
reg('WEAPON_RAYMINIGUN', obj(S.rayminigun, 232, stretch=1.12))

# --- armas brancas (diagonal) ---
D = dict(rotate=-40)
reg('WEAPON_KNIFE', obj(M.knife, 236, **D))
reg('WEAPON_DAGGER', obj(M.dagger, 236, **D))
reg('WEAPON_SWITCHBLADE', obj(M.switchblade, 230, **D))
reg('WEAPON_MACHETE', obj(M.machete, 240, **D))
reg('WEAPON_HATCHET', obj(M.hatchet, 232, **D))
reg('WEAPON_STONE_HATCHET', obj(M.hatchet, 232, stone=True, **D))
reg('WEAPON_BATTLEAXE', obj(M.battleaxe, 236, **D))
reg('WEAPON_BAT', obj(M.bat, 240, **D))
reg('WEAPON_GOLFCLUB', obj(M.golfclub, 240, **D))
reg('WEAPON_POOLCUE', obj(M.poolcue, 244, **D))
reg('WEAPON_CROWBAR', obj(M.crowbar, 236, **D))
reg('WEAPON_HAMMER', obj(M.hammer, 226, **D))
reg('WEAPON_WRENCH', obj(M.wrench, 226, **D))
reg('WEAPON_NIGHTSTICK', obj(M.nightstick, 232, **D))
reg('WEAPON_FLASHLIGHT', obj(M.flashlight, 230, **D))
reg('WEAPON_CANDYCANE', obj(M.candycane, 220, **D))
reg('WEAPON_BOTTLE', obj(M.bottle_broken, 230, **D))
reg('WEAPON_BREAD', obj(M.bread, 232, **D))
reg('WEAPON_METALDETECTOR', obj(M.metaldetector, 232, **D))
reg('WEAPON_FLARE', obj(M.roadflare, 226, **D))
reg('WEAPON_KNUCKLE', obj(M.knuckle, 200))
reg('WEAPON_HANDCUFFS', obj(M.handcuffs, 206))
reg('WEAPON_DIGISCANNER', obj(M.digiscanner, 200))
reg('WEAPON_FIREEXTINGUISHER', obj(M.extinguisher, 206))
reg('WEAPON_PETROLCAN', obj(M.jerrycan, 200))
reg('WEAPON_HAZARDCAN', obj(M.jerrycan, 200, mat='yellow', hazard=True))
reg('WEAPON_FERTILIZERCAN', obj(M.fertilizercan, 200))
reg('WEAPON_BRIEFCASE', obj(M.briefcase, 206))
reg('WEAPON_BRIEFCASE_02', obj(M.briefcase, 206, mat='chrome'))
reg('WEAPON_GARBAGEBAG', obj(M.garbagebag, 200))
reg('WEAPON_ACIDPACKAGE', obj(M.acidpackage, 200))
reg('WEAPON_BALL', obj(M.baseball, 176))
reg('WEAPON_SNOWBALL', obj(M.snowball, 176))
reg('WEAPON_GRENADE', obj(M.frag, 196))
reg('WEAPON_BZGAS', obj(M.canister, 196, mat='darksteel', band='#f2cc35', label='BZ', label_color='#f2cc35'))
reg('WEAPON_SMOKEGRENADE', obj(M.canister, 196, mat='olive', band='#e6e9eb', label='SMK'))
reg('WEAPON_GAS', obj(M.canister, 196, mat='darksteel', band='#d6392d', label='CS', label_color='#ff8f80'))
reg('WEAPON_PIPEBOMB', obj(M.pipebomb, 214))
reg('WEAPON_PROXMINE', obj(M.proxmine, 200))
reg('WEAPON_STICKYBOMB', obj(M.stickybomb, 206))
reg('WEAPON_MOLOTOV', obj(M.molotov, 200))

# --- munição ---
import ammo as A  # noqa: E402
import items as I  # noqa: E402

AB = obj(A.ammo_box, 204)
reg('ammo-9', AB, box='navy', label='9mm', band='#5fa8ff')
reg('ammo-22', AB, box='darkgreen', label='.22 LR', band='#7cc443', n=6, s=0.7, size=20)
reg('ammo-38', AB, box='orange', label='.38 SPL', band='#f28a2e', round='hollow', size=19)
reg('ammo-44', AB, box='darkred', label='.44 MAG', band='#d6392d', round='hollow', s=1.1, size=19)
reg('ammo-45', AB, box='purple', label='.45 ACP', band='#8a5ad6', s=1.05, size=19)
reg('ammo-50', AB, box='polymer', label='.50 AE', band='#e7bf4a', round='hollow', s=1.2, n=3, size=20)
reg('ammo-rifle', AB, box='olive', label='5.56', band='#c4df9b', round='rifle', n=5, s=0.8)
reg('ammo-rifle2', AB, box='darkgreen', label='7.62', band='#e6b65c', round='rifle', n=4, s=0.9)
reg('ammo-sniper', AB, box='tan', label='.308', band='#b8a06f', round='rifle', n=4, s=1.0)
reg('ammo-heavysniper', AB, box='gunmetal', label='.50 BMG', band='#ff8f80', round='rifle', n=3, s=1.25, size=19)
reg('ammo-shotgun', AB, box='darkred', label='12 GA', band='#ff8f80', round='shell', n=4, shell='red')
reg('ammo-beanbag', AB, box='blue', label='BEANBAG', band='#f2cc35', round='shell', n=4, shell='orange', size=16)
reg('ammo-rocket', obj(A.ammo_rocket, 236, rotate=-40))
reg('ammo-grenade', obj(A.ammo_grenade40, 206))
reg('ammo-flare', obj(A.ammo_flare, 200))
reg('ammo-firework', obj(A.ammo_firework, 200))
reg('ammo-emp', obj(A.ammo_cell, 190))
reg('ammo-laser', obj(A.ammo_cell, 190, glow='#ff4a6a'))
reg('ammo-railgun', obj(A.ammo_rail, 220, rotate=-35))
reg('ammo-musket', obj(A.ammo_musket, 196))

# --- acessórios ---
reg('at_suppressor', obj(A.suppressor, 236, rotate=-35))
reg('at_barrel', obj(A.barrel_part, 236, rotate=-35))
reg('at_clip_drum', obj(A.clip_drum, 200))
reg('at_clip_extended', obj(A.clip_ext, 200))
reg('at_clip_extended2', obj(A.clip_ext, 200, curved=True))
reg('at_flashlight', obj(A.weapon_light, 214))
reg('at_grip', obj(A.fore_grip, 190))
for _k in ('bell', 'fat', 'flat', 'heavy', 'precision', 'slanted', 'split', 'squared', 'tactical'):
	reg('at_muzzle_' + _k, obj(A.muzzle_dev, 220, rotate=-30, k=_k))
for _k in ('small', 'medium', 'large', 'advanced', 'nv'):
	reg('at_scope_' + _k, obj(A.scope_part, 232, rotate=-28, k=_k))
for _k in ('holo', 'thermal'):
	reg('at_scope_' + _k, obj(A.scope_part, 214, k=_k))

# --- comida e bebida ---
reg('burger', obj(I.burger, 204))
reg('burger_chicken', obj(I.burger, 204, chicken=True))
reg('donut', obj(I.donut, 200))
reg('fries', obj(I.fries, 200))
reg('pizza_ham', obj(I.pizza, 200))
reg('pizza_ham_slice', obj(I.pizza_slice, 200))
reg('pizza_ham_box', obj(I.pizza_box, 214))
reg('sandwich', obj(I.sandwich, 200))
reg('chocolate', obj(I.wrapper_bar, 220, rotate=-20, label='CHOCO', label_mat='red'))
reg('cereal_bar', obj(I.cereal_bar, 220, rotate=-20))
reg('chips', obj(I.chips, 200))
reg('mustard', obj(I.mustard, 200))
reg('sprunk', obj(I.can, 200, mat='green', label='Sprunk', size=20, wave='#ffffff'))
reg('ecola', obj(I.can, 200, mat='red', label='eCola', size=22, wave='#ffffff'))
reg('energy_drink', obj(I.can, 200, mat='polymer', label='⚡', size=40, label_color='#c4df9b', label_y=120,
	wave='#c4df9b'))
reg('beer', obj(I.bottle, 204, glass='amberglass', label='PIBWASSER', size=11, cap='gold', liquid=None))
reg('whiskey', obj(I.bottle, 204, glass='amberglass', h=0.6, label='WHISKEY', size=13, cap='blackleather',
	label_mat='blackleather', label_color='#e7bf4a'))
reg('vodka', obj(I.bottle, 204, glass='glass', h=0.7, label='VODKA', size=15, cap='red', op=0.85, label_color='#d6392d'))
reg('water', obj(I.water, 200))
reg('coffee', obj(I.coffee, 204))

# --- ingredientes ---
reg('ingredient_meat', obj(I.meat, 200))
reg('ingredient_potato', obj(I.potato, 190))
reg('ingredient_dough', obj(I.dough, 196))
reg('ingredient_cheese', obj(I.cheese, 200))
reg('cloth', obj(I.cloth, 200))

# --- consumíveis ---
reg('cigarette', obj(I.cigarette, 230, rotate=-30))
reg('cigarettes_redwood', obj(I.cig_pack, 200))
reg('armour', obj(I.armour, 200))
reg('medikit', obj(I.medikit, 200))
reg('advancedkit', obj(I.advancedkit, 206))
reg('repair_kit', obj(I.repair_kit, 206))
reg('bandage', obj(I.bandage, 196))
reg('painkillers', obj(I.painkillers, 196))
reg('cocaine', obj(I.baggie, 196, content='coke'))
reg('meth', obj(I.baggie, 196, content='meth'))
reg('weed', obj(I.baggie, 196, content='weed'))

# --- dinheiro e documentos ---
reg('money', obj(I.money, 210))
reg('black_money', obj(I.money, 210, mat='redmoney', band='#1a1a1a', dirty=True))
reg('card_bank', obj(I.card, 214))
reg('card_id', obj(I.card, 214, kind='id', mat='darkgreen'))
reg('crypto_paper', obj(I.paper_wallet, 204))

# --- chaves e ferramentas ---
reg('key', obj(I.key, 220, rotate=-35))
reg('oldkey', obj(I.key, 220, rotate=-35, old=True))
reg('carkey', obj(I.carkey, 214, rotate=-25))
reg('lockpick', obj(I.lockpick, 206))
reg('ziptie', obj(I.ziptie, 206))

# --- eletrônicos ---
reg('phone', obj(I.phone, 206))
reg('radio', obj(I.radio, 206))
reg('laptop', obj(I.laptop, 214))
reg('desktop_pc', obj(I.desktop_pc, 214))
reg('home_server', obj(I.home_server, 200))
reg('usb_black', obj(I.usb, 214, rotate=-35))
reg('onion_usb', obj(I.usb, 214, rotate=-35, mat='purple', glow='#d3b4ff'))
reg('crypto_usb', obj(I.hw_wallet, 210, rotate=-20))
reg('news_camera', obj(I.news_camera, 214))
reg('news_mic', obj(I.news_mic, 200, rotate=-25))
reg('news_boom', obj(I.news_boom, 210))

# --- roupas e equipamentos ---
reg('panties', obj(I.panties, 200))
reg('parachute', obj(I.parachute, 196))

# --- peças ---
reg('part_engine_oil', obj(I.oil, 200))
reg('part_air_filter', obj(I.air_filter, 206))
reg('part_spark_plugs', obj(I.spark_plugs, 200))
reg('part_brake_pads', obj(I.brake_pads, 206))
reg('part_brake_discs', obj(I.brake_disc, 200))
reg('part_clutch', obj(I.clutch, 200))
reg('part_suspension', obj(I.suspension, 200, rotate=-30))
reg('rubber', obj(I.rubber, 196))
reg('plastic', obj(I.plastic, 200))
reg('scrapmetal', obj(I.scrapmetal, 200))
reg('fuel_can', obj(I.jerry_small, 196, mat='green'))

# --- recipientes e lixo ---
reg('paperbag', obj(I.paperbag, 200))
reg('garbage', obj(I.garbage, 204))
reg('trash', obj(I.trash, 200))
reg('trash_bread', obj(I.trash, 204, k='bread'))
reg('trash_burger', obj(I.trash, 204, k='burger'))
reg('trash_can', obj(I.trash, 204, k='can'))
reg('trash_chips', obj(I.trash, 204, k='chips'))
