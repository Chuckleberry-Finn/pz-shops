require "shop-wallet"
local _internal = require "shop-shared"

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

---@param item InventoryItem
function shopsAndTradersRecipe.checkDeedValid(recipe, playerObj, item) --onCanPerform
    if not item then return false end
    print("checkDeedValid: item:"..tostring(item))

    local cont = item:getContainer()
    if not cont then
        print("not cont")
        return false
    end

    local worldObj = cont and (not cont:isInCharacterInventory(playerObj)) and cont:getParent()
    if not worldObj then
        print("not worldObj")
        return false
    end
    if worldObj and worldObj:getModData().storeObjID then
        print("storeObjID present")
        return false
    end


    return true
end

---@param items ArrayList
---@param player IsoPlayer|IsoGameCharacter
function shopsAndTradersRecipe.onActivateDeed(items, result, player) --onCreate
    if player and player:getSteamID()==0 then return end
    local item = items:get(0)
    print("onActivateDeed: item:"..tostring(item))

    local cont = item:getContainer()
    if not cont then
        print("not cont")
        return false
    end

    local worldObj = cont and (not cont:isInCharacterInventory(player)) and cont:getParent()
    if not worldObj then
        print("not worldObj")
        return false
    end
    if worldObj and worldObj:getModData().storeObjID then
        print("storeObjID present")
        return false
    end

    cont:DoRemoveItem(item)

    print("deed activated")

    local x, y, z, worldObjName = worldObj:getX(), worldObj:getY(), worldObj:getZ(), _internal.getWorldObjectName(worldObj)
    sendClientCommand("shop", "assignStore", { x=x, y=y, z=z, worldObjName=worldObjName, owner=player:getSteamID() })
end


--[[
local moneyValueForDeedRecipe
function shopsAndTradersRecipe.addMoneyTypesToRecipe(scriptItems)
    print(" -- recipe adding: ")
    for _,type in pairs(_internal.getMoneyTypes()) do
        print(" --- ?: "..type)
        local scriptItem = getScriptManager():getItem(type)
        if not scriptItems:contains(scriptItem) then scriptItems:add(scriptItem) end
    end
end

function shopsAndTradersRecipe.onCanPerform(recipe, playerObj, item)
    return true
end

function shopsAndTradersRecipe.onCreate(items, result, player) end

--Creates Recipe for Shop Deeds
function shopsAndTradersRecipe.addDeedRecipe()
    local deedRecipe = SandboxVars.ShopsAndTraders.PlayerOwnedShopDeeds
    if not deedRecipe or deedRecipe=="" then return end

    local deedScript = {
        header="module ShopsAndTraders { imports { Base } recipe Create Shop Deed { ",
        footer="Result:ShopsAndTraders.ShopDeed, Time:30.0, Category:Shops,} }",
    }

    local rebuiltScript = ""
    for str in string.gmatch(deedRecipe, "([^|]+)") do

        local value, money = string.gsub(str, "%$", "")
        if money > 0 then
            moneyValueForDeedRecipe = value
            rebuiltScript = rebuiltScript.."keep Base.Money, "
            print("DEED SCRIPT: CURRENCY: ", value)
        else
            rebuiltScript = rebuiltScript..str..", "
            print("DEED SCRIPT:", str)
        end
    end

    print("SCRIPT:", rebuiltScript)

    local scriptManager = getScriptManager()
    scriptManager:ParseScript(deedScript.header..rebuiltScript..deedScript.footer)
end
--]]

--Events.OnResetLua.Add(shopsAndTradersRecipe.addDeedRecipe)
--Events.OnLoad.Add(shopsAndTradersRecipe.addDeedRecipe)
--if isServer() then Events.OnGameBoot.Add(shopsAndTradersRecipe.addDeedRecipe) end
