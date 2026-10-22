<p align="right">
  <a href="README.md">🇺🇸 English</a> • <b>🇧🇷 Português</b>
</p>

# ⚡ COE Framework

> **A Nova Geração da Engenharia FiveM** — Arquitetura Server-Authoritative, desacoplamento nativo via Camada de Plataforma (`Core.Platform`), 0.00ms de resmon em repouso e tipagem estrita.

[![FiveM](https://img.shields.io/badge/FiveM-FXServer%20b3407+-blue.svg)](https://fivem.net)
[![Lua](https://img.shields.io/badge/Lua-5.4-blue.svg)](https://www.lua.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Architecture](https://img.shields.io/badge/Architecture-Server--Authoritative-orange.svg)](#arquitetura-e-padroes-de-engenharia)
[![Website](https://img.shields.io/badge/Website-coeroleplay.app-success.svg)](https://www.coeroleplay.app/)
[![Documentation](https://img.shields.io/badge/Docs-docs.coeroleplay.app-purple.svg)](https://docs.coeroleplay.app/)

---

## 💬 Uma Mensagem de Marcelo Matz: Devolvendo à Comunidade FiveM

> *"Trabalho com desenvolvimento de software há mais de 25 anos. Ao longo de toda a minha trajetória na tecnologia, poucas coisas me fascinaram tanto quanto a mágica do roleplay e o poder criativo do FiveM. Ver centenas de pessoas conectadas simultaneamente, construindo histórias, cidades e comunidades inteiras em cima de código é algo verdadeiramente inspirador.*
>
> *Hoje, o lançamento do **COE Framework** em código aberto é a minha forma de começar a devolver um pouco de tudo aquilo que essa comunidade já me proporcionou ao longo dos anos.*
>
> *Quero deixar registrado o meu mais profundo respeito e gratidão a todos os pioneiros e desenvolvedores de frameworks como **ESX**, **QBCore**, **Qbox** e **Ox**, que desbravaram caminhos, criaram os alicerces onde todos nós pisamos e continuam fazendo um trabalho admirável pelo ecossistema. Da mesma forma, meu agradecimento sincero a cada **modder**, criador de conteúdo e administrador de servidor que dedica noites e fins de semana para tornar o ambiente do FiveM cada vez melhor.*
>
> *O COE Framework nasce como uma contribuição de coração aberto: 25 resources em arquitetura limpa, com desempenho inegociável (0.00ms idle), totalmente orientados ao servidor, desacoplados via Platform HAL e com banco assíncrono MariaDB 11. Que ele sirva como ferramenta, inspiração e base sólida para que a comunidade continue criando o futuro do roleplay."*
>
> — **Marcelo Matz**

---

## 📖 Visão Geral

O **COE Framework** é uma base de RPG completa e de alta performance para FiveM construída do zero sobre princípios modernos de engenharia de software:

* **Server-Authoritative Estrito**: O cliente FiveM não toma decisões de estado, saldo ou inventário. Todas as transações são validadas e processadas no servidor.
* **Camada de Plataforma (`Core.Platform`)**: Nenhuma chamada a natives do GTA V é feita diretamente dentro da lógica de negócio. Todas as interações com o jogo passam por abstrações testáveis e desacopladas.
* **Performance Real**: Módulos operando a **0.00ms no resmon** em idle através de renderização orientada a eventos e raycasting otimizado.
* **Internacionalização (i18n)**: Suporte nativo completo a múltiplos idiomas (`pt-BR`, `en-US`), com paridade de chaves e resolução defensiva em tempo de execução.
* **Banco de Dados Durável**: Conexões assíncronas via pool MariaDB parametrizado com proteção anti-injeção e auditoria durável em tempo real.

---

## 📦 Estrutura dos Módulos Abertos (Tier 1 & Tier 2)

O repositório `coe-framework` disponibiliza **25 resources** essenciais e autossuficientes sob licença [MIT](LICENSE):

### 🏛️ Tier 1 — Core do Ecossistema (9 Resources)
| Resource | Descrição |
|---|---|
| [`coe_core`](coe_core) | Registro central de entidades, ciclo de vida do jogador, contratos de export e camada HAL (`Core.Platform`). |
| [`coe_database`](coe_database) | Camada de persistência assíncrona baseada em MariaDB com pool de conexões otimizado e transações seguras. |
| [`coe_ui`](coe_ui) | Design System NUI com design tokens, suporte a 5 temas dinâmicos e componentes de interface reativos. |
| [`coetarget`](coetarget) | Sistema de interação contextual por mira/raycasting com detecção espacial de alta frequência (0.00ms em idle). |
| [`coe_supervisor`](coe_supervisor) | Monitoramento de integridade e telemetria de inicialização de recursos com watchdogs defensivos. |
| [`coe_logging`](coe_logging) | Pipeline estruturado de telemetria e registro de logs com níveis dinâmicos por recurso. |
| [`coe_notify`](coe_notify) | Fila de notificações visuais reativa em NUI integrada com o sistema de design tokens. |
| [`coe_loadscreen`](coe_loadscreen) | Tela de carregamento imersiva integrada ao ciclo de boot e sincronizada com a autenticação. |
| [`coe_audit`](coe_audit) | Trilha imutável de auditoria financeira, movimentações de itens e ações de jogadores gravadas em MariaDB. |

### 🌐 Tier 2 — Base Comunitária (16 Resources)
| Resource | Descrição |
|---|---|
| [`coe_characters`](coe_characters) | Seleção de múltiplos personagens por identificador com suporte a metadados dinâmicos e slots configuráveis. |
| [`coe_spawn`](coe_spawn) | Pipeline determinístico de spawn com câmeras cinemáticas de aproximação e seletor de locais. |
| [`coe_appearance`](coe_appearance) | Customização facial, genética, roupas e vestuário com compatibilidade com modelos MP e freemode. |
| [`coe_hud`](coe_hud) | Interface do jogador exibindo velocímetro digital, status corporais, combustível, microfone e cinto de segurança. |
| [`coe_needs`](coe_needs) | Simulação fisiológica de fome, sede, estresse e fadiga com decaimento desacoplado e efeitos dinâmicos. |
| [`coe_inventory`](coe_inventory) | Inventário em grid interativo com suporte a baús, portas-luvas, porta-malas, bolsos e drop físico no chão (233 ícones WebP/PNG). |
| [`coe_map`](coe_map) | Gerenciamento de blips no minimapa e mapa ampliado por categorias com controle de visibilidade dinâmica. |
| [`coe_pausemenu`](coe_pausemenu) | Menu de pausa personalizado integrado à NUI com abas de mapa, inventário, configurações e desconexão. |
| [`coe_talk`](coe_talk) | Integração com o sistema de voz nativo do FiveM (3D Audio), rádios e canais de frequência. |
| [`coe_businesses`](coe_businesses) | Registro de empresas privadas, quadros societários, balance sheet e gestão de franquias. |
| [`coe_economy`](coe_economy) | Livro-razão contábil duplo, suporte a moedas primárias/secundárias e validação transacional estrita. |
| [`coe_shops`](coe_shops) | Mercados, farmácias e lojas de conveniência com cestas de compras, conferência de peso e pagamento por conta ou dinheiro. |
| [`coe_bank`](coe_bank) | Banco básico: saldo, saque e depósito em espécie, transferência por ID de cidadão e extrato, em agências e caixas eletrônicos. |
| [`coe_jobs`](coe_jobs) | Arquitetura de profissões públicas e privadas com níveis de progressão salarial, turnos e permissões por cargo. |
| [`coe_vehicle_catalog`](coe_vehicle_catalog) | Catálogo unificado de metadados de veículos, classes, especificações técnicas e capacidades de carga. |
| [`coe_vehicles`](coe_vehicles) | Gestão de propriedade veicular, emplacamento, chaves digitais, trancamento e danos de motor/lataria. |

---

## 💎 Módulos Avançados (Planejamento de Suíte Comercial Futura)

O foco absoluto e prioritário deste projeto é fornecer e aprimorar continuamente a base **Open-Source** para a comunidade. Como etapa futura, pacotes opcionais complementares de padrão estúdio AAA serão disponibilizados de forma modular sob proteção **Cfx.re Asset Escrow**:

1. **COE OS Suite**: Celulares de última geração, Tablets corporativos, Redes sociais, E-mail criptografado e Ecossistema de aplicativos.
2. **Automotive Pro & Dyno**: Dinamômetro ao vivo, mecânica minuciosa de motores, desgaste de peças e postos de combustível com precificação flutuante.
3. **Cyber & Underworld**: Terminal Deepweb (Mercado Negro), Criptoativo Noxcoin com cotação dinâmica, invasão de cofres e sistema de facções ilegais.
4. **Public Safety & Forensics**: Polícia Forense com análise balística e DNA, SAMU com triagem médica real, Central de Despacho CAD e MDT integrado.
5. **Enterprise & Governance**: Sistema bancário institucional com empréstimos e cartões de crédito, Imobiliária instanciada, Portas de alta segurança e Manufatura avançada.

---

## 🚀 Como Iniciar

### Pré-requisitos
* FiveM Server Artifacts **b3407** ou superior (Windows ou Linux).
* MariaDB Server **10.6+** ou MySQL **8.0+**.
* Lua **5.4** habilitado no `fxmanifest.lua` (`lua54 'yes'`).

### 1. Clonagem e Configuração
```bash
# Clone o repositório dentro do diretório de resources do seu servidor
cd txData/YOUR_SERVER/resources
git clone https://github.com/marcelomatz/coe-framework.git [coe-framework]
```

### 2. Configuração do `server.cfg`
Certifique-se de carregar o supervisor antes de qualquer outro módulo:
```cfg
# Inicialização do ecossistema COE
ensure coe_supervisor
ensure [coe-framework]

# Staff: administrar grupos sem painel (/grupo definir <ID> <grupo> [grau])
add_ace group.admin command.grupo allow
```

Scripts de terceiros se integram sem editar o framework: cada um recebe no `server.cfg` só as capacidades que usa, por ACE no principal do resource (lista em `ARCHITECTURE.md` do coe-docs):

```cfg
add_ace resource.meu_script coe.database allow
add_ace resource.meu_script coe.economy.money allow
```

### 3. Validação de Contratos
Antes de iniciar o servidor em produção, execute a suíte de auditoria local:
```bash
cd [coe-framework]
lua tools/check_contracts.lua
lua tools/smoke_boot_test.lua
```

---

## 🛠️ Regras de Contribuição & CLA

Contribuições da comunidade são muito bem-vindas! Para submeter código, melhorias ou correções:
1. Leia atentamente o [Guia de Contribuição e Contributor License Agreement (CLA)](CONTRIBUTING.md).
2. Certifique-se de que nenhum código viola as 6 regras de ouro (Server-Authoritative, desacoplamento HAL, zero natives no domínio, i18n em todas as mensagens).
3. Abra um Pull Request detalhando as alterações.

---

## 📄 Licença

O código contido neste repositório está licenciado sob a licença [MIT](LICENSE).

---

## 🌐 Links e Comunidade

* **Website Oficial**: [www.coeroleplay.app](https://www.coeroleplay.app/)
* **Documentação Oficial**: [docs.coeroleplay.app](https://docs.coeroleplay.app/)
* **Reportar Bugs / Issues**: [GitHub Issues](https://github.com/marcelomatz/coe-framework/issues)
