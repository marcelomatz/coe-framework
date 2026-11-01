---@meta
-- Contrato público de coe_deepweb para LuaLS. Não é carregado pelo servidor.
-- Ver docs/ANNOTATIONS.md. O app `onion` atende smartphone e tablet (só coe_phone e coe_tablet chamam); os
-- computadores usam a NUI própria do resource (eventos `coe_deepweb:computer:*`).

---@class CoeDeepwebExports
local exports_coe_deepweb = {}

---O app `onion` aparece no aparelho em uso? Só depois de instalar o navegador pelo pen drive (`onion_usb`).
---@param playerId integer
---@param appId string
---@return boolean visible
function exports_coe_deepweb:TabletVisible(playerId, appId) end

---Ação do app `onion` no smartphone ou no tablet.
---@param playerId integer
---@param appId string
---@param action string Identidade: `state|handleCreate|handleLogin|handleLogout|handlePassword|handleReset`; navegador: `bookmarks|bookmarkAdd|bookmarkRemove|site|directory|search|contactThread|contactSend`; Rabbit: `forumHome|forumCommunity|forumPost|forumUser|forumSubmit|forumComment|forumVote|forumRemove|forumCreate`; Deep Market: `marketHome|marketListing|marketBuy|marketMine|marketOrder|marketSave|marketListingStatus|marketAct|marketReview`
---@param payload table|nil
---@return table result `{ ok, ... }` ou `{ ok = false, error }`
function exports_coe_deepweb:TabletCall(playerId, appId, action, payload) end

---Panorama da DeepWeb para o admin: sites, fornecedores NPC, pedidos em disputa ou pagos sem entrega, posts recentes e contatos dos perfis. Só `coe_admin`.
---@return table result `{ available, ready, sites, vendors, orders, posts, contacts, categories, decimals, blockTypes }` ou `{ error }`
function exports_coe_deepweb:AdminOverview() end

---Cria ou atualiza um site por blocos (`.onion`). Sites de sistema não são editáveis. Só `coe_admin`.
---@param raw table `{ domain, title, description, keywords, blocks, active, listed }` (`listed = false`: fora do diretório e da busca)
---@return table result `{ ok, domain }` ou `{ error, index }`
function exports_coe_deepweb:AdminSaveSite(raw) end

---Apaga um site por blocos. Só `coe_admin`.
---@param raw table `{ domain }`
---@return table result `{ ok }` ou `{ error }`
function exports_coe_deepweb:AdminDeleteSite(raw) end

---Cria ou atualiza um anúncio de fornecedor NPC do Deep Market (preço em texto de moeda, ex.: `0,5`). Só `coe_admin`.
---@param raw table `{ id?, vendor, kind, category, title, description, item, count, price, stock, status }`
---@return table result `{ ok, id }` ou `{ error }`
function exports_coe_deepweb:AdminSaveVendor(raw) end

---Remove um anúncio de fornecedor NPC (pedidos em andamento continuam). Só `coe_admin`.
---@param raw table `{ id }`
---@return table result `{ ok }` ou `{ error }`
function exports_coe_deepweb:AdminDeleteVendor(raw) end

---Decide um pedido em disputa (ou cancela um pago sem entrega): `buyer` devolve, `seller` paga o vendedor. Só `coe_admin`.
---@param raw table `{ id, decision }`
---@return table result `{ ok, status }` ou `{ error }`
function exports_coe_deepweb:AdminResolveOrder(raw) end

---Remove um post do Rabbit. Só `coe_admin`.
---@param raw table `{ id }`
---@return table result `{ ok }` ou `{ error }`
function exports_coe_deepweb:AdminRemovePost(raw) end

---Responde uma mensagem de contato de um site de perfil (ex.: `fantasma.onion`) e avisa o apelido se estiver online. Só `coe_admin`.
---@param raw table `{ id, reply }`
---@return table result `{ ok }` ou `{ error }` (`invalid_reply`, `contact_closed`, `not_found`)
function exports_coe_deepweb:AdminReplyContact(raw) end

---Arquiva uma mensagem de contato. Só `coe_admin`.
---@param raw table `{ id }`
---@return table result `{ ok }` ou `{ error }`
function exports_coe_deepweb:AdminCloseContact(raw) end
