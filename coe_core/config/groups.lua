-- Definições de grupos de gameplay. Este arquivo é a fonte da verdade: é sincronizado com o
-- banco quando o core inicia. Remover um grupo não apaga os vínculos dos personagens.
--
-- name: minúsculas, dígitos e _ (começa com letra, até 32 caracteres).
-- type: um dos Types. Cada personagem tem no máximo um grupo ativo por tipo.
-- grades: número de 0 a 255; quanto maior, maior a autoridade.
CoeGroupsConfig = {
	Types = { 'job', 'gang' },
	Groups = {
		police = {
			type = 'job',
			label = 'Polícia',
			grades = {
				[0] = { label = 'Cadete' },
				[1] = { label = 'Oficial' },
				[2] = { label = 'Sargento' },
				[3] = { label = 'Comandante' }
			}
		},
		fib = {
			type = 'job',
			label = 'FIB — Inteligência Federal',
			grades = {
				[0] = { label = 'Agente Especial' },
				[1] = { label = 'Agente Sênior' },
				[2] = { label = 'Supervisor de Divisão' },
				[3] = { label = 'Diretor Federal' }
			}
		},
		doj = {
			type = 'job',
			label = 'DOJ — Justiça Federal',
			grades = {
				[0] = { label = 'Defensor Público' },
				[1] = { label = 'Promotor de Justiça' },
				[2] = { label = 'Juiz Federal' },
				[3] = { label = 'Procurador-Geral' }
			}
		},
		mechanic = {
			type = 'job',
			label = 'Oficina',
			grades = {
				[0] = { label = 'Aprendiz' },
				[1] = { label = 'Mecânico' },
				[2] = { label = 'Chefe de oficina' }
			}
		},
		ambulance = {
			type = 'job',
			label = 'Hospital',
			grades = {
				[0] = { label = 'Estagiário' },
				[1] = { label = 'Médico' },
				[2] = { label = 'Diretor' }
			}
		},
		banker = {
			type = 'job',
			label = 'Executivo Bancário',
			grades = {
				[0] = { label = 'Analista Bancário' },
				[1] = { label = 'Gerente de Contas' },
				[2] = { label = 'Diretor de Compliance' }
			}
		}
		-- Exemplo de gangue:
		-- ballas = { type = 'gang', label = 'Ballas', grades = { [0] = { label = 'Membro' }, [1] = { label = 'Líder' } } }
	}
}
