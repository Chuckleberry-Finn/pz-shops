require "shop-globalModDataServer"
require "shop-shared"

WALLET_HANDLER = {}
STORE_HANDLER = {}

---@class wallet Pseudo-Object
local wallet = {}
wallet.steamID = false
wallet.playerUUID = false
wallet.playerUsername = false
wallet.amount = 25


function WALLET_HANDLER.new(playerID,steamID,playerUsername)
    if not playerID then print("ERROR: wallet:new - No playerID provided.") return end
    if not steamID then print("ERROR: wallet:new - No steamID provided.") return end
    local newWallet = copyTable(wallet)
    newWallet.playerUUID = playerID
    newWallet.steamID = steamID
    newWallet.playerUsername = playerUsername
    newWallet.amount = SandboxVars.ShopsAndTraders.StartingWallet or newWallet.amount
    GLOBAL_WALLETS[newWallet.playerUUID] = newWallet
end

function WALLET_HANDLER.scrubWallet(playerID)
    GLOBAL_WALLETS[playerID] = nil
end

function WALLET_HANDLER.getOrSetPlayerWallet(playerID,steamID,playerUsername)
    local matchingWallet = GLOBAL_WALLETS[playerID] or WALLET_HANDLER.new(playerID,steamID,playerUsername)

    matchingWallet.steamID = matchingWallet.steamID or steamID
    matchingWallet.playerUsername = matchingWallet.playerUsername or playerUsername

    return matchingWallet
end


function WALLET_HANDLER.getWalletsByUuidAndSteam(playerID,steamID,playerUsername)

    local matchingWallets = {}

    local walletByUUID = WALLET_HANDLER.getorSetPlayerWallet(playerID,steamID,playerUsername)
    table.insert(matchingWallets, walletByUUID)

    for _,playerWallet in pairs(GLOBAL_WALLETS) do if (playerWallet.steamID == steamID) then table.insert(matchingWallets, playerWallet) end end

    return matchingWallets
end


---@class store_listing Pseudo-Object
local store_listing = {}
store_listing.item = false
store_listing.price = 0
store_listing.buybackRate = 0
store_listing.stock = 0
store_listing.available = 0
store_listing.storeID = false
store_listing.reselling = true
store_listing.alwaysShow = false

function STORE_HANDLER.newListing(storeObj,item,price,stock,buybackRate,reselling,alwaysShow)
    local oldListing = storeObj.listings[item]
    local newListing = oldListing or copyTable(store_listing)
    newListing.item = item
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

    if reselling then newListing.reselling = true else newListing.reselling = false end
    if alwaysShow then newListing.alwaysShow = true else newListing.alwaysShow = false end

    storeObj.listings[item] = newListing
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

function STORE_HANDLER.restocking()
    if not GLOBAL_STORES or type(GLOBAL_STORES)~="table" then print("ERROR: GLOBAL_STORES not present or not table: "..tostring(GLOBAL_STORES)) end
    for ID,_ in pairs(GLOBAL_STORES) do
        if not GLOBAL_STORES[ID].restockHrs then GLOBAL_STORES[ID].restockHrs = 48 end
        GLOBAL_STORES[ID].nextRestock = (GLOBAL_STORES[ID].nextRestock or GLOBAL_STORES[ID].restockHrs)-1
        if GLOBAL_STORES[ID].nextRestock > GLOBAL_STORES[ID].restockHrs then GLOBAL_STORES[ID].nextRestock = GLOBAL_STORES[ID].restockHrs-1 end
        if GLOBAL_STORES[ID].nextRestock < 0 then
            GLOBAL_STORES[ID].nextRestock = GLOBAL_STORES[ID].restockHrs
            for type,_ in pairs(GLOBAL_STORES[ID].listings) do
                local listing = GLOBAL_STORES[ID].listings[type]
                if listing and listing.stock ~= -1 then
                    if SandboxVars.ShopsAndTraders.TradersResetStock == true then listing.available = listing.stock
                    else listing.available = math.max(listing.available,listing.stock) end
                end
            end
        end
    end
    triggerEvent("SHOPPING_ServerModDataReady")
end
Events.EveryHours.Add(STORE_HANDLER.restocking)

