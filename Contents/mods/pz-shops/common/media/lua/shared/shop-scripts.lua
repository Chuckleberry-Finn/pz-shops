if isServer() then return end

local _internal = require "shop-shared"

function shopsAndTradersGenerateMoneyValue(item) _internal.generateMoneyValue(item) end

local function applyOnCreate()
    local SM = getScriptManager()
    local moneyTypes = _internal.getMoneyTypes()
    for _,moneyType in pairs(moneyTypes) do
        local moneyScript = SM:getItem(moneyType)
        if moneyScript then
            moneyScript:DoParam("OnCreate = shopsAndTradersGenerateMoneyValue")
        end
    end
end
applyOnCreate()
