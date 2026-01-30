require "ISUI/ISPanelJoypad"
require "shop-globalModDataClient"
require "shop-wallet"
require "shop-itemDictionary"
require "TimedActions/ISInventoryTransferAction"
local _internal = require "shop-shared"
local itemFields = require "shop-itemFields"

---@class storeWindow : ISPanel
storeWindow = ISPanelJoypad:derive("storeWindow")
storeWindow.messages = {}
storeWindow.CoolDownMessage = 300
storeWindow.MaxItems = 20
storeWindow.modifiedListings = {}

---@param item InventoryItem
function storeWindow.validateItemForStock(item, name)
    return ((not name) or (item:getDisplayName()==name))
end

function storeWindow:getItemTypesInStoreContainer(listing)
    ---@type IsoObject
    local worldObject = self.worldObject
    if not worldObject then return end

    local itemType = listing.item

    local container = worldObject:getContainer()
    if not _internal.isValidContainer(container) then return end

    local fieldName = listing.fields and listing.fields.name
    local items = container:getAllTypeEvalArg(itemType, storeWindow.validateItemForStock, fieldName)
    if items then return items end
end


function storeWindow:getAvailableStock(listing)
    if not self.storeObj or not listing then return end
    if self.storeObj.ownerID then

        if listing.reselling==false then return 0 end

        local stock = self:getItemTypesInStoreContainer(listing)
        if stock then return stock:size() end
    end
    return listing.available
end


function storeWindow:onCartItemSelected()
    local row = self.yourCartData:rowAt(self.yourCartData:getMouseX(), self.yourCartData:getMouseY())
    if row ~= self.yourCartData.selected then return end
    self.yourCartData:removeItemByIndex(self.yourCartData.selected)
end


function storeWindow:storeItemRowAt(y)
    local y0 = 0

    if not self.storeObj then return -1 end

    local listings = self.storeObj.listings
    for i,v in ipairs(self.storeStockData.items) do
        if not v.height then v.height = self.storeStockData.itemheight end

        local listing = listings[v.listingID]
        if not listing then return end

        local texture, script, validCategory = nil, nil, false
        if type(v.item) == "string" then
            script = getScriptManager():getItem(v.item)
            if script then texture = script:getNormalTexture()
            else validCategory = isValidItemDictionaryCategory(v.item:gsub("category:",""))
            end
        else
            texture = v.item:getTex()
        end

        local availableStock = self:getAvailableStock(listing)

        local validItem = (texture or validCategory)
        local availableItem = (availableStock ~= 0)
        local itemReselling = (listing.stock ~= 0 or listing.reselling==true)

        local showListing = validItem and itemReselling and availableItem

        if listing.alwaysShow==true then showListing = true end
        local managing = (self:isBeingManaged() and _internal.canManageStore(self.storeObj,self.player))

        if showListing or managing then
            if y >= y0 and y < y0 + v.height then return i end
            y0 = y0 + v.height
        end
    end
    return -1
end


function storeWindow:stockRowDeleteZone()
    local sz = self.storeStockData.itemheight * 0.75
    local x = self.storeStockData:getWidth() - sz - 10
    return x, sz
end


function storeWindow:onStoreItemDoubleClick()
end


function storeWindow:onStoreItemSelected()

    local row = self:storeItemRowAt(self.storeStockData:getMouseY())
    if not self.storeStockData.items[row] then return end

    local item = self.storeStockData.items[row].item
    local listingID = self.storeStockData.items[row].listingID
    local listing = self.storeObj.listings[listingID]

    if self:isBeingManaged() then
        self.pressedRow = row
        self.pressedListingID = listingID
        self.pressedMouseX = self.storeStockData:getMouseX()
        self.dragStartRow = (self.activeCategoryTab == "All") and row or nil
        self.dragStartY = (self.activeCategoryTab == "All") and self.storeStockData:getMouseY() or nil
        self.dragStartTime = (self.activeCategoryTab == "All") and getTimeInMillis() or nil
        self.dragTargetRow = nil
        return
    end

    if #self.yourCartData.items >= self.MaxItems then return end
    local inCart = 0
    for _,v in pairs(self.yourCartData.items) do if v.item == listingID then inCart = inCart+1 end end

    local availableStock = self:getAvailableStock(listing)

    if self.storeObj and ((availableStock >= inCart+1) or (availableStock == -1)) then
        local script = getScriptManager():getItem(listing.item)
        if script then
            local listingName = listing.label or (listing.fields and listing.fields.name)
            local scriptName = listingName or script:getDisplayName()
            local cartItem = self.yourCartData:addItem(scriptName, listingID)
            cartItem.itemType = item
        end
    end
end


function storeWindow:addItemToYourStock(store, x, y, z, worldObjName, item, worldObject)

    local itemType = item:getFullType()
    local fields = itemFields.gatherFields(item, true)

    local movable = string.find(itemType, "Moveables.") and "Moveables.Moveable"
    if movable then itemType = movable end

    sendClientCommand("shop", "listNewItem",
            { isBeingManaged=store.isBeingManaged, alwaysShow = false,
              item=itemType, fields=fields, price=0, stock=0, buybackRate=0, reselling=false,
              storeID=store.ID, x=x, y=y, z=z, worldObjName=worldObjName })

    if worldObject and item then
        local itemCont = item:getContainer()
        local worldObjectContainer = worldObject:getContainer()
        if worldObjectContainer then

            if self.player:isEquipped(item) then ISTimedActionQueue.add(ISUnequipAction:new(self.player, item, 1)) end

            local action = ISInventoryTransferAction:new(self.player, item, itemCont, worldObjectContainer)
            action.shopTransaction=true
            ISTimedActionQueue.add(action)
        end
    end
end


function storeWindow:yourStockingMouseUp(x, y)
    local store = self.parent.storeObj
    if self.vscroll then self.vscroll.scrolling = false end

    local managing = self.parent:isBeingManaged() and _internal.canManageStore(store, self.parent.player)
    if not managing then return end

    if ISMouseDrag.dragging then
        local worldObject = self.parent.worldObject
        local woX, woY, woZ, worldObjName = worldObject:getX(), worldObject:getY(), worldObject:getZ(), _internal.getWorldObjectName(worldObject)
        local counta = 1
        for i,v in ipairs(ISMouseDrag.dragging) do
            counta = 1
            if instanceof(v, "InventoryItem") then
                self.parent:addItemToYourStock(store, woX, woY, woZ, worldObjName, v, worldObject)
            else
                if v.invPanel.collapsed[v.name] then
                    counta = 1
                    for i2,v2 in ipairs(v.items) do
                        if counta > 1 then
                            self.parent:addItemToYourStock(store, woX, woY, woZ, worldObjName, v2, worldObject)
                        end
                        counta = counta + 1
                    end
                end
            end
        end
        return
    end

    local dragStartRow = self.parent.dragStartRow
    local dragStartY = self.parent.dragStartY
    local pressedRow = self.parent.pressedRow
    local pressedListingID = self.parent.pressedListingID
    local pressedMouseX = self.parent.pressedMouseX

    self.parent.dragStartRow = nil
    self.parent.dragStartY = nil
    self.parent.dragStartTime = nil
    self.parent.dragTargetRow = nil
    self.parent.pressedRow = nil
    self.parent.pressedListingID = nil
    self.parent.pressedMouseX = nil

    if dragStartRow and dragStartY and math.abs(y - dragStartY) > 8 then
        local targetRow = self.parent:storeItemRowAt(y)
        if targetRow and targetRow > 0 and targetRow ~= dragStartRow then
            local order = self.parent.listingOrder
            local srcID = self.items[dragStartRow] and self.items[dragStartRow].listingID
            local dstID = self.items[targetRow] and self.items[targetRow].listingID
            if order and srcID and dstID then
                local srcIdx, dstIdx
                for i,id in ipairs(order) do
                    if id == srcID then srcIdx = i end
                    if id == dstID then dstIdx = i end
                end
                if srcIdx and dstIdx then
                    local moved = table.remove(order, srcIdx)
                    table.insert(order, dstIdx, moved)
                end
            end
        end
        return
    end

    local releaseRow = self.parent:storeItemRowAt(y)
    if not releaseRow or releaseRow ~= pressedRow then return end

    local listingID = pressedListingID
    if not listingID then return end

    local delX, delSz = self.parent:stockRowDeleteZone()
    if self.parent.selectedListing and self.parent.selectedListing.id == listingID
            and pressedMouseX and pressedMouseX >= delX and pressedMouseX <= delX + delSz then
        self.parent.storeStockData:removeItemByIndex(self.parent.storeStockData.selected)
        self.parent.addStockEntry:setText("")
        self.parent.selectedListing = nil
        self.parent.addListingList:clear()
        if self.parent.listingOrder then
            for i,id in ipairs(self.parent.listingOrder) do
                if id == listingID then table.remove(self.parent.listingOrder, i) break end
            end
        end
        sendClientCommand("shop", "removeListing", { item=listingID, storeID=store.ID })
        return
    end

    local listing = store.listings[listingID]
    if not listing then return end

    if self.parent.selectedListing and self.parent.selectedListing.id == listingID then
        self.parent:commitActiveListing()
        self.parent.selectedListing = nil
        self.parent.addListingList:clear()
        self.parent.addStockEntry:setText("")
    else
        self.parent:commitActiveListing()
        self.parent:setStockInput(listing)
    end
end


function storeWindow:setStockInput(listing)
    if not self:isBeingManaged() then return end

    if not listing then return end

    local option = self.addStockSearchPartition:getOptionData(self.addStockSearchPartition.selected)
    local text

    local SM = getScriptManager()
    local movable = string.find(listing.item, "Moveables.") and "Moveables.Moveable"
    local script = SM:getItem(listing.item)
    if script or movable then

        if self.tempStockSearchPartitionData then
            self.addStockSearchPartition:selectData(self.tempStockSearchPartitionData)
            option = self.tempStockSearchPartitionData
            self.tempStockSearchPartitionData = nil
        end

        if movable then
            text = movable
        elseif option == "category" then
            text = script:getDisplayCategory()
        elseif option == "name" then
            text = script:getDisplayName()
        elseif option == "type" then
            text = script:getFullName()
        end
    else
        local categoryFound = listing.item:gsub("category:","")
        if categoryFound and isValidItemDictionaryCategory(categoryFound) then
            text = categoryFound
            self.tempStockSearchPartitionData = option
            self.addStockSearchPartition:selectData("category")
        end
    end

    if not text then return end
    self.addStockEntry:setText(text)
    self:populateListingList(listing)
end


function storeWindow:commitActiveListing()
    if not self.selectedListing then return end
    if not self:isBeingManaged() then return end
    if not self.storeObj then return end

    storeWindow.listingInputEntered(self.listingInput)

    local listingSelected = self.selectedListing
    if not listingSelected then return end

    local listingID = listingSelected.id
    if not listingID then
        self.selectedListing = nil
        self.addListingList:clear()
        self.addStockEntry:setText("")
        return
    end

    self.dirtyListingIDs = self.dirtyListingIDs or {}
    self.dirtyListingIDs[listingID] = listingSelected

    self.selectedListing = nil
    self.addListingList:clear()
    self.addStockEntry:setText("")
    self.tempStockSearchPartitionData = nil
end


function storeWindow:flushDirtyListings()
    if not self.dirtyListingIDs then return end
    if not self.storeObj then return end

    local x, y, z = self.worldObject:getX(), self.worldObject:getY(), self.worldObject:getZ()
    local worldObjName = _internal.getWorldObjectName(self.worldObject)
    local store = self.storeObj

    for listingID, listing in pairs(self.dirtyListingIDs) do
        local price = listing.price or 0
        if SandboxVars.ShopsAndTraders.ShopItemPriceLimit and SandboxVars.ShopsAndTraders.ShopItemPriceLimit > 0
                and price > SandboxVars.ShopsAndTraders.ShopItemPriceLimit then
            price = SandboxVars.ShopsAndTraders.ShopItemPriceLimit
        end

        sendClientCommand("shop", "listNewItem", {
            isBeingManaged=store.isBeingManaged,
            alwaysShow=listing.alwaysShow or false,
            item=listing.item,
            price=price,
            fields=listing.fields,
            buyConditions=listing.buyConditions or false,
            stock=listing.stock or 0,
            buybackRate=listing.buybackRate or 0,
            reselling=listing.reselling or false,
            label=listing.label or nil,
            listingID=listingID,
            storeID=store.ID, x=x, y=y, z=z, worldObjName=worldObjName })
    end

    self.dirtyListingIDs = {}
end


function storeWindow:onAddStockListSelected(selected)
    if not self:isBeingManaged() then return end
    local label = self.addStockList.labels[selected]
    self.addStockEntry:setText(label)
end


