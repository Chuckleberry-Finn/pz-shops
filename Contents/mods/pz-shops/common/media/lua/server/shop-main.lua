require "shop-globalModDataServer"
local _internal = require "shop-shared"
local itemTransmit = require "shop-itemTransmit"
local shopMarkerSystem = require "shop-markers.lua"

WALLET_HANDLER = {}
STORE_HANDLER = {}

local SHOPS_FILE = "shopsAndTradersData.json"
local WALLETS_FILE = "shopsAndTradersWallets.json"

function STORE_HANDLER.saveToFile()
    if isClient() and not isServer() then return end
    local path = _internal.getSavePath("shopsAndTraders", SHOPS_FILE)
    local writer = getFileWriter(path, true, false)
    if not writer then print("[Shop] ERROR: Could not write "..path) return end
    writer:write(_internal.jsonEncode(GLOBAL_STORES))
    writer:close()
end

function STORE_HANDLER.loadFromFile()
    local path = _internal.getSavePath("shopsAndTraders", SHOPS_FILE)
    local reader = getFileReader(path, false)
    if not reader then return nil end
    local lines = {}
    local line = reader:readLine()
    while line do
        table.insert(lines, line)
        line = reader:readLine()
    end
    reader:close()
    local str = table.concat(lines, "\n")
    if str == "" then return nil end
    local data, err = _internal.jsonDecode(str)
    if not data then print("[Shop] Failed to load "..path..": "..(err or "")) return nil end
    for _, storeData in pairs(data) do
        if storeData.listings then
            for listingKey, listing in pairs(storeData.listings) do
                if not listing.id then listing.id = listingKey end
            end
        end
    end
    return data
end

function WALLET_HANDLER.saveToFile()
    if isClient() and not isServer() then return end
    local path = _internal.getSavePath("shopsAndTraders", WALLETS_FILE)
    local writer = getFileWriter(path, true, false)
    if not writer then print("[Shop] ERROR: Could not write "..path) return end
    writer:write(_internal.jsonEncode(GLOBAL_WALLETS))
    writer:close()
end

function WALLET_HANDLER.loadFromFile()
    local path = _internal.getSavePath("shopsAndTraders", WALLETS_FILE)
    local reader = getFileReader(path, false)
    if not reader then return nil end
    local lines = {}
    local line = reader:readLine()
    while line do
        table.insert(lines, line)
        line = reader:readLine()
    end
    reader:close()
    local str = table.concat(lines, "\n")
    if str == "" then return nil end
    local data, err = _internal.jsonDecode(str)
    if not data then print("[Shop] Failed to load "..path..": "..(err or "")) return nil end
    return data
end

---@class wallet Pseudo-Object
local wallet = {}
wallet.steamID = false
wallet.walletID = false
wallet.playerUsername = false
wallet.amount = 25


function WALLET_HANDLER.new(walletID, steamID, playerUsername)
    if not walletID then print("ERROR: WALLET_HANDLER.new - No walletID provided.") return end
    local newWallet = copyTable(wallet)
    newWallet.walletID = walletID
    newWallet.steamID = steamID or false
    newWallet.playerUsername = playerUsername or false
    newWallet.amount = SandboxVars.ShopsAndTraders.StartingWallet or newWallet.amount

    GLOBAL_WALLETS[newWallet.walletID] = newWallet
    WALLET_HANDLER.saveToFile()
    return GLOBAL_WALLETS[newWallet.walletID]
end

function WALLET_HANDLER.scrubWallet(walletID)
    GLOBAL_WALLETS[walletID] = nil
    WALLET_HANDLER.saveToFile()
end


function WALLET_HANDLER.updateWallet(playerObj, playerWallet)
    if isServer() then
        sendServerCommand(playerObj, "shop", "updateWallet", {wallet=playerWallet})
    else
        CLIENT_WALLETS[playerWallet.walletID] = playerWallet
    end
    WALLET_HANDLER.saveToFile()
end


function WALLET_HANDLER.processCreditToStore(playerWallet, playerObj, amount, storeID)
    playerWallet.credit = playerWallet.credit or {}
    playerWallet.credit[storeID] = (playerWallet.credit[storeID] or 0) + amount
    WALLET_HANDLER.updateWallet(playerObj, playerWallet)
