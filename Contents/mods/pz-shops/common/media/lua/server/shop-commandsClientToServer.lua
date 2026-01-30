local itemDictionaryUpdated = false ---NEEDED FOR BETTER SORTING TO WORK IN MP
local _internal = require "shop-shared"

local pendingTradeOffers = {}

local function onClientCommand(_module, _command, _player, _data)
    if _module ~= "shop" then return end
    _data = _data or {}

    ---NEEDED FOR BETTER SORTING TO WORK IN MP
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

    if _command == "grabShop" then
        local storeObj = STORE_HANDLER.getStoreByID(_data.storeID)
        if storeObj then
            if isServer() then
                sendServerCommand(_player, "shop", "grabShop", {store=storeObj})
            else
                CLIENT_STORES[_data.storeID] = storeObj
            end
        end
    end

    if _command == "ImportStores" then
        if isServer() then
            if _data.stores then _internal.copyAgainst(GLOBAL_STORES, _data.stores) end
            sendServerCommand(_player,"shop", "incomingImport", {stores=GLOBAL_STORES})
        else
            if _data.stores then
                _internal.copyAgainst(CLIENT_STORES, _data.stores)
                _internal.copyAgainst(GLOBAL_STORES, _data.stores)
            end
        end
    end

    if _command == "ExportStores" then
        if isServer() then
            sendServerCommand(_player, "shop", "ExportStores", {stores=GLOBAL_STORES})
        else
            local jsonStr = _internal.jsonEncode(GLOBAL_STORES)
            local writer = getFileWriter("shopsAndTradersData.json", true, false)
            if writer then
                writer:write(jsonStr)
                writer:close()
                print("[Shop] Exported stores to shopsAndTradersData.json")
            end
        end
    end

    if _command == "getOrSetWallet" then
        local walletID, steamID, playerUsername = _data.walletID, _data.steamID, _data.playerUsername
        WALLET_HANDLER.getOrSetWallet(walletID, steamID, playerUsername, _player)
    end

    if _command == "scrubWallet" then
        local walletID = _data.walletID
        WALLET_HANDLER.scrubWallet(walletID)
    end

    if _command == "transferFunds" then
        local walletID, amount, toStoreID, forceCash = _data.walletID, _data.amount, _data.toStoreID, _data.forceCash

        if toStoreID then
            local storeObj = STORE_HANDLER.getStoreByID(toStoreID)
            if storeObj then
                local newValue = math.max(0, (storeObj.cash or 0)-amount)
                storeObj.cash = _internal.floorCurrency(newValue)
                STORE_HANDLER.updateStore(storeObj,toStoreID)
            end
        end

        local playerWallet
        if walletID then playerWallet = WALLET_HANDLER.getOrSetWallet(walletID) end
        if playerWallet and amount then
            WALLET_HANDLER.validateMoneyOrWallet(playerWallet, _player, amount)
            if forceCash then
                WALLET_HANDLER.validateMoneyOrWallet(playerWallet, _player, 0-amount, true)
            end
        end
    end

    if _command == "splitMoney" then
        local originalValue = _data.originalValue
        local splitValue = _data.splitValue
        local originalItemID = _data.originalItemID

        if originalValue and splitValue and splitValue > 0 and splitValue < originalValue then
            local newOriginalValue = _internal.floorCurrency(originalValue - splitValue)

            if originalItemID then
                local originalItem = _player:getInventory():getItemWithID(originalItemID)
                if originalItem and _internal.isMoneyType(originalItem:getFullType()) then
                    originalItem:getModData().value = newOriginalValue
                    originalItem:setActualWeight((SandboxVars.ShopsAndTraders.MoneyWeight or 0.001) * newOriginalValue)
                    syncItemModData(_player, originalItem)
                    if isServer() then
                        sendServerCommand(_player, "shop", "updateMoneyItemName", {itemID=originalItemID, value=newOriginalValue})
                    end
                end
            end

            WALLET_HANDLER.spawnMoneyItem(_player, splitValue)
        end
    end

    if _command == "removeMoneyItem" then
        local itemID = _data.itemID
        if itemID then
            local item = _player:getInventory():getItemWithID(itemID)
            if item and _internal.isMoneyType(item:getFullType()) then
                WALLET_HANDLER.serverRemoveMoneyItem(_player, item)
            end
        end
    end

    if _command == "stackMoney" then
        local targetItemID = _data.targetItemID
        local newValue = _data.newValue

        if targetItemID and newValue and newValue > 0 then
            local targetItem = _player:getInventory():getItemWithID(targetItemID)
            if targetItem and _internal.isMoneyType(targetItem:getFullType()) then
                local floored = _internal.floorCurrency(newValue)
                targetItem:getModData().value = floored
                targetItem:setActualWeight((SandboxVars.ShopsAndTraders.MoneyWeight or 0.001) * floored)
                syncItemModData(_player, targetItem)
                if isServer() then
                    sendServerCommand(_player, "shop", "updateMoneyItemName", {itemID=targetItemID, value=floored})
                end
            end
        end
    end

    if _command == "createMoneyOnDeath" then
        local walletID = _data.walletID
        local amount = _data.amount
        if walletID and amount and amount > 0 then
            WALLET_HANDLER.spawnMoneyItem(_player, amount)
        end
    end

    if _command == "exchangeFunds" then
        local playerObjA = _player
        local playerObjB = _data.otherOnlineID and getPlayerByOnlineID(_data.otherOnlineID)

        if not playerObjA then print("ERR: exchangeFunds - no playerA.") return end
        if not playerObjB then print("ERR: exchangeFunds - could not find playerB by onlineID.") return end

        local offerA = pendingTradeOffers[playerObjA:getOnlineID()] or 0
        local offerB = pendingTradeOffers[playerObjB:getOnlineID()] or 0
        pendingTradeOffers[playerObjA:getOnlineID()] = nil
        pendingTradeOffers[playerObjB:getOnlineID()] = nil

        local walletIDA = _internal.getWalletID(playerObjA)
        local walletIDB = _internal.getWalletID(playerObjB)

        local walletA = walletIDA and WALLET_HANDLER.getOrSetWallet(walletIDA)
        local walletB = walletIDB and WALLET_HANDLER.getOrSetWallet(walletIDB)

        if walletA then
            if offerA > 0 then WALLET_HANDLER.validateMoneyOrWallet(walletA, playerObjA, 0-offerA) end
            if offerB > 0 then WALLET_HANDLER.validateMoneyOrWallet(walletA, playerObjA, offerB) end
        else
            print("ERR: walletA not found for exchange.")
        end

        if walletB then
            if offerB > 0 then WALLET_HANDLER.validateMoneyOrWallet(walletB, playerObjB, 0-offerB) end
            if offerA > 0 then WALLET_HANDLER.validateMoneyOrWallet(walletB, playerObjB, offerA) end
        else
            print("ERR: walletB not found for exchange.")
        end
    end

    if _command == "changeTransferOffer" then
        local amount, onlineID = _data.amount, _data.onlineID
        pendingTradeOffers[_player:getOnlineID()] = amount or 0
        local player = onlineID and getPlayerByOnlineID(onlineID)
        if player then
            sendServerCommand(player, "shop", "updateTransferOffer", {amount=amount})
        end
    end

    if _command == "assignStore" or _command == "copyStorePreset" or _command == "connectStorePreset"
            or _command == "clearStoreFromWorldObj" or _command == "checkMapObject" or _command == "checkLocation" then

        local storeID, x, y, z, worldObjName, owner = _data.storeID, _data.x, _data.y, _data.z, _data.worldObjName, _data.owner
        local sq = getSquare(x, y, z)
        if not sq then print("ERROR: Could not find square for assigning store.") return end

        local objects = sq:getObjects()
        if not objects then print("ERROR: Could not find objects for assigning store.") return end

        local foundObjToApplyTo

        for i=0,objects:size()-1 do
            ---@type IsoObject
            local object = objects:get(i)
            if object and (not instanceof(object, "IsoWorldInventoryObject")) and _internal.getWorldObjectName(object)==worldObjName then

                local objMD = object:getModData()
                local stores = isServer() and GLOBAL_STORES or CLIENT_STORES

                if objMD and objMD.storeObjID and not stores[objMD.storeObjID] then
                    objMD.storeObjID = nil
                    print("WARNING: Clearing object with invalid storeID: "..worldObjName)
                    object:transmitModData()
                end

                if _command ~= "clearStoreFromWorldObj" and _command ~= "checkMapObject" and objMD and objMD.storeObjID and objMD.storeObjID~=storeID then
                    print("WARNING: ".._command.." failed: Matching object ID: ("..stores[object:getModData().storeObjID].name.."); bypassed.")
                else
                    foundObjToApplyTo = object
                end
            end
        end

        if not foundObjToApplyTo then print("ERROR: ".._command..": No foundObjToApplyTo.") return end

        if _command == "checkLocation" and foundObjToApplyTo then
            if SandboxVars.ShopsAndTraders.ShopsLocationTracking == true then
                local CheckFor = worldObjName and worldObjName.."_"..x.."_"..y.."_"..z
                local foundID = CheckFor and STORE_HANDLER.findStoreFromLocation(CheckFor)
                if foundID then
                    STORE_HANDLER.connectStoreByID(foundObjToApplyTo,foundID)
                end
            end
        end

        if _command == "checkMapObject" then
            STORE_HANDLER.addLocation(storeID,foundObjToApplyTo)
            if isServer() then
                sendServerCommand(_player, "shop", "grabShop", {store=GLOBAL_STORES[storeID]})
            else
                CLIENT_STORES[storeID] = copyTable(GLOBAL_STORES[storeID])
            end
            return
        end

        if _command == "connectStorePreset" then
            STORE_HANDLER.connectStoreByID(foundObjToApplyTo,storeID)
        elseif _command == "clearStoreFromWorldObj" then
            STORE_HANDLER.clearStoreFromObject(foundObjToApplyTo, _player)
        elseif _command == "assignStore" or _command == "copyStorePreset" then
            STORE_HANDLER.copyStoreOntoObject(foundObjToApplyTo,storeID,true, owner)
        end

    elseif _command == "deleteStorePreset" then
        local storeID = _data.storeID
        STORE_HANDLER.deleteStore(storeID)

    elseif _command == "setStoreIsBeingManaged" then
        local status, storeID, storeName, restockHrs = _data.isBeingManaged, _data.storeID, _data.storeName, _data.restockHrs
        local storeObj = STORE_HANDLER.getStoreByID(storeID)
        storeObj.isBeingManaged = status
        if storeName then storeObj.name = storeName end
        if restockHrs then
            storeObj.restockHrs = math.max(1,restockHrs)
            storeObj.nextRestock = storeObj.restockHrs
        end
        if _data.listingOrder then storeObj.listingOrder = _data.listingOrder end
        STORE_HANDLER.updateStore(storeObj)

    elseif _command == "removeListing" then
        local item, storeID = _data.item, _data.storeID
        local storeObj = STORE_HANDLER.getStoreByID(storeID)
        if not storeObj then print("ERROR: No storeObj to remove listing from!") return end

        STORE_HANDLER.removeListing(storeObj,item)

    elseif _command == "listNewItem" then
        local status, buybackRate, reselling = (_data.isBeingManaged or true), (_data.buybackRate or false), _data.reselling
        local item, storeID, price, stock, alwaysShow = _data.item, _data.storeID, (_data.price or 0), (_data.stock or 0), _data.alwaysShow
        local fields = _data.fields
        local buyConditions = _data.buyConditions
        local listingID = _data.listingID
        local label = _data.label

        if not item then print("ERROR: No item param to list!") return end
        if not storeID then print("ERROR: No storeID!") return end

        local storeObj = STORE_HANDLER.getStoreByID(storeID)
        if not storeObj then print("ERROR: No storeObj to give new listing!") return end
        storeObj.isBeingManaged = status
        STORE_HANDLER.newListing(storeObj,item,fields,price,stock,buybackRate,reselling,alwaysShow,buyConditions,listingID,label)

    elseif _command == "processOrder" then

        local storeID, buying, selling, playerID, money = _data.storeID, _data.buying, _data.selling, _data.playerID, _data.money
        STORE_HANDLER.validateOrder(_player, playerID, storeID, buying, selling, money, _data.moneyItemIDs)
    end

end
Events.OnClientCommand.Add(onClientCommand)
