LuaEventManager.AddEvent("SHOPPING_ServerModDataReady")

local itemDictionaryUpdated = false

local function onClientCommand(_module, _command, _player, _data)
    --if getDebug() then print("Received command from " .. _player:getUsername() .." [".._module..".".._command.."]") end

    if _module ~= "shop" then return end
    _data = _data or {}

    if _command == "updateItemDictionary" then
        if itemDictionaryUpdated then return end
        itemDictionaryUpdated = true
        local itemsToCategories = _data.itemsToCategories
        local scriptManager = getScriptManager()
        for moduleType,displayCategory in pairs(itemsToCategories) do
            local scriptFound = scriptManager:getItem(moduleType)
            if scriptFound then scriptFound:DoParam("DisplayCategory = "..displayCategory) end
        end
    end

    if _command == "ImportStores" then
        _internal.copyAgainst(GLOBAL_STORES, _data.stores)
        triggerEvent("SHOPPING_ServerModDataReady")
    end

    if _command == "getOrSetWallet" then
        print("SETTING PLAYER WALLET: ".._data.playerID.."  for user:".._data.steamID)
        local playerID, steamID, playerUsername = _data.playerID, _data.steamID, _data.playerUsername
        WALLET_HANDLER.getOrSetPlayerWallet(playerID,steamID,playerUsername)
        triggerEvent("SHOPPING_ServerModDataReady")
    end

    if _command == "scrubWallet" then
        local playerID = _data.playerID
        WALLET_HANDLER.scrubWallet(playerID)
        triggerEvent("SHOPPING_ServerModDataReady")
    end

    if _command == "transferFunds" then
        local giverID, give, receiverID, receive = _data.giver, _data.give, _data.receiver, _data.receive
        local giverWallet, receiverWallet

        if giverID then giverWallet = WALLET_HANDLER.getOrSetPlayerWallet(giverID) end
        if receiverID then receiverWallet = WALLET_HANDLER.getOrSetPlayerWallet(receiverID) end

        if giverWallet and receiverWallet then
            if give then
                giverWallet.amount = giverWallet.amount-give
                receiverWallet.amount = receiverWallet.amount+give
            end
            if receive then
                giverWallet.amount = giverWallet.amount+receive
                receiverWallet.amount = receiverWallet.amount-receive
            end
        else
            if not receiverWallet then print("ERROR: transferFunds: No valid receiverWallet") end
            if not giverWallet then print("ERROR: transferFunds: No valid giverWallet") end
        end
        triggerEvent("SHOPPING_ServerModDataReady")
    end

    if _command == "changeTransferOffer" then
        local amount, onlineID = _data.amount, _data.onlineID
        local player
        if onlineID then
            local playersOnline = getOnlinePlayers()
            if playersOnline then
                for i=0, playersOnline:size()-1 do
                    local p = playersOnline:get(i)
                    if p:getOnlineID() == onlineID then player = p break end
                end
            end
        end
        sendServerCommand(player, "shop", "updateTransferOffer", {amount=amount})
    end

    if _command == "assignStore" or _command == "copyStorePreset" or _command == "connectStorePreset" or _command == "clearStoreFromMapObj" then

        local storeID, x, y, z, mapObjName = _data.storeID, _data.x, _data.y, _data.z, _data.mapObjName
        local sq = getSquare(x, y, z)
        if not sq then print("ERROR: Could not find square for assigning store.") return end

        local objects = sq:getObjects()
        if not objects then print("ERROR: Could not find objects for assigning store.") return end

        local foundObjToApplyTo

        for i=0,objects:size()-1 do
            ---@type IsoObject|MapObjects
            local object = objects:get(i)
            if object and (not instanceof(object, "IsoWorldInventoryObject")) and _internal.getMapObjectName(object)==mapObjName then

                local objMD = object:getModData()
                if objMD and objMD.storeObjID and not GLOBAL_STORES[objMD.storeObjID] then objMD.storeObjID = nil end

                if _command ~= "clearStoreFromMapObj" and objMD and objMD.storeObjID then
                    print("WARNING: ".._command.." failed: Matching object ID: ("..GLOBAL_STORES[object:getModData().storeObjID].name.."); bypassed.")
                else
                    foundObjToApplyTo = object
                end
            end
        end

        if not foundObjToApplyTo then print("ERROR: No foundObjToApplyTo.") return end

        if _command == "connectStorePreset" then
            STORE_HANDLER.connectStoreByID(foundObjToApplyTo,storeID)
        elseif _command == "clearStoreFromMapObj" then
            STORE_HANDLER.clearStoreFromObject(foundObjToApplyTo)
        else --assign or copy
            STORE_HANDLER.copyStoreOntoObject(foundObjToApplyTo,storeID,true)
        end
        triggerEvent("SHOPPING_ServerModDataReady")

    elseif _command == "deleteStorePreset" then
        local storeID = _data.storeID
        STORE_HANDLER.deleteStore(storeID)
        triggerEvent("SHOPPING_ServerModDataReady")

    elseif _command == "setStoreIsBeingManaged" then
        local status, storeID, storeName, restockHrs = _data.isBeingManaged, _data.storeID, _data.storeName, _data.restockHrs
        local storeObj = STORE_HANDLER.getStoreByID(storeID)
        storeObj.isBeingManaged = status
        if storeName then storeObj.name = storeName end
        if restockHrs then storeObj.restockHrs = math.max(0,restockHrs) end
        triggerEvent("SHOPPING_ServerModDataReady")

    elseif _command == "removeListing" then
        local item, storeID = _data.item, _data.storeID
        local storeObj = STORE_HANDLER.getStoreByID(storeID)
        if not storeObj then print("ERROR: No storeObj to remove listing from!") return end

        STORE_HANDLER.removeListing(storeObj,item)
        triggerEvent("SHOPPING_ServerModDataReady")

    elseif _command == "listNewItem" then
        local status, buybackRate, reselling = (_data.isBeingManaged or true), (_data.buybackRate or false), _data.reselling
        local item, storeID, price, quantity, alwaysShow = _data.item, _data.storeID, (_data.price or 0), (_data.quantity or 0), _data.alwaysShow

        if not item then print("ERROR: No item param to list!") return end
        if not storeID then print("ERROR: No storeID!") return end

        local storeObj = STORE_HANDLER.getStoreByID(storeID)
        if not storeObj then print("ERROR: No storeObj to give new listing!") return end
        storeObj.isBeingManaged = status
        STORE_HANDLER.newListing(storeObj,item,price,quantity,buybackRate,reselling,alwaysShow)
        triggerEvent("SHOPPING_ServerModDataReady")

    elseif _command == "processOrder" then

        local storeID, buying, selling, playerID = _data.storeID, _data.buying, _data.selling, _data.playerID
        STORE_HANDLER.validateOrder(_player, playerID, storeID, buying, selling)
        triggerEvent("SHOPPING_ServerModDataReady")
    end

end
Events.OnClientCommand.Add(onClientCommand)--/client/ to server

local function onServerModDataReady() sendServerCommand("shop", "severModData_received", {}) end
Events.SHOPPING_ServerModDataReady.Add(onServerModDataReady)