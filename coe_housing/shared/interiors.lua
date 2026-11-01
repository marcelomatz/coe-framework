-- Catálogo de interiores nativos do GTA V usados como interior dos imóveis.
-- Coordenadas = ponto de chegada (e de saída) dentro do interior. Use "Visitar" no admin para conferir e ajustar.
-- ipls: carregados antes de entrar. group: estilos do mesmo espaço físico; só um fica carregado por vez.
-- entitySets: conjuntos de móveis/equipamentos ativados no interior depois que ele carrega.
-- Para adicionar um interior: inclua uma linha com id único (a-z, 0-9 e _, até 32) e reinicie coe_housing e coe_admin.
HousingInteriors = {
	categories = {
		{ 'apartment', 'Apartamentos' },
		{ 'house', 'Casas' },
		{ 'office', 'Escritórios' },
		{ 'warehouse', 'Galpões e industriais' },
		{ 'garage', 'Garagens' },
		{ 'venue', 'Comércio e lazer' }
	},
	list = {
		-- Apartamentos sempre carregados
		{ id = 'apt_low', label = 'Apartamento simples', category = 'apartment', x = 261.46, y = -998.82, z = -99.01 },
		{ id = 'apt_medium', label = 'Apartamento médio', category = 'apartment', x = 347.27, y = -999.30, z = -99.20 },
		{ id = 'apt_integrity_28', label = '4 Integrity Way, apto 28', category = 'apartment', x = -18.08, y = -583.67, z = 79.47 },
		{ id = 'apt_integrity_30', label = '4 Integrity Way, apto 30', category = 'apartment', x = -35.31, y = -580.42, z = 88.71 },
		{ id = 'apt_dellperro_4', label = 'Dell Perro Heights, apto 4', category = 'apartment', x = -1468.14, y = -541.82, z = 73.44 },
		{ id = 'apt_dellperro_7', label = 'Dell Perro Heights, apto 7', category = 'apartment', x = -1477.14, y = -538.75, z = 55.53 },
		{ id = 'apt_richard_2', label = 'Richards Majestic, apto 2', category = 'apartment', x = -915.81, y = -379.43, z = 113.67 },
		{ id = 'apt_tinsel_42', label = 'Tinsel Towers, apto 42', category = 'apartment', x = -614.86, y = 40.68, z = 97.60 },
		{ id = 'apt_eclipse_3', label = 'Eclipse Towers, apto 3', category = 'apartment', x = -773.41, y = 341.77, z = 211.40 },
		{ id = 'apt_vespucci', label = 'Apartamento em Vespucci Beach', category = 'apartment', x = -1150.70, y = -1520.71, z = 10.63 },

		-- Coberturas executivas (mesmo espaço, um estilo por IPL)
		{ id = 'apt_exec_modern', label = 'Cobertura executiva: Moderna', category = 'apartment', x = -786.87, y = 315.76, z = 217.64, group = 'apa_eclipse', ipls = { 'apa_v_mp_h_01_a' } },
		{ id = 'apt_exec_moody', label = 'Cobertura executiva: Sóbria', category = 'apartment', x = -786.87, y = 315.76, z = 217.64, group = 'apa_eclipse', ipls = { 'apa_v_mp_h_02_a' } },
		{ id = 'apt_exec_vibrant', label = 'Cobertura executiva: Vibrante', category = 'apartment', x = -786.87, y = 315.76, z = 217.64, group = 'apa_eclipse', ipls = { 'apa_v_mp_h_03_a' } },
		{ id = 'apt_exec_sharp', label = 'Cobertura executiva: Marcante', category = 'apartment', x = -786.87, y = 315.76, z = 217.64, group = 'apa_eclipse', ipls = { 'apa_v_mp_h_04_a' } },
		{ id = 'apt_exec_mono', label = 'Cobertura executiva: Monocromática', category = 'apartment', x = -786.87, y = 315.76, z = 217.64, group = 'apa_eclipse', ipls = { 'apa_v_mp_h_05_a' } },
		{ id = 'apt_exec_seductive', label = 'Cobertura executiva: Sedutora', category = 'apartment', x = -786.87, y = 315.76, z = 217.64, group = 'apa_eclipse', ipls = { 'apa_v_mp_h_06_a' } },
		{ id = 'apt_exec_regal', label = 'Cobertura executiva: Imponente', category = 'apartment', x = -786.87, y = 315.76, z = 217.64, group = 'apa_eclipse', ipls = { 'apa_v_mp_h_07_a' } },
		{ id = 'apt_exec_aqua', label = 'Cobertura executiva: Aqua', category = 'apartment', x = -786.87, y = 315.76, z = 217.64, group = 'apa_eclipse', ipls = { 'apa_v_mp_h_08_a' } },

		-- Casas
		{ id = 'house_forum', label = 'Casa em Forum Drive', category = 'house', x = -14.38, y = -1438.51, z = 31.11 },
		{ id = 'house_elburro', label = 'Casa em El Burro Heights', category = 'house', x = 1273.90, y = -1719.31, z = 54.77 },
		{ id = 'house_vinewood', label = 'Mansão em Vinewood Hills', category = 'house', x = 7.12, y = 536.62, z = 176.03 },
		{ id = 'house_rockford', label = 'Mansão em Rockford Hills', category = 'house', x = -813.60, y = 179.47, z = 72.15 },
		{ id = 'house_trailer_tidy', label = 'Trailer em Sandy Shores (arrumado)', category = 'house', x = 1972.61, y = 3817.04, z = 33.43, group = 'sandy_trailer', ipls = { 'TrevorsTrailerTidy' } },
		{ id = 'house_trailer_trash', label = 'Trailer em Sandy Shores (bagunçado)', category = 'house', x = 1972.61, y = 3817.04, z = 33.43, group = 'sandy_trailer', ipls = { 'TrevorsTrailerTrash' } },
		{ id = 'house_wild_oats', label = '3655 Wild Oats Drive', category = 'house', x = -169.29, y = 486.49, z = 137.44 },
		{ id = 'house_conker_2044', label = '2044 North Conker Avenue', category = 'house', x = 340.94, y = 437.18, z = 149.39 },
		{ id = 'house_conker_2045', label = '2045 North Conker Avenue', category = 'house', x = 373.02, y = 416.11, z = 145.70 },
		{ id = 'house_hillcrest_2862', label = '2862 Hillcrest Avenue', category = 'house', x = -676.13, y = 588.61, z = 145.17 },
		{ id = 'house_hillcrest_2868', label = '2868 Hillcrest Avenue', category = 'house', x = -763.11, y = 615.91, z = 144.14 },
		{ id = 'house_hillcrest_2874', label = '2874 Hillcrest Avenue', category = 'house', x = -857.80, y = 682.56, z = 152.65 },
		{ id = 'house_whispymound', label = '2677 Whispymound Drive', category = 'house', x = 120.50, y = 549.95, z = 184.10 },
		{ id = 'house_mad_wayne', label = '2133 Mad Wayne Thunder Drive', category = 'house', x = -1288.00, y = 440.75, z = 97.69 },

		-- Escritórios executivos (cada prédio aceita um estilo por vez)
		{ id = 'office_arcadius_warm', label = 'Arcadius: escritório clássico quente', category = 'office', x = -141.20, y = -620.91, z = 168.82, group = 'office_arcadius', ipls = { 'ex_dt1_02_office_01a' } },
		{ id = 'office_arcadius_rich', label = 'Arcadius: escritório executivo nobre', category = 'office', x = -141.20, y = -620.91, z = 168.82, group = 'office_arcadius', ipls = { 'ex_dt1_02_office_02b' } },
		{ id = 'office_arcadius_ice', label = 'Arcadius: escritório moderno gelo', category = 'office', x = -141.20, y = -620.91, z = 168.82, group = 'office_arcadius', ipls = { 'ex_dt1_02_office_03a' } },
		{ id = 'office_maze_classic', label = 'Maze Bank Tower: escritório clássico', category = 'office', x = -75.85, y = -826.99, z = 243.39, group = 'office_maze', ipls = { 'ex_dt1_11_office_01b' } },
		{ id = 'office_maze_cool', label = 'Maze Bank Tower: escritório executivo frio', category = 'office', x = -75.85, y = -826.99, z = 243.39, group = 'office_maze', ipls = { 'ex_dt1_11_office_02c' } },
		{ id = 'office_maze_polished', label = 'Maze Bank Tower: escritório moderno polido', category = 'office', x = -75.85, y = -826.99, z = 243.39, group = 'office_maze', ipls = { 'ex_dt1_11_office_03c' } },
		{ id = 'office_lom_vintage', label = 'Lombank West: escritório clássico vintage', category = 'office', x = -1579.76, y = -565.07, z = 108.52, group = 'office_lom', ipls = { 'ex_sm_13_office_01c' } },
		{ id = 'office_lom_contrast', label = 'Lombank West: escritório executivo contraste', category = 'office', x = -1579.76, y = -565.07, z = 108.52, group = 'office_lom', ipls = { 'ex_sm_13_office_02a' } },
		{ id = 'office_mazewest_rich', label = 'Maze Bank West: escritório executivo nobre', category = 'office', x = -1392.67, y = -480.47, z = 72.04, group = 'office_mazewest', ipls = { 'ex_sm_15_office_02b' } },
		{ id = 'office_mazewest_sober', label = 'Maze Bank West: escritório moderno sóbrio', category = 'office', x = -1392.67, y = -480.47, z = 72.04, group = 'office_mazewest', ipls = { 'ex_sm_15_office_03b' } },
		{ id = 'office_fib_lobby', label = 'Saguão corporativo (FIB)', category = 'office', x = 110.40, y = -744.20, z = 45.75 },

		-- Galpões e industriais
		{ id = 'warehouse_small', label = 'Galpão pequeno', category = 'warehouse', x = 1094.99, y = -3101.78, z = -39.00 },
		{ id = 'warehouse_medium', label = 'Galpão médio', category = 'warehouse', x = 1056.49, y = -3105.72, z = -39.00 },
		{ id = 'warehouse_large', label = 'Galpão grande', category = 'warehouse', x = 1006.97, y = -3102.08, z = -39.00 },
		{ id = 'warehouse_vehicles', label = 'Galpão de veículos', category = 'warehouse', x = 994.59, y = -3002.59, z = -39.65 },
		{ id = 'warehouse_bunker', label = 'Bunker', category = 'warehouse', x = 899.55, y = -3246.04, z = -98.05, entitySets = { 'Bunker_Style_A', 'standard_bunker_set' } },
		{ id = 'lab_meth', label = 'Laboratório químico', category = 'warehouse', x = 1009.50, y = -3196.60, z = -39.00, entitySets = { 'meth_lab_basic' } },
		{ id = 'lab_weed', label = 'Estufa de cultivo', category = 'warehouse', x = 1051.49, y = -3196.54, z = -39.15, entitySets = { 'weed_standard_equip' } },
		{ id = 'lab_cocaine', label = 'Depósito de embalagem', category = 'warehouse', x = 1093.60, y = -3196.60, z = -39.00, entitySets = { 'equipment_basic' } },
		{ id = 'lab_print', label = 'Gráfica', category = 'warehouse', x = 1121.90, y = -3195.34, z = -40.40, entitySets = { 'counterfeit_standard_equip' } },
		{ id = 'lab_documents', label = 'Escritório de documentos', category = 'warehouse', x = 1165.00, y = -3196.60, z = -39.01, entitySets = { 'interior_basic' } },

		-- Garagens
		{ id = 'garage_2', label = 'Garagem para 2 veículos', category = 'garage', x = 173.29, y = -1003.60, z = -99.66 },
		{ id = 'garage_6', label = 'Garagem para 6 veículos', category = 'garage', x = 197.82, y = -1002.29, z = -99.66 },
		{ id = 'garage_10', label = 'Garagem para 10 veículos', category = 'garage', x = 229.96, y = -981.79, z = -99.66 },

		-- Comércio e lazer
		{ id = 'venue_bahama', label = 'Casa noturna à beira-mar', category = 'venue', x = -1388.00, y = -618.42, z = 30.82 },
		{ id = 'venue_nightclub', label = 'Boate subterrânea', category = 'venue', x = -1604.66, y = -3012.58, z = -78.00, entitySets = { 'Int01_ba_Style01' } },
		{ id = 'venue_clubhouse_1', label = 'Sede de clube (galpão)', category = 'venue', x = 1107.04, y = -3157.40, z = -37.52 },
		{ id = 'venue_clubhouse_2', label = 'Sede de clube (bar)', category = 'venue', x = 998.48, y = -3164.71, z = -38.91 },
		{ id = 'venue_morgue', label = 'Necrotério', category = 'venue', x = 275.45, y = -1361.11, z = 24.54 }
	}
}

HousingInteriors.byId = {}
for _, entry in ipairs(HousingInteriors.list) do
	HousingInteriors.byId[entry.id] = entry
end
