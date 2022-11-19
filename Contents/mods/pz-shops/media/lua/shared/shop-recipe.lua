require "shop-wallet"

---Authentic Z
--recipe Make a Stack of Money { Money, Result:Authentic_MoneyStack, Time:30.0, }
--recipe Convert into Item { Authentic_MoneyStack, Result:Money, Time:30.0, }

shopsAndTraders = {}
function shopsAndTraders.OnAuthZMoneyStack(items, result, player) return false end

local function recipeOverride()
    local allRecipes = getAllRecipes()
    for i=0, allRecipes:size()-1 do
        ---@type Recipe
        local recipe = allRecipes:get(i)
        if recipe and recipe:getResult():getFullType()=="AuthenticZClothing.Authentic_MoneyStack" then recipe:setLuaTest("shopsAndTraders.OnAuthZMoneyStack") end
    end
end
Events.OnGameBoot.Add(recipeOverride)