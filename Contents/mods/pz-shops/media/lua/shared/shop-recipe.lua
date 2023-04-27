require "shop-wallet"
local _internal = require "shop-shared"

shopsAndTradersRecipe = {}

local moneyValueForDeedRecipe

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

    print("deed activated")

    storeWindow:onBrowse(nil, worldObj)

    local x, y, z, worldObjName = worldObj:getX(), worldObj:getY(), worldObj:getZ(), _internal.getWorldObjectName(worldObj)
    sendClientCommand("shop", "assignStore", { x=x, y=y, z=z, worldObjName=worldObjName, owner=player:getUsername() })

    cont:DoRemoveItem(item)
end


function shopsAndTradersRecipe.addMoneyTypesToRecipe(scriptItems)
    print(" -- recipe adding: ")
    for _,type in pairs(_internal.getMoneyTypes()) do
        print(" --- ?: "..type)
        local scriptItem = getScriptManager():getItem(type)
        if not scriptItems:contains(scriptItem) then scriptItems:add(scriptItem) end
    end
end


---@param recipe Recipe
---@param playerObj IsoPlayer|IsoGameCharacter
---@param item InventoryItem
function shopsAndTradersRecipe.onCanPerform(recipe, playerObj, item)
    if not moneyValueForDeedRecipe then return true end
    local wallet, walletBalance = getWallet(playerObj), 0
    if wallet then walletBalance = wallet.amount end

    local money = walletBalance

    for _,moneyType in pairs(_internal.getMoneyTypes()) do
        local moneyItems = playerObj:getInventory():getAllType(moneyType)
        for i=0, moneyItems:size()-1 do
            local moneyItem = moneyItems:get(i)
            if moneyItem and moneyItem:getModData().value then
                money = money + moneyItem:getModData().value
            end
        end
    end

    print("recipe:"..tostring(recipe))
    print("playerObj:"..tostring(playerObj))
    print("item:getType()"..(item and item:getType() or "null"))

    if money >= moneyValueForDeedRecipe then return true end
    return false
end


function shopsAndTradersRecipe.onCreate(items, result, player)
    print("items:"..tostring(items))
    print("result:"..tostring(result))
    print("player"..tostring(player))
end


--Creates Recipe for Shop Deeds
function shopsAndTradersRecipe.addDeedRecipe()
    local deedRecipe = SandboxVars.ShopsAndTraders.PlayerOwnedShopDeeds
    if not deedRecipe or deedRecipe=="" then return end

    local deedScript = {
        header = "module ShopsAndTraders { imports { Base } recipe Create Shop Deed { ",
        footer = "Result:ShopsAndTraders.ShopDeed, OnCreate:shopsAndTradersRecipe.onCreate, OnCanPerform:shopsAndTradersRecipe.onCanPerform, Time:30.0, Category:Shops,} }",
    }

    local rebuiltScript = ""
    for str in string.gmatch(deedRecipe, "([^|]+)") do

        local item = str

        local value, money = string.gsub(item, "%$", "")
        if money > 0 then
            moneyValueForDeedRecipe = value
            item = "keep Base.Money"
        end

        local extracted = string.match(item, " (.*)") or item

        if not string.match(extracted,"%.") then
            item = string.gsub(item, extracted, "Base."..extracted)
        end

        if (item:sub(1, #"keep ")=="keep ") then
            rebuiltScript = rebuiltScript..item..", "
        elseif (item:sub(1, #"destroy ")=="destroy ") then
            rebuiltScript = rebuiltScript..item..", "
        else
            rebuiltScript = item..", "..rebuiltScript
        end
    end

    print("SCRIPT:", rebuiltScript)
    print("$VALUE: ", moneyValueForDeedRecipe)

    local scriptManager = getScriptManager()
    scriptManager:ParseScript(deedScript.header..rebuiltScript..deedScript.footer)
end

--Events.OnGameBoot.Add(shopsAndTradersRecipe.addDeedRecipe)
--Events.OnResetLua.Add(shopsAndTradersRecipe.addDeedRecipe)
Events.OnLoad.Add(shopsAndTradersRecipe.addDeedRecipe)
if isServer() then Events.OnGameBoot.Add(shopsAndTradersRecipe.addDeedRecipe) end
