local _internal = require "shop-shared"

local function applyOnCreate()
    local SM = getScriptManager()
    local moneyTypes = _internal.getMoneyTypes()
    for _,moneyType in pairs(moneyTypes) do
        local moneyScript = SM:getItem(moneyType)
        if moneyScript then
            moneyScript:DoParam("OnCreate = generateMoneyValue")
        end
    end
end
applyOnCreate()
