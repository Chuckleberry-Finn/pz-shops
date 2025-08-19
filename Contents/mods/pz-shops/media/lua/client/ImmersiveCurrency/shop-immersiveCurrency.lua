if not IC then return end

require "ICClient.lua"
require "ICRecipes.lua"

local _internal = require "shop-shared"
require "shop-wallet.lua"

---    recipe Put Money
--	{
--		Base.Money,
--		destroy MoneyStack,
--		Result: MoneyStack,
--		Time:10.0,
--		Category: Currency,
--		NeedToBeLearn:false,
--		CanBeDoneFromFloor:false,
--		StopOnWalk:false,
--		Sound: IC_MoneyCount,
--		OnTest:recipe_Put_Money_TestIsValid,
--		OnCreate:recipe_PutMoney,
--	}
function recipe_PutMoney(items, result, player)
    player = getPlayer()

    local money = items:get(0)
    local moneyStack = items:get(1)

    local value = money:getModData().value
    local stackCapacity = _internal.floorCurrency((1 - moneyStack:getUsedDelta()) * 100)
    local addDollars = _internal.floorCurrency(math.min(value, stackCapacity))

    local remainder = _internal.floorCurrency(value-addDollars)
    if remainder > 0 then
        local moneyTypes = _internal.getMoneyTypes()
        local type = moneyTypes[ZombRand(#moneyTypes)+1]
        local newMoney = InventoryItemFactory.CreateItem(type)
        generateMoneyValue(newMoney, remainder, true)
        player:getInventory():AddItem(newMoney)
    end

    result:setUsedDelta(moneyStack:getUsedDelta()+(addDollars/100))

    if IC.GiveMood then
        local unhappyness = player:getBodyDamage():getUnhappynessLevel()
        player:getBodyDamage():setUnhappynessLevel(unhappyness - 1)
    end
end


---    recipe Take Money
--	{
--		MoneyStack,
--		Result:Base.Money,
--		Time:10.0,
--		Category: Currency,
--		NeedToBeLearn:false,
--		CanBeDoneFromFloor:false,
--		StopOnWalk:false,
--		Sound: IC_MoneyCount,
--		OnTest:recipe_Take_Money_TestIsValid,
--		OnCreate:recipe_TakeMoney,
--	}
function recipe_TakeMoney(items, result, player)
    player = player or getPlayer()

    generateMoneyValue(result, 1, true)

    for i=0, items:size()-1 do
        if items:get(i):getType() == "MoneyStack" then
            local stack = items:get(i)
            local stackData = stack:getModData()
            local stackDelta = items:get(i):getUsedDelta()
            if stackDelta <= 0.01 then player:getInventory():AddItem("Base.RubberBand") end
            if IC.GiveMood then
                local unhappyness = player:getBodyDamage():getUnhappynessLevel()
                player:getBodyDamage():setUnhappynessLevel(unhappyness - 1)
            end
            break
        end
    end
end


function recipe_MakeMoneyStack_TestIsValid(sourceItem, result)
    if _internal.isMoneyType(sourceItem:getFullType()) then
        local value = sourceItem:getModData().value
        return value >= 100
    end
    return true
end


local function recipeOverride()
    ---@type Recipe
    local recipe = getScriptManager():getRecipe("ICurrency.Make Money Stack")
    if recipe then

        local script = {}
        script.header = "module ICurrency { recipe Make Money Stack { "
		script.ingredients = "Base.Money, Base.RubberBand, "
		script.result = "Result:ICurrency.MoneyStack, "
        script.params = "Time: 40.0, Category: Currency, NeedToBeLearn: false, Sound: IC_RubberSnap, "
        script.override = "Override:true, "
        script.lua = "OnCreate:recipe_MakeMoneyStack, OnTest:recipe_MakeMoneyStack_TestIsValid, "
        script.tooltip = "Tooltip:"..getText("IGUI_requires").." ".._internal.numToCurrency(100)..", "
        script.footer = "} }"

        local scriptManager = getScriptManager()
        scriptManager:ParseScript(script.header..script.ingredients..script.result..script.params..script.override..script.lua..script.tooltip..script.footer)
    end
end
Events.OnGameBoot.Add(recipeOverride)


function recipe_MakeMoneyStack(items, result, player)
    player = player or getPlayer()

    local money = items:get(0)
    local value = money:getModData().value

    local stacks = math.floor(value / 100) - 1
    local remainder = value % 100

    if stacks > 0 then
        player:getInventory():AddItems("ICurrency.MoneyStack", stacks)
    end

    if remainder > 0 then
        local newMoney = InventoryItemFactory.CreateItem(money:getFullType())
        generateMoneyValue(newMoney, remainder, true)
        player:getInventory():AddItem(newMoney)
    end

    player:Say(IC:selectRandom({
        getText("IGUI_StackSpeech1"),
        getText("IGUI_StackSpeech2"),
        getText("IGUI_StackSpeech3")
    }))
end


---    recipe Unpack Money Stack
--	{
--		MoneyStack,
--		Result: Base.Money,
--		Time: 40.0,
--		Category: Currency,
--		NeedToBeLearn: false,
--		Sound: IC_RubberSnap,
--		OnCreate:recipe_UnpackMoneyStack,
--	}
function recipe_UnpackMoneyStack(items, result, player)
    player = player or getPlayer()
    local stack = items:get(0)
    local delta = stack:getUsedDelta() + 0.01
    if delta > 0 then
        generateMoneyValue(result, delta * 100, true)
        player:getInventory():AddItem("Base.RubberBand")
        player:getInventory():DoRemoveItem(stack)
    end
end


function IC:unpackWallet(item)
    local player = getPlayer()
    local inventory = player:getInventory()
    local random = ZombRand(1, 100)
    local isPresent = IC:checkItemParent(item)

    if not isPresent then return end -- Nooope

    -- Add used wallet
    local itemType = item:getFullType()
    if itemType == "Base.Wallet" then
        inventory:AddItem("ICurrency.WalletUsed_01")
    end
    if itemType == "Base.Wallet2" then
        inventory:AddItem("ICurrency.WalletUsed_02")
    end
    if itemType == "Base.Wallet3" then
        inventory:AddItem("ICurrency.WalletUsed_03")
    end
    if itemType == "Base.Wallet4" then
        inventory:AddItem("ICurrency.WalletUsed_04")
    end

    if SandboxVars.ICurrency.MaxMoneyPerWallet ~=0 then
        local amount = ZombRand(SandboxVars.ICurrency.MinMoneyPerWallet, SandboxVars.ICurrency.MaxMoneyPerWallet)
        if amount ~= 0 then
            player:Say("+" .. amount .. "$")

            local moneyTypes = _internal.getMoneyTypes()
            local type = moneyTypes[ZombRand(#moneyTypes)+1]
            local money = InventoryItemFactory.CreateItem(type)
            generateMoneyValue(money, amount, true)
            inventory:AddItem(money)

            ---inventory:AddItems("Base.Money", amount)
        end
    end
    if random <= 50 then
        inventory:AddItem('Base.CreditCard')
    end
    if random <= 50 then
        inventory:AddItem('Base.SheetPaper2')
    end
    if random <= 25 then
        inventory:AddItem('Base.RubberBand')
    end
    if random == 1 then
        inventory:AddItem('Base.SpiffoBig')
        player:Say("... !?")
    end

    inventory:DoRemoveItem(item)
end