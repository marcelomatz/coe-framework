# Guia de Contribuição & Termo de Licença do Colaborador (CLA)

Agradecemos o seu interesse em contribuir com o **COE Framework**! Para manter a integridade arquitetural do projeto, a estabilidade de 0.00ms no resmon e garantir a sustentabilidade jurídica e comercial do ecossistema, todas as contribuições devem seguir as diretrizes abaixo.

---

## 🛠️ Padrões de Engenharia Inegociáveis

Antes de submeter um Pull Request (PR), certifique-se de que o seu código atende às 6 regras de ouro do ecossistema:

1. **Server-Authoritative Estrito**:
   - O cliente FiveM é 100% não confiável.
   - Todas as decisões de saldo, itens de inventário, cooldowns e estados devem ser validadas no servidor.
2. **Camada de Plataforma (`Core.Platform`)**:
   - NUNCA chame natives do GTA V diretamente na lógica de negócio (domínio).
   - Utilize sempre as abstrações encapsuladas em `Core.Platform.Entities`, `Core.Platform.Vehicles`, etc.
3. **Internacionalização (`Core.Locale`)**:
   - NUNCA utilize textos literais hardcoded para mensagens, notificações ou menus.
   - Declare as chaves em `locales/pt-br.lua` e `locales/en-us.lua` mantendo 100% de paridade.
4. **Banco de Dados Assíncrono**:
   - Todas as consultas SQL devem utilizar placeholders parametrizados `?` (proteção contra SQL Injection).
   - Nenhuma operação bloqueante é permitida na main-thread do servidor.
5. **Tipagem e Contratos LuaLS**:
   - Todos os exports públicos devem ter anotações formais em `types.lua` (`---@param`, `---@return`).
   - Seu PR deve passar com zero erros no validador: `lua tools/check_contracts.lua --strict`.
6. **Design System (`coe_ui`)**:
   - Interfaces NUI devem reutilizar os tokens CSS oficiais e suportar os 5 temas dinâmicos.

---

## 📜 Contributor License Agreement (CLA)

Ao submeter um Pull Request, Issue, patch ou código de qualquer natureza para os repositórios do **COE Framework**, você expressamente concorda com os seguintes termos:

1. **Cessão de Licença Irrevogável**:
   Você concede ao mantenedor e titular dos direitos autorais do projeto (**Marcelo Matz / COE Team**) uma licença mundial, perpétua, irrevogável, não exclusiva, livre de royalties e totalmente sublicenciável para usar, reproduzir, modificar, adaptar, publicar, traduzir, distribuir e explorar comercialmente sua contribuição, isoladamente ou como parte do COE Framework ou de produtos derivados (incluindo distribuições proprietárias na Tebex Store ou Asset Escrow).

2. **Originalidade da Obra**:
   Você declara e garante que a contribuição é uma criação original sua e que você possui todos os direitos legais necessários para conceder a licença descrita acima, sem violar patentes, direitos autorais, marcas ou segredos comerciais de terceiros.

3. **Ausência de Vínculo Empregatício ou Compensação**:
   Você compreende e concorda que a sua contribuição para os repositórios abertos do COE Framework é voluntária e não cria nenhum vínculo trabalhista, sociedade comercial ou direito a compensação financeira presente ou futura.

---

## 🚀 Como Submeter uma Contribuição

1. Faça um Fork do repositório correspondente no GitHub.
2. Crie uma branch específica para sua feature ou correção: `git checkout -b feature/minha-melhoria`.
3. Escreva testes unitários comprovando que sua alteração não causa regressões.
4. Execute o linter estrito de validação:
   ```bash
   lua tools/check_contracts.lua --strict --audit-natives --audit-locales
   ```
5. Abra o Pull Request descrevendo claramente o problema resolvido e a motivação técnica.
