local _, ns = ...
local locale = type(GetLocale) == "function" and GetLocale() or "enUS"
ns.locale = locale == "enGB" and "enUS" or locale
ns.L = setmetatable({}, { __index = function(_, key) return key end })

function ns:RegisterLocale(language, translations)
    if language ~= self.locale then return end
    for key, value in pairs(translations) do
        if type(value) == "string" and value ~= "" then self.L[key] = value end
    end
end