function STORE_HANDLER.deleteStore(thisID)
    local storeObj = GLOBAL_STORES[thisID]
    if not storeObj then return end
    storeObj.ID = nil
    storeObj.name = nil
    storeObj.listings = {}
    storeObj.isBeingManaged = false
    storeObj = nil
    GLOBAL_STORES[thisID] = nil
end

---@param isoObj IsoObject
function STORE_HANDLER.connectStoreByID(isoObj,ID)
    local modData = isoObj:getModData()
    if not modData then print("ERROR: Can't apply store to obj:"..tostring(isoObj)) return end
    if modData.storeObjID and (not GLOBAL_STORES[modData.storeObjID]) then STORE_HANDLER.clearStoreFromObject(isoObj) end
    if modData.storeObjID then print("ERROR: Object already has store assigned. obj:"..tostring(isoObj)) return end
    modData.storeObjID = ID
    isoObj:transmitModData()
end

---@param isoObj IsoObject
function STORE_HANDLER.copyStoreOntoObject(isoObj,ID,managed)
    local modData = isoObj:getModData()
    if not modData then print("ERROR: Can't apply store to obj:"..tostring(isoObj)) return end
    if modData.storeObjID and (not GLOBAL_STORES[modData.storeObjID]) then STORE_HANDLER.clearStoreFromObject(isoObj) end
    if modData.storeObjID then print("ERROR: Object already has store assigned. obj:"..tostring(isoObj)) return end
    local newStore = STORE_HANDLER.new(ID)
    newStore.isBeingManaged = managed or false
    modData.storeObjID = newStore.ID
    isoObj:transmitModData()
end

---@param isoObj IsoObject
function STORE_HANDLER.clearStoreFromObject(isoObj)
    local modData = isoObj:getModData()
    if not modData then print("ERROR: Can't apply store to obj:"..tostring(isoObj)) return end
    if not modData.storeObjID then print("ERROR: Object has no store assigned. obj:"..tostring(isoObj)) return end
    modData.storeObjID = nil
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
end


function STORE_HANDLER.validateItemType(storeID,itemType)
    if not storeID then print("ERROR: validatePurchases: No storeID") return end
    local storeObj = STORE_HANDLER.getStoreByID(storeID)
    if not storeObj then print("ERROR: validatePurchases: No storeObj") return end
    local validItem = getScriptManager():getItem(itemType)
    if not validItem then print("ERROR: no script found for \'"..itemType.."\'") return end

    local listing = storeObj.listings[itemType]
    if not listing then listing = storeObj.listings["category:"..validItem:getDisplayCategory()] end
    if not listing then print("ERROR: \'"..itemType.."\' not a listed for \'"..storeObj.name.."\'") return end
    return listing
end


---@param playerObj IsoPlayer|IsoGameCharacter|IsoMovingObject|IsoObject
function STORE_HANDLER.validateOrder(playerObj, playerID,storeID,buying,selling)
    if not playerID then print("ERROR: validatePurchases: No playerID") return end
    if not storeID then print("ERROR: validatePurchases: No storeID") return end

    local storeObj = STORE_HANDLER.getStoreByID(storeID)
    if not storeObj then print("ERROR: validatePurchases: No storeObj") return end

    local playerWallet = WALLET_HANDLER.getOrSetPlayerWallet(playerID)
    if not playerWallet then print("ERROR: validatePurchases: No valid player wallet") return end

    for _,itemType in pairs(selling) do

        local listing = STORE_HANDLER.validateItemType(storeID,itemType)
        if listing then
            local adjustedPrice = listing.price*(listing.buybackRate/100)
            playerWallet.amount = playerWallet.amount+adjustedPrice

            if listing.reselling == true then
                if listing.item ~= itemType then
                    local newListing = STORE_HANDLER.newListing(storeObj,itemType,listing.price,0,listing.buybackRate,listing.reselling)
                    newListing.available = newListing.available+1
                else
                    listing.available = listing.available+1
                end
            end
        end
    end

    for _,itemType in pairs(buying) do
        local listing = STORE_HANDLER.validateItemType(storeID,itemType)
        if listing then
            if playerWallet.amount-listing.price < 0 then break end
            playerWallet.amount = playerWallet.amount-listing.price
            if listing.available > 0 then
                if listing.available <  1 then return end
                listing.available = listing.available-1
            end

            if isServer() then sendServerCommand(playerObj, "shop", "transmitItem", {item=listing.item})
            else playerObj:getInventory():AddItem(listing.item)
            end
        end
    end
end