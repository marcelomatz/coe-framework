# Contribution Guide & Contributor License Agreement (CLA)

Thank you for your interest in contributing to the **COE Framework**! To preserve the project's architectural integrity, 0.00ms resmon performance, and the ecosystem's legal and commercial sustainability, all contributions must follow the guidelines below.

---

## 🛠️ Non-Negotiable Engineering Standards

Before submitting a pull request (PR), make sure your code follows the ecosystem's 7 golden rules:

1. **Strictly server-authoritative**:
   - The FiveM client is 100% untrusted.
   - All decisions involving balances, inventory items, cooldowns, and state must be validated on the server.
2. **Platform layer (`Core.Platform`)**:
   - NEVER call GTA V natives directly from business (domain) logic.
   - Always use the abstractions encapsulated in `Core.Platform.Entities`, `Core.Platform.Vehicles`, etc.
3. **Internationalization (`Core.Locale`)**:
   - NEVER hardcode literal text for messages, notifications, or menus.
   - Declare keys in `locales/pt-br.lua` and `locales/en-us.lua`, maintaining 100% parity.
4. **Asynchronous database access**:
   - All SQL queries must use `?` parameter placeholders (protection against SQL injection).
   - Blocking operations are not allowed on the server's main thread.
5. **LuaLS types and contracts**:
   - All public exports must have formal annotations in `types.lua` (`---@param`, `---@return`).
   - Your PR must pass the validator with zero errors: `lua tools/check_contracts.lua --strict`.
6. **Design system (`coe_ui`)**:
   - NUI interfaces must reuse the official CSS tokens and support all 5 dynamic themes.
7. **Open-core boundary**:
   - Code in this repository must never name a resource that is not in this repository (exports, `nui://`, events, allowlists).
   - Other resources access it through ACE permissions in the resource's main entry point (`@coe_core/lib/access.lua`), with defaults only for resources in this repository.
   - Your PR must pass `lua tools/check_boundary.lua`.

---

## 📜 Contributor License Agreement (CLA)

By submitting a pull request, issue, patch, or any other code to the **COE Framework** repositories, you expressly agree to the following terms:

1. **Irrevocable license grant**:
   You grant the project's maintainer and copyright holder (**Marcelo Matz / COE Team**) a worldwide, perpetual, irrevocable, non-exclusive, royalty-free, fully sublicensable license to use, reproduce, modify, adapt, publish, translate, distribute, and commercially exploit your contribution, either alone or as part of the COE Framework or derivative products (including proprietary distributions through the Tebex Store or Asset Escrow).

2. **Original work**:
   You represent and warrant that your contribution is your original work and that you hold all legal rights required to grant the license described above, without infringing any third-party patents, copyrights, trademarks, or trade secrets.

3. **No employment relationship or compensation**:
   You understand and agree that your contributions to the COE Framework's open repositories are voluntary and do not create an employment relationship, business partnership, or present or future right to financial compensation.

---

## 🚀 How to Submit a Contribution

1. Fork the corresponding repository on GitHub.
2. Create a dedicated branch for your feature or fix: `git checkout -b feature/my-improvement`.
3. Write unit tests proving that your changes do not cause regressions.
4. Run the strict validation linter:
   ```bash
   lua tools/check_contracts.lua --strict --audit-natives --audit-locales
   ```
5. Open a pull request that clearly describes the issue being fixed and the technical motivation.
