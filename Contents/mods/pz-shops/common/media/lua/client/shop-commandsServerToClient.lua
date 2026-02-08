local _internal = require "shop-shared"

local shopMarkerSystem = require "shop-markers.lua"

local shopCommandsServerToClient = {}

function shopCommandsServerToClient.onServerCommand(_module, _command, _data)
    if _module ~= "shop" then return end
    _data = _data or {}

    if _command == "grabShop" then
        if _data.store and _data.store.ID then CLIENT_STORES[_data.store.ID] = _data.store end
        shopMarkerSystem.needDefine = true
    end

    if _command == "removeStore" then
        if _data.storeID then CLIENT_STORES[_data.storeID] = nil end
        shopMarkerSystem.needDefine = true
    end

    if _command == "incomingImport" then
        if _data.stores then _internal.copyAgainst(CLIENT_STORES, _data.stores) end
        if _data.close and storeWindow.instance and storeWindow.instance:isVisible() and (not _internal.isAdminHostDebug()) then
            storeWindow.instance:closeStoreWindow()
        end
        shopMarkerSystem.needDefine = true
    end
    
    if _command == "tryShopUpdateToAll" then
        if _data.store and _data.store.ID then
            local window = storeWindow.instance
            if window and window:isVisible() and window.storeObj and window.storeObj.ID then
                if window.storeObj.ID == _data.store.ID then
                    CLIENT_STORES[_data.store.ID] = _data.store
                    window.storeObj = CLIENT_STORES[_data.store.ID]
                end
            end
        end
        shopMarkerSystem.needDefine = true
    end

    if _command == "transmitItems" then
    end

    if _command == "updateWallet" then
        local wallet = _data.wallet
        if not wallet.playerUUID then return end
        CLIENT_WALLETS[wallet.playerUUID] = _data.wallet
    end

    if _command == "sendMoneyItem" then
    end

    if _command == "updateTransferOffer" then
        if ISTradingUI.instance and ISTradingUI.instance:isVisible() then ISTradingUI.instance.setOfferedAmount = _data.amount end
    end
end
Events.OnServerCommand.Add(shopCommandsServerToClient.onServerCommand)

return shopCommandsServerToClient
