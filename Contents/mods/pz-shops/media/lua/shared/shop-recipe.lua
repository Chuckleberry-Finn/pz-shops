require "shop-wallet"

---Authentic Z
--recipe Make a Stack of Money { Money, Result:Authentic_MoneyStack, Time:30.0, }
--recipe Convert into Item { Authentic_MoneyStack, Result:Money, Time:30.0, }

function ShopsAndTradersOnAuthZMoneyStack(items, result, player) return false end

local function recipeOverride()
    local allRecipes = getAllRecipes()
    for i=0, allRecipes:size()-1 do
        ---@type Recipe
        local recipe = allRecipes:get(i)
        if recipe then
            if recipe:getResult():getFullType()=="AuthenticZClothing.Authentic_MoneyStack" then
                recipe:setLuaTest("ShopsAndTradersOnAuthZMoneyStack")
                recipe:setIsHidden(true)
            end
        end
    end
end
Events.OnGameBoot.Add(recipeOverride)


function shopsAndTraders_checkDeedValid()
    return true
end

function shopsAndTraders_activateDeed()

end

--Creates Recipe for Shop Deeds
local ran = false
function shopsAndTraders_addDeedRecipe()
    if ran then return else ran = true end

    local deedRecipe = SandboxVars.ShopsAndTraders.PlayerOwnedShopDeeds
    if not deedRecipe or deedRecipe=="" then return end

    local deedScript = {
        header="recipe Create Shop Deed { ",
        footer=" Result:ShopsAndTraders.ShopDeed, Time:30.0, }"
    }

    --	   destroy PanFriedVegetables2,
    --	   	   BaseballBat,
    --       	   Nails=5,
    --       	   keep [Recipe.GetItemTypes.Hammer],
    --       	           TreeBranch,
    --                      keep [Recipe.GetItemTypes.SharpKnife]/MeatCleaver,

    local scriptManager = getScriptManager()
    scriptManager:ParseScript()
end
Events.OnGameBoot.Add(shopsAndTraders_addDeedRecipe)