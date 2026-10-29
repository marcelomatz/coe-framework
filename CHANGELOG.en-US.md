# Release Notes & Changelog

Official version history, new implementations, architectural enhancements, and bug fixes for the **COE Framework** (Open-Source MIT · FiveM Enhanced Gen9 / DirectX 12).

> [!TIP]
> **In-Game Auto-Updater (`coe_supervisor` + `F10`):**
> Starting with `v0.1.0-beta.1`, every COE Framework server automatically checks on boot whether a newer release has been published in the official repository. When an update is available, a console notice is printed (`coe update`) and an interactive 1-click update banner appears in the **Admin Panel Overview (`F10`)**.

---

## How the Release Cycle Works

| Channel | SemVer Format | Stability | Target Audience |
| :--- | :--- | :--- | :--- |
| **Beta (`beta`)** | `0.x.y-beta.N` | Real-world server validation and rapid API evolution | Early adopters, developers, and servers under construction |
| **Release Candidate (`rc`)** | `x.y.z-rc.N` | Feature freeze and final regression testing | Servers preparing for production deployment |
| **Stable (`stable`)** | `x.y.z` | Full production readiness with strict SemVer contract guarantees | All production servers |

---

<!-- COE_RELEASES_START -->

## [v0.1.0-beta.13] — 2026-10-29 · `BETA`

COE Framework v0.1.0-beta.13 (beta): 2 atualização(ões) nos resources do ecossistema. Destaque: **[tools]** Atualiza tools.

### ✨ Implementations (New Features & Systems)

- Release v0.1.0-beta.13 (BETA) consolidated with 29 first-party resources.

### ⚡ Architectural & UX Improvements

- Performance, HAL contract validation, and bilingual documentation parity.

### 🐛 Bug Fixes

- General stability and persistence fixes across core and gameplay modules.


## [v0.1.0-beta.12] — 2026-10-29 · `BETA`

COE Framework v0.1.0-beta.11 (beta): 1 atualização(ões). Destaque: Atualiza coe_core, reference, tools.

### ✨ Implementations (New Features & Systems)

- COE Framework v0.1.0-beta.11 (beta): 1 atualização(ões). Destaque: Atualiza coe_core, reference, tools.

### ⚡ Architectural & UX Improvements

- Validação estrita de contratos HAL, locales pt-BR/en-US e telemetria 0.00ms idle.

### 🐛 Bug Fixes

- Correções gerais de estabilidade e persistência MariaDB.


## [v0.1.0-beta.11] — 2026-10-28 · `BETA`

COE Framework v0.1.0-beta.11 (beta): 1 atualização(ões). Destaque: Atualiza coe_core, reference, tools.

### ✨ Implementations (New Features & Systems)

- Release v0.1.0-beta.11 (BETA) consolidated with 27 first-party resources.

### ⚡ Architectural & UX Improvements

- Performance, HAL contract validation, and bilingual documentation parity.

### 🐛 Bug Fixes

- General stability and persistence fixes across core and gameplay modules.


## [v0.1.0-beta.10] — 2026-10-28 · `BETA`

