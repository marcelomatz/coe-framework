<p align="right">
  <b>🇺🇸 English</b> • <a href="README.pt-BR.md">🇧🇷 Português</a>
</p>

# ⚡ COE Framework

> **The Next Generation of FiveM Engineering** — Strict Server-Authoritative Architecture, Hardware Abstraction Layer (`Core.Platform`), 0.00ms Idle Resmon, and End-to-End Type Safety.

[![FiveM](https://img.shields.io/badge/FiveM-FXServer%20b3407+-blue.svg)](https://fivem.net)
[![Lua](https://img.shields.io/badge/Lua-5.4-blue.svg)](https://www.lua.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Architecture](https://img.shields.io/badge/Architecture-Server--Authoritative-orange.svg)](#architecture--engineering-principles)
[![Documentation](https://img.shields.io/badge/Docs-COE%20Docs-purple.svg)](https://github.com/marcelomatz/coe-docs)

---

## 💬 A Message from Marcelo Matz: Giving Back to the FiveM Community

> *"I have been developing software for over 25 years. Throughout my entire career in technology, very few things have captivated me as deeply as the magic of roleplay and the boundless creativity of the FiveM community. Seeing hundreds of players simultaneously connected, weaving stories, creating cities, and sustaining vibrant communities through code is nothing short of inspiring.*
>
> *Releasing the **COE Framework** as open source is my humble way of giving back a portion of everything this wonderful community has given me over the years.*
>
> *I want to express my deepest respect and heartfelt gratitude to the pioneers and brilliant minds behind frameworks like **ESX**, **QBCore**, **Qbox**, and **Ox**. They laid the very foundation on which we all stand today, and they continue to do tireless, incredible work for the ecosystem. Likewise, my warmest thanks go out to every single **modder**, creator, and server administrator who dedicates their nights and weekends to making FiveM an ever-evolving, richer platform.*
>
> *The COE Framework is offered to the community with an open heart: 24 production-ready, fully tested resources built from a clean sheet with strict server-authoritative logic, 0.00ms idle resmon, a complete Platform HAL, and MariaDB 11 async pooling. May it serve as a reliable tool, a modern alternative, and an open foundation for our community to keep building the future of roleplay."*
>
> — **Marcelo Matz**

---

## 📖 Overview

**COE Framework** is a complete, high-performance roleplay foundation for FiveM, engineered from the ground up based on contemporary software architecture:

* **Strict Server-Authoritative**: The FiveM client is treated as an untrusted rendering terminal. State transitions, cash balances, and inventory changes are verified and executed strictly on the server.
* **Platform Abstraction Layer (`Core.Platform`)**: Zero GTA V raw natives in domain logic. Game engine interactions pass through modular, testable abstraction contracts.
* **Peak Performance**: Resources operating at **0.00ms idle resmon** via event-driven rendering and spatially optimized raycasting.
* **Dynamic Internationalization (i18n)**: Native asynchronous multi-language engine (`en-US`, `pt-BR`) with 100% key parity and defensive runtime fallback.
* **Durable Relational Persistence**: MariaDB 11 connection pooling in Node.js 22 LTS with prepared statements, idempotent migrations, and zero-rollback durability.

---

## 📦 Open Source Modules (Tier 1 & Tier 2 — 24 Resources)

The `coe-framework` repository provides **24 essential and self-contained resources** under the permissive [MIT License](LICENSE):

### 🏛️ Tier 1 — Core Ecosystem (9 Resources)
| Resource | Description |
|---|---|
| [`coe_core`](coe_core) | Central entity registry, player lifecycle management, export contracts, and Platform HAL (`Core.Platform`). |
| [`coe_database`](coe_database) | Asynchronous persistence layer via Node.js 22 MariaDB dynamic pooling with parameterized security. |
| [`coe_ui`](coe_ui) | NUI Design System featuring CSS design tokens, 5 dynamic themes, and accessible reactive components. |
| [`coetarget`](coetarget) | High-performance 3D raycast eye-targeting with line-of-sight (LOS) checks (0.00ms idle resmon). |
| [`coe_supervisor`](coe_supervisor) | Topological dependency boot manager, startup telemetry, and watchdog supervision. |
| [`coe_logging`](coe_logging) | Structured telemetry pipeline with caller allowlist, sanitization, and runtime level overrides. |
| [`coe_notify`](coe_notify) | Reactive NUI notification queue integrated with universal audio cues and visual tokens. |
| [`coe_loadscreen`](coe_loadscreen) | Modern loading screen integrated with the server handshake and seamless camera transitions. |
| [`coe_audit`](coe_audit) | Immutable, durable audit ledger recorded in MariaDB for financial operations and security. |

### 🌐 Tier 2 — Community Base (15 Resources)
| Resource | Description |
|---|---|
| [`coe_characters`](coe_characters) | Multi-character 3D scene selector with dynamic slots, state synchronization, and metadata. |
| [`coe_spawn`](coe_spawn) | Deterministic player spawn pipeline with cinematic camera transitions and interior restoration. |
| [`coe_appearance`](coe_appearance) | Character creator (genetic inheritance, facial sculpting, and clothing) compatible with freemode models. |
| [`coe_hud`](coe_hud) | Customizable HUD (`/hud`), digital speedometer, health/armor gauges, fuel level, and voice range. |
| [`coe_needs`](coe_needs) | Physiological simulation of hunger, thirst, and stress calculated authoritatively in server batches. |
| [`coe_inventory`](coe_inventory) | Grid-based drag-and-drop inventory with trunks, gloveboxes, stashes, and 233 WebP/PNG icons. |
| [`coe_map`](coe_map) | Dynamic minimap blip controller and radar expansion overlay triggered by the Z key. |
| [`coe_pausemenu`](coe_pausemenu) | Custom ESC pause menu styled with `coe_ui` tokens, featuring rules, guide, and shortcuts. |
| [`coe_talk`](coe_talk) | 3D native audio integration, submix filters, radio channels, and proximity volume controls. |
| [`coe_businesses`](coe_businesses) | Corporate business management, 0–99 rank hierarchy, physical duty clock-in, and payroll. |
| [`coe_economy`](coe_economy) | Dual-entry immutable financial ledger, `/balance` command, and corporate society accounts. |
| [`coe_shops`](coe_shops) | 24/7 convenience stores, supermarkets, and shopping carts with weight checks and account billing. |
| [`coe_jobs`](coe_jobs) | Freelance careers (lumberjack, miner, delivery, etc.) with shared career progression and XP. |
| [`coe_vehicle_catalog`](coe_vehicle_catalog) | Neutral automotive metadata database indexing GTA V vehicle classes, names, and storage specs. |
| [`coe_vehicles`](coe_vehicles) | Authoritative vehicle ownership, plate management, digital key chains, lock states, and digital odometers. |

---

## 💎 Advanced Modules (Future Commercial Suite)

The primary and immediate focus of this project is to consolidate and support the open-source foundation for the FiveM community. In a future phase, complementary AAA studio-grade suites will be made available as modular, optional add-ons under **Cfx.re Asset Escrow**:

1. **COE OS Suite**: Smartphones with WebRTC calling, enterprise Tablets, professional networking, and App Marketplace.
2. **Automotive Pro & Dyno**: Live dynamometer with torque curves, 16 mechanical subsystems wear, and mixed fuel pumps.
3. **Cyber & Underworld**: Dark web Onion browser, Noxcoin cryptocurrency mining, stashes, and faction territory wars.
4. **Public Safety & Forensics**: Forensic police investigations (ballistics & DNA), EMS medical triage, and MDT mobile data terminal.
5. **Enterprise & Governance**: Commercial banking with credit scoring, instanced housing in routing buckets, and high-security doors.

---

## 🚀 Quickstart

### Prerequisites
* FiveM Server Artifacts **b3407+** or recommended production build (Windows or Linux).
* MariaDB Server **10.6+** or MySQL **8.0+** with `utf8mb4_unicode_ci`.
* Lua **5.4** runtime enabled (`lua54 'yes'`).

### 1. Installation
```bash
# Clone the repository into your server resources directory
cd txData/YOUR_SERVER/resources
git clone https://github.com/marcelomatz/coe-framework.git [coe-framework]
```

### 2. Configure `server.cfg`
Ensure `coe_supervisor` is launched prior to other modules:
```cfg
ensure coe_supervisor
ensure [coe-framework]
```

### 3. Validate Contracts
Run the offline verification suite before starting your live environment:
```bash
cd [coe-framework]
lua tools/check_contracts.lua --strict --audit-natives --audit-locales
lua tools/smoke_boot_test.lua
```

---

## 🛠️ Contributing & CLA

Community contributions are warmly welcomed! To contribute code, translations, or bug fixes:
1. Review the [Contributing Guidelines & Contributor License Agreement (CLA)](CONTRIBUTING.md).
2. Ensure new features adhere to the architectural rules (Server-Authoritative, Platform HAL decoupling, strict i18n).
3. Open a Pull Request with a clear description of your changes.

---

## 📄 License

The code in this repository is licensed under the permissive [MIT License](LICENSE).

---

## 🌐 Links & Community

* **Official Documentation**: [COE Docs](https://github.com/marcelomatz/coe-docs)
* **Official Website**: [COE Framework](https://coe.matz.digital)
* **Issue Tracker**: [GitHub Issues](https://github.com/marcelomatz/coe-framework/issues)
