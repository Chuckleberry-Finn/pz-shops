local _internal = require "shop-shared"

local function sumMoneyValue(itemList)
    local total = 0
    for i=0, itemList:size()-1 do
        local item = itemList:get(i)
        if item and _internal.isMoneyType(item:getFullType()) then
            total = total + (item:getModData().value or 0)
        end
    end
    return _internal.floorCurrency(total)
end

function ShopsAndTradersOnBundleMoney(craftRecipeData, character)
    local total = sumMoneyValue(craftRecipeData:getAllConsumedItems())
    if total <= 0 then return end

    local created = craftRecipeData:getAllCreatedItems()
    for i=0, created:size()-1 do
        local item = created:get(i)
        if item then
            item:getModData().bundledValue = total
            if isServer() then item:syncItemFields() end
        end
    end
end


function ShopsAndTradersOnUnbundleMoney(craftRecipeData, character)
    local consumed = craftRecipeData:getAllConsumedItems()
    local total = 0
    for i=0, consumed:size()-1 do
        local item = consumed:get(i)
        if item and item:getModData().bundledValue then
            total = total + item:getModData().bundledValue
        end
    end

    local created = craftRecipeData:getAllCreatedItems()
    local count = created:size()
    if count <= 0 or total <= 0 then return end

    local remaining = total
    for i=0, count-1 do
        local item = created:get(i)
        if item then
            local value
            if i == count-1 then
                value = remaining
            else
                value = _internal.floorCurrency(remaining / (count - i))
            end
            item:getModData().value = value
            item:setActualWeight(SandboxVars.ShopsAndTraders.MoneyWeight * value)
            remaining = remaining - value
            if not isServer() then
                item:setName(_internal.numToCurrency(value))
            end
            if isServer() then item:syncItemFields() end
        end
    end
end


local function applyMoneyBundleRecipeHooks()
    local SM = getScriptManager()

    local bundleRecipeID = "stack_items"
    local bundleRecipe = SM:getCraftRecipe(bundleRecipeID)
    if bundleRecipe then
        bundleRecipe:Load(bundleRecipeID, "{ OnCreate = ShopsAndTradersOnBundleMoney, }")
    else
        print("[ShopsAndTraders] WARNING: could not find craftRecipe \""..bundleRecipeID.."\".")
    end

    local unbundleRecipeID = "UnbundleMoney"
    local unbundleRecipe = SM:getCraftRecipe(unbundleRecipeID)

    if unbundleRecipe then
        unbundleRecipe:Load(unbundleRecipeID, "{ OnCreate = ShopsAndTradersOnUnbundleMoney, }")
    else
        print("[ShopsAndTraders] WARNING: could not find craftRecipe \""..unbundleRecipeID.."\".")
    end
end

Events.OnGameStart.Add(applyMoneyBundleRecipeHooks)
if isServer() then Events.OnGameBoot.Add(applyMoneyBundleRecipeHooks) end