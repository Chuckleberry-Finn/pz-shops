require "shop-wallet"

---Authentic Z
--recipe Make a Stack of Money { Money, Result:Authentic_MoneyStack, Time:30.0, }
--recipe Convert into Item { Authentic_MoneyStack, Result:Money, Time:30.0, }

shopsAndTraders = {}
function shopsAndTraders.OnAuthZMoneyStack(items, result, player)
    return false
    --[[
    local moneyItem
    for i=0, items:size()-1 do
        local item = items:get(i)
        if item and isMoneyType(item:getFullType()) and item:getModData().value then
            moneyItem = item
            break
        end
    end
    if moneyItem and isMoneyType(result:getFullType()) then
        generateMoneyValue(result, moneyItem:getModData().value, true)
    end
    --]]
end

local function recipeOverride()
    local allRecipes = getAllRecipes()

    for i=0, allRecipes:size()-1 do
        ---@type Recipe
        local recipe = allRecipes:get(i)

        if recipe and isMoneyType(recipe:getResult():getFullType()) then
            --setLuaCreate
            recipe:setLuaTest("shopsAndTraders.OnAuthZMoneyStack")
            print("LUA CREATE APPLIED")
        end
    end
end
Events.OnGameBoot.Add(recipeOverride)