-- coe_garage (shared): tradutor global _t usado por client.lua e application/service.lua.
-- Carregado depois dos arquivos de locales. Não sobrescreve um _t já definido (os testes injetam o seu).
if type(_t) ~= 'function' then
	local rawLocales = (type(Locales) == 'table' and Locales) or {}
	local instance = (type(Core) == 'table' and type(Core.Locale) == 'table' and type(Core.Locale.New) == 'function')
		and Core.Locale.New({ default = Core.Locale.GetDefaultLang(), locales = rawLocales })
		or nil

	function _t(key, params)
		if instance then
			return instance:T(key, params)
		end
		local dict = rawLocales['pt-BR'] or {}
		local text = dict[key] or key
		if type(params) == 'table' then
			for k, v in pairs(params) do
				text = text:gsub('{' .. k .. '}', tostring(v))
			end
		end
		return text
	end
end