end


function WALLET_HANDLER.spawnMoneyItem(playerObj, amount)
    if not playerObj or not amount or amount <= 0 then return end
    amount = _internal.floorCurrency(amount)
    local moneyTypes = _internal.getMoneyTypes()
    local moneyType = moneyTypes[ZombRand(#moneyTypes)+1]
    local money = instanceItem(moneyType)
    if not money then print("[Shop] ERROR: Failed to create money item of type: "..tostring(moneyType)) return end
    money:getModData().value = amount
    money:setActualWeight((SandboxVars.ShopsAndTraders.MoneyWeight or 0.001) * amount)
    playerObj:getInventory():AddItem(money)
    syncItemModData(playerObj, money)
    sendAddItemToContainer(playerObj:getInventory(), money)
    if isServer() then
        sendServerCommand(playerObj, "shop", "updateMoneyItemName", {itemID=money:getID(), value=amount})
    end
    return money
end


function WALLET_HANDLER.serverRemoveMoneyItem(playerObj, item)
    if not playerObj or not item then return end
    playerObj:getInventory():DoRemoveItem(item)
    sendRemoveItemFromContainer(playerObj:getInventory(), item)
end


function WALLET_HANDLER.validateMoneyOrWallet(playerWallet, playerObj, amount, forceCash)
    if SandboxVars.ShopsAndTraders.PlayerWallets and (not forceCash) then
        local newValue = math.max(0, playerWallet.amount+amount)
        playerWallet.amount = _internal.floorCurrency(newValue)
        WALLET_HANDLER.updateWallet(playerObj, playerWallet)
    else
        if amount > 0 then
            WALLET_HANDLER.spawnMoneyItem(playerObj, amount)
        end
    end
end


function WALLET_HANDLER.getOrSetWallet(walletID, steamID, playerUsername, playerObj)
    local matchingWallet = GLOBAL_WALLETS[walletID] or WALLET_HANDLER.new(walletID, steamID, playerUsername)
    if not matchingWallet then return end
    matchingWallet.steamID = matchingWallet.steamID or steamID
    matchingWallet.playerUsername = matchingWallet.playerUsername or playerUsername

    local walletValue = matchingWallet.amount
    if playerObj and (not SandboxVars.ShopsAndTraders.PlayerWallets) and walletValue > 0 then
        WALLET_HANDLER.validateMoneyOrWallet(matchingWallet, playerObj, walletValue)
        matchingWallet.amount = 0
    end

    if isServer() then
        sendServerCommand(playerObj, "shop", "updateWallet", {wallet=matchingWallet})
    else
        CLIENT_WALLETS[matchingWallet.walletID] = matchingWallet
    end

    return matchingWallet
end


---@class store_listing Pseudo-Object
local store_listing = {}
store_listing.item = false
store_listing.label = nil
store_listing.price = 0
store_listing.buybackRate = 0
store_listing.stock = 0
store_listing.available = 0
store_listing.reselling = true
store_listing.alwaysShow = false
store_listing.fields = false
store_listing.buyConditions = false

function STORE_HANDLER.newListing(storeObj,item,fields,price,stock,buybackRate,reselling,alwaysShow,buyConditions,listingID,label)

    listingID = listingID or getRandomUUID()
    local oldListing = storeObj.listings[listingID]
    local newListing = oldListing or copyTable(store_listing)

    newListing.id = listingID
    newListing.item = item
    newListing.label = label or nil
    if price then
        if price < 0 then price = 0 end
        newListing.price = price
    end
    if stock then
        local stockDiff = 0
        if oldListing then stockDiff = (oldListing.available-oldListing.stock) end
        newListing.available = math.max(0,stock+stockDiff)

        if stock < -1 then stock = -1 end
        newListing.stock = stock
    end
    if buybackRate then
        if buybackRate > 100 then buybackRate = 100 end
        if buybackRate < 0 then buybackRate = 0 end
        newListing.buybackRate = buybackRate
    end

    if fields then newListing.fields = fields end
    if buyConditions then newListing.buyConditions = buyConditions else newListing.buyConditions = false end

    if reselling then newListing.reselling = true else newListing.reselling = false end
    if alwaysShow then newListing.alwaysShow = true else newListing.alwaysShow = false end


    storeObj.listings[listingID] = newListing

    STORE_HANDLER.updateStore(storeObj,storeObj.ID)

    return newListing
end


---@class store Pseudo-Object
local store = {}
store.name = "new store"
store.listings = {}
store.ID = false
store.isBeingManaged = false
store.restockHrs = 48
store.nextRestock = 48
store.ownerID = nil
store.managerIDs = {}
store.cash = 0
store.locations = {}

function STORE_HANDLER.new(copyThisID)
    local original = store
    if copyThisID then
        local originalStore = GLOBAL_STORES[copyThisID]
        if originalStore then
            original = GLOBAL_STORES[copyThisID]
        else print("ERROR: Tried to copy store that doesn't exist.") return end
    end
    local newStore = copyTable(original)
    newStore.ID = getRandomUUID()
    if copyThisID then newStore.name = newStore.name.." (copy)" end
    print(" - NEW STORE: "..tostring(newStore.name).." ("..tostring(newStore.ID)..")")
    GLOBAL_STORES[newStore.ID] = newStore
    return newStore
end


function STORE_HANDLER.findStoreFromLocation(CheckFor)

    if not GLOBAL_STORES or type(GLOBAL_STORES)~="table" then print("ERROR: GLOBAL_STORES not present or not table: "..tostring(GLOBAL_STORES)) end
    if not CheckFor then print("ERROR: findStoreFromLocation: No CheckFor ") return end

    for ID,storeObj in pairs(GLOBAL_STORES) do
        if storeObj.locations then
            local loc = storeObj.locations[CheckFor]
            if loc then
                return ID
            end
        end
    end
end


function STORE_HANDLER.addLocation(storeID,worldObj)
    if not storeID then return end
    local storeObj = STORE_HANDLER.getStoreByID(storeID)
    if not storeObj then return end
    local objectName = _internal.getWorldObjectDisplayName(worldObj)
    local tabelTop = worldObj:isTableTopObject()
    local x, y, z = worldObj:getX(), worldObj:getY(), worldObj:getZ()
    storeObj.locations = storeObj.locations or {}
    storeObj.locations[objectName.."_"..x.."_"..y.."_"..z] = {objName=objectName, x=x,y=y,z=z, tabelTop=tabelTop}
    shopMarkerSystem.needDefine = true
end


function STORE_HANDLER.removeLocation(storeID,worldObj)
    if not storeID then print("ERROR: validatePurchases: No storeID") return end
    local storeObj = STORE_HANDLER.getStoreByID(storeID)
    if not storeObj then return end
    local objectName = _internal.getWorldObjectDisplayName(worldObj)
    local x, y, z = worldObj:getX(), worldObj:getY(), worldObj:getZ()
    storeObj.locations[objectName.."_"..x.."_"..y.."_"..z] = nil
    shopMarkerSystem.needDefine = true
end


function STORE_HANDLER.restocking()
    if not GLOBAL_STORES or type(GLOBAL_STORES)~="table" then print("ERROR: GLOBAL_STORES not present or not table: "..tostring(GLOBAL_STORES)) end
    for ID,_ in pairs(GLOBAL_STORES) do
        local storeObj = GLOBAL_STORES[ID]
        if not storeObj.ownerID then
            if not storeObj.restockHrs then storeObj.restockHrs = 48 end
            storeObj.nextRestock = (storeObj.nextRestock or storeObj.restockHrs)-1
            if storeObj.nextRestock > storeObj.restockHrs then storeObj.nextRestock = storeObj.restockHrs-1 end
            if storeObj.nextRestock < 0 then
                storeObj.nextRestock = storeObj.restockHrs

                if storeObj.listings and type(storeObj.listings) == "table" then
                    for type,_ in pairs(storeObj.listings) do
                        local listing = storeObj.listings[type]
                        if listing and listing.stock ~= -1 then
                            if SandboxVars.ShopsAndTraders.TradersResetStock == true then listing.available = listing.stock
                            else listing.available = math.max(listing.available,listing.stock) end
                        end
                    end
                end
                STORE_HANDLER.updateStore(storeObj,ID)
            end
        end
    end
end
Events.EveryHours.Add(STORE_HANDLER.restocking)


function STORE_HANDLER.updateStore(storeObj,ID)
    GLOBAL_STORES[ID] = storeObj
    if isServer() then
        sendServerCommand("shop", "tryShopUpdateToAll", {store=storeObj})
    else
        CLIENT_STORES[ID] = storeObj
        shopMarkerSystem.needDefine = true
    end
    STORE_HANDLER.saveToFile()
end


function STORE_HANDLER.deleteStore(thisID)
    local storeObj = GLOBAL_STORES[thisID]
    if not storeObj then return end
    storeObj.ID = nil
    storeObj.name = nil
    storeObj.listings = {}
    storeObj.isBeingManaged = false
    storeObj = nil
    GLOBAL_STORES[thisID] = nil

    if isServer() then
        sendServerCommand("shop", "removeStore", {storeID=thisID})
    else
        CLIENT_STORES[thisID] = nil
        shopMarkerSystem.needDefine = true
    end
    STORE_HANDLER.saveToFile()
end

---@param isoObj IsoObject
function STORE_HANDLER.connectStoreByID(isoObj,ID)
    local modData = isoObj:getModData()
    if not modData then print("ERROR: Can't apply store to obj:"..tostring(isoObj)) return end
    if modData.storeObjID and (not GLOBAL_STORES[modData.storeObjID]) then STORE_HANDLER.clearStoreFromObject(isoObj) end
    if modData.storeObjID then print("ERROR: Object already has store assigned. obj:"..tostring(isoObj)) return end
    modData.storeObjID = ID
    isoObj:transmitModData()
    local storeObj = STORE_HANDLER.getStoreByID(ID)
    STORE_HANDLER.addLocation(ID,isoObj)
    STORE_HANDLER.updateStore(storeObj,ID)
end

---@param isoObj IsoObject|IsoThumpable
function STORE_HANDLER.copyStoreOntoObject(isoObj,ID,managed,owner)
    local modData = isoObj:getModData()
    if not modData then print("ERROR: Can't apply store to obj:"..tostring(isoObj)) return end
    if modData.storeObjID and (not GLOBAL_STORES[modData.storeObjID]) then STORE_HANDLER.clearStoreFromObject(isoObj) end
    if modData.storeObjID then print("ERROR: Object already has store assigned. obj:"..tostring(isoObj)) return end
    local newStore = STORE_HANDLER.new(ID)
    newStore.ownerID = owner
    newStore.isBeingManaged = managed or false
    modData.storeObjID = newStore.ID
    if instanceof(isoObj, "IsoThumpable") then
        modData.originalIsThumpable = isoObj:isThumpable()
        isoObj:setIsThumpable(false)
    end
    STORE_HANDLER.addLocation(ID,isoObj)
    isoObj:transmitModData()
    STORE_HANDLER.updateStore(newStore,newStore.ID)
end

---@param isoObj IsoObject
function STORE_HANDLER.clearStoreFromObject(isoObj, player)
    local modData = isoObj:getModData()
    if not modData then print("ERROR: Can't clear store to obj:"..tostring(isoObj)) return end
    if not modData.storeObjID then print("ERROR: Object has no store assigned. obj:"..tostring(isoObj)) return end

    if instanceof(isoObj, "IsoThumpable") and modData.originalIsThumpable then
        isoObj:setIsThumpable(modData.originalIsThumpable)
    end

    local storeID = modData.storeObjID
    local storeObj = storeID and STORE_HANDLER.getStoreByID(storeID)
    modData.storeObjID = nil

    if storeObj then
        if storeObj.ownerID then
            STORE_HANDLER.deleteStore(storeID)
            if player then
                local itemsToTransmit = {{item="Base.ShopDeed"}}
                itemTransmit.doIt(itemsToTransmit, player)
            end
        else
            STORE_HANDLER.removeLocation(storeID,isoObj)
        end
    end

    isoObj:transmitModData()
end

function STORE_HANDLER.getStoreFromObject(isoObj)
    if not isoObj then print("ERROR: No obj to get store from:"..tostring(isoObj)) return end
    local modData = isoObj:getModData()
    if not modData then print("ERROR: Can't apply store to obj:"..tostring(isoObj)) return end
    if not modData.storeObjID then print("ERROR: Object has no store assigned. obj:"..tostring(isoObj)) return false end
    return GLOBAL_STORES[modData.storeObjID]
end

function STORE_HANDLER.getStoreByID(storeID)
    local storeObj = GLOBAL_STORES[storeID]

    return storeObj
end

function STORE_HANDLER.removeListing(storeObj,item)
    if not storeObj then print("ERROR: No storeObj:"..tostring(storeObj)) return end
    if storeObj.listings[item] then
        storeObj.listings[item] = nil
    else
        print("ERROR: Warning: "..item.." not in listings to remove.")
    end
    STORE_HANDLER.updateStore(storeObj,storeObj.ID)
end


function STORE_HANDLER.validateItemType(storeID,listingID)
    if not listingID then print("ERROR: validateItemType: listingID = nil") return end
    if not storeID then print("ERROR: validateItemType: No storeID") return end
    local storeObj = STORE_HANDLER.getStoreByID(storeID)
    if not storeObj then print("ERROR: validateItemType: No storeObj") return end

    local listing = storeObj.listings[listingID]
    if listing then return listing end

    print("ERROR: listing '"..tostring(listingID).."' not found in '"..tostring(storeObj.name).."'")
    return nil
end


function STORE_HANDLER.findListingForSale(storeObj,itemType,itemFieldsTable)
    local script = getScriptManager():getItem(itemType)
    local displayCat = script and script:getDisplayCategory()
    local order = storeObj.listingOrder or {}

    local orderIndex = {}
    for i,id in ipairs(order) do orderIndex[id] = i end

    local best = nil
    local bestScore = -1
    local bestOrder = math.huge

    for id,listing in pairs(storeObj.listings) do
        if listing.buybackRate and listing.buybackRate > 0 then
            local isExact = listing.item == itemType
            local isCat = (not isExact) and displayCat and listing.item == "category:"..displayCat
            if isExact or isCat then
                if STORE_HANDLER.fieldsMeetBuyConditions(listing, itemFieldsTable) then
                    local hasCond = listing.buyConditions and type(listing.buyConditions) == "table"
                    local specificity = (isExact and 2 or 1) + (hasCond and 1 or 0)
                    local idx = orderIndex[id] or math.huge
                    if specificity > bestScore
                            or (specificity == bestScore and idx < bestOrder) then
                        best = listing
                        bestScore = specificity
                        bestOrder = idx
                    end
                end
            end
        end
    end

    return best
end


---Checks a table of item field values (as gathered by itemFields.gatherFields) against the
---listing's buyConditions table using parseConditional. Returns true if all conditions pass
---or if no buyConditions are set. Missing fields vacuously pass — callers should pass full
---(non-purged) field tables for reliable results.
---@param listing table
---@param itemFieldsTable table  Field values from itemFields.gatherFields(item, false)
---@return boolean
function STORE_HANDLER.fieldsMeetBuyConditions(listing, itemFieldsTable)
    if not listing.buyConditions then return true end
    local itemFields = require "shop-itemFields"
    for fieldKey, expr in pairs(listing.buyConditions) do
        if fieldKey == "modData" and type(expr) == "table" then
            local md = type(itemFieldsTable.modData) == "table" and itemFieldsTable.modData or {}
            for mdKey, mdExpr in pairs(expr) do
                if not itemFields.parseConditional(mdExpr, md[mdKey]) then
                    return false
                end
            end
        else
            local actual = itemFieldsTable[fieldKey]
            if not itemFields.parseConditional(expr, actual) then
                return false
            end
        end
    end
    return true
end


function STORE_HANDLER.validateOrder(playerObj, playerID, storeID, buying, selling, money, moneyItemIDs)
    if not playerID then print("ERROR: validatePurchases: No playerID") return end
    if not storeID then print("ERROR: validatePurchases: No storeID") return end

    local storeObj = STORE_HANDLER.getStoreByID(storeID)
    if not storeObj then print("ERROR: validatePurchases: No storeObj") return end

    local playerWallet = WALLET_HANDLER.getOrSetWallet(playerID)
    if not playerWallet then print("ERROR: validatePurchases: No valid player wallet") return end

    if moneyItemIDs and #moneyItemIDs > 0 then
        local verified = 0
        for _,entry in pairs(moneyItemIDs) do
            local item = playerObj:getInventory():getItemWithID(entry.itemID)
            if item and _internal.isMoneyType(item:getFullType()) and item:getModData().value then
                verified = _internal.floorCurrency(verified + item:getModData().value)
                WALLET_HANDLER.serverRemoveMoneyItem(playerObj, item)
            end
        end
        money = verified
    end

    for _,data in pairs(selling) do
        local listing = STORE_HANDLER.findListingForSale(storeObj, data.itemType, data.buyCheckFields or data.fields or {})
        if listing then

            local adjustedPrice = listing.price*(listing.buybackRate/100)

            if SandboxVars.ShopsAndTraders.ShopsUseCash == 2 then
                WALLET_HANDLER.processCreditToStore(playerWallet,playerObj,adjustedPrice,storeID)
            elseif SandboxVars.ShopsAndTraders.ShopsUseCash == 3 then
            else
                WALLET_HANDLER.validateMoneyOrWallet(playerWallet,playerObj,adjustedPrice)
            end

            if SandboxVars.ShopsAndTraders.ShopsUseCash < 2 then
                storeObj.cash = _internal.floorCurrency((storeObj.cash or 0) - adjustedPrice)
            end

            if listing.reselling == true then
                if listing.item ~= data.itemType then
                    local newListing = STORE_HANDLER.newListing(storeObj,data.itemType,data.itemFields,listing.price,0,listing.buybackRate,listing.reselling)
                    if not storeObj.ownerID then newListing.available = newListing.available+1 end
                else
                    if not storeObj.ownerID then listing.available = listing.available+1 end
                end
            end

            if not storeObj.ownerID and data.itemID then
                local soldItem = playerObj:getInventory():getItemWithID(data.itemID)
                if soldItem then WALLET_HANDLER.serverRemoveMoneyItem(playerObj, soldItem) end
            end
        else
            print("[Shop] Sell rejected: '"..tostring(data.itemType).."' no matching listing for '"..tostring(storeID).."'")
        end
    end

    local itemsToTransmit = {}

    for _,listingID in pairs(buying) do
        local listing = STORE_HANDLER.validateItemType(storeID,listingID)
        if listing then

            local credit = playerWallet and playerWallet.credit and playerWallet.credit[storeID] or 0

            local purchasePower = playerWallet.amount+money+credit
            if purchasePower-listing.price < 0 then break end

            local moneyNeeded = math.min(listing.price, money)
            money = math.max(0, money-moneyNeeded)
            local costRemainder = math.max(0, listing.price-moneyNeeded)

            if listing.available > 0 then listing.available = listing.available-1 end

            if credit and credit>0 then
                local creditUsed = math.min(credit, costRemainder)
                costRemainder = costRemainder-creditUsed
                moneyNeeded = moneyNeeded-creditUsed
                WALLET_HANDLER.processCreditToStore(playerWallet,playerObj,0-creditUsed,storeID)
            end

            WALLET_HANDLER.validateMoneyOrWallet(playerWallet,playerObj,0-costRemainder)

            if SandboxVars.ShopsAndTraders.ShopsUseCash < 2 then
                storeObj.cash = _internal.floorCurrency((storeObj.cash or 0) + costRemainder)
            end

            if not storeObj.ownerID then
                table.insert(itemsToTransmit,{item=listing.item,fields=listing.fields})
            end
        end
    end

    if SandboxVars.ShopsAndTraders.ShopsUseCash == 2 then
        WALLET_HANDLER.processCreditToStore(playerWallet,playerObj,money,storeID)
    elseif SandboxVars.ShopsAndTraders.ShopsUseCash == 3 then
    else
        WALLET_HANDLER.validateMoneyOrWallet(playerWallet,playerObj,money)
    end

    if #itemsToTransmit > 0 then itemTransmit.doIt(itemsToTransmit, playerObj) end

    STORE_HANDLER.updateStore(storeObj, storeID)
end
