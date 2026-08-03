if not isServer() then require "shop-wallet" end
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


function shopsAndTradersRecipe.checkDeedValid(item, playerObj) --OnTest
    --local result = craftRecipeData:getAllCreatedItems():get(0)
    --local item = craftRecipeData:getAllConsumedItems():get(0)
    if not item then return false end

    local cont = item:getContainer()
    if not _internal.isValidContainer(cont) then return false end

    local worldObj = cont and (not cont:isInCharacterInventory(playerObj)) and cont:getParent()
    if not worldObj then return false end
    if worldObj and worldObj:getModData().storeObjID then return false end

    return true
end


---@param player IsoPlayer|IsoGameCharacter
function shopsAndTradersRecipe.onActivateDeed(craftRecipeData, player) --onCreate
    -- local result = craftRecipeData:getAllCreatedItems():get(0)
    local item = craftRecipeData:getAllConsumedItems():get(0)
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


---@param playerObj IsoPlayer|IsoGameCharacter
function shopsAndTradersRecipe.canCraftDeed(craftRecipeData, playerObj) --OnTest
    -- local result = craftRecipeData:getAllCreatedItems():get(0)
    --local item = craftRecipeData:getAllConsumedItems():get(0)

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


---@param playerObj IsoPlayer|IsoGameCharacter
function shopsAndTradersRecipe.onCraftDeed(craftRecipeData, playerObj)
    -- local item = craftRecipeData:getAllConsumedItems():get(0)
    -- local result = craftRecipeData:getAllCreatedItems():get(0)

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
            local walletID = _internal.getWalletID(playerObj)
            local transferValue = math.min(wallet.amount, costNeeded)
            costNeeded = costNeeded-transferValue
            sendClientCommand("shop", "transferFunds", {walletID=walletID, amount=(0-transferValue)})
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
                    sendClientCommand("shop", "splitMoney", {
                        originalItemID = mItem:getID(),
                        originalValue = mValue,
                        splitValue = cost,
                    })
                end
            end
        end
    end
end


function shopsAndTradersRecipe.addDeedRecipe()

    local sandboxRecipe = SandboxVars.ShopsAndTraders.PlayerOwnedShopDeeds

    local modified_option = ""
    local tooltip = ""

    local blockCrafting = (not sandboxRecipe or sandboxRecipe:match("^%s*$") or sandboxRecipe=="NONE")
    if blockCrafting then
        print("[ShopsAndTraders] No CraftDeed recipe configured - deeds are not craftable")
    else

        if string.lower(sandboxRecipe) == "default" then
            modified_option = "item 1 [$1000] flags[Prop2] mode:destroy, item 1 [Base.SheetPaper2] flags[Prop1] mode:destroy,"
        else
            modified_option = tostring(sandboxRecipe)
        end

        modified_option = string.gsub(modified_option, "|", ",")
        modified_option = modified_option:match("^(.-)%s*$")
        if modified_option:sub(-1) ~= "," then modified_option = modified_option .. "," end

        local value = modified_option:match("%[%$(%d+)%]")
        if value then
            moneyValueForDeedRecipe = tonumber(value)
            modified_option = modified_option:gsub("%[%$(%d+)%]", "[Base.Money]")
            if moneyValueForDeedRecipe and moneyValueForDeedRecipe > 0 then
                tooltip = "Tooltip = "..getText("IGUI_requires").." ".._internal.numToCurrency(moneyValueForDeedRecipe)..", "
            end
        end
    end

    local needToLearn = "NeedToBeLearn = "..tostring(blockCrafting)..", "
    local newScript = "{ "..tooltip..needToLearn.."inputs { " .. modified_option .. " } }"

    print("[ShopsAndTraders] Final Recipe for CraftDeed: ", newScript)

    local scriptManager = getScriptManager()
    local recipe = scriptManager:getCraftRecipe("CraftDeed")
    if recipe then
        local inputs = recipe:getInputs()
        local ioLines = recipe:getIoLines()
        for i = ioLines:size() - 1, 0, -1 do
            if inputs:contains(ioLines:get(i)) then
                ioLines:remove(i)
            end
        end
        inputs:clear()

        recipe:Load("CraftDeed", newScript)
        recipe:OnPostWorldDictionaryInit()
    else
        print("[ShopsAndTraders] ERROR: Could not find CraftRecipe 'CraftDeed'")
    end
end

Events.OnGameStart.Add(shopsAndTradersRecipe.addDeedRecipe)