COE Framework v0.1.0-beta.10 (beta): 2 nova(s) funcionalidade(s), 29 melhoria(s) de arquitetura/UX, 1 correção(ões). Destaque: **[staff]** Separate hotel tab, add blip toggle, public garages management and coe_rentals resource (#37).

### ✨ Implementations (New Features & Systems)

- [staff] Separate hotel tab, add blip toggle, public garages management and coe_rentals resource (#37)
- [supervisor] Preserve modified config files and detect new keys on update (#35)

### ⚡ Architectural & UX Improvements

- [coe_workpad] Modificações em andamento em coe_workpad
- [coe_vehicle_catalog] Modificações em andamento em coe_vehicle_catalog
- [coe_vehicles] Modificações em andamento em coe_vehicles
- [coe_ui] Modificações em andamento em coe_ui
- [coe_talk] Modificações em andamento em coe_talk
- [coe_supervisor] Modificações em andamento em coe_supervisor
- [coe_staff] Modificações em andamento em coe_staff
- [coe_spawn] Modificações em andamento em coe_spawn
- [coe_shops] Modificações em andamento em coe_shops
- [coe_rentals] Modificações em andamento em coe_rentals
- [coe_notify] Modificações em andamento em coe_notify
- [coe_needs] Modificações em andamento em coe_needs
- [coe_mobile] Modificações em andamento em coe_mobile
- [coe_map] Modificações em andamento em coe_map
- [coe_logging] Modificações em andamento em coe_logging
- [coe_loadscreen] Modificações em andamento em coe_loadscreen
- [coe_jobs] Modificações em andamento em coe_jobs
- [coe_inventory] Modificações em andamento em coe_inventory
- [coe_hud] Modificações em andamento em coe_hud
- [coe_garage] Modificações em andamento em coe_garage
- [coe_economy] Modificações em andamento em coe_economy
- [coe_database] Modificações em andamento em coe_database
- [coe_core] Modificações em andamento em coe_core
- [coe_characters] Modificações em andamento em coe_characters
- [coe_businesses] Modificações em andamento em coe_businesses
- [coe_bank] Modificações em andamento em coe_bank
- [coe_audit] Modificações em andamento em coe_audit
- [coe_appearance] Modificações em andamento em coe_appearance
- [coetarget] Modificações em andamento em coetarget

### 🐛 Bug Fixes

- [inventory] Unwrap self in exports, restore NUI image paths and stream binary downloads (#36)


## [v0.1.0-beta.9] — 2026-10-28 · `BETA`

COE Framework v0.1.0-beta.9 (beta): 3 nova(s) funcionalidade(s), 5 correção(ões). Destaque: **[garage]** Add basic open-core public garages resource with staff provider.

### ✨ Implementations (New Features & Systems)

- [garage] Add basic open-core public garages resource with staff provider
- [staff] Separate hotel tab, add blip toggle, public garages management and coe_rentals resource
- [supervisor] Preserve modified config files and detect new keys on update (#35)

### ⚡ Architectural & UX Improvements

- Performance, HAL contract validation, and bilingual documentation parity.

### 🐛 Bug Fixes

- [coe_database] Support flexible parameter parsing and lua unpack calls
- [rentals] Use defensive _t, fix server return logic and expand smoke boot coverage
- [staff] Show friendly empty state when garage service is unavailable
- [staff] Remove duplicate closing brace in renderGarages
- [staff] Decouple garages via RegisterGaragesProvider for open-core compliance


## [v0.1.0-beta.8] — 2026-10-26 · `BETA`

COE Framework v0.1.0-beta.8 (beta): 4 atualização(ões). Destaque: Atualiza coe_database, coe_inventory, coe_spawn, recipe.yaml.

### ✨ Implementations (New Features & Systems)

- Release v0.1.0-beta.8 (BETA) consolidated with 27 first-party resources.

### ⚡ Architectural & UX Improvements

- Performance, HAL contract validation, and bilingual documentation parity.

### 🐛 Bug Fixes

- General stability and persistence fixes across core and gameplay modules.


## [v0.1.0-beta.7] — 2026-10-26 · `BETA`

COE Framework v0.1.0-beta.7 (beta): 2 atualização(ões). Destaque: Sincroniza versão e manifesto em coe_supervisor, tools, version.json.

### ✨ Implementations (New Features & Systems)

- Release v0.1.0-beta.7 (BETA) consolidated with 27 first-party resources.

### ⚡ Architectural & UX Improvements

- Performance, HAL contract validation, and bilingual documentation parity.

### 🐛 Bug Fixes

- General stability and persistence fixes across core and gameplay modules.


## [v0.1.0-beta.6] — 2026-10-26 · `BETA`

COE Framework v0.1.0-beta.6 (beta): 1 atualização(ões). Destaque: Sincroniza versão e manifesto em coe_staff, coe_supervisor, tools, version.json.

### ✨ Implementations (New Features & Systems)

- Release v0.1.0-beta.6 (BETA) consolidated with 27 first-party resources.

### ⚡ Architectural & UX Improvements

- Performance, HAL contract validation, and bilingual documentation parity.

### 🐛 Bug Fixes

- General stability and persistence fixes across core and gameplay modules.


## [v0.1.0-beta.5] — 2026-10-26 · `BETA`

COE Framework v0.1.0-beta.5 (beta): 1 atualização(ões). Destaque: Sincroniza versão e manifesto em coe_staff, coe_supervisor, tools, version.json.

### ✨ Implementations (New Features & Systems)

- Release v0.1.0-beta.5 (BETA) consolidated with 27 first-party resources.

### ⚡ Architectural & UX Improvements

- Performance, HAL contract validation, and bilingual documentation parity.

### 🐛 Bug Fixes

- General stability and persistence fixes across core and gameplay modules.


## [v0.1.0-beta.4] — 2026-10-26 · `BETA`

COE Framework v0.1.0-beta.4 (beta): 2 atualização(ões). Destaque: Atualiza coe_spawn, reference.

### ✨ Implementations (New Features & Systems)

- Release v0.1.0-beta.4 (BETA) consolidated with 27 first-party resources.

### ⚡ Architectural & UX Improvements

- Performance, HAL contract validation, and bilingual documentation parity.

### 🐛 Bug Fixes

- General stability and persistence fixes across core and gameplay modules.


## [v0.1.0-beta.3] — 2026-10-26 · `BETA`

COE Framework v0.1.0-beta.3 (beta): 3 atualização(ões) em coetarget, coe_appearance, coe_audit, coe_bank, coe_businesses e +22 resources. Destaque: **[release]** Prepara release v0.1.0-beta.2.

### ✨ Implementations (New Features & Systems)

- Release v0.1.0-beta.3 (BETA) consolidated with 27 first-party resources.

### ⚡ Architectural & UX Improvements

- Performance, HAL contract validation, and bilingual documentation parity.

### 🐛 Bug Fixes

- General stability and persistence fixes across core and gameplay modules.


## [v0.1.0-beta.2] — 2026-10-26 · `BETA`

COE Framework v0.1.0-beta.2 (beta): 2 atualização(ões) em coetarget, coe_appearance, coe_audit, coe_bank, coe_businesses e +22 resources. Destaque: **[staff]** Atualiza coe_staff.

### ✨ Implementations (New Features & Systems)

- Release v0.1.0-beta.2 (BETA) consolidated with 27 first-party resources.

### ⚡ Architectural & UX Improvements

- Performance, HAL contract validation, and bilingual documentation parity.

### 🐛 Bug Fixes

- General stability and persistence fixes across core and gameplay modules.


## [v0.1.0-beta.1] — 2026-10-26 · `BETA`

First structured public release of the **COE Framework** for **FiveM Enhanced (Build b170+ / DirectX 12 / GTAV Gen9)**, consolidating all **27 first-party resources** (9 Tier 1 Infrastructure + 18 Tier 2 City Base), native versioning and in-game auto-updater, integrated player metabolism with tactical HUD indicators, and turnkey deployment stability via txAdmin Recipe.

### ✨ Implementations (New Features & Systems)

- **Unified Versioning System & In-Game Auto-Updater (`coe_supervisor` + `coe_staff`)**:
  - Central `version.json` manifest synchronized across all 27 `fxmanifest.lua` files, `recipe.yaml`, and `docs`.
  - Automatic startup update checker (`coe_supervisor/updater.lua`) querying the latest official release without blocking server boot.
  - Console command `coe update` (and `coe version`) + 1-click interactive updater inside the Admin Panel (`F10` → Overview), downloading and applying updated scripts while automatically preserving local `config.lua` customizations.
- **Full Consumables, Alcohol, Energy Drinks & Substances Integration (`coe_inventory` + `coe_needs` + `coe_hud`)**:
  - Per-item configurable consumption time (`consumeTime` in ms) with animated progress bar and instant cancellation via the **`X`** key (`KEY_X`) prior to completion.
  - Dedicated tactical HUD indicators (`coe_hud`) for **Alcohol (`alcohol`)** and **Substances (`drug`)** with smart on-demand visibility and progressive camera/movement effects.
  - Dynamic status drain (`coe_needs`) tied to real-time player actions (sprinting, swimming, melee combat, and high-speed driving).
- **Beginner Onboarding & AI Agent Integration Guide (`coedocs`)**:
  - Step-by-step guide for first-time server owners to install and run the COE Framework (`GETTING_STARTED_BEGINNERS.en-US.md`).
  - Practical guide for connecting AI coding agents to the COE ecosystem rules (`.agents/rules/`), skills (`.agents/skills/`), and typed contracts (`types.lua`).

### ⚡ Architectural & UX Improvements

- **Official Alignment with Cfx.re FiveM Enhanced Build `b170+`**:
  - Standardized all documentation, website guides, and deployment recipes around the recommended FiveM Enhanced server artifact (`b170+` / Node 22 LTS / MariaDB 11.x+).
- **Standardized Keybinds & Input Contracts**:
  - Unified Inventory on key **`I`** (`coe_inventory:open`) and Quick Hotbar on key **`TAB`** (`coe_inventory:hotbar`) with 100% parity between code and documentation.
- **Release Pipeline & Git Workflow in `CoeBuildManager`**:
  - Dedicated **Releases** tab featuring an automated categorized Release Notes generator (Implementations, Improvements, Fixes), enforced unique `chore/...` branches per PR, and automatic synchronization with `docs` and `website`.

### 🐛 Bug Fixes

- **Admin Panel `F10` (`coe_staff`) — Businesses Tab**:
  - Fixed `TypeError: (state.businesses.permissions || []).forEach is not a function` when an empty Lua permissions table was serialized as an empty JSON object `{}` in NUI.
- **Business Tablet Icon (`coe_inventory`)**:
  - Added and mapped `data/images/business_tablet.webp` in `coe_inventory/fxmanifest.lua`, eliminating the missing NUI file error.
- **Admin Money Grant & MariaDB Strict Mode Persistence (`coe_staff` + `coe_economy` + `coe_businesses`)**:
  - Fixed `set coe_database_port {{dbPort}}` syntax in txAdmin `recipe.yaml`.
  - Increased physical `money` item `maxStack` to `10,000,000` in `coe_inventory/config.lua` so staff can grant large cash amounts via `F10`.
  - Updated `coe_businesses` SQL queries for full MariaDB 11.x+ `ONLY_FULL_GROUP_BY` compliance and immediate persistence into `coe_business_grades`.

### 📦 Modules & Resources in this Release (`27/27`)

- **Infrastructure (Tier 1 — 9 resources):** `coe_supervisor`, `coe_logging`, `coe_database`, `coe_core`, `coe_ui`, `coetarget`, `coe_audit`, `coe_notify`, `coe_loadscreen`.
- **City Base (Tier 2 — 18 resources):** `coe_characters`, `coe_spawn`, `coe_appearance`, `coe_hud`, `coe_map`, `coe_needs`, `coe_inventory`, `coe_economy`, `coe_shops`, `coe_vehicles`, `coe_vehicle_catalog`, `coe_talk`, `coe_jobs`, `coe_businesses`, `coe_emotes`, `coe_interactions`, `coe_medic`, `coe_staff`.

<!-- COE_RELEASES_END -->