function storeWindow:drawAddStockList(y, item, alt)
    if not self.parent:isBeingManaged() then return y end

    local color = {r=1, g=1, b=1, a=0.9}

    self:drawRectBorder(0, (y), self:getWidth(), self.itemheight - 1, 0.9, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    self:drawText(item.text, 4, y+2, color.r, color.g, color.b, color.a, self.font)

    return y + self.itemheight
end


function storeWindow:addItemEntryChange()
    local s = storeWindow.instance
    if not s then return end

    s.tempStockSearchPartitionData = nil

    local addStockEntry = s.addStockEntry
    local addStockPart = s.addStockSearchPartition
    local matches, matchesToType = findMatchesFromItemDictionary(addStockEntry:getInternalText(), addStockPart:getOptionData(addStockPart.selected))

    s.addStockList:clear()
    if not s:isBeingManaged() then return end
    if not matchesToType then return end
    for label,type in pairs(matchesToType) do
        local listedItem = s.addStockList:addItem(label, type)
        s.addStockList.labels[type] = label
    end
end


function storeWindow:getAvailableStoreFunds()
    if not self.storeObj then return end
    if self.storeObj.ownerID then

        local moneyTypes = _internal.getMoneyTypes()
        local monies, value = nil, self.storeObj.cash
--[[
        if SandboxVars.ShopsAndTraders.ShopsUseCash<=2 then
            for _,moneyType in pairs(moneyTypes) do
                local moniesOfType = self:getItemTypesInStoreContainer(moneyType)
                for i=0,moniesOfType:size()-1 do
                    local money = moniesOfType:get(i)
                    if money then
                        monies = monies or {}
                        table.insert(monies, money)
                        value = value + money:getModData().value
                    end
                end
            end
        end
--]]
        return monies, value
    end
    return false
end


function storeWindow:onChangeStoreCash()
    local value = tonumber(self:getText()) or 0
    local playerObj = self.parent.player

    if not self.parent.storeObj then return end
    if not self.parent.storeObj.ownerID then return end

    local playerModData = playerObj:getModData()
    if not playerModData then print("WARN: Player without modData.") return end
    if not playerModData.wallet_UUID then print("- No Player wallet_UUID.") return end

    local wallet, walletBalance = getWallet(playerObj), 0
    if wallet then walletBalance = wallet.amount end

    local cashInStore = self.parent.storeObj.cash or 0

    value = math.max(0,math.min(cashInStore+walletBalance, value))
    self:setText(tostring(value))
    value = (cashInStore-value)

    sendClientCommand("shop", "transferFunds", {playerWalletID=playerModData.wallet_UUID, amount=value, toStoreID=self.parent.storeObj.ID})
end


function storeWindow:dummyBringToTop() return end



function storeWindow:onAddListingListSelected(selected)
    if not self:isBeingManaged() then return end
    --local label = self.addStockList.labels[selected]
    --self.addStockEntry:setText(label)
end




function storeWindow:listingInputEntered()
    if not self.parent.storeWindow:isBeingManaged() then return end

    local storeWindow = self.parent.storeWindow
    local listing = storeWindow.selectedListing
    local field = listing and storeWindow.addListingList.accessing

    if field then
        local rawText = self:getText()

        local bcKey = field:match("^bc:(.+)$")
        local mdKey = field:match("^md:(.+)$")

        if field == "__add_bc__" then
            local k, v = rawText:match("^%s*([%w_]+)%s*=(.+)$")
            if k and v then
                v = v:match("^%s*(.-)%s*$")
                listing.buyConditions = listing.buyConditions or {}
                listing.buyConditions[k] = v
                storeWindow:populateListingList(listing)
            end

        elseif field == "__add_md__" then
            local k, v = rawText:match("^([^=]+)=(.+)$")
            if k and v then
                k = k:match("^%s*(.-)%s*$")
                v = tonumber(v) or (v == "true" and true) or (v == "false" and false) or v
                if type(listing.fields) == "table" and type(listing.fields.modData) == "table" then
                    listing.fields.modData[k] = v
                    storeWindow:populateListingList(listing)
                end
            end

        elseif bcKey then
            storeWindow:populateListingList(listing, field, rawText ~= "" and rawText or nil)

        elseif mdKey then
            local v = rawText ~= "" and (tonumber(rawText) or (rawText=="true" and true) or (rawText=="false" and false) or rawText) or nil
            storeWindow:populateListingList(listing, field, v)

        elseif field == "label" then
            listing.label = (rawText ~= "" and rawText) or nil
            storeWindow:populateListingList(listing)

        else
            if (storeWindow.storeObj and storeWindow.storeObj.ownerID) and (listing[field]==nil) then
                -- skip; owned-store non-listing fields read-only
            else
                local value = tonumber(rawText) or rawText
                if value == "false" then value = false end
                if value == "true"  then value = true  end
                if field == "price" then value = math.max(0, value) end
                storeWindow:populateListingList(listing, field, value)
            end
        end
    end

    storeWindow.addListingList.accessing = nil
    self:setVisible(false)
    self:clear()
    self:setY(storeWindow.addListingList:getY())
    self:setHeight(0)
end



function storeWindow.clipText(text, maxW, font)
    local tm = getTextManager()
    if tm:MeasureStringX(font, text) <= maxW then return text, false end
    while #text > 1 and tm:MeasureStringX(font, text.."...") > maxW do
        text = text:sub(1, #text - 1)
    end
    return text.."...", true
end


function storeWindow:tagListingRow(row, sectionType, label, displayValue)
    row.sectionType  = sectionType
    row.label        = label
    row.displayValue = displayValue or ""
end


function storeWindow:addListingHeader(label, tooltipText, sectionKey)
    local h = self.addListingList:addItem(label, nil)
    h.isHeader = true
    h.fieldID = "__header__"
    h.label = label
    h.sectionKey = sectionKey
    if tooltipText then h.tooltip = tooltipText end
    return h
end


function storeWindow:addStockListing(listing, managed)
    local storeObj = self.storeObj
    local scriptManager = getScriptManager()
    local movable = string.find(listing.item, "Moveables.") and "Moveables.Moveable"
    local script = scriptManager:getItem(listing.item)
    local fieldName = listing.fields and listing.fields.name
    local scriptName = (script and script:getDisplayName()) or listing.item
    local itemDisplayName = listing.label or scriptName

    local listingID = listing.id

    local isCategoryListingAndIsValid = (string.match(listing.item, "category:") and isValidItemDictionaryCategory(listing.item:gsub("category:","")))

    local inCart = 0
    for _,v in pairs(self.yourCartData.items) do if v.item == listingID then inCart = inCart+1 end end

    local availableStock = self:getAvailableStock(listing)
    local availableTemp = availableStock-inCart

    local stockText = " ("..availableTemp.."/"..math.max(availableStock, listing.stock)..")"
    if listing.stock == -1 or string.match(listing.item, "category:") then stockText = "" end

    local price = listing.price
    if storeObj.ownerID and listing.reselling==false and listing.buybackRate>0 then
        price = price * (listing.buybackRate/100)
        stockText = " \[BUYING\]"
    end

    if listing.price <= 0 then
        price = getText("IGUI_FREE")
    else
        price = _internal.numToCurrency(price)
    end

    if itemDisplayName and string.match(itemDisplayName, "category:") then
        itemDisplayName = itemDisplayName:gsub("category:","")
        itemDisplayName = getTextOrNull("IGUI_ItemCat_"..itemDisplayName) or itemDisplayName
        if managed then itemDisplayName = "category: "..itemDisplayName end
    end

    local label = price.."  "..(itemDisplayName or "!")..stockText
    local listedItem = self.storeStockData:addItem(label, listing.item)
    listedItem.listingID = listingID

    local tooltipText = label
    if managed then
        tooltipText = tooltipText.."\n"
        if not string.match(listedItem.item, "category:") then
            tooltipText = tooltipText.." [restock x"..listing.stock.."]"
        end
        tooltipText = tooltipText.." [buyback "..listing.buybackRate.."%]"

        if not script and not movable and not isCategoryListingAndIsValid then tooltipText = "\<INVALID ITEM\> "..tooltipText end

        local resell = listing.reselling
        if resell~=SandboxVars.ShopsAndTraders.TradersResellItems then if resell then tooltipText = tooltipText.." [resell]" else tooltipText = tooltipText.." [no resell]" end end
    end
    if tooltipText ~= "" then listedItem.tooltip = tooltipText end
end


function storeWindow:listingMatchesTab(listing)
    local activeTab = self.activeCategoryTab or "All"
    if activeTab == "All" then return true end
    if string.match(listing.item, "category:") then
        local catName = listing.item:gsub("category:","")
        return catName == activeTab
    end
    local script = getScriptManager():getItem(listing.item)
    return script and script:getDisplayCategory() == activeTab
end


function storeWindow.prerenderAddListingList(list)
    if list:isVisible() then
        local sw = list.storeWindow
        list:setX(sw.x+sw.width+3)
        list:setY(sw.y+32)
        ISScrollingListBox.prerender(list)
    end
end


function storeWindow.readImportFile(name)
    local reader = getFileReader(name, false)
    if not reader then return nil end
    local lines = {}
    local line = reader:readLine()
    while line do table.insert(lines, line) line = reader:readLine() end
    reader:close()
    return table.concat(lines, "\n")
end


function storeWindow:drawAddListingList(y, item, alt)
    if not self.storeWindow:isBeingManaged() then return y end

    local sbW   = (self.vscroll and self.vscroll:isVisible() and self.vscroll.width or 0)
    local drawW = self:getWidth() - sbW
    local ACCENT_W = 0
    local isSub  = item.fieldID and (item.fieldID:match("^bc:") or item.fieldID:match("^md:")
                       or item.fieldID == "__add_bc__" or item.fieldID == "__add_md__")
    local indent = isSub and 14 or 4

    if item.isHeader then
        self:drawRect(0, y, self:getWidth(), self.itemheight - 1, 0.18, 0.5, 0.5, 0.5)
        local label = item.label or item.text
        if item.sectionKey then
            local collapsed = self.storeWindow.collapsedSections and self.storeWindow.collapsedSections[item.sectionKey]
            label = (collapsed and "+ " or "- ")..label
        end
        label = storeWindow.clipText(label, drawW - 8, self.font)
        local lW = getTextManager():MeasureStringX(self.font, label)
        self:drawText(label, (drawW - lW) / 2, y + 2, 0.75, 0.75, 0.75, 0.9, self.font)
        return y + self.itemheight
    end

    self.itemAlpha = ((y / self.itemheight) % 2 == 0) and 0.3 or 0.6

    if self.accessing and self.accessing == item.fieldID then

        local input     = self.storeWindow.listingInput
        local scrolledY = y + self:getYScroll()

        if scrolledY < 0 or scrolledY > (self:getHeight() - self.itemheight) then
            input:setVisible(false)
        else
            input:setY(scrolledY)
            if not input:isVisible() then
                local isBcOrMd = item.fieldID:match("^bc:") or item.fieldID:match("^md:")
                    or item.fieldID == "__add_bc__" or item.fieldID == "__add_md__"
                input:setOnlyNumbers((not isBcOrMd) and (tonumber(item.item) ~= nil))
                if item.fieldID == "__add_bc__" or item.fieldID == "__add_md__" then
                    input:setText("")
                else
                    input:setText(tostring(item.item))
                end
                input:setWidth(drawW)
                input:setVisible(true)
                input:setHeight(self.itemheight)
                input:focus()
            end

            local hint
            if item.fieldID == "__add_bc__" then
                hint = "field=expr  e.g. name==~Ring"
            elseif item.fieldID == "__add_md__" then
                hint = "key=value"
            elseif item.fieldID:match("^bc:") then
                hint = ">N  <N  N~M  !N  =~text"
            elseif item.fieldID:match("^md:") then
                hint = item.fieldID:match("^md:(.+)$")
            else
                hint = item.fieldID
            end
            local hintW = getTextManager():MeasureStringX(self.font, hint)
            self:drawText(hint, drawW - hintW - 4, y + 2,
                self.itemTextColor.r, self.itemTextColor.g, self.itemTextColor.b, 0.35, self.font)
        end

    else

        self:drawRect(0, y, self:getWidth(), self.itemheight - 1, self.itemAlpha, 0.4, 0.4, 0.4)

        local alphaShift = item.faded and 0.35 or self.itemTextColor.a

        local labelColor = {
            r = item.isConditional and 1.0  or self.itemTextColor.r,
            g = item.isConditional and 0.78 or self.itemTextColor.g,
            b = item.isConditional and 0.25 or self.itemTextColor.b,
        }

        local label        = item.label        or item.text
        local displayValue = item.displayValue or ""
        local tm           = getTextManager()

        local usable   = drawW - indent - ACCENT_W - 4
        local labelMax = math.floor(usable * 0.55)
        local valueMax = usable - labelMax - 8

        local safeLabel, labelClipped = storeWindow.clipText(label,        labelMax, self.font)
        local safeValue, valueClipped = storeWindow.clipText(displayValue, valueMax, self.font)

        if labelClipped or valueClipped then
            item.tooltip = (displayValue ~= "") and (label..": "..displayValue) or label
        else
            item.tooltip = nil
        end

        local valueW = tm:MeasureStringX(self.font, safeValue)
        local labelX = indent + ACCENT_W
        local valueX = drawW - valueW - 4

        self:drawText(safeLabel, labelX, y + 2,
            labelColor.r, labelColor.g, labelColor.b, alphaShift, self.font)

        if displayValue ~= "" then
            local vc = alphaShift * (item.faded and 1 or 0.8)
            self:drawText(safeValue, valueX, y + 2,
                self.itemTextColor.r, self.itemTextColor.g, self.itemTextColor.b, vc, self.font)
        end
    end

    return y + self.itemheight
end


function storeWindow:addListingListMouseUp(x, y)

    local spot = self:rowAt(x, y)
    if not spot then return end

    local field = self.items[spot]
    if not field then return end
    if self.accessing then return end

    if field.isHeader or field.fieldID == "__header__" or field.fieldID == "categoryListing" then
        if field.sectionKey then
            local sw = self.storeWindow
            sw.collapsedSections = sw.collapsedSections or {}
            sw.collapsedSections[field.sectionKey] = not sw.collapsedSections[field.sectionKey]
            sw:populateListingList(sw.selectedListing)
        end
        return
    end
    if not self.storeWindow.storeObj then return end

    local listing = self.storeWindow.selectedListing
    if listing then
        local isBcField = field.fieldID:match("^bc:(.+)$")
        local isMdField = field.fieldID:match("^md:(.+)$")
        local isAddRow  = field.fieldID == "__add_bc__" or field.fieldID == "__add_md__"

        if not (isBcField or isMdField or isAddRow) then
            if (self.storeWindow.storeObj and self.storeWindow.storeObj.ownerID) and (listing[field.fieldID] == nil) then return end
        end

        if not isBcField and not isMdField and not isAddRow then
            if field.item == true or field.item == false then
                self.storeWindow:populateListingList(listing, field.fieldID, not field.item)
                return
            end
        end
    end

    self.accessing = field.fieldID
end


function storeWindow:populateListingList(listing, changeToField, newValue)
    if not self:isBeingManaged() then return end

    self.selectedListing = listing
    self.addListingList:clear()

    self.collapsedSections = self.collapsedSections or {fields=true, moddata=true, conditions=true}

    local _category = string.match(listing.item, "category:")
    local _catName  = listing.item:gsub("category:", "")
    local category  = _category and isValidItemDictionaryCategory(_catName)
    if category then
        local ch = self:addListingHeader("Category: ".._catName)
        ch.fieldID = "categoryListing"
    end

    if changeToField then
        local bcKey = changeToField:match("^bc:(.+)$")
        local mdKey = changeToField:match("^md:(.+)$")

        if changeToField == "__add_bc__" or changeToField == "__add_md__" then

        elseif bcKey then
            listing.buyConditions = listing.buyConditions or {}
            if newValue == nil or newValue == "" then
                listing.buyConditions[bcKey] = nil
                local hasAny = false
                for _ in pairs(listing.buyConditions) do hasAny = true break end
                if not hasAny then listing.buyConditions = false end
            else
                listing.buyConditions[bcKey] = newValue
            end
        elseif mdKey then
            if type(listing.fields) == "table" and type(listing.fields.modData) == "table" then
                listing.fields.modData[mdKey] = (newValue ~= "" and newValue ~= nil) and newValue or nil
            end
        elseif listing[changeToField] ~= nil then
            if changeToField == "stock" then listing.available = newValue end
            listing[changeToField] = newValue
        end
    end

    self:addListingHeader("[ Listing ]")

    local labelVal = listing.label or ""
    local labelRow = self.addListingList:addItem("Listing Name: "..labelVal, labelVal)
    labelRow.fieldID = "label"
    self:tagListingRow(labelRow, "listing", "Listing Name", labelVal)

    local price = self.addListingList:addItem("Price: "..listing.price, listing.price)
    price.fieldID = "price"
    self:tagListingRow(price, "listing", "Price", tostring(listing.price))

    local buyback = self.addListingList:addItem("Buyback Rate: "..listing.buybackRate, listing.buybackRate)
    buyback.fieldID = "buybackRate"
    self:tagListingRow(buyback, "listing", "Buyback Rate", tostring(listing.buybackRate))

    local movable = string.find(listing.item, "Moveables.") and "Moveables.Moveable"
    local script  = getScriptManager():getItem(listing.item)

    if (script or movable) and self.storeObj and not self.storeObj.ownerID then
        local stock = self.addListingList:addItem("Stock: "..listing.stock, listing.stock)
        stock.fieldID = "stock"
        self:tagListingRow(stock, "listing", "Stock", tostring(listing.stock))
    end

    local alwaysShow = self.addListingList:addItem("Always Show: "..tostring(listing.alwaysShow), listing.alwaysShow)
    alwaysShow.fieldID = "alwaysShow"
    self:tagListingRow(alwaysShow, "listing", "Always Show", tostring(listing.alwaysShow))

    local reselling = self.addListingList:addItem("Resell: "..tostring(listing.reselling), listing.reselling)
    reselling.fieldID = "reselling"
    self:tagListingRow(reselling, "listing", "Resell", tostring(listing.reselling))

    if listing.fields then
        local total_fields = itemFields.gatherFields(listing.item)
        if total_fields then

            if changeToField and not changeToField:match("^bc:") and not changeToField:match("^md:")
                    and changeToField ~= "__add_bc__" and changeToField ~= "__add_md__"
                    and (not listing[changeToField]) then
                local defaultValue = total_fields[changeToField]
                local currentValue = listing.fields[changeToField]
                if defaultValue == newValue then
                    listing.fields[changeToField] = nil
                elseif currentValue ~= newValue then
                    listing.fields[changeToField] = newValue
                end
            end

            self:addListingHeader("[ Item Fields ]", nil, "fields")

            if not self.collapsedSections["fields"] then
                for field, _value in pairs(total_fields) do
                    if field ~= "modData" then
                        local value = listing.fields[field] or _value
                        local displayValue = type(value) == "table" and "{...}" or tostring(value)
                        local addedField = self.addListingList:addItem(field..": "..displayValue, value)

                        if (not listing.fields[field]) or (self.storeObj and self.storeObj.ownerID) then
                            addedField.faded = true
                        end
                        addedField.fieldID = field
                        addedField.isConditional = type(value) == "string"
                            and (value:match("^[><!][=]?%-?[%d%.]") or value:match("^%-?[%d%.]+~%-?[%d%.]+$"))
                        self:tagListingRow(addedField, "fields", field, displayValue)
                    end
                end
            end

            local md = listing.fields.modData
            if type(md) == "table" then
                self:addListingHeader("[ ModData ]",
                    "Mod-specific data stored on the item.\nClick a key to edit its value.\nSet to empty to remove the key.\nAdd new entries below using  key=value  syntax.",
                    "moddata")
                if not self.collapsedSections["moddata"] then
                    for mdKey, mdVal in pairs(md) do
                        local dv = tostring(mdVal)
                        local mdRow = self.addListingList:addItem(mdKey..": "..dv, mdVal)
                        mdRow.fieldID = "md:"..mdKey
                        mdRow.isConditional = type(mdVal) == "string"
                            and (mdVal:match("^[><!][=]?%-?[%d%.]") or mdVal:match("^%-?[%d%.]+~%-?[%d%.]+$"))
                        self:tagListingRow(mdRow, "moddata", mdKey, dv)
                    end
                    local addMd = self.addListingList:addItem("+ Add modData", "__add_md__")
                    addMd.fieldID = "__add_md__"
                    addMd.faded = true
                end
            end
        end
    end

    self:addListingHeader("[ Buy Conditions ]",
        "Requirements the sold item must meet for this listing to accept it.\nExamples:  condition=>75   sharpness=0.5~1.0   name==~Ring   isFrozen=false\nOperators: >N  <N  >=N  <=N  !N  N~M (inclusive range)  =~text (contains)  exact value\nSet to empty to remove a condition.",
        "conditions")
    if not self.collapsedSections["conditions"] then
        local bc = listing.buyConditions
        if type(bc) == "table" then
            for bcKey, bcExpr in pairs(bc) do
                local dv = tostring(bcExpr)
                local bcRow = self.addListingList:addItem(bcKey..": "..dv, bcExpr)
                bcRow.fieldID = "bc:"..bcKey
                bcRow.isConditional = true
                self:tagListingRow(bcRow, "conditions", bcKey, dv)
            end
        end
        local addBc = self.addListingList:addItem("+ Add condition...", "__add_bc__")
        addBc.fieldID = "__add_bc__"
        addBc.faded = true
        self:tagListingRow(addBc, "add", "+ Add condition...", "field=expr")
    end

    if (not self.addListingList.selected) or (self.addListingList.options and self.addListingList.selected > #self.addListingList.options) then
        self.addListingList.selected = 1
    end
end


function storeWindow:rebuildListingOrder()
    local storeObj = self.storeObj
    if not storeObj then self.listingOrder = {} return end
    local seed = self.listingOrder or storeObj.listingOrder or {}
    local seen = {}
    for _,id in ipairs(seed) do seen[id] = true end
    local newOrder = {}
    for _,id in ipairs(seed) do
        if storeObj.listings[id] then table.insert(newOrder, id) end
    end
    for id in pairs(storeObj.listings) do
        if not seen[id] then table.insert(newOrder, id) end
    end
    self.listingOrder = newOrder
end


function storeWindow:listingIsVisible(listing)
    local storeObj = self.storeObj
    if self:isBeingManaged() and _internal.canManageStore(storeObj, self.player) then return true end
    local script = getScriptManager():getItem(listing.item)
    local validCategory = (not script) and isValidItemDictionaryCategory(listing.item:gsub("category:",""))
    local validItem = script or validCategory
    local availableStock = self:getAvailableStock(listing)
    local availableItem = availableStock ~= 0
    local itemReselling = listing.stock ~= 0 or listing.reselling == true
    local ifNotSellingThenBuying = not (storeObj.ownerID and listing.reselling == false and listing.buybackRate <= 0)
    local showListing = itemReselling and availableItem and validItem and ifNotSellingThenBuying
    if listing.alwaysShow == true then showListing = true end
    return showListing
end


function storeWindow:buildCategoryTabs()
    local prevScroll = self.categoryTabScroll or 0
    self.categoryTabs = {"All"}
    self.categoryTabScroll = prevScroll

    if not self.storeObj then return end

    local seen = {}
    for _,listing in pairs(self.storeObj.listings) do
        if self:listingIsVisible(listing) then
            if string.match(listing.item, "category:") then
                local cat = listing.item:gsub("category:","")
                if not seen[cat] then seen[cat] = true table.insert(self.categoryTabs, cat) end
            else
                local script = getScriptManager():getItem(listing.item)
                local cat = script and script:getDisplayCategory()
                if cat and not seen[cat] then seen[cat] = true table.insert(self.categoryTabs, cat) end
            end
        end
    end
    table.sort(self.categoryTabs, function(a,b)
        if a == "All" then return true end
        if b == "All" then return false end
        return a < b
    end)

    if self.activeCategoryTab and self.activeCategoryTab ~= "All" then
        local stillExists = false
        for _,cat in ipairs(self.categoryTabs) do
            if cat == self.activeCategoryTab then stillExists = true break end
        end
        if not stillExists then self.activeCategoryTab = "All" end
    end
end


function storeWindow:drawCategoryTabs()
    if not self.categoryTabs or not self.categoryTabY then return end
    local font = UIFont.NewSmall
    local tm = getTextManager()
    local tabH = self.categoryTabH
    local y = self.categoryTabY
    local pad = 6
    local x = self.categoryTabX - (self.categoryTabScroll or 0)
    local mx = self:getMouseX()
    local my = self:getMouseY()
    local hoveredFullName
    local tabRight = self.categoryTabX + self.storeStockData.width

    for i,cat in ipairs(self.categoryTabs) do
        local fullName = cat ~= "All" and (getTextOrNull("IGUI_ItemCat_"..cat) or cat) or cat
        local label = cat ~= "All" and fullName:sub(1,1) or "All"
        local w = tm:MeasureStringX(font, label) + pad*2
        local isActive = (self.activeCategoryTab == cat)

        local fullyVisible = x >= self.categoryTabX and x + w <= tabRight

        if fullyVisible then
            local bgA = isActive and 0.6 or 0.2
            self:drawRect(x, y, w, tabH, bgA, 0.2, 0.2, 0.2)
            self:drawRectBorder(x, y, w, tabH, 0.7,
                isActive and 1 or 0.4,
                isActive and 1 or 0.4,
                isActive and 1 or 0.4)
            self:drawText(label, x+pad, y+2, 1, 1, 1, isActive and 1 or 0.6, font)

            if cat ~= "All" and mx >= x and mx < x+w and my >= y and my < y+tabH then
                hoveredFullName = fullName
            end
        end

        x = x + w + 2
    end
    self.categoryTabsTotalWidth = x - self.categoryTabX + (self.categoryTabScroll or 0)

    if hoveredFullName then
        local tw = tm:MeasureStringX(font, hoveredFullName) + 8
        local fh = tm:getFontHeight(font)
        local tx = math.min(mx, tabRight - tw - 2)
        local ty = y - fh - 4
        self:drawRect(tx, ty, tw, fh+4, 0.85, 0.1, 0.1, 0.1)
        self:drawRectBorder(tx, ty, tw, fh+4, 0.9, 0.5, 0.5, 0.5)
        self:drawText(hoveredFullName, tx+4, ty+2, 1, 1, 1, 1, font)
    end
end


function storeWindow:onCategoryTabClick(mx, my)
    if not self.categoryTabs or not self.categoryTabY then return false end
    if my < self.categoryTabY or my > self.categoryTabY + self.categoryTabH then return false end
    if mx < self.categoryTabX or mx > self.categoryTabX + self.storeStockData.width then return false end

    local font = UIFont.NewSmall
    local tm = getTextManager()
    local pad = 6
    local x = self.categoryTabX - (self.categoryTabScroll or 0)

    for i,cat in ipairs(self.categoryTabs) do
        local fullName = cat ~= "All" and (getTextOrNull("IGUI_ItemCat_"..cat) or cat) or cat
        local label = cat ~= "All" and fullName:sub(1,1) or "All"
        local w = tm:MeasureStringX(font, label) + pad*2
        if mx >= x and mx < x + w then
            self.activeCategoryTab = cat
            return true
        end
        x = x + w + 2
    end
    return false
end


function storeWindow:initialise()
    ISPanelJoypad.initialise(self)
    local btnWid = 100
    local btnHgt = 25
    local padBottom = 10
    local listWidh = (self.width / 2)-15
    local listHeight = (self.height*0.6)
    local tabH = 20

    local storeName = "new store"
    if self.storeObj and self.storeObj.name then storeName = self.storeObj.name end

    self.manageStoreName = ISTextEntryBox:new(storeName, 10, 12, self.width-20, btnHgt)
    self.manageStoreName.font = UIFont.Medium
    self.manageStoreName:initialise()
    self.manageStoreName:instantiate()
    self.manageStoreName.borderColor = { r = 1, g = 0, b = 0, a = 0.7 }
    self:addChild(self.manageStoreName)

    self.yourCartData = ISScrollingListBox:new(10, 80, listWidh, listHeight)
    self.yourCartData:initialise()
    self.yourCartData:instantiate()
    self.yourCartData:setOnMouseDownFunction(self, self.onCartItemSelected)
    self.yourCartData.itemheight = (self.yourCartData.height/9)+2
    self.yourCartData.selected = 0
    self.yourCartData.joypadParent = self
    self.yourCartData.font = UIFont.NewSmall
    self.yourCartData.doDrawItem = self.drawCart
    self.yourCartData.onMouseUp = self.yourOfferMouseUp
    self.yourCartData.drawBorder = true
    self:addChild(self.yourCartData)

    local stockX = self.width-listWidh-10
    local stockY = self.yourCartData.y + tabH + 2
    self.storeStockData = ISScrollingListBox:new(stockX, stockY, listWidh, listHeight - tabH - 2)
    self.storeStockData:initialise()
    self.storeStockData:instantiate()
    self.storeStockData:setOnMouseDownFunction(self, self.onStoreItemSelected)
    self.storeStockData.itemheight = (self.storeStockData.height/9)+2
    self.storeStockData.selected = 0
    self.storeStockData.joypadParent = self
    self.storeStockData.font = UIFont.NewSmall
    self.storeStockData.doDrawItem = self.drawStock
    self.storeStockData.onMouseUp = self.yourStockingMouseUp
    self.storeStockData.drawBorder = true
    self:addChild(self.storeStockData)

    self.categoryTabY = self.yourCartData.y
    self.categoryTabH = tabH
    self.categoryTabX = stockX

    self.activeCategoryTab = "All"

    self:rebuildListingOrder()
    self:displayStoreStock()
    self:buildCategoryTabs()

    local manageStockButtonsX = (self.storeStockData.x+self.storeStockData.width)
    local manageStockButtonsY = self.storeStockData.y+self.storeStockData.height
    self.addStockBtn = ISButton:new(manageStockButtonsX-23, manageStockButtonsY+4, btnHgt-3, btnHgt-3, "+", self, storeWindow.onClick)
    self.addStockBtn.internal = "ADDSTOCK"
    self.addStockBtn.font = UIFont.Small
    self.addStockBtn:initialise()
    self.addStockBtn:instantiate()
    self:addChild(self.addStockBtn)

    self.addStockEntry = ISTextEntryBox:new("", self.storeStockData.x, self.addStockBtn.y, self.storeStockData.width-self.addStockBtn.width-3, self.addStockBtn.height)
    self.addStockEntry.font = UIFont.Small
    self.addStockEntry.onTextChange = storeWindow.addItemEntryChange
    self.addStockEntry:initialise()
    self.addStockEntry:instantiate()
    self:addChild(self.addStockEntry)

    --addStockBuyBackRate
    --addStockPrice
    --addStockQuantity

    self.addListingList = ISScrollingListBox:new(0, 0, listWidh, self.height-32)
    self.addListingList:initialise()
    self.addListingList:instantiate()
    self.addListingList:setOnMouseDownFunction(self, self.onAddListingListSelected)
    self.addListingList.itemheight = getTextManager():getFontHeight(UIFont.NewMedium)+5
    self.addListingList.selected = 0
    self.addListingList.borderColor = {r=1, g=0, b=0, a=0.5}

    self.addListingList.itemTextColor = {r=1, g=1, b=1, a=0.9}

    self.addListingList.labels = {}
    self.addListingList.storeWindow = self
    self.addListingList.joypadParent = self
    self.addListingList.font = UIFont.NewMedium
    self.addListingList.doDrawItem = self.drawAddListingList
    self.addListingList.onMouseUp = self.addListingListMouseUp
    self.addListingList.drawBorder = true
    self.addListingList.prerender = storeWindow.prerenderAddListingList

    local _font = UIFont.Large
    local FONT_HGT = getTextManager():getFontHeight(_font)
    self.addListingList.label = ISLabel:new(0+(self.addListingList.width/2), 0-FONT_HGT, FONT_HGT, "MANAGE MODE", 1, 0, 0, 0.7, _font, true)
    self.addListingList.label.center = true
    self.addListingList.label:initialise()
    self.addListingList.label:instantiate()
    self.addListingList:addChild(self.addListingList.label)
    self.addListingList:setVisible(false)
    self.addListingList:addToUIManager()
    --addChild(self.addListingList)

    self.listingInput = ISTextEntryBox:new("", self.addListingList:getX(), self.y, self.addListingList:getWidth(), 0)
    self.listingInput.font = UIFont.NewMedium
    self.listingInput.onCommandEntered = storeWindow.listingInputEntered
    self.listingInput:initialise()
    self.listingInput:instantiate()
    --parent is not store window
    self.addListingList:addChild(self.listingInput)
    self.listingInput:setVisible(false)

    self.purchase = ISButton:new(self.storeStockData.x + self.storeStockData.width - (math.max(btnWid, getTextManager():MeasureStringX(UIFont.Small, getText("IGUI_PURCHASE")) + 10)), self:getHeight() - padBottom - btnHgt, btnWid, btnHgt - 3, getText("IGUI_PURCHASE"), self, storeWindow.onClick)
    self.purchase.internal = "PURCHASE"
    self.purchase.borderColor = {r=1, g=1, b=1, a=0.4}
    self.purchase:initialise()
    self.purchase:instantiate()
    self:addChild(self.purchase)

    self.addStockSearchPartition = ISComboBox:new(self.purchase.x, self.addStockEntry.y+self.addStockEntry.height+6, self.purchase.width-2, 18)
    self.addStockSearchPartition.borderColor = { r = 1, g = 1, b = 1, a = 0.4 }
    self.addStockSearchPartition.onChange = storeWindow.addItemEntryChange
    self.addStockSearchPartition:initialise()
    self.addStockSearchPartition:instantiate()
    self:addChild(self.addStockSearchPartition)
    self.addStockSearchPartition:addOptionWithData(getText("IGUI_Name"), "name")
    self.addStockSearchPartition:addOptionWithData(getText("IGUI_invpanel_Type"), "type")
    self.addStockSearchPartition:addOptionWithData(getText("IGUI_invpanel_Category"), "category")


    self.manageBtn = ISButton:new((self.width/2)-45, 77-btnHgt, 70, 20, getText("IGUI_MANAGESTORE"), self, storeWindow.onClick)
    self.manageBtn.internal = "MANAGE"
    self.manageBtn:initialise()
    self.manageBtn:instantiate()
    self:addChild(self.manageBtn)

    local addStockListY = self.addStockSearchPartition.y
    local addStockListW = self.storeStockData.width-self.purchase.width-8
    self.addStockList = ISScrollingListBox:new(self.storeStockData.x, addStockListY, addStockListW, self.height-addStockListY-10)
    self.addStockList:initialise()
    self.addStockList:instantiate()
    self.addStockList:setOnMouseDownFunction(self, self.onAddStockListSelected)
    self.addStockList.itemheight = getTextManager():getFontHeight(UIFont.NewSmall)+4
    self.addStockList.selected = 0
    self.addStockList.labels = {}
    self.addStockList.joypadParent = self
    self.addStockList.font = UIFont.NewSmall
    self.addStockList.doDrawItem = self.drawAddStockList
    --self.addStockList.onMouseUp = self.addStockListMouseUp
    self.addStockList.drawBorder = true
    self:addChild(self.addStockList)

    local restockHours = ""
    if self.storeObj then restockHours = tostring(self.storeObj.restockHrs) end

    self.restockHours = ISTextEntryBox:new(restockHours, self.width-50, 70-btnHgt, 40, self.addStockBtn.height)
    self.restockHours.font = UIFont.Medium
    self.restockHours.borderColor = { r = 1, g = 0, b = 0, a = 0.7 }
    self.restockHours:initialise()
    self.restockHours:instantiate()
    self:addChild(self.restockHours)

    if self.storeObj and self.storeObj.ownerID then
        self.restockHours:setX(self.width-75)
        self.restockHours:setWidth(65)
        local cash = tostring(self.storeObj.cash)
        self.restockHours:setText(cash)
        self.restockHours.tooltip = getText("IGUI_STORECASHINPUTTOOLTIP")
        self.restockHours.onCommandEntered = self.onChangeStoreCash
    end

    self.clearStore = ISButton:new(self.manageBtn.x+self.manageBtn.width+4, self.manageBtn.y, 10, 20, "X", self, storeWindow.onClick)
    self.clearStore.internal = "CLEAR_STORE"
    self.clearStore.font = UIFont.NewSmall
    self.clearStore.textColor = { r = 1, g = 0, b = 0, a = 0.7 }
    self.clearStore.borderColor = { r = 1, g = 0, b = 0, a = 0.7 }
    self.clearStore.tooltip = getText("IGUI_DISCONNECT_STORE")
    self.clearStore:initialise()
    self.clearStore:instantiate()
    self:addChild(self.clearStore)

    self.blocker = ISPanel:new(0,0, self.width, self.height)
    self.blocker.moveWithMouse = true
    self.blocker.backgroundColor = {r=0, g=0, b=0, a=0.8}
    self.blocker:initialise()
    self.blocker:instantiate()
    self.blocker.bringToTop = self.dummyBringToTop
    self:addChild(self.blocker)

    self.no = ISButton:new(10, self:getHeight() - padBottom - btnHgt, btnWid, btnHgt, getText("UI_Cancel"), self, storeWindow.onClick)
    self.no.internal = "CANCEL"
    self.no.borderColor = {r=1, g=1, b=1, a=0.4}
    self.no:initialise()
    self.no:instantiate()
    self:addChild(self.no)

    local acbWidth = (self.width/2)+64
    local btnBuffer = 2
    local buttonW = (acbWidth/2)-btnBuffer
    local delBtnW = (buttonW/3)

    self.assignComboBox = ISComboBox:new((self.width/2)-(acbWidth/2)+(delBtnW/4)+2, (self.height/2)-1, acbWidth, 22)
    self.assignComboBox.borderColor = { r = 1, g = 1, b = 1, a = 0.4 }
    self.assignComboBox:initialise()
    self.assignComboBox:instantiate()
    self:addChild(self.assignComboBox)
    self:populateComboList()

    local acb = self.assignComboBox

    self.aBtnDel = ISButton:new(acb.x-delBtnW-2, acb.y, delBtnW, acb.height, getText("IGUI_DELETEPRESET"), self, storeWindow.onClick)
    self.aBtnDel.internal = "DELETE_STORE_PRESET"
    self.aBtnDel.font = UIFont.NewSmall
    self.aBtnDel.borderColor = { r = 1, g = 0, b = 0, a = 0.7 }
    self.aBtnDel.textColor = { r = 1, g = 0, b = 0, a = 0.7 }
    self.aBtnDel:initialise()
    self.aBtnDel:instantiate()
    self:addChild(self.aBtnDel)

    self.aBtnConnect = ISButton:new(acb.x, acb.y-29, buttonW, 25, getText("IGUI_CONNECTPRESET"), self, storeWindow.onClick)
    self.aBtnConnect.internal = "CONNECT_TO_STORE"
    self.aBtnConnect:initialise()
    self.aBtnConnect:instantiate()
    self:addChild(self.aBtnConnect)

    self.aBtnCopy = ISButton:new(self.aBtnConnect.x+buttonW+(btnBuffer*2), acb.y-29, buttonW, 25, getText("IGUI_COPYPRESET"), self, storeWindow.onClick)
    self.aBtnCopy.internal = "COPY_STORE"
    self.aBtnCopy:initialise()
    self.aBtnCopy:instantiate()
    self:addChild(self.aBtnCopy)

    self.exportButton = ISButton:new(self.aBtnDel.x, acb.y-54, self.aBtnDel.width, 25, "Export", self, storeWindow.onClick)
    self.exportButton.internal = "EXPORT_TO_LOCAL"
    self.exportButton.borderColor = { r = 1, g = 1, b = 1, a = 0.7 }
    self.exportButton.textColor = { r = 1, g = 1, b = 1, a = 0.7 }
    self.exportButton.tooltip = "Export server shops to local shopsAndTradersData.json"
    self.exportButton:initialise()
    self.exportButton:instantiate()
    self:addChild(self.exportButton)

    self.loadButton = ISButton:new(self.aBtnDel.x, acb.y-29, self.aBtnDel.width, 25, "Load", self, storeWindow.onClick)
    self.loadButton.internal = "LOAD_FROM_FILE"
    self.loadButton.borderColor = { r = 1, g = 1, b = 1, a = 0.7 }
    self.loadButton.textColor = { r = 1, g = 1, b = 1, a = 0.7 }
    self.loadButton.tooltip = "Load from local shopsAndTradersData.json"
    self.loadButton:initialise()
    self.loadButton:instantiate()
    self:addChild(self.loadButton)
end


function storeWindow:populateComboList()
    self.assignComboBox:clear()
    self.assignComboBox:addOptionWithData("BLANK", false)
    if _internal.isAdminHostDebug() then
        for ID,DATA in pairs(CLIENT_STORES) do
            if ID and DATA.name and (not DATA.ownerID) then self.assignComboBox:addOptionWithData(DATA.name, ID) end
        end
    end
    if (not self.assignComboBox.selected) or (self.assignComboBox.selected > #self.assignComboBox.options) then self.assignComboBox.selected = 1 end
end


function storeWindow:isOwner(player)
    if not self.storeObj or not player then return false end
    local shopOwnerID = self.storeObj.ownerID
    local playerUsername = player:getUsername()
    if playerUsername and shopOwnerID and playerUsername==shopOwnerID then return true end
    if self.storeObj.managerIDs and self.storeObj.managerIDs[playerUsername] then return true end
    return false
end


function storeWindow:isBeingManaged()
    if self.storeObj and self.storeObj.isBeingManaged then return true end
    return false
end


function storeWindow:rtrnTypeIfValid(item)
    local itemType
    local itemCat

    local storeObj = self.storeObj

    if type(item) == "string" then
        local movable = string.find(item, "Moveables.")
        local typing = movable and "Moveables.Moveable" or item
        local itemScript = getScriptManager():getItem(typing)
        if itemScript then itemType = typing end
        return itemType, false, itemCat
    else

        local container = item:getContainer()
        if self.player and container and (not container:isInCharacterInventory(self.player)) then
            return false, "IGUI_NOTRADE_OUTSIDEINV"
        end

        if (item:getCondition()/item:getConditionMax())<0.75 or item:isBroken() then return false, "IGUI_NOTRADE_DAMAGED" end
        itemType = item:getFullType()
        if (_internal.isMoneyType(itemType) and item:getModData().value) then
            if SandboxVars.ShopsAndTraders.ShopsUseCash > 2 then return false,"IGUI_NOTRADE_NOCASH" end
            return itemType
        end

        itemCat = item:getDisplayCategory()

        if storeObj and itemType then
            local fullFields = itemFields.gatherFields(item, false)
            local order = storeObj.listingOrder or {}
            local orderIndex = {}
            for i,id in ipairs(order) do orderIndex[id] = i end

            local best = nil
            local bestScore = -1
            local bestOrder = math.huge

            for id,listing in pairs(storeObj.listings) do
                if listing.buybackRate and listing.buybackRate > 0 then
                    local isExact = listing.item == itemType
                    local isCat = (not isExact) and itemCat and listing.item == "category:"..itemCat
                    if isExact or isCat then
                        local condMet = true
                        if listing.buyConditions and type(listing.buyConditions) == "table" then
                            for condField, expr in pairs(listing.buyConditions) do
                                local actual = fullFields and fullFields[condField]
                                if not itemFields.parseConditional(expr, actual) then
                                    condMet = false break
                                end
                            end
                        end
                        if condMet then
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

            if best then return itemType, false, itemCat, best end
            return false, "IGUI_NOTRADE_INVALIDTYPE"
        end
    end

    return false, nil
end


function storeWindow:drawCart(y, item, alt)
    local texture

    local storeObj = self.parent.storeObj
    if (not storeObj) then return end

    local listingID = item.item

    local checkThis = (type(item.item) ~= "string" and item.item) or item.itemType
    local itemType, reason, itemCat, matchedListing = self.parent:rtrnTypeIfValid(checkThis)

    if type(item.item) == "string" then
        local listingItem = storeObj.listings[item.item]
        local movableSprite = listingItem and listingItem.fields and listingItem.fields.worldSprite

        if movableSprite then
            texture = getTexture(movableSprite)
        else
            local script = getScriptManager():getItem(item.itemType)
            texture = script and script:getNormalTexture()
        end

    else texture = item.item:getTex() end

    local color = {r=1, g=1, b=1, a=0.9}
    local noList = false

    if reason then
        color = {r=0.75, g=0, b=0, a=0.45}
        noList = true
    end

    self:drawRectBorder(0, y, self:getWidth(), self.itemheight - 1, 0.9, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    self:drawTextureScaledAspect(texture, 5, y+3, 22, 22, color.a, color.r, color.g, color.b)
    self:drawText(item.text or "", 32, y+6, color.r, color.g, color.b, color.a, self.font)

    if noList then
        local nlW = (self:getWidth()/6)+20
        if reason then
            reason = getText(reason)
            nlW = math.max(nlW, (getTextManager():MeasureStringX(self.font,reason)+20))
        end
        local nlH = (self.itemheight-1)/2
        local nlX = (self:getWidth())-(nlW)-10
        local nlY = y+(nlH/2)
        color = {r=1, g=0, b=0, a=0.6}
        self:drawRect(nlX, nlY, nlW, nlH, 1, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
        self:drawText(reason or "", nlX+10, nlY, color.r, color.g, color.b, color.a, self.font)
        self:drawRectBorder(nlX, nlY, nlW, nlH, 0.9, color.r, color.g, color.b)
    end

    local balanceDiff = 0

    if storeObj and (not noList) then

        local listing
        if type(item.item) == "string" then
            listing = storeObj.listings[listingID]
        else
            listing = matchedListing
        end
        if listing or _internal.isMoneyType(itemType) then
            if type(item.item) == "string" then balanceDiff = listing.price
            else
                if _internal.isMoneyType(itemType) then balanceDiff = 0-item.item:getModData().value
                else balanceDiff = 0-(listing.price*(listing.buybackRate/100))
                end
            end

            local balanceColor = {r=1, g=1, b=1, a=0.9}
            if balanceDiff > 0 then
                balanceDiff = "-".._internal.numToCurrency(balanceDiff)
                balanceColor = {r=1, g=0.2, b=0.2, a=0.9}

            elseif balanceDiff < 0 then
                balanceDiff = "+".._internal.numToCurrency(math.abs(balanceDiff))
                balanceColor = {r=0.2, g=1, b=0.2, a=0.9}
            else
                balanceDiff = " ".._internal.numToCurrency(balanceDiff)
            end

            local costDiff_x = getTextManager():MeasureStringX(self.font,balanceDiff)+30
            self:drawText(balanceDiff, (self.x+self.width)-costDiff_x, y+6, balanceColor.r, balanceColor.g, balanceColor.b, balanceColor.a, self.font)
        end
    end

    return y + self.itemheight
end


function storeWindow:drawStock(y, entry, alt)

    local text = entry.text
    local item = entry.item
    local listingID = entry.listingID

    local storeObj = self.parent.storeObj
    if storeObj then
        local listing = storeObj.listings[listingID]
        if listing then

            local texture, script, validCategory = nil, nil, nil
            if type(item) == "string" then

                local movableSprite = listing and listing.fields and listing.fields.worldSprite

                script = getScriptManager():getItem(item)
                if script then
                    texture = movableSprite and getTexture(movableSprite) or script:getNormalTexture()
                else
                    validCategory = isValidItemDictionaryCategory(item:gsub("category:",""))
                end
            else
                texture = item:getTex()
            end

            local color = {r=1, g=1, b=1, a=0.9}

            local availableStock = self.parent:getAvailableStock(listing)
            local validItem = (texture or validCategory)
            local availableItem = (availableStock ~= 0)
            local itemReselling = (listing.stock ~= 0 or listing.reselling==true)

            local ifNotSellingThenBuying = true
            if storeObj.ownerID and listing.reselling==false and listing.buybackRate<=0 then ifNotSellingThenBuying = false end

            local showListing = itemReselling and availableItem and validItem and ifNotSellingThenBuying

            if listing.alwaysShow==true then showListing = true end
            local managing = (self.parent:isBeingManaged() and _internal.canManageStore(storeObj,self.parent.player))

            if showListing or managing then

                if not string.match(item, "category:") then
                    local inCart = 0
                    for _,v in pairs(self.parent.yourCartData.items) do if v.item == listingID then inCart = inCart+1 end end
                    local availableTemp = availableStock-inCart

                    if storeObj.ownerID and listing.reselling==false and listing.buybackRate>0 then availableTemp = 1 end

                    if availableTemp <= 0 then color = {r=0.7, g=0.7, b=0.7, a=0.3} end
                end

                local extra = ""
                if (not texture) and (not validCategory) then extra = "\[!\] " end

                local isSelected = self.parent.selectedListing and self.parent.selectedListing.id == listingID
                if isSelected then
                    self:drawRect(0, y, self:getWidth(), self.itemheight - 1, 0.25, 1, 0.6, 0)
                    local delX, delSz = self.parent:stockRowDeleteZone()
                    local dy = y + (self.itemheight - delSz) / 2
                    self:drawRect(delX, dy, delSz, delSz, 0.85, 0.6, 0.1, 0.1)
                    self:drawRectBorder(delX, dy, delSz, delSz, 0.9, 1, 0.3, 0.3)
                    local xW = getTextManager():MeasureStringX(self.font, "X")
                    self:drawText("X", delX + (delSz - xW) / 2, dy + 2, 1, 0.8, 0.8, 1, self.font)
                end

                local dragStart = self.parent.dragStartRow
                local dragStartY = self.parent.dragStartY
                local isDragging = dragStart and dragStartY and math.abs(self:getMouseY() - dragStartY) > 8
                if isDragging then
                    self.parent.dragTargetRow = self.parent:storeItemRowAt(self:getMouseY())
                    local dragTarget = self.parent.dragTargetRow
                    local thisRow
                    for i,v in ipairs(self.items) do
                        if v.listingID == listingID then thisRow = i break end
                    end
                    if thisRow == dragStart then
                        self:drawRect(0, y, self:getWidth(), self.itemheight - 1, 0.6, 0, 0, 0)
                    end
                    if dragTarget and thisRow == dragTarget then
                        local lineY = (dragTarget >= dragStart) and (y + self.itemheight - 2) or y
                        self:drawRect(0, lineY, self:getWidth(), 2, 1, 1, 0.8, 0.2)
                    end
                end

                self:drawRectBorder(0, y, self:getWidth(), self.itemheight - 1, 0.9, self.borderColor.r, self.borderColor.g, self.borderColor.b)
                if texture then self:drawTextureScaledAspect(texture, 5, y+3, 22, 22, color.a, color.r, color.g, color.b) end
                self:drawText(extra..text, 32, y+6, color.r, color.g, color.b, color.a, self.font)

                return y + self.itemheight
            end
        end
    end
    return y
end


function storeWindow:displayStoreStock()

    self.storeStockData:clear()

    local storeObj = self.storeObj
    if not storeObj then return end

    if not storeObj.listings then print("ERROR: storeObj.listings: not found") return end
    if storeObj.listings and type(storeObj.listings)~="table" then print("ERROR: storeObj.listings: not table: "..tostring(storeObj.listings)) return end

    local managed = self:isBeingManaged() and _internal.canManageStore(storeObj,self.player)

    local listingCount = 0
    for _ in pairs(storeObj.listings) do listingCount = listingCount+1 end
    if listingCount ~= self.lastListingCount or managed ~= self.lastManaged then
        self.lastListingCount = listingCount
        self.lastManaged = managed
        self:buildCategoryTabs()
        self:rebuildListingOrder()
    end

    local function addOrdered(categoryOnly)
        for _,id in ipairs(self.listingOrder) do
            local listing = storeObj.listings[id]
            if listing then
                local isCategory = string.match(listing.item, "category:") ~= nil
                if isCategory == categoryOnly and self:listingMatchesTab(listing) then
                    self:addStockListing(listing, managed)
                end
            end
        end
    end

    addOrdered(true)
    addOrdered(false)
end


function storeWindow:addItemToYourCart(item)
    local add = true
    for _,v in ipairs(self.yourCartData.items) do
        if (v.item == item.listingID) or v.item == item then
            add = false break
        end
    end

    if add then self.yourCartData:addItem(item:getName(), item) end
end


function storeWindow:yourOfferMouseUp(x, y)
    if self.vscroll then self.vscroll.scrolling = false end
    local counta = 1

    if ISMouseDrag.dragging then
        for i,v in ipairs(ISMouseDrag.dragging) do
            counta = 1

            if instanceof(v, "InventoryItem") then
                self.parent:addItemToYourCart(v)
            else
                if v.invPanel.collapsed[v.name] then
                    counta = 1
                    for i2,v2 in ipairs(v.items) do
                        if counta > 1 then
                            self.parent:addItemToYourCart(v2)
                        end
                        counta = counta + 1
                    end

                end
            end
        end
    end
end


function storeWindow:update()

    local activityExpired = false
    if SandboxVars.ShopsAndTraders.ActivityTimeOut and (SandboxVars.ShopsAndTraders.ActivityTimeOut > 0) then
        activityExpired = getTimeInMillis() > self.activityTimeOut
    end

    if not _internal.isAdminHostDebug(self.storeObj,self.player) and not self.storeObj then
        self:closeStoreWindow()
        return
    end

    if not self.storeObj and #self.yourCartData.items>0 then
        self:closeStoreWindow()
        return
    end

    if activityExpired or not self.player or not self.worldObject or (math.abs(self.player:getX()-self.worldObject:getX())>2) or (math.abs(self.player:getY()-self.worldObject:getY())>2) then
        self:closeStoreWindow()
        return
    end
end


function storeWindow:removeItem(item) self.yourCartData:removeItem(item.text) end

--validateAddStockColor
function storeWindow:applyElementColor(e, color)
    if not e then return end

    local r, g, b, a = color.r, color.g, color.b, color.a

    e.borderColor = { r = r, g = g, b = b, a = a }
    e.textColor = { r = r, g = g, b = b, a = a }

    if e.javaObject.setTextColor then
        e.javaObject:setTextColor(ColorInfo.new(e.textColor.r,e.textColor.g,e.textColor.b,e.textColor.a))
    end
end


function storeWindow:getOrderTotal()
    local totalForTransaction = 0
    local invalidOrder = false
    local itemListedInCart = false

    if (not self.storeObj) then
        return totalForTransaction, invalidOrder
    end

    for i,v in ipairs(self.yourCartData.items) do
        local itemType, reason, itemCat, matchedListing = self:rtrnTypeIfValid(v.itemType or v.item)
        if itemType then

            if reason then invalidOrder = true end
            if type(v.item) ~= "string" then
                if _internal.isMoneyType(itemType) then
                    if SandboxVars.ShopsAndTraders.ShopsUseCash <= 2 then
                        itemListedInCart = true
                    end
                    totalForTransaction = totalForTransaction-(v.item:getModData().value)
                else
                    local itemListing = matchedListing

                    if itemListing then
                        itemListedInCart = true
                        totalForTransaction = totalForTransaction-(itemListing.price*(itemListing.buybackRate/100))
                    end
                end
            else
                local itemListing = self.storeObj.listings[v.item] --or self.storeObj.listings[v.item]
                if itemListing then
                    itemListedInCart = true
                    totalForTransaction = totalForTransaction+itemListing.price
                end
            end
        end
    end

    if (not itemListedInCart) then invalidOrder = true end

    return totalForTransaction, invalidOrder
end

function storeWindow:getPurchaseTotal()
    local totalForPurchase = 0
    for i,v in ipairs(self.yourCartData.items) do
        local itemType, _, itemCat = self:rtrnTypeIfValid(v.itemType or v.item)
        if itemType then
            if type(v.item) == "string" then
                local itemListing = self.storeObj.listings[v.item]
                if itemListing then totalForPurchase = totalForPurchase+itemListing.price end
            end
        end
    end
    return totalForPurchase
end


function storeWindow:displayOrderTotal()
    if not self.storeObj then return end
    if self:isBeingManaged() and (not _internal.canManageStore(self.storeObj,self.player)) then return end

    local x = self.yourCartData.x
    local y = self.yourCartData.y+self.yourCartData.height
    local w = self.yourCartData.width
    local fontH = getTextManager():MeasureFont(self.font)
    local fontPadded = (fontH*1.5)+2

    local rowPadding = 4
    local rows = 0

    local balanceColor = {
        normal = {r=1, g=1, b=1, a=0.9},
        normal2 = {r=0.7, g=0.7, b=0.7, a=0.7},
        red = {r=1, g=0.2, b=0.2, a=0.9},
        green = {r=0.2, g=1, b=0.2, a=0.9},
        gray = {r=0.5, g=0.5, b=0.5, a=0.5}
    }

    self:drawRect(x, y+(rows*fontPadded)+(rowPadding*(rows+1)), w, fontPadded, 0.9, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
    self:drawRectBorder(x, y+(rows*fontPadded)+(rowPadding*(rows+1)), w, fontPadded, 0.9, self.borderColor.r, self.borderColor.g, self.borderColor.b)

    local totalLine = getText("IGUI_TOTAL")..": "
    self:drawText(totalLine, x+10, y+(rows*fontPadded)+(rowPadding*(rows+1))+rowPadding, balanceColor.normal.r, balanceColor.normal.g, balanceColor.normal.b, balanceColor.normal.a, self.font)

    local totalForTransaction, invalidOrder = self:getOrderTotal()
    local textForTotal = _internal.numToCurrency(math.abs(totalForTransaction))
    local tColor = balanceColor.normal
    if totalForTransaction < 0 then tColor, textForTotal = balanceColor.green, "+"..textForTotal
    elseif totalForTransaction > 0 then tColor, textForTotal = balanceColor.red, "-"..textForTotal
    else textForTotal = " "..textForTotal end
    local xOffset = getTextManager():MeasureStringX(self.font, textForTotal)+15
    self:drawText(textForTotal, w-xOffset+5, y+(rows*fontPadded)+(rowPadding*(rows+1))+rowPadding, tColor.r, tColor.g, tColor.b, tColor.a, self.font)

    local wallet, walletBalance = getWallet(self.player), 0
    if wallet then walletBalance = wallet.amount end

    local walletRow, creditRow

    if SandboxVars.ShopsAndTraders.PlayerWallets then
        rows = rows+1
        walletRow = rows
        self:drawRect(x, y+(rows*fontPadded)+(rowPadding*(rows+1)), w, fontPadded, 0.9, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
        self:drawRectBorder(x, y+(rows*fontPadded)+(rowPadding*(rows+1)), w, fontPadded, 0.9, self.borderColor.r, self.borderColor.g, self.borderColor.b)

        local walletBalanceLine = getText("IGUI_WALLETBALANCE")..": ".._internal.numToCurrency(walletBalance)
        local bColor = balanceColor.normal
        if (walletBalance-totalForTransaction) < 0 then bColor = balanceColor.red end

        self:drawText(walletBalanceLine, x+10, y+(rows*fontPadded)+(rowPadding*(rows+1))+rowPadding, bColor.r, bColor.g, bColor.b, bColor.a, self.font)
    end

    local storeCredit

    --[[
    if not SandboxVars.ShopsAndTraders.PlayerWallets then
        local bColor = balanceColor.red
        self:drawTextRight(getText("IGUI_NOTRADE_NOCASH"), w-10, y+(rows*fontPadded)+(rowPadding*(rows+1))+rowPadding, bColor.r, bColor.g, bColor.b, bColor.a, self.font)
    end
    --]]


    local credit = wallet and (wallet.credit or {}) or false
    if credit then
        storeCredit = self.storeObj and credit[self.storeObj.ID]
        if storeCredit and storeCredit > 0 then
            rows = rows+1
            creditRow = rows

            self:drawRect(x, y+(rows*fontPadded)+(rowPadding*(rows+1)), w, fontPadded, 0.9, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
            self:drawRectBorder(x, y+(rows*fontPadded)+(rowPadding*(rows+1)), w, fontPadded, 0.9, self.borderColor.r, self.borderColor.g, self.borderColor.b)

            local bColor = balanceColor.normal
            if storeCredit-totalForTransaction < 0 then bColor = balanceColor.red end

            local creditLine = getText("IGUI_credit")..": ".._internal.numToCurrency(storeCredit)
            self:drawText(creditLine, x+10, y+(rows*fontPadded)+(rowPadding*(rows+1))+rowPadding, bColor.r, bColor.g, bColor.b, bColor.a, self.font)
        end
    end


    if totalForTransaction ~= 0 and SandboxVars.ShopsAndTraders.ShopsUseCash == 2 then
        if storeCredit and storeCredit>0 and creditRow then
            local storeCreditAfter = math.max(0, storeCredit-totalForTransaction)
            totalForTransaction = math.max(0, totalForTransaction-storeCredit)
            local sign = " "
            if storeCreditAfter < 0 then sign = "-" end
            local wbaText = sign.._internal.numToCurrency(math.abs(storeCreditAfter))
            local xOffset2 = getTextManager():MeasureStringX(self.font, wbaText)+15
            self:drawText(wbaText, w-xOffset2+5, y+(creditRow*fontPadded)+(rowPadding*(creditRow+1))+rowPadding, 0.7, 0.7, 0.7, 0.7, self.font)
        end
    end

    if totalForTransaction ~= 0 and SandboxVars.ShopsAndTraders.PlayerWallets then
        local walletBalanceAfter = walletBalance-totalForTransaction
        local sign = " "
        if walletBalanceAfter < 0 then sign = "-" end
        local wbaText = sign.._internal.numToCurrency(math.abs(walletBalanceAfter))
        local xOffset2 = getTextManager():MeasureStringX(self.font, wbaText)+15
        self:drawText(wbaText, w-xOffset2+5, y+(walletRow*fontPadded)+(rowPadding*(walletRow+1))+rowPadding, balanceColor.normal2.r, balanceColor.normal2.g, balanceColor.normal2.b, balanceColor.normal2.a, self.font)
    end

    if totalForTransaction<0 and self.storeObj and self.storeObj.ownerID and SandboxVars.ShopsAndTraders.ShopsUseCash < 2 then
        local storeCash = (self.storeObj.cash or 0)
        if storeCash < math.abs(totalForTransaction) then
            self:drawTextRight(getText("IGUI_NOTRADE_NOFUNDS"), self.purchase.x-10, self.purchase.y+rowPadding, balanceColor.red.r, balanceColor.red.g, balanceColor.red.b, balanceColor.red.a, self.font)
        end
    end

end


function storeWindow:prerender()

    self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)

    local topPadding = 8
    local font = UIFont.NewSmall
    local fontHeight = getTextManager():getFontHeight(font)

    if self:isBeingManaged() and _internal.canManageStore(self.storeObj,self.player) then

        local color

        if self.storeObj then
            local ownerID = self.storeObj.ownerID
            if ownerID then
                local prefix, suffix = getText("IGUI_CURRENCY_PREFIX"), getText("IGUI_CURRENCY_SUFFIX")
                self:drawTextRight(prefix, self.restockHours.x-6, self.restockHours.y, 0.9,0.2,0.2,0.9, UIFont.Medium)
            end
        end

    else

        local storeName = "No Name Set"
        if self.storeObj and self.storeObj.name then storeName = self.storeObj.name end
        local lengthStoreName = (getTextManager():MeasureStringX(UIFont.Medium, storeName)/2)
        self:drawText(storeName, (self.width/2)-lengthStoreName, topPadding-2, 1,1,1,1, UIFont.Medium)

        if self.storeObj then

            local ownerID = self.storeObj.ownerID
            if ownerID then
                local textOwnerID = getText("IGUI_ownedBy", ownerID)
                local lengthOwnerID = (getTextManager():MeasureStringX(font, textOwnerID)/2)
                self:drawText(textOwnerID, (self.width/2)-lengthOwnerID, topPadding+fontHeight+2, 0.9,0.9,0.9,0.8, font)
            else
                local restockingIn = tostring(self.storeObj.nextRestock)
                if restockingIn then self:drawTextRight(getText("IGUI_RESTOCK_HR", restockingIn), self.width-10, topPadding, 0.9,0.9,0.9,0.8, font) end
            end
        end
    end


    local cartText = getText("IGUI_YOURCART")
    local cartTextX = (self.yourCartData.x+(self.yourCartData.width/2))-(getTextManager():MeasureStringX(font, cartText)/2)
    self:drawText(cartText, cartTextX, self.yourCartData.y-20, 1,1,1,1, font)

    local stockText = getText("IGUI_STORESTOCK")
    local stockTextX = (self.storeStockData.x+(self.storeStockData.width/2))-(getTextManager():MeasureStringX(font, stockText)/2)
    self:drawText(stockText, stockTextX, self.yourCartData.y-20, 1,1,1,1, font)
end


function storeWindow:updateTooltip()
    local x = self:getMouseX()
    local y = self:getMouseY()
    local item
    if x >= self.storeStockData:getX() and x <= self.storeStockData:getX() + self.storeStockData:getWidth() and y >= self.storeStockData:getY() and y <= self.storeStockData:getY() + self.storeStockData:getHeight() then
        y = self.storeStockData:rowAt(self.storeStockData:getMouseX(), self.storeStockData:getMouseY())
        if self.storeStockData.items[y] then
            item = self.storeStockData.items[y]
        end
    end
    if x >= self.yourCartData:getX() and x <= self.yourCartData:getX() + self.yourCartData:getWidth() and y >= self.yourCartData:getY() and y <= self.yourCartData:getY() + self.yourCartData:getHeight() then
        y = self.yourCartData:rowAt(self.yourCartData:getMouseX(), self.yourCartData:getMouseY())
        if self.yourCartData.items[y] then
            item = self.yourCartData.items[y]
        end
    end

    if item and item.item and type(item.item)~="string" then

        if self.toolRender then
            self.toolRender:setItem(item.item)
            if not self:getIsVisible() then self.toolRender:setVisible(false)
            else
                self.toolRender:setVisible(true)
                self.toolRender:addToUIManager()
                self.toolRender:bringToTop()
            end
        else
            self.toolRender = ISToolTipInv:new(item.item)
            self.toolRender:initialise()
            self.toolRender:addToUIManager()
            if not self:getIsVisible() then
                self.toolRender:setVisible(true)
            end
            self.toolRender:setOwner(self)
            self.toolRender:setCharacter(self.player)
            self.toolRender:setX(self:getMouseX())
            self.toolRender:setY(self:getMouseY())
            self.toolRender.followMouse = true
        end
    else
        if self.toolRender then
            self.toolRender:setVisible(false)
        end
    end
end


function storeWindow:updateButtons()

    self.purchase.enable = false
    self.manageBtn.enable = false
    self.clearStore.enable = false
    self.addStockBtn.enable = false
    self.addStockSearchPartition.enable = false
    self.addStockList.enable = false

    self.assignComboBox.enable = false
    self.aBtnCopy.enable = false
    self.aBtnConnect.enable = false
    self.aBtnConnect.borderColor = { r = 0.3, g = 0.3, b = 0.3, a = 0.7 }
    self.loadButton.enable = false
    self.loadButton.borderColor = { r = 0.3, g = 0.3, b = 0.3, a = 0.7 }
    self.exportButton.enable = false
    self.exportButton.borderColor = { r = 0.3, g = 0.3, b = 0.3, a = 0.7 }
    self.aBtnDel.enable = false
    self.aBtnDel.borderColor = { r = 0.3, g = 0.3, b = 0.3, a = 0.7 }

    if not self.storeObj then
        self.assignComboBox.enable = true
        self.aBtnCopy.enable = true
        self.loadButton.enable = true
        self.loadButton.borderColor = { r = 1, g = 1, b = 1, a = 0.7 }
        self.exportButton.enable = true
        self.exportButton.borderColor = { r = 1, g = 1, b = 1, a = 0.7 }
        if self.assignComboBox.selected~=1 then
            self.aBtnConnect.enable = true
            self.aBtnConnect.borderColor = { r = 1, g = 1, b = 1, a = 0.7 }
            self.aBtnDel.enable = true
            self.aBtnDel.borderColor = { r = 1, g = 0, b = 0, a = 0.7 }
        end
        return
    end

    if _internal.canManageStore(self.storeObj,self.player) then
        self.manageBtn.enable = true
        if self:isBeingManaged() then
            self.clearStore.enable = true
            self.addStockBtn.enable = true
            self.addStockSearchPartition.enable = true
            self.addStockList.enable = true
        end
    end
end


function storeWindow:validateAddStockEntry()
    local entryText = tostring(self.addStockEntry:getInternalText())
    if not entryText or entryText=="" then return false end

    local movable = string.find(entryText, "Moveables.")
    if movable then return true end

    local matches, matchesToType = findMatchesFromItemDictionary(entryText, self.addStockSearchPartition:getOptionData(self.addStockSearchPartition.selected))
    if not matches or #matches <= 0 then return false end

    --[[
    print("matches: #:"..#matches.."   "..tostring(matches))
    for k,v in pairs(matches) do print("<"..k.."><"..v..">") end
    print("---")
    for k,v in pairs(matchesToType) do print("<"..k.."><"..v..">") end
    --]]

    local script = matchesToType[entryText]
    if script and getScriptManager():getItem(script) then return true end

    --print("no script: "..tostring(entryText))

    return false
end


function storeWindow:render()
    --self.addStockBtn
    local worldObjModData
    if self.worldObject then
        worldObjModData = self.worldObject:getModData()
        if worldObjModData and worldObjModData.storeObjID then
            self.storeObj = CLIENT_STORES[worldObjModData.storeObjID]
        end
        if self.storeObj and not worldObjModData.storeObjID then self.storeObj = nil end
    end

    self:updateButtons()
    self:updateTooltip()

    self:displayStoreStock()

    local managed = self:isBeingManaged()
    local canManage = _internal.canManageStore(self.storeObj,self.player)
    local blocked = false

    self.manageBtn:setVisible(canManage)

    if canManage then
        if managed then
            self.manageBtn.textColor = { r = 1, g = 0, b = 0, a = 0.7 }
            self.manageBtn.borderColor = { r = 1, g = 0, b = 0, a = 0.7 }
            self.storeStockData.borderColor = { r = 1, g = 0, b = 0, a = 0.7 }
        else
            self.manageBtn.textColor = { r = 1, g = 1, b = 1, a = 0.4 }
            self.manageBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.4 }
            self.storeStockData.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 0.9}
        end
    else
        if managed then blocked = true end
    end

    if (not self.storeObj) then
        self.manageBtn:setVisible(false)
        blocked = true
    end

    if self.repop and self.repop > 0 then
        self.repop = self.repop-1
        if self.repop <= 0 then self:populateComboList() end
    end

    local shouldSeeStorePresetOptions = (not self.storeObj) and _internal.isAdminHostDebug()

    self.assignComboBox:setVisible(shouldSeeStorePresetOptions)
    self.aBtnConnect:setVisible(shouldSeeStorePresetOptions)
    self.aBtnDel:setVisible(shouldSeeStorePresetOptions)
    self.loadButton:setVisible(shouldSeeStorePresetOptions)
    self.exportButton:setVisible(shouldSeeStorePresetOptions)
    self.aBtnCopy:setVisible(shouldSeeStorePresetOptions)

    self:displayOrderTotal()

    self.addListingList:setVisible(managed and not blocked)
    self.addStockBtn:setVisible(managed and not blocked)
    self.manageStoreName:setVisible(managed and not blocked)
    self.addStockEntry:setVisible(managed and not blocked)
    self.clearStore:setVisible(managed and not blocked)
    self.restockHours:setVisible(managed and not blocked)
    self.addStockSearchPartition:setVisible(managed and not blocked)
    self.addStockList:setVisible(managed and not blocked)
    self.manageStoreName:setEditable(not blocked)

    self.addStockEntry:setEditable((not self.addListingList.accessing) and (not self.selectedListing) and (not blocked))

    local totalForTransaction, invalidOrder = self:getOrderTotal()

    local wallet, walletBalance = getWallet(self.player), 0
    if wallet then walletBalance = wallet.amount end

    --print("tFT:"..totalForTransaction.."  sUC:"..SandboxVars.ShopsAndTraders.ShopsUseCash.."  iO:"..tostring(invalidOrder))

    local validIfNotWallets = ((not SandboxVars.ShopsAndTraders.PlayerWallets) and (totalForTransaction<=0))

    local credit = self.storeObj and wallet and wallet.credit and wallet.credit[self.storeObj.ID]
    local validIfCredit = self.storeObj and credit and ((credit-totalForTransaction) >= 0) or false

    --if validIfCredit then totalForTransaction = totalForTransaction+wallet.credit[self.storeObj.ID] end

    local validIfWallets = (SandboxVars.ShopsAndTraders.PlayerWallets and ((walletBalance-totalForTransaction) >= 0))
    --if validIfWallets then totalForTransaction = totalForTransaction+walletBalance end

    if self.storeObj and self.storeObj.ownerID then
        if SandboxVars.ShopsAndTraders.ShopsUseCash == 1 then
            local storeCash = (self.storeObj.cash or 0)+(credit or 0)
            if totalForTransaction < 0 and storeCash < math.abs(totalForTransaction) then invalidOrder = true end
        --elseif SandboxVars.ShopsAndTraders.ShopsUseCash == 2 then
        --    if totalForTransaction >= 0 then invalidOrder = true end
        end
    end

    --print(" iO:"..tostring(invalidOrder).." vIW:"..tostring(validIfWallets).." vINW:"..tostring(validIfNotWallets).." vIC:"..tostring(validIfCredit))

    local purchaseValid = (validIfWallets or validIfNotWallets or validIfCredit) and (not invalidOrder)

    local worldObjSquare = self.worldObject and self.worldObject:getSquare()
    if (SandboxVars.ShopsAndTraders.ShopsRequirePower == true) and worldObjSquare then
        if (not worldObjSquare:haveElectricity()) and (not getWorld():isHydroPowerOn()) then
            purchaseValid = false
            if not managed and not blocked then
                self:drawText(self.needs_power_message.text, self.width/2 - (self.needs_power_message.x / 2), (self.height - self.needs_power_message.y) - 10, 1,0,0,0.8, UIFont.Medium)
            end
        end
    end

    self.purchase.enable = (not managed and not blocked and #self.yourCartData.items>0 and purchaseValid)

    local gb = 1
    if not purchaseValid then gb = 0 end
    self.purchase.textColor = { r = 1, g = gb, b = gb, a = 0.7 }
    self.purchase.borderColor = { r = 1, g = gb, b = gb, a = 0.7 }

    local selectedListing = self.selectedListing
    self.fadedEntryColor = self.fadedEntryColor or { r = 0.3, g = 0.3, b = 0.3, a = 0.3 }
    self.redEntryColor = self.redEntryColor or { r = 1, g = 0, b = 0, a = 0.8 }
    self.normalEntryColor = self.normalEntryColor or { r = 1, g = 1, b = 1, a = 0.8 }

    if selectedListing then
        self.addStockBtn.enable = false
        self.addStockBtn.backgroundColor = {r=0.1, g=0.1, b=0.1, a=1.0}
        self:applyElementColor(self.addStockBtn, self.fadedEntryColor)
        self.addStockEntry.enable = false
        self:applyElementColor(self.addStockEntry, self.fadedEntryColor)
    else
        self.addStockBtn.backgroundColor = {r=0, g=0, b=0, a=1.0}
    end

    if self.addStockBtn:isVisible() and not selectedListing then
        local enabled = self:validateAddStockEntry()

        self.addStockEntry.enable = (not self.addListingList.accessing) and enabled
        local stockEntryColor = ((not enabled) and self.redEntryColor) or self.normalEntryColor
        self:applyElementColor(self.addStockEntry, stockEntryColor)

        self.addStockBtn.enable = enabled
        local stockBtnColor = (not enabled) and self.redEntryColor or self.normalEntryColor
        self:applyElementColor(self.addStockBtn, stockBtnColor)
    end

    self.blocker:setVisible(blocked)
    if blocked then
        local blockingMessage = getText("IGUI_STOREBEINGMANAGED")
        self.blocker:drawText(blockingMessage, self.width/2 - (getTextManager():MeasureStringX(UIFont.Medium, blockingMessage) / 2), (self.height / 3) - 5, 1,1,1,1, UIFont.Medium)
        local uiButtons = {self.no, self.assignComboBox, self.aBtnConnect, self.aBtnDel, self.aBtnCopy, self.loadButton, self.exportButton}
        for _,btn in pairs(uiButtons) do btn:bringToTop() end
    end

    if not blocked and not shouldSeeStorePresetOptions then self:drawCategoryTabs() end

    if self.dragStartRow and self.dragStartY and self.storeStockData then
        local my = self:getMouseY()
        local stockLocalY = self.dragStartY + self.storeStockData.y
        local heldLong = self.dragStartTime and (getTimeInMillis() - self.dragStartTime) > 200
        if math.abs(my - stockLocalY) > 8 and heldLong then
            local dragItem = self.storeStockData.items and self.storeStockData.items[self.dragStartRow]
            if dragItem then
                local font = UIFont.NewSmall
                local tm = getTextManager()
                local label = dragItem.text or ""
                local lw = tm:MeasureStringX(font, label)
                local lh = tm:getFontHeight(font)
                local gx = self:getMouseX() + 12
                local gy = my - lh / 2
                self:drawRect(gx, gy, lw + 8, lh + 4, 0.85, 0.15, 0.15, 0.15)
                self:drawRectBorder(gx, gy, lw + 8, lh + 4, 0.9, 1, 0.8, 0.2)
                self:drawText(label, gx + 4, gy + 2, 1, 0.8, 0.2, 1, font)
            end
        end
    end

    self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
end


function storeWindow:onMouseDown(x, y)
    local shouldSeeStorePresetOptions = (not self.storeObj) and _internal.isAdminHostDebug()
    local blocked = self.blocker and self.blocker:isVisible()
    if not blocked and not shouldSeeStorePresetOptions and self:onCategoryTabClick(x, y) then
        return true
    end
    return ISPanelJoypad.onMouseDown(self, x, y)
end


function storeWindow:onMouseWheel(del)
    if self.categoryTabY and self:getMouseY() >= self.categoryTabY
            and self:getMouseY() <= self.categoryTabY + self.categoryTabH then
        local maxScroll = math.max(0, (self.categoryTabsTotalWidth or 0) - self.storeStockData.width)
        self.categoryTabScroll = math.max(0, math.min(maxScroll, (self.categoryTabScroll or 0) - del * 30))
        return true
    end
    return ISPanelJoypad.onMouseWheel(self, del)
end


function storeWindow:onClick(button)

    self:resetActivity()

    local x, y, z, worldObjName = self.worldObject:getX(), self.worldObject:getY(), self.worldObject:getZ(), _internal.getWorldObjectName(self.worldObject)

    if button.internal == "CONNECT_TO_STORE" or button.internal == "COPY_STORE" or button.internal == "DELETE_STORE_PRESET" then

        local currentAssignSelection = self.assignComboBox:getOptionData(self.assignComboBox.selected)

        if button.internal == "COPY_STORE" and self.assignComboBox.selected==1 then
            sendClientCommand("shop", "assignStore", { x=x, y=y, z=z, worldObjName=worldObjName })
        else
            if self.assignComboBox.selected~=1 then
                if button.internal == "COPY_STORE" then
                    sendClientCommand("shop", "copyStorePreset", { storeID=currentAssignSelection, x=x, y=y, z=z, worldObjName=worldObjName })

                elseif button.internal == "DELETE_STORE_PRESET" then
                    sendClientCommand("shop", "deleteStorePreset", { storeID=currentAssignSelection })

                elseif button.internal == "CONNECT_TO_STORE" then
                    sendClientCommand("shop", "connectStorePreset", { storeID=currentAssignSelection, x=x, y=y, z=z, worldObjName=worldObjName })

                end
            end
        end

        self.repop = 2
    end

    if button.internal == "CLEAR_STORE" and self.storeObj and self:isBeingManaged() then
        --local tempWorldObj = self.worldObject
        --local playerOwnedStore = self.storeObj and self.storeObj.ownerID
        sendClientCommand(self.player, "shop", "clearStoreFromWorldObj", { storeID=self.storeObj.ID, x=x, y=y, z=z, worldObjName=worldObjName })
    end

    if button.internal == "MANAGE" then
        local newName
        local restockHrs
        local store = self.storeObj
        if store then
            if self:isBeingManaged() then
                self:commitActiveListing()
                self:flushDirtyListings()
                store.isBeingManaged = false
                newName = self.manageStoreName:getInternalText() or "no name set"
                if not self.storeObj.ownerID then
                    restockHrs = tonumber(self.restockHours:getInternalText()) or 1
                    restockHrs = math.max(1,restockHrs)
                end
                self.storeObj.name = newName
            else
                self.manageStoreName:setText(store.name)
                store.isBeingManaged = true
                self.dirtyListingIDs = {}
            end
            if self.worldObject then self.worldObject:transmitModData() end
            sendClientCommand("shop", "setStoreIsBeingManaged", {isBeingManaged=store.isBeingManaged, storeID=store.ID, storeName=newName, restockHrs=restockHrs, listingOrder=self.listingOrder})

            if self.storeObj and self.storeObj.ownerID and self.storeObj.cash then self.restockHours:setText(tostring(self.storeObj.cash)) end
        end
    end

    if button.internal == "ADDSTOCK" then
        local store = self.storeObj
        if not store then return end
        if not self:isBeingManaged() then return end
        if not self.addStockBtn.enable then return end

        local newEntry = self.addStockEntry:getInternalText()
        if not newEntry or newEntry=="" then return end

        local movable = string.find(newEntry, "Moveables.")

        local matches, matchesToType = findMatchesFromItemDictionary(newEntry, self.addStockSearchPartition:getOptionData(self.addStockSearchPartition.selected))
        if not matches then return end

        if isValidItemDictionaryCategory(newEntry) then
            newEntry = "category:"..newEntry
        else
            local scriptType = matchesToType[newEntry]
            if (not movable) and (not scriptType) then return end

            local script = scriptType and getScriptManager():getItem(scriptType)
            if script then newEntry = script:getFullName() end
        end

        self.listingInputEntered(self.listingInput)

        local listingSelected = self.selectedListing
        local listingID = listingSelected and listingSelected.id

        if listingSelected and not listingID then
            print("[Shop] ADDSTOCK aborted: selectedListing has no id")
            self.selectedListing = nil
            self.addListingList:clear()
            self.addStockEntry:setText("")
            return
        end

        local price = listingSelected and listingSelected.price or 0
        if price then
            if SandboxVars.ShopsAndTraders.ShopItemPriceLimit and SandboxVars.ShopsAndTraders.ShopItemPriceLimit > 0 and price > SandboxVars.ShopsAndTraders.ShopItemPriceLimit then
                price = SandboxVars.ShopsAndTraders.ShopItemPriceLimit
            end
        end

        local stock = listingSelected and listingSelected.stock or 0
        local buybackRate = listingSelected and listingSelected.buybackRate or 0
        local alwaysShow = listingSelected and (listingSelected.alwaysShow ~= nil and listingSelected.alwaysShow) or false
        local reselling = listingSelected and (listingSelected.reselling ~= nil and listingSelected.reselling) or false
        local fields = listingSelected and listingSelected.fields or itemFields.gatherFields(newEntry, true)
        local buyConditions = listingSelected and listingSelected.buyConditions or false

        sendClientCommand("shop", "listNewItem", {
            isBeingManaged=store.isBeingManaged,
            alwaysShow = alwaysShow,
            item=newEntry,
            price=price,
            fields=fields,
            buyConditions=buyConditions,
            listingID=listingID,
            stock=stock,
            buybackRate=buybackRate,
            reselling=reselling,
            storeID=store.ID, x=x, y=y, z=z, worldObjName=worldObjName })

        self.selectedListing = nil
        self.addListingList:clear()
        self.addStockEntry:setText("")
    end

    if button.internal == "CANCEL" then
        self:closeStoreWindow()
    end

    if button.internal == "PURCHASE" then self:finalizeDeal() end


    if button.internal == "EXPORT_TO_LOCAL" then
        if isClient() then
            sendClientCommand(self.player, "shop", "ExportStores", {})
        else
            local jsonStr = _internal.jsonEncode(GLOBAL_STORES)
            local writer = getFileWriter("shopsAndTradersData.json", true, false)
            if writer then
                writer:write(jsonStr)
                writer:close()
                print("[Shop] Exported stores to local shopsAndTradersData.json")
            end
        end
    end

    if button.internal == "LOAD_FROM_FILE" then
        local jsonStr = storeWindow.readImportFile("shopsAndTradersData.json")
        local txtStr = (not jsonStr or jsonStr == "") and storeWindow.readImportFile("exportedShops.txt")

        if (not jsonStr or jsonStr == "") and (not txtStr or txtStr == "") then
            print("[Shop] Load failed: shopsAndTradersData.json not found in Lua cache.")
            return
        end

        local tbl, err
        if jsonStr and jsonStr ~= "" then
            tbl, err = _internal.jsonDecode(jsonStr)
        elseif txtStr and txtStr ~= "" then
            tbl, err = _internal.stringToTable(txtStr)
            if tbl then
                local jsonWriter = getFileWriter("shopsAndTradersData.json", true, false)
                jsonWriter:write(_internal.jsonEncode(tbl))
                jsonWriter:close()
                print("[Shop] Converted exportedShops.txt to shopsAndTradersData.json")
            end
        end

        if err or (not tbl) or (type(tbl)~="table") then
            print("[Shop] Load failed: "..(err or "unknown error"))
            return
        end

        sendClientCommand(self.player,"shop", "ImportStores", {stores=tbl, close=true})
        print("[Shop] Loaded shops from file.")
        self.repop = 2
    end
end


function storeWindow:finalizeDeal()
    if not self.storeObj then return end
    local itemToPurchase = {}
    local itemsToSell = {}

    local worldObjSquare = self.worldObject and self.worldObject:getSquare()
    if (SandboxVars.ShopsAndTraders.ShopsRequirePower == true) and worldObjSquare then
        if (not worldObjSquare:haveElectricity()) and (not getWorld():isHydroPowerOn()) then
            return
        end
    end

    local walletID = getOrSetWalletID(self.player)
    if not walletID then print("ERROR: finalizeDeal: No Wallet ID for "..self.player:getUsername()..", aborting.") return end

    local purchaseTotal = self:getPurchaseTotal()
    local moneyItemValueUsed = 0

    local worldObjectCont = self.worldObject and self.worldObject:getContainer()

    local counts = {}
    for i,v in ipairs(self.yourCartData.items) do

        local _item = v.item

        if type(_item) == "string" then
            if self.storeObj.ownerID then
                local listing = self.storeObj.listings[v.item]
                local storeStock = self:getItemTypesInStoreContainer(listing)
                if storeStock and storeStock:size() > 0 then
                    counts[_item] = (counts[_item] or -1) + 1
                    local item = storeStock:get(counts[_item])
                    if item then
                        local action = ISInventoryTransferAction:new(self.player, item, worldObjectCont, self.player:getInventory(), 0)
                        action.stopOnWalk = false
                        action.stopOnRun = false
                        action.stopOnAim = false
                        action.shopTransaction=true
                        ISTimedActionQueue.add(action)
                    end
                end
            end
            table.insert(itemToPurchase, _item)
        else
            local itemType, _, _ = self:rtrnTypeIfValid(v.itemType or v.item)
            if itemType then
                local removeItem, isMoney = false, false
                if _internal.isMoneyType(itemType) then
                    local moneyAmount = v.item:getModData().value

                    moneyItemValueUsed = moneyItemValueUsed+moneyAmount
                    removeItem = true
                    isMoney = true
                    --[[
                    if purchaseTotal > 0 then
                        local remainder = math.max(0, moneyAmount-purchaseTotal)
                        local moneyNeeded = math.min(purchaseTotal, moneyAmount)

                        moneyItemValueUsed = moneyItemValueUsed+moneyNeeded
                        purchaseTotal = purchaseTotal-moneyNeeded

                        if remainder <= 0 then
                            removeItem = true
                            isMoney = true
                        else
                            _internal.generateMoneyValue(v.item, remainder, true)
                        end
                    end
                    --]]
                else
                    removeItem = true
                    local fields = itemFields.gatherFields(v.item, true)
                    local buyCheckFields = itemFields.gatherFields(v.item, false)
                    table.insert(itemsToSell, {itemType=itemType,fields=fields,buyCheckFields=buyCheckFields})
                end

                ---@type IsoPlayer|IsoGameCharacter|IsoMovingObject|IsoObject
                if removeItem then
                    if (not isMoney) and self.storeObj.ownerID then
                        if worldObjectCont then

                            if self.player:isEquipped(v.item) then ISTimedActionQueue.add(ISUnequipAction:new(self.player, v.item, 1)) end

                            local action = ISInventoryTransferAction:new(self.player, v.item, v.item:getContainer(), worldObjectCont, 0)
                            action.stopOnWalk = false
                            action.stopOnRun = false
                            action.stopOnAim = false
                            action.shopTransaction=true
                            ISTimedActionQueue.add(action)
                        end
                    else
                        local container = v.item:getContainer()
                        if container then
                            if isClient() and (v.item:getOutermostContainer() and not instanceof(v.item:getOutermostContainer():getParent(), "IsoPlayer")) and (v.item:getContainer():getType()~="floor") then
                                container:removeItemOnServer(v.item)
                            end
                            container:DoRemoveItem(v.item)
                        end
                    end
                end

            end
        end
    end
    self.yourCartData:clear()
    sendClientCommand(self.player,"shop", "processOrder", { playerID=walletID, storeID=self.storeObj.ID, buying=itemToPurchase, selling=itemsToSell, money=moneyItemValueUsed })
end


function storeWindow:RestoreLayout(name, layout) ISLayoutManager.DefaultRestoreWindow(self, layout) end
function storeWindow:SaveLayout(name, layout) ISLayoutManager.DefaultSaveWindow(self, layout) end

function storeWindow:new(player, storeObj, worldObj)
    local o = {}

    local sW = getCore():getScreenWidth()
    local sH = getCore():getScreenHeight()

    local width = sW * 0.3
    local height = sH * 0.5

    local x = sW / 2 - (width / 2)
    local y = sH / 2 - (height / 2)
    o = ISPanelJoypad:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    player:StopAllActionQueue()
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
    o.backgroundColor = {r=0, g=0, b=0, a=0.8}
    o.listHeaderColor = {r=0.4, g=0.4, b=0.4, a=0.3}
    o.width = width
    o.height = height
    o.player = player

    local tm = getTextManager()
    local needs_power_message = getText("IGUI_SHOP_NEEDS_POWER")
    local npm_x = tm:MeasureStringX(UIFont.Medium, needs_power_message)
    local npm_y = tm:MeasureStringY(UIFont.Medium, needs_power_message)
    o.needs_power_message = {text=needs_power_message, x=npm_x, y=npm_y}

    if isClient() and worldObj then
        local worldObjModData = worldObj:getModData()
        worldObjModData.shopsAndTradersShoppers = worldObjModData.shopsAndTradersShoppers or {}
        table.insert(worldObjModData.shopsAndTradersShoppers, player:getUsername())
        worldObj:transmitModData()
    end

    o.worldObject = worldObj
    o.storeObj = storeObj
    o.moveWithMouse = true
    o.selectedItem = nil
    o.pendingRequest = false
    storeWindow.instance = o

    return o
end


storeWindow.activityTimeOut = false
function storeWindow:resetActivity()
    if SandboxVars.ShopsAndTraders.ActivityTimeOut and SandboxVars.ShopsAndTraders.ActivityTimeOut > 0 then
        self.activityTimeOut = getTimeInMillis()+(SandboxVars.ShopsAndTraders.ActivityTimeOut*1000)
    end
end

function storeWindow:onMouseUp(x, y)
    self:resetActivity()
    ISPanelJoypad.onMouseUp(self)
end


function storeWindow:closeStoreWindow()
    if isClient() and self.worldObject and self.player then
        local worldObjModData = self.worldObject:getModData()
        worldObjModData.shopsAndTradersShoppers = worldObjModData.shopsAndTradersShoppers or {}

        local needUpdate = false
        local pU = self.player:getUsername()
        for n,username in pairs(worldObjModData.shopsAndTradersShoppers) do
            if username == pU then
                needUpdate = true
                worldObjModData.shopsAndTradersShoppers[n] = nil
            end
        end
        if needUpdate then self.worldObject:transmitModData() end
    end

    if self.addListingList then
        self.addListingList:setVisible(false)
        self.addListingList:removeFromUIManager()
    end

    self:setVisible(false)
    self:removeFromUIManager()
end

function storeWindow.checkMaxShopperCapacity(storeObj, worldObj, player)
    if not worldObj then return true end
    if _internal.canManageStore(storeObj,player) then return true end

    if SandboxVars.ShopsAndTraders.MaxUsers and SandboxVars.ShopsAndTraders.MaxUsers > 0 then
        local worldObjModData = worldObj:getModData()
        worldObjModData.shopsAndTradersShoppers = worldObjModData.shopsAndTradersShoppers or {}
        local needUpdate = false
        for n,username in pairs(worldObjModData.shopsAndTradersShoppers) do
            local uP = getPlayerFromUsername(username)
            local closeEnough = uP and ((math.abs(uP:getX()-worldObj:getX())<=2) or (math.abs(uP:getY()-worldObj:getY())<=2))
            if (not uP) or (not closeEnough) then
                needUpdate = true
                worldObjModData.shopsAndTradersShoppers[n] = nil
            end
        end
        if needUpdate then worldObj:transmitModData() end

        if #worldObjModData.shopsAndTradersShoppers >= SandboxVars.ShopsAndTraders.MaxUsers then return false end
    end
    return true
end


---@param worldObj IsoObject
function storeWindow:onBrowse(storeObj, worldObj, shopper, ignoreCapacityCheck)
    if storeWindow.instance and storeWindow.instance:isVisible() then storeWindow.instance:closeStoreWindow() end

    shopper = shopper or getPlayer()

    if (shopper:getSquare():isBlockedTo(worldObj:getSquare())) or (math.abs(shopper:getX()-worldObj:getX())>2) or (math.abs(shopper:getY()-worldObj:getY())>2) then return end

    getOrSetWalletID(shopper)

    if isClient() and (not ignoreCapacityCheck) and (not storeWindow.checkMaxShopperCapacity(storeObj, worldObj, shopper)) then return end

    local itemDictionary = getItemDictionary()
    itemDictionary.assemble()

    local ui = storeWindow:new(shopper, storeObj, worldObj)
    ui:initialise()
    ui:addToUIManager()

    if SandboxVars.ShopsAndTraders.ActivityTimeOut and SandboxVars.ShopsAndTraders.ActivityTimeOut > 0 then
        ui.activityTimeOut = getTimeInMillis()+(SandboxVars.ShopsAndTraders.ActivityTimeOut*1000)
    end
end


if getActivatedMods():contains("\\ChuckleberryFinnAlertSystem") then
else print("WARNING: Highly recommended to install `ChuckleberryFinnAlertSystem` (Workshop ID: `3077900375`) for latest news and updates.") end