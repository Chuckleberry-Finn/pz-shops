require "shop-wallet"

shopsAndTradersRecipe = {}

---Authentic Z
--recipe Make a Stack of Money { Money, Result:Authentic_MoneyStack, Time:30.0, }
--recipe Convert into Item { Authentic_MoneyStack, Result:Money, Time:30.0, }

function shopsAndTradersRecipe.OnAuthZMoneyStack(items, result, player) return false end

local function recipeOverride()
    local allRecipes = getAllRecipes()
    for i=0, allRecipes:size()-1 do
        ---@type Recipe
        local recipe = allRecipes:get(i)
        if recipe then
            if recipe:getResult():getFullType()=="AuthenticZClothing.Authentic_MoneyStack" then
                recipe:setLuaTest("shopsAndTradersRecipe.OnAuthZMoneyStack")
                recipe:setIsHidden(true)
            end
        end
    end
end
Events.OnGameBoot.Add(recipeOverride)


function shopsAndTradersRecipe.checkDeedValid()
    return true
end


local moneyValueForDeedRecipe
function shopsAndTradersRecipe.spendMoney() end


function shopsAndTradersRecipe.activateDeed() end


--Creates Recipe for Shop Deeds
local ran = false

function shopsAndTradersRecipe.addDeedRecipe()
    if ran then return else ran = true end

    local deedRecipe = SandboxVars.ShopsAndTraders.PlayerOwnedShopDeeds
    if not deedRecipe or deedRecipe=="" then return end

    local deedScript = {
        header="recipe Create Shop Deed { ",
        footer=" Result:ShopsAndTraders.ShopDeed, Time:30.0, }",
    }

    local rebuiltScript = ""

    for str in string.gmatch(deedRecipe, "([^,]+)") do

        local value, money = string.gsub(str, "%$", "")
        if money > 0 then
            moneyValueForDeedRecipe = value
            rebuiltScript = rebuiltScript.."[shopsAndTradersRecipe.spendMoney]"..", "
            print("DEED SCRIPT: CURRENCY: ",value)
        else
            rebuiltScript = rebuiltScript..str..", "
            print("DEED SCRIPT:",str)
        end
    end

    local scriptManager = getScriptManager()
    scriptManager:ParseScript(deedScript.header..rebuiltScript..deedScript.footer)
end
Events.OnGameBoot.Add(shopsAndTradersRecipe.addDeedRecipe)