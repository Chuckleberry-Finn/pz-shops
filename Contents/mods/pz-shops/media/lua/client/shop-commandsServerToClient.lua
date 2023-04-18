local _internal = require "shop-shared"

LuaEventManager.AddEvent("SHOPPING_ClientModDataReady")

local function onClientModDataReady()
    if not isClient() then
        _internal.copyAgainst(GLOBAL_STORES, CLIENT_STORES)
        _internal.copyAgainst(GLOBAL_WALLETS, CLIENT_WALLETS)
    else
        ModData.request("STORES")
        ModData.request("WALLETS")
    end
end
Events.SHOPPING_ClientModDataReady.Add(onClientModDataReady)


local function onServerCommand(_module, _command, _data)
    if _module ~= "shop" then return end
    _data = _data or {}

    if _command == "severModData_received" then onClientModDataReady() end
    if _command == "transmitItems" then for _,itemType in pairs(_data.items) do getPlayer():getInventory():AddItem(itemType) end end

    if _command == "sendMoneyItem" then
        local moneyTypes = _internal.getMoneyTypes()
        local type = moneyTypes[ZombRand(#moneyTypes)+1]
        local money = InventoryItemFactory.CreateItem(type)
        generateMoneyValue(money, _data.value)
        getPlayer():getInventory():AddItem(money)
    end

    if _command == "updateTransferOffer" then
        if ISTradingUI.instance and ISTradingUI.instance:isVisible() then ISTradingUI.instance.setOfferedAmount = _data.amount end
    end
end
Events.OnServerCommand.Add(onServerCommand)
