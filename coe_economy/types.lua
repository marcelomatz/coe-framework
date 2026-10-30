---@meta
-- Contrato público de coe_economy para LuaLS. Não é carregado pelo servidor. Ver docs/ANNOTATIONS.md.
-- Exports server-only. O chamador vem do runtime (GetInvokingResource) e precisa estar em `EconomyConfig.AllowedResources`
-- ou ter a ACE `coe.economy.money` (add_ace resource.<nome> coe.economy.money allow). Valores são inteiros >= 1 e
-- <= `MaxAmount`; ids de personagem são inteiros positivos (número ou string); `reason` é `[a-z0-9_]{1,32}` e
-- `reference` é `[A-Za-z0-9_:-]{0,64}`. Códigos de erro comuns: `forbidden`, `not_ready`, `invalid_amount`,
-- `invalid_character`, `invalid_reason`, `invalid_reference`, `insufficient_funds`, `balance_limit`, `database_error`.

---@class CoeEconomyExports
local exports_coe_economy = {}

---@class CoeEconomyError
---@field error string Código de erro

---@class CoeEconomyLedgerRow
---@field delta integer Positivo = entrada, negativo = saída
---@field reason string
---@field reference string
---@field created_at any texto do banco (fuso do servidor MariaDB)
---@field at number|string segundos Unix (UNIX_TIMESTAMP), prefira este para exibir datas

---@class CoeEconomyPayrollSummary
---@field paid table[] Pagamentos feitos (`characterId`, `salary`)
---@field total integer Total pago
---@field skipped table[] Quem não recebeu (`characterId`, `salary`, `reason`: `off_duty` | `insufficient_funds`)

-- Contas pessoais --------------------------------------------------------------------------------------------

---Persistência pronta e chamador autorizado.
---@return boolean ready
function exports_coe_economy:IsReady() end

---Totais da economia (contas e soma dos saldos). Exige também a ACE `coe.economy.admin`.
---@return { accounts: integer, total: integer }|CoeEconomyError summary
function exports_coe_economy:Summary() end

---Saldo do personagem (a conta é criada com `StartingBalance` no primeiro acesso).
---@param characterId integer|string
---@return integer|nil balance
---@return string|nil errorCode
function exports_coe_economy:GetBalance(characterId) end

---Credita na conta do personagem, respeitando o teto `MaxBalance`. Auditado (`money_credited`).
---@param characterId integer|string
---@param amount integer
---@param reason string
---@param reference string|nil
---@return true|nil ok
---@return string|nil errorCode
function exports_coe_economy:Credit(characterId, amount, reason, reference) end

---Debita da conta do personagem; recusa sem saldo (transação estrita no banco). Auditado (`money_debited`).
---@param characterId integer|string
---@param amount integer
---@param reason string
---@param reference string|nil
---@return true|nil ok
---@return string|nil errorCode
function exports_coe_economy:Debit(characterId, amount, reason, reference) end

---Transfere entre dois personagens numa única transação. Auditado (`money_transferred`).
---@param fromId integer|string
---@param toId integer|string
---@param amount integer
---@param reason string
---@param reference string|nil
---@return true|nil ok
---@return string|nil errorCode `same_account` além dos comuns
function exports_coe_economy:Transfer(fromId, toId, amount, reason, reference) end

---Extrato pessoal, mais recentes primeiro.
---@param characterId integer|string
---@param limit integer|nil 1-100 (padrão 20)
---@return CoeEconomyLedgerRow[]|CoeEconomyError rows
function exports_coe_economy:Ledger(characterId, limit) end

---Estatísticas do extrato no período.
---@param characterId integer|string
---@param days integer|nil 1-365 (padrão 7)
---@param ignored string[]|nil Motivos que não contam como entrada (até 20)
---@return { firstAt: integer|nil, inflow: integer }|CoeEconomyError stats
function exports_coe_economy:LedgerStats(characterId, days, ignored) end

-- Sociedade (conta do negócio, coe_businesses) ----------------------------------------------------------------
-- Retornam valor único ou { error = codigo }: multi-retorno se perde entre resources. `unknown_business` quando o
-- negócio não existe no coe_businesses.

---@param businessId string
---@return integer|CoeEconomyError balance
function exports_coe_economy:SocietyBalance(businessId) end

---@param businessId string
---@param limit integer|nil 1-100 (padrão 20)
---@return table[]|CoeEconomyError rows
function exports_coe_economy:SocietyLedger(businessId, limit) end

---Depósito do saldo pessoal na sociedade. Só dono ou equipe do negócio (`not_staff`).
---@param businessId string
---@param characterId integer|string
---@param amount integer
---@return true|CoeEconomyError result
function exports_coe_economy:SocietyDeposit(businessId, characterId, amount) end

---Saque da sociedade para o saldo pessoal. Exige a permissão de cargo `business.funds` (o dono tem todas).
---@param businessId string
---@param characterId integer|string
---@param amount integer
---@return true|CoeEconomyError result
function exports_coe_economy:SocietyWithdraw(businessId, characterId, amount) end

---Aporte administrativo, sem personagem. Exige a ACE `coe.economy.admin`.
---@param businessId string
---@param amount integer
---@param reason string|nil Padrão `admin_adjustment`
---@return true|CoeEconomyError result
function exports_coe_economy:SocietyCredit(businessId, amount, reason) end

---Repasse de receita já cobrada de um cidadão (ex.: venda da loja). Só `SocietyCollectors` ou ACE
---`coe.economy.society.collect`.
---@param businessId string
---@param amount integer
---@param reason string
---@return true|CoeEconomyError result
function exports_coe_economy:SocietyCollect(businessId, amount, reason) end

---Despesa do negócio sem personagem (ex.: aluguel). Só `SocietyPayers` ou ACE `coe.economy.society.pay`.
---@param businessId string
---@param amount integer
---@param reason string
---@param reference string|nil
---@return true|CoeEconomyError result
function exports_coe_economy:SocietyCharge(businessId, amount, reason, reference) end

-- Conta bancária empresarial: só `SocietyBankers` ou ACE `coe.economy.society.bank`. O banco confere as
-- permissões de cargo; aqui ficam a atomicidade, os limites e o extrato.

---Da sociedade para a conta de um personagem.
---@param businessId string
---@param characterId integer|string
---@param amount integer
---@param reason string
---@param reference string|nil
---@return true|CoeEconomyError result
function exports_coe_economy:BankSocietyPay(businessId, characterId, amount, reason, reference) end

---Da conta de um personagem para a sociedade.
---@param businessId string
---@param characterId integer|string
---@param amount integer
---@param reason string
---@param reference string|nil
---@return true|CoeEconomyError result
function exports_coe_economy:BankSocietyDeposit(businessId, characterId, amount, reason, reference) end

---Saída sem conta de personagem do outro lado (saque em espécie, compra com cartão empresarial).
---@param businessId string
---@param amount integer
---@param reason string
---@param reference string|nil
---@return true|CoeEconomyError result
function exports_coe_economy:BankSocietyDebit(businessId, amount, reason, reference) end

---Entrada sem conta de personagem do outro lado (depósito em espécie, estorno).
---@param businessId string
---@param amount integer
---@param reason string
---@param reference string|nil
---@return true|CoeEconomyError result
function exports_coe_economy:BankSocietyCredit(businessId, amount, reason, reference) end

---Entre duas empresas.
---@param fromId string
---@param toId string
---@param amount integer
---@param reason string
---@param reference string|nil
---@return true|CoeEconomyError result
function exports_coe_economy:BankSocietyTransfer(fromId, toId, amount, reason, reference) end

---Extrato filtrado com totais do período.
---@param businessId string
---@param filter { direction: 'in'|'out'|nil, reasons: string[]|nil, days: integer|nil, limit: integer|nil, beforeId: integer|nil }|nil
---@return { rows: table[], totals: table }|CoeEconomyError page
function exports_coe_economy:BankSocietyLedger(businessId, filter) end

---Paga o salário do cargo a quem está de ponto, da conta da sociedade; sem saldo, não paga e não acumula dívida.
---Exige ACE `coe.economy.admin` ou ser banqueiro. Dispara o evento local `coe_economy:payrollPaid`.
---@param businessId string
---@return CoeEconomyPayrollSummary|CoeEconomyError summary
function exports_coe_economy:RunPayroll(businessId) end
