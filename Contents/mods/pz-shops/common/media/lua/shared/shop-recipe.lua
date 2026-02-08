require "shop-wallet"
local _internal = require "shop-shared"

shopsAndTradersRecipe = {}

local moneyValueForDeedRecipe

---Authentic Z
--recipe Make a Stack of Money { Money, Result:Authentic_MoneyStack, Time:30.0, }
--recipe Convert into Item { Authentic_MoneyStack, Result:Money, Time:30.0, }
--[[
function shopsAndTradersRecipe.OnAuthZMoneyStack(items, result, player) return false end

local function recipeOverride()
    local allRecipes = getAllRecipes()
    for i=0, allRecipes:size()-1 do
        ---@type Recipe
        local recipe = allRecipes:get(i)
        if recipe then
            local result = recipe and recipe:getResult()
            if result and result:getType()=="Authentic_MoneyStack" then
                recipe:setLuaTest("shopsAndTradersRecipe.OnAuthZMoneyStack")
                recipe:setIsHidden(true)
            end
        end
    end
end
Events.OnGameBoot.Add(recipeOverride)
--]]

---@param item InventoryItem
function shopsAndTradersRecipe.checkDeedValid(recipe, playerObj, item) --onCanPerform
    if not item then return false end

    local cont = item:getContainer()
    if not _internal.isValidContainer(cont) then return false end

    local worldObj = cont and (not cont:isInCharacterInventory(playerObj)) and cont:getParent()
    if not worldObj then return false end
    if worldObj and worldObj:getModData().storeObjID then return false end

    return true
end

---@param items ArrayList
---@param player IsoPlayer|IsoGameCharacter
function shopsAndTradersRecipe.onActivateDeed(items, result, player) --onCreate

    local item = items:get(0)
    local cont = item:getContainer()
    if not _internal.isValidContainer(cont) then return false end

    local worldObj = cont and (not cont:isInCharacterInventory(player)) and cont:getParent()
    if not worldObj then return false end
    if worldObj and worldObj:getModData().storeObjID then return false end

    local x, y, z, worldObjName = worldObj:getX(), worldObj:getY(), worldObj:getZ(), _internal.getWorldObjectName(worldObj)
    sendClientCommand("shop", "assignStore", { x=x, y=y, z=z, worldObjName=worldObjName, owner=player:getUsername() })

    storeWindow:onBrowse(nil, worldObj, player)

    if isClient() then
        cont:removeItemOnServer(item)
    end
    cont:DoRemoveItem(item)
end


function shopsAndTradersRecipe.addMoneyTypesToRecipe(scriptItems)
    for _,type in pairs(_internal.getMoneyTypes()) do
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
    --print("recipe:"..tostring(recipe))
    --print("playerObj:"..tostring(playerObj))
    --print("item:getType()"..(item and item:getType() or "null"))
    --print("money: "..money)

    if money >= moneyValueForDeedRecipe then return true end
    return false
end


function shopsAndTradersRecipe.onCreate(items, result, playerObj)
    if not moneyValueForDeedRecipe or moneyValueForDeedRecipe==0 then return true end

    local costNeeded = moneyValueForDeedRecipe
    local wallet, walletBalance = getWallet(playerObj), 0
    if wallet then walletBalance = wallet.amount end

    local money = walletBalance

    local moneyItems = {}
    for _,moneyType in pairs(_internal.getMoneyTypes()) do
        local playersMoneyItems = playerObj:getInventory():getAllType(moneyType)
        for i=0, playersMoneyItems:size()-1 do
            local moneyItem = playersMoneyItems:get(i)
            if moneyItem then
                local value = moneyItem:getModData().value
                if value then
                    money = money + value
                    moneyItems[moneyItem] = value
                end
            end
        end
    end

    if money >= costNeeded then
        if wallet and wallet.amount > 0 then
            local playerModData = playerObj:getModData()
            local transferValue = math.min(wallet.amount, costNeeded)
            costNeeded = costNeeded-transferValue
            sendClientCommand("shop", "transferFunds", {playerWalletID=playerModData.wallet_UUID, amount=(0-transferValue)})
        end

        if costNeeded > 0 then
            for mItem,mValue in pairs(moneyItems) do
                if costNeeded <= 0 then break end
                local cost = math.min(mValue, costNeeded)
                costNeeded = costNeeded-cost
                if mValue-cost <= 0 then
                    safelyRemoveMoney(mItem, playerObj)
                else
                    _internal.generateMoneyValue(mItem, mValue-cost, true)
                end
            end
        end
    end
end



--Creates Recipe for Shop Deeds
function shopsAndTradersRecipe.addDeedRecipe()

    local defaultRecipe = "item 1 [$1000] flags[Prop2] mode:destroy, item 1 [Base.SheetPaper2] flags[Prop1] mode:destroy,"
    local sandboxRecipe = SandboxVars.ShopsAndTraders.PlayerOwnedShopDeeds
    if not sandboxRecipe or sandboxRecipe=="NONE" then return end

    --- Maybe a way to validate the recipe would be possible?
    --correct old sandbox options
    local modified_option = sandboxRecipe and string.gsub(sandboxRecipe, "|", ",")
    --add missing comma that might be default for some older saves
    if modified_option and modified_option:sub(-1) ~= "," then modified_option = modified_option .. "," end

    local inputs = (not sandboxRecipe or sandboxRecipe == "") and defaultRecipe or modified_option

    --- find "[$X]," and replace X with "Base.Money"
    --- set `moneyValueForDeedRecipe` to value that was inbetween
    local value = inputs:match("%[%$(%d+)%]")
    if value then
        moneyValueForDeedRecipe = tonumber(value)
        inputs = inputs:gsub("%[%$(%d+)%]", "[Base.Money]")
    end

    local newScript = "{ inputs { " .. inputs .. " } }"

    local tooltip = ""
    if moneyValueForDeedRecipe and moneyValueForDeedRecipe > 0 then
        tooltip = "Tooltip:"..getText("IGUI_requires").." ".._internal.numToCurrency(moneyValueForDeedRecipe)..", "
    end

    if newScript then
        local scriptManager = getScriptManager()
        local recipe = scriptManager:getCraftRecipe("CraftDeed")
        if recipe then
            print("Shops and Traders: CraftDeed: Load: ", newScript)
            recipe:Load("CraftDeed", newScript)
        else
            print("ERROR: Could not find CraftRecipe 'CraftDeed'")
        end
    end
end

Events.OnGameBoot.Add(shopsAndTradersRecipe.addDeedRecipe)
