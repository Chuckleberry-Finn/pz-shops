require "ISUI/ISPanelJoypad"
require "shop-globalModDataClient"
require "shop-wallet"
require "luautils"
require "shop-itemLookup"
require "shop-shared"

---@class storeWindow : ISPanel
storeWindow = ISPanelJoypad:derive("storeWindow")
storeWindow.messages = {}
storeWindow.CoolDownMessage = 300
storeWindow.MaxItems = 20


function storeWindow:onCartItemSelected()
    local row = self.yourCartData:rowAt(self.yourCartData:getMouseX(), self.yourCartData:getMouseY())
    if row ~= self.yourCartData.selected then return end
    self.yourCartData:removeItemByIndex(self.yourCartData.selected)
end


function storeWindow:storeItemRowAt(y)
    local y0 = 0
    local listings = self.storeObj.listings
    for i,v in ipairs(self.storeStockData.items) do
        if not v.height then v.height = self.storeStockData.itemheight end

        local listing = listings[v.item]

        local texture, script, validCategory
        if type(v.item) == "string" then
            script = getScriptManager():getItem(v.item)
            if script then texture = script:getNormalTexture()
            else validCategory = findMatchesFromCategories(v.item:gsub("category:",""))
            end
        else
            texture = v.item:getTex()
        end

        local showListing = ((listing.stock ~= 0 or listing.reselling==true) and (listing.available ~= 0) and (texture or #validCategory>0))
        if listing.alwaysShow==true then showListing = true end
        local managing = (self:isBeingManaged() and (isAdmin() or isCoopHost() or getDebug()))

        if showListing or managing then
            if y >= y0 and y < y0 + v.height then return i end
            y0 = y0 + v.height
        end
    end
    return -1
end


function storeWindow:onStoreItemSelected()
    local row = self:storeItemRowAt(self.storeStockData:getMouseY())
    if not self.storeStockData.items[row] then return end
    local item = self.storeStockData.items[row].item

    if self:isBeingManaged() then
        self.storeStockData:removeItemByIndex(self.storeStockData.selected)
        sendClientCommand("shop", "removeListing", { item=item, storeID=self.storeObj.ID })
        return
    end

    if #self.yourCartData.items >= storeWindow.MaxItems then return end
    local inCart = 0
    for k,v in pairs(self.yourCartData.items) do if v.item == item then inCart = inCart+1 end end

    if self.storeObj and ((self.storeObj.listings[item].available >= inCart+1) or (self.storeObj.listings[item].available == -1)) then
        local script = getScriptManager():getItem(item)
        local scriptName = script:getDisplayName()
        self.yourCartData:addItem(scriptName, item)
    end
end


function storeWindow:addItemEntryChange()
    local s = storeWindow.instance
    if not s then return end
    local matches

    if s.categorySet.selected[1] == true then
        matches = findMatchesFromCategories(s.addStockEntry:getInternalText())
    else
        matches = findMatchesFromItemDictionary(s.addStockEntry:getInternalText())
    end

    if matches then
        local text
        for _,type in pairs(matches) do text = (text or "")..type.."\n" end
        if text then self.tooltip = text return end
    end
    self.tooltip = nil
end


function storeWindow:initialise()
    ISPanelJoypad.initialise(self)
    local btnWid = 100
    local btnHgt = 25
    local padBottom = 10
    local listWidh = (self.width / 2)-15
    local listHeight = (self.height*0.6)

    local storeName = "new store"
    if self.storeObj then storeName = self.storeObj.name end

    self.manageStoreName = ISTextEntryBox:new(storeName, 10, 10, self.width-20, btnHgt)
    self.manageStoreName:initialise()
    self.manageStoreName:instantiate()
    self.manageStoreName.font = UIFont.Medium
    self.manageStoreName.borderColor = { r = 1, g = 0, b = 0, a = 0.7 }
    self:addChild(self.manageStoreName)

    self.yourCartData = ISScrollingListBox:new(10, 80, listWidh, listHeight)
    self.yourCartData:initialise()
    self.yourCartData:instantiate()
    self.yourCartData:setOnMouseDownFunction(self, self.onCartItemSelected)
    self.yourCartData.itemheight = 30
    self.yourCartData.selected = 0
    self.yourCartData.joypadParent = self
    self.yourCartData.font = UIFont.NewSmall
    self.yourCartData.doDrawItem = self.drawCart
    self.yourCartData.onMouseUp = self.yourOfferMouseUp
    self.yourCartData.drawBorder = true
    self:addChild(self.yourCartData)

    self.storeStockData = ISScrollingListBox:new(self.width-listWidh-10, self.yourCartData.y, listWidh, listHeight)
    self.storeStockData:initialise()
    self.storeStockData:instantiate()
    self.storeStockData:setOnMouseDownFunction(self, self.onStoreItemSelected)
    self.storeStockData.itemheight = 30
    self.storeStockData.selected = 0
    self.storeStockData.joypadParent = self
    self.storeStockData.font = UIFont.NewSmall
    self.storeStockData.doDrawItem = self.drawStock
    self.storeStockData.drawBorder = true
    self:addChild(self.storeStockData)

    self:displayStoreStock()

    local manageStockButtonsX = (self.storeStockData.x+self.storeStockData.width)
    local manageStockButtonsY = self.storeStockData.y+self.storeStockData.height
    self.addStockBtn = ISButton:new(manageStockButtonsX-22, manageStockButtonsY+5, btnHgt-3, btnHgt-3, "+", self, storeWindow.onClick)
    self.addStockBtn.internal = "ADDSTOCK"
    self.addStockBtn:initialise()
    self.addStockBtn:instantiate()
    self:addChild(self.addStockBtn)

    self.addStockEntry = ISTextEntryBox:new("", self.storeStockData.x, self.addStockBtn.y, self.storeStockData.width-self.addStockBtn.width-3, self.addStockBtn.height)
    self.addStockEntry.font = UIFont.Medium
    self.addStockEntry:initialise()
    self.addStockEntry:instantiate()
    self.addStockEntry.onTextChange = storeWindow.addItemEntryChange
    self:addChild(self.addStockEntry)

    self.addStockPrice = ISTextEntryBox:new("0", self.addStockEntry.x+10, self.addStockEntry.y+self.addStockEntry.height+3, 30, self.addStockBtn.height)
    self.addStockPrice.font = UIFont.Small
    self.addStockPrice.tooltip = getText("IGUI_CURRENCY_TOOLTIP")
    self.addStockPrice:initialise()
    self.addStockPrice:instantiate()
    self:addChild(self.addStockPrice)

    self.addStockQuantity = ISTextEntryBox:new("0", self.addStockPrice.x+self.addStockPrice.width+20, self.addStockPrice.y, 30, self.addStockBtn.height)
    self.addStockQuantity.font = UIFont.Small
    self.addStockQuantity.tooltip = getText("IGUI_STOCK_TOOLTIP")
    self.addStockQuantity:initialise()
    self.addStockQuantity:instantiate()
    self:addChild(self.addStockQuantity)

    self.addStockBuyBackRate = ISTextEntryBox:new("0", self.addStockQuantity.x+self.addStockQuantity.width+20, self.addStockQuantity.y, 30, self.addStockBtn.height)
    self.addStockBuyBackRate.font = UIFont.Small
    self.addStockBuyBackRate.tooltip = getText("IGUI_RATE_TOOLTIP")
    self.addStockBuyBackRate:initialise()
    self.addStockBuyBackRate:instantiate()
    self:addChild(self.addStockBuyBackRate)

    self.categorySet = ISTickBox:new(self.addStockBuyBackRate.x+self.addStockBuyBackRate.width+10, self.addStockBuyBackRate.y, 18, 18, "", self, nil)
    self.categorySet.textColor = { r = 1, g = 0, b = 0, a = 0.7 }
    self.categorySet.tooltip = getText("IGUI_STOCKCATEGORY_TOOLTIP")
    self.categorySet:initialise()
    self.categorySet:instantiate()
    self.categorySet.selected[1] = false
    self.categorySet:addOption(getText("IGUI_STOCKCATEGORY"))
    self:addChild(self.categorySet)

    self.resell = ISTickBox:new(self.addStockBuyBackRate.x+self.addStockBuyBackRate.width+10, self.categorySet.y+self.categorySet.height+2, 18, 18, "", self, nil)
    self.resell.textColor = { r = 1, g = 0, b = 0, a = 0.7 }
    self.resell.tooltip = getText("IGUI_IGUI_RESELL_TOOLTIP")
    self.resell:initialise()
    self.resell:instantiate()
    self.resell.selected[1] = SandboxVars.ShopsAndTraders.TradersResellItems
    self.resell:addOption(getText("IGUI_RESELL"))
    self:addChild(self.resell)

    self.alwaysShow = ISTickBox:new(self.addStockBuyBackRate.x+self.addStockBuyBackRate.width+10, self.resell.y+self.resell.height+2, 18, 18, "", self, nil)
    self.alwaysShow.textColor = { r = 1, g = 0, b = 0, a = 0.7 }
    self.alwaysShow.tooltip = getText("IGUI_ALWAYSSHOW_TOOLTIP")
    self.alwaysShow:initialise()
    self.alwaysShow:instantiate()
    self.alwaysShow.selected[1] = false
    self.alwaysShow:addOption(getText("IGUI_ALWAYSSHOW"))
    self:addChild(self.alwaysShow)

    self.purchase = ISButton:new(self.storeStockData.x + self.storeStockData.width - (math.max(btnWid, getTextManager():MeasureStringX(UIFont.Small, getText("IGUI_PURCHASE")) + 10)), self:getHeight() - padBottom - btnHgt, btnWid, btnHgt - 3, getText("IGUI_PURCHASE"), self, storeWindow.onClick)
    self.purchase.internal = "PURCHASE"
    self.purchase.borderColor = {r=1, g=1, b=1, a=0.4}
    self.purchase:initialise()
    self.purchase:instantiate()
    self:addChild(self.purchase)

    self.manageBtn = ISButton:new((self.width/2)-45, 70-btnHgt, 70, 25, getText("IGUI_MANAGESTORE"), self, storeWindow.onClick)
    self.manageBtn.internal = "MANAGE"
    self.manageBtn:initialise()
    self.manageBtn:instantiate()
    self:addChild(self.manageBtn)

    local restockHours = ""
    if self.storeObj then restockHours = tostring(self.storeObj.restockHrs) end
    self.restockHours = ISTextEntryBox:new(restockHours, self.width-60, 70-btnHgt, 50, self.addStockBtn.height)
    self.restockHours.font = UIFont.Medium
    self.restockHours.borderColor = { r = 1, g = 0, b = 0, a = 0.7 }
    self.restockHours:initialise()
    self.restockHours:instantiate()
    self:addChild(self.restockHours)

    self.clearStore = ISButton:new(self.manageBtn.x+self.manageBtn.width+4, self.manageBtn.y+6, 10, 14, "X", self, storeWindow.onClick)
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
    self.blocker:initialise()
    self.blocker:instantiate()
    self.blocker:drawRect(0, 0, self.blocker.width, self.blocker.height, 0.8, 0, 0, 0)
    local blockingMessage = getText("IGUI_STOREBEINGMANAGED")
    self.blocker:drawText(blockingMessage, self.width/2 - (getTextManager():MeasureStringX(UIFont.Medium, blockingMessage) / 2), (self.height / 3) - 5, 1,1,1,1, UIFont.Medium)
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


    self.importBtn = ISButton:new(self.aBtnDel.x, acb.y-29, self.aBtnDel.width, 25, getText("IGUI_IMPORT"), self, storeWindow.onClick)
    self.importBtn.internal = "IMPORT_EXPORT_STORES"
    self.importBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.7 }
    self.importBtn.textColor = { r = 1, g = 1, b = 1, a = 0.7 }
    self.importBtn.toggled = false
    self.importBtn:initialise()
    self.importBtn:instantiate()
    self:addChild(self.importBtn)

    self.importCancel = ISButton:new(self.aBtnDel.x, self.aBtnDel.y, self.aBtnDel.width, 25, getText("UI_Cancel"), self, storeWindow.onClick)
    self.importCancel.font = UIFont.NewSmall
    self.importCancel.internal = "IMPORT_EXPORT_CANCEL"
    self.importCancel.borderColor = { r = 1, g = 1, b = 1, a = 0.7 }
    self.importCancel.textColor = { r = 1, g = 1, b = 1, a = 0.7 }
    self.importCancel:initialise()
    self.importCancel:instantiate()
    self:addChild(self.importCancel)

    local iTMargin = 4
    local importTextX = self.importBtn.x+self.importBtn.width+iTMargin
    self.importText = ISTextEntryBox:new("", importTextX, iTMargin, self:getWidth() - importTextX-iTMargin, self:getHeight()-(iTMargin*2))
    self.importText.backgroundColor = {r=0, g=0, b=0, a=0.8}
    self.importText:initialise()
    self.importText:instantiate()
    self.importText:setMultipleLine(true)
    self.importText.javaObject:setMaxLines(15)
    --self.entry.javaObject:setMaxTextLength(self.maxTextLength)
    self:addChild(self.importText)

end


function storeWindow:populateComboList()
    self.assignComboBox:clear()
    self.assignComboBox:addOptionWithData("BLANK", false)
    for ID,DATA in pairs(CLIENT_STORES) do self.assignComboBox:addOptionWithData(DATA.name, ID) end
    if (not self.assignComboBox.selected) or (self.assignComboBox.selected > #self.assignComboBox.options) then self.assignComboBox.selected = 1 end
end


function storeWindow:isBeingManaged()
    if self.storeObj and self.storeObj.isBeingManaged then return true end
    return false
end


function storeWindow:rtrnTypeIfValid(item)
    local itemType
    local itemCat
    if type(item) == "string" then
        local itemScript = getScriptManager():getItem(item)
        if itemScript then itemType = item end
    else
        if self.player and luautils.haveToBeTransfered(self.player, item) then return false, "IGUI_NOTRADE_OUTSIDEINV" end
        if (item:getCondition()/item:getConditionMax())<0.75 or item:isBroken() then return false, "IGUI_NOTRADE_DAMAGED" end
        itemType = item:getFullType()
        if (isMoneyType(itemType) and item:getModData().value) then return itemType end

        itemCat = item:getDisplayCategory()
    end

    local storeObj = self.storeObj
    if storeObj and itemType then

        local listing = storeObj.listings[itemType]
        if not listing and itemCat then listing = storeObj.listings["category:"..tostring(itemCat)] end
        if not listing then return false, "IGUI_NOTRADE_INVALIDTYPE" end
        if listing then
            if listing.buybackRate > 0 then return itemType, false, itemCat
            else return itemType, "IGUI_NOTRADE_ONLYSELL" end
        end

    end
    return false, nil
end


function storeWindow:drawCart(y, item, alt)
    local texture
    local itemType, reason, itemCat = self.parent:rtrnTypeIfValid(item.item)

    if type(item.item) == "string" then texture = getScriptManager():getItem(item.item):getNormalTexture()
    else texture = item.item:getTex() end

    local color = {r=1, g=1, b=1, a=0.9}
    local storeObj = self.parent.storeObj
    local noList = false
    if reason and type(item.item) ~= "string" then
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
        local listing = storeObj.listings[itemType] or storeObj.listings["category:"..tostring(itemCat)] or isMoneyType(itemType)
        if listing then
            if type(item.item) == "string" then balanceDiff = listing.price
            else
                if isMoneyType(itemType) then balanceDiff = 0-item.item:getModData().value
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


function storeWindow:drawStock(y, item, alt)
    local texture, script, validCategory
    if type(item.item) == "string" then
        script = getScriptManager():getItem(item.item)
        if script then texture = script:getNormalTexture()
        else validCategory = findMatchesFromCategories(item.item:gsub("category:",""))
        end
    else
        texture = item.item:getTex()
    end

    local color = {r=1, g=1, b=1, a=0.9}

    local storeObj = self.parent.storeObj
    if storeObj then
        local listing = storeObj.listings[item.item]
        if listing then

            local validCategoryLen = 0
            if type(validCategory)=="table" then validCategoryLen = #validCategory end

            local showListing = ((listing.stock ~= 0 or listing.reselling==true) and (listing.available ~= 0) and (texture or validCategoryLen>0))
            if listing.alwaysShow==true then showListing = true end
            local managing = (self.parent:isBeingManaged() and (isAdmin() or isCoopHost() or getDebug()))

            if showListing or managing then

                if not string.match(item.item, "category:") then
                    local inCart = 0
                    for k,v in pairs(self.parent.yourCartData.items) do if v.item == item.item then inCart = inCart+1 end end
                    local availableTemp = listing.available-inCart
                    if availableTemp == 0 then color = {r=0.7, g=0.7, b=0.7, a=0.3} end
                end

                local extra = ""
                if (not texture) or (not validCategoryLen>0) then extra = "\<!\> " end

                self:drawRectBorder(0, (y), self:getWidth(), self.itemheight - 1, 0.9, self.borderColor.r, self.borderColor.g, self.borderColor.b)
                if texture then self:drawTextureScaledAspect(texture, 5, y+3, 22, 22, color.a, color.r, color.g, color.b) end
                self:drawText(extra..item.text, 32, y+6, color.r, color.g, color.b, color.a, self.font)

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
    local scriptManager = getScriptManager()

    if not storeObj.listings then print("storeObj.listings: not found") return end
    if storeObj.listings and type(storeObj.listings)~="table" then
        print("storeObj.listings: not table: "..tostring(storeObj.listings))
        return
    end

    local managed = self:isBeingManaged() and (isAdmin() or isCoopHost() or getDebug())

    for _,listing in pairs(storeObj.listings) do

        local script = scriptManager:getItem(listing.item)
        local itemDisplayName = listing.item
        if script then itemDisplayName = script:getDisplayName() end

        local isCategoryListingAndIsValid = (string.match(listing.item, "category:") and findMatchesFromCategories(listing.item:gsub("category:","")))

        local price = _internal.numToCurrency(listing.price)
        if listing.price <= 0 then price = getText("IGUI_FREE") end

        local inCart = 0
        for k,v in pairs(self.yourCartData.items) do if v.item == listing.item then inCart = inCart+1 end end
        local availableTemp = listing.available-inCart

        local stockText = " ("..availableTemp.."/"..math.max(listing.available, listing.stock)..")"
        if listing.stock == -1 or string.match(listing.item, "category:") then stockText = "" end

        if string.match(itemDisplayName, "category:") then
            itemDisplayName = itemDisplayName:gsub("category:","")
            itemDisplayName = getTextOrNull("IGUI_ItemCat_"..itemDisplayName) or itemDisplayName
            if managed then itemDisplayName = "category: "..itemDisplayName end
        end

        local listedItem = self.storeStockData:addItem(price.."  "..itemDisplayName..stockText, listing.item)

        if managed then
            local tooltipText = ""
            if not string.match(listedItem.item, "category:") then
                tooltipText = tooltipText.." [restock x"..listing.stock.."]"
            end
            tooltipText = tooltipText.." [buyback "..listing.buybackRate.."%]"

            if not script and not isCategoryListingAndIsValid then tooltipText = "\<INVALID ITEM\> "..tooltipText end

            local resell = listing.reselling
            if resell~=SandboxVars.ShopsAndTraders.TradersResellItems then if resell then tooltipText = tooltipText.." [resell]" else tooltipText = tooltipText.." [no resell]" end end
            if tooltipText ~= "" then listedItem.tooltip = tooltipText end
        end
    end
end


function storeWindow:addItemToYourCart(item)
    local add = true
    for i,v in ipairs(self.yourCartData.items) do if v.item == item then add = false break end end
    if add then self.yourCartData:addItem(item:getName(), item) end
end


function storeWindow:yourOfferMouseUp(x, y)
    if self.vscroll then self.vscroll.scrolling = false end
    local counta = 1
    if ISMouseDrag.dragging then
        for i,v in ipairs(ISMouseDrag.dragging) do
            counta = 1
            if instanceof(v, "InventoryItem") then self.parent:addItemToYourCart(v)
            else
                if v.invPanel.collapsed[v.name] then
                    counta = 1
                    for i2,v2 in ipairs(v.items) do
                        if counta > 1 then self.parent:addItemToYourCart(v2) end
                        counta = counta + 1
                    end
                end
            end
        end
    end
end


function storeWindow:update()
    if not self.player or not self.mapObject or (math.abs(self.player:getX()-self.mapObject:getX())>2) or (math.abs(self.player:getY()-self.mapObject:getY())>2) then
        self:setVisible(false)
        self:removeFromUIManager()
        return
    end
end


function storeWindow:removeItem(item) self.yourCartData:removeItem(item.text) end


function storeWindow:validateElementColor(e)
    if not e then return end
    if e==self.addStockQuantity and self.categorySet.selected[1] == true then
        e.borderColor = { r = 0.3, g = 0.3, b = 0.3, a = 0.3 }
        e.textColor = { r = 0.3, g = 0.3, b = 0.3, a = 0.3 }
        return
    end

    if e.enable then
        if not self.addStockEntry.enable then
            e.borderColor = { r = 0.3, g = 0.3, b = 0.3, a = 0.3 }
            e.textColor = { r = 0.3, g = 0.3, b = 0.3, a = 0.3 }
        else
            e.borderColor = { r = 1, g = 1, b = 1, a = 0.8 }
            e.textColor = { r = 1, g = 1, b = 1, a = 0.8 }
        end
    else
        e.borderColor = { r = 1, g = 0, b = 0, a = 0.8 }
        e.textColor = { r = 1, g = 0, b = 0, a = 0.8 }
    end
end


function storeWindow:getOrderTotal()
    local totalForTransaction = 0
    for i,v in ipairs(self.yourCartData.items) do
        local itemType, _, itemCat = self:rtrnTypeIfValid(v.item)
        if itemType then
            if type(v.item) ~= "string" then
                if isMoneyType(itemType) then totalForTransaction = totalForTransaction-(v.item:getModData().value)
                else
                    local itemListing = self.storeObj.listings[itemType] or self.storeObj.listings["category:"..tostring(itemCat)]
                    if itemListing then totalForTransaction = totalForTransaction-(itemListing.price*(itemListing.buybackRate/100)) end
                end
            else
                local itemListing = self.storeObj.listings[v.item]
                if itemListing then totalForTransaction = totalForTransaction+itemListing.price end
            end
        end
    end
    return totalForTransaction
end


function storeWindow:displayOrderTotal()
    local x = self.yourCartData.x
    local y = self.yourCartData.y+self.yourCartData.height
    local w = self.yourCartData.width
    local fontH = getTextManager():MeasureFont(self.font)
    local h = fontH+(fontH/2)

    local balanceColor = { normal = {r=1, g=1, b=1, a=0.9}, red = {r=1, g=0.2, b=0.2, a=0.9}, green = {r=0.2, g=1, b=0.2, a=0.9} }
    self:drawRect(x, y+4, w, h, 0.9, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)

    local totalLine = getText("IGUI_TOTAL")..": "
    self:drawText(totalLine, x+10, y+(fontH/2), balanceColor.normal.r, balanceColor.normal.g, balanceColor.normal.b, balanceColor.normal.a, self.font)

    local totalForTransaction = self:getOrderTotal()
    local textForTotal = _internal.numToCurrency(math.abs(totalForTransaction))
    local tColor = balanceColor.normal
    if totalForTransaction < 0 then tColor, textForTotal = balanceColor.green, "+"..textForTotal
    elseif totalForTransaction > 0 then tColor, textForTotal = balanceColor.red, "-"..textForTotal
    else textForTotal = " "..textForTotal end
    local xOffset = getTextManager():MeasureStringX(self.font, textForTotal)+15
    self:drawText(textForTotal, w-xOffset+5, y+(fontH/2), tColor.r, tColor.g, tColor.b, tColor.a, self.font)
    self:drawRectBorder(x, y+4, w, h, 0.9, self.borderColor.r, self.borderColor.g, self.borderColor.b)

    self:drawRect(x, y+h+8, w, h, 0.9, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
    local walletBalance = getWalletBalance(self.player)
    local walletBalanceLine = getText("IGUI_WALLETBALANCE")..": ".._internal.numToCurrency(walletBalance)
    local bColor = balanceColor.normal
    if (walletBalance-totalForTransaction) < 0 then bColor = balanceColor.red end
    self:drawText(walletBalanceLine, x+10, y+h+4+(fontH/2), bColor.r, bColor.g, bColor.b, bColor.a, self.font)

    local walletBalanceAfter = walletBalance-totalForTransaction
    local sign = " "
    if walletBalanceAfter < 0 then sign = "-" end
    local wbaText = sign.._internal.numToCurrency(math.abs(walletBalanceAfter))
    local xOffset2 = getTextManager():MeasureStringX(self.font, wbaText)+15
    self:drawText(wbaText, w-xOffset2+5, y+h+4+(fontH/2), 0.7, 0.7, 0.7, 0.7, self.font)
    self:drawRectBorder(x, y+h+8, w, h, 0.9, self.borderColor.r, self.borderColor.g, self.borderColor.b)
end


function storeWindow:prerender()
    local z = 15
    local splitPoint = 100
    local x = 10
    self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)


    if not self:isBeingManaged() then
        local storeName = "No Name Set"
        if self.storeObj then storeName = self.storeObj.name end
        self:drawText(storeName, self.width/2 - (getTextManager():MeasureStringX(UIFont.Medium, storeName)/2), z, 1,1,1,1, UIFont.Medium)

        if self.storeObj then
            local restockingIn = tostring(self.storeObj.nextRestock)
            if restockingIn then self:drawTextRight(getText("IGUI_RESTOCK_HR", restockingIn), self.width-10, 10, 0.9,0.9,0.9,0.8, UIFont.NewSmall) end
        end

    else
        local cat = "category:"
        local catX = getTextManager():MeasureStringX(UIFont.Small, cat)+4

        if self.categorySet.selected[1] == true then
            local addStockEntryColor = self.addStockEntry.textColor
            self.addStockEntry:setX(self.storeStockData.x+catX)
            self.addStockEntry:setWidth(self.storeStockData.width-self.addStockBtn.width-3-catX)
            self:drawText(cat, self.storeStockData.x+1, self.addStockEntry.y-1, addStockEntryColor.r,addStockEntryColor.g,addStockEntryColor.b,addStockEntryColor.a, UIFont.Small)
        else
            self.addStockEntry:setX(self.storeStockData.x)
            self.addStockEntry:setWidth(self.storeStockData.width-self.addStockBtn.width-3)
        end

        self:validateElementColor(self.addStockPrice)
        local color = self.addStockPrice.textColor
        self:drawText(getText("IGUI_CURRENCY_PREFIX"), self.addStockPrice.x-12, self.addStockPrice.y, color.r,color.g,color.b,color.a, UIFont.Small)
        self:drawText(" "..getText("IGUI_CURRENCY_SUFFIX"), self.addStockPrice.x+self.addStockPrice.width+12, self.addStockPrice.y, color.r,color.g,color.b,color.a, UIFont.Small)

        self:validateElementColor(self.addStockQuantity)
        color = self.addStockQuantity.textColor
        self:drawText(getText("IGUI_STOCK"), self.addStockQuantity.x-12, self.addStockQuantity.y, color.r,color.g,color.b,color.a, UIFont.Small)

        self:validateElementColor(self.addStockBuyBackRate)
        color = self.addStockBuyBackRate.textColor
        self:drawText(getText("IGUI_RATE"), self.addStockBuyBackRate.x-14, self.addStockBuyBackRate.y, color.r,color.g,color.b,color.a, UIFont.Small)
    end


    self:drawText(getText("IGUI_YOURCART"), self.yourCartData.x+10, self.yourCartData.y - 32, 1,1,1,1, UIFont.Small)

    local yourItems = getText("IGUI_TradingUI_Items", #self.yourCartData.items, storeWindow.MaxItems)
    self:drawText(yourItems, self.yourCartData.x+10, self.yourCartData.y - 20, 1,1,1,1, UIFont.Small)

    local stockTextX = (self.storeStockData.x+(self.storeStockData.width/2))-(getTextManager():MeasureStringX(UIFont.Small, getText("IGUI_STORESTOCK"))/2)
    self:drawText(getText("IGUI_STORESTOCK"), stockTextX, self.storeStockData.y - 26, 1,1,1,1, UIFont.Small)

    z = z + 30
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
    self.categorySet.enable = false
    self.alwaysShow.enable = false
    self.resell.enable = false

    self.importText.enable = false
    self.importCancel.enable = false

    self.assignComboBox.enable = false
    self.aBtnCopy.enable = false
    self.aBtnConnect.enable = false
    self.aBtnConnect.borderColor = { r = 0.3, g = 0.3, b = 0.3, a = 0.7 }
    self.importBtn.enable = false
    self.importBtn.borderColor = { r = 0.3, g = 0.3, b = 0.3, a = 0.7 }
    self.aBtnDel.enable = false
    self.aBtnDel.borderColor = { r = 0.3, g = 0.3, b = 0.3, a = 0.7 }

    if not self.storeObj then
        if self.importBtn.toggled==true then
            self.importText.enabled = true
            self.importCancel.enable = true
        end
        self.assignComboBox.enable = true
        self.aBtnCopy.enable = true
        self.importBtn.enable = true
        self.importBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.7 }
        if self.assignComboBox.selected~=1 then
            self.aBtnConnect.enable = true
            self.aBtnConnect.borderColor = { r = 1, g = 1, b = 1, a = 0.7 }
            self.aBtnDel.enable = true
            self.aBtnDel.borderColor = { r = 1, g = 0, b = 0, a = 0.7 }
        end
        return
    end

    if (isAdmin() or isCoopHost() or getDebug()) then
        self.manageBtn.enable = true
        if self:isBeingManaged() then
            self.clearStore.enable = true
            self.addStockBtn.enable = true
            self.categorySet.enable = true
            self.alwaysShow.enable = true
            self.resell.enable = true
        end
    end
end


function storeWindow:validateAddStockEntry()
    local entryText = self.addStockEntry:getInternalText()
    if not entryText or entryText=="" then return false end
    local itemDict = getItemDictionary()
    if self.categorySet.selected[1] == true then if itemDict.categories[entryText] then return true end
    else if getScriptManager():getItem(entryText) then return true end
    end
    return false
end


function storeWindow:render()

    if self.mapObject and self.mapObject:getModData().storeObjID then self.storeObj = CLIENT_STORES[self.mapObject:getModData().storeObjID] end
    if self.storeObj and self.mapObject and not self.mapObject:getModData().storeObjID then self.storeObj = nil end

    self:updateButtons()
    self:updateTooltip()

    self:displayStoreStock()

    local managed = false
    if self:isBeingManaged() then
        managed = true
        self.manageBtn.textColor = { r = 1, g = 0, b = 0, a = 0.7 }
        self.manageBtn.borderColor = { r = 1, g = 0, b = 0, a = 0.7 }
        self.storeStockData.borderColor = { r = 1, g = 0, b = 0, a = 0.7 }
    else
        self.manageBtn.textColor = { r = 1, g = 1, b = 1, a = 0.4 }
        self.manageBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.4 }
        self.storeStockData.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 0.9}
    end

    local blocked = false
    if not (isAdmin() or isCoopHost() or getDebug()) then
        self.manageBtn:setVisible(false)
        if managed then blocked = true end
    end
    if not (self.storeObj) then
        self:populateComboList()
        blocked = true
    end

    local shouldSeeStorePresetOptions = (not self.storeObj) and (isAdmin() or isCoopHost() or getDebug())
    self.assignComboBox:setVisible(shouldSeeStorePresetOptions)
    self.aBtnConnect:setVisible(shouldSeeStorePresetOptions)
    self.aBtnDel:setVisible(shouldSeeStorePresetOptions)
    self.importBtn:setVisible(shouldSeeStorePresetOptions)
    self.aBtnCopy:setVisible(shouldSeeStorePresetOptions)

    self.importText:setVisible(shouldSeeStorePresetOptions and self.importBtn.toggled)
    self.importCancel:setVisible(shouldSeeStorePresetOptions and self.importBtn.toggled)

    if not (shouldSeeStorePresetOptions and self.importBtn.toggled) then self:displayOrderTotal() end

    self.addStockBtn:setVisible(managed and not blocked)
    self.manageStoreName:setVisible(managed and not blocked)
    self.addStockEntry:setVisible(managed and not blocked)
    self.addStockPrice:setVisible(managed and not blocked)
    self.addStockQuantity:setVisible(managed and not blocked)
    self.addStockBuyBackRate:setVisible(managed and not blocked)
    self.clearStore:setVisible(managed and not blocked)
    self.restockHours:setVisible(managed and not blocked)
    self.categorySet:setVisible(managed and not blocked)
    self.alwaysShow:setVisible(managed and not blocked)
    self.resell:setVisible(managed and not blocked)

    self.manageStoreName:isEditable(not blocked)
    self.addStockEntry:isEditable(not blocked)
    self.addStockPrice:isEditable(not blocked)
    self.addStockQuantity:isEditable(not blocked and (self.categorySet.selected[1] == false))
    self.addStockBuyBackRate:isEditable(not blocked)

    self.importText:isEditable(shouldSeeStorePresetOptions and self.importBtn.toggled)

    local purchaseValid = (getWalletBalance(self.player)-self:getOrderTotal()) >= 0
    self.purchase.enable = (not managed and not blocked and #self.yourCartData.items>0 and purchaseValid)
    local gb = 1
    if not purchaseValid then gb = 0 end
    self.purchase.textColor = { r = 1, g = gb, b = gb, a = 0.7 }
    self.purchase.borderColor = { r = 1, g = gb, b = gb, a = 0.7 }

    if self.addStockBtn:isVisible() then

        local elements = {self.addStockBtn, self.addStockEntry, self.addStockPrice, self.addStockQuantity, self.addStockBuyBackRate}

        self.addStockEntry.enable = self:validateAddStockEntry()

        self.addStockPrice.enable = (self.addStockPrice:getInternalText()=="" or tonumber(self.addStockPrice:getInternalText()))
        self.addStockQuantity.enable = (self.addStockQuantity:getInternalText()=="" or tonumber(self.addStockQuantity:getInternalText()))

        if self.categorySet.selected[1] == true then self.addStockQuantity:setText("") end

        local convertedBuyBackRate = tonumber(self.addStockBuyBackRate:getInternalText())
        self.addStockBuyBackRate.enable = (self.addStockBuyBackRate:getInternalText()=="" or (convertedBuyBackRate and (convertedBuyBackRate < 100 or convertedBuyBackRate > 0)))
        self.addStockBtn.enable = (self.addStockEntry.enable and self.addStockPrice.enable and (self.addStockQuantity.enable or self.categorySet.selected[1] == true) and self.addStockBuyBackRate.enable)

        for _,e in pairs(elements) do self:validateElementColor(e) end
    end

    self.blocker:setVisible(blocked)
    self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    self.no:bringToTop()
    self.assignComboBox:bringToTop()
    self.aBtnConnect:bringToTop()
    self.aBtnDel:bringToTop()
    self.aBtnCopy:bringToTop()

    self.importBtn:bringToTop()
    self.importCancel:bringToTop()
    self.importText:bringToTop()
end


function storeWindow:onClick(button)

    local x, y, z, mapObjName = self.mapObject:getX(), self.mapObject:getY(), self.mapObject:getZ(), _internal.getMapObjectName(self.mapObject)

    if button.internal == "CONNECT_TO_STORE" or button.internal == "COPY_STORE" or button.internal == "DELETE_STORE_PRESET" then

        local currentAssignSelection = self.assignComboBox:getOptionData(self.assignComboBox.selected)

        if button.internal == "COPY_STORE" and self.assignComboBox.selected==1 then
            sendClientCommand("shop", "assignStore", { x=x, y=y, z=z, mapObjName=mapObjName })
        else
            if self.assignComboBox.selected~=1 then
                if button.internal == "COPY_STORE" then
                    sendClientCommand("shop", "copyStorePreset", { storeID=currentAssignSelection, x=x, y=y, z=z, mapObjName=mapObjName })

                elseif button.internal == "DELETE_STORE_PRESET" then
                    sendClientCommand("shop", "deleteStorePreset", { storeID=currentAssignSelection })

                elseif button.internal == "CONNECT_TO_STORE" then
                    sendClientCommand("shop", "connectStorePreset", { storeID=currentAssignSelection, x=x, y=y, z=z, mapObjName=mapObjName })

                end
            end
        end
    end

    if button.internal == "CLEAR_STORE" and self.storeObj and self:isBeingManaged() then
        sendClientCommand("shop", "clearStoreFromMapObj", { storeID=self.storeObj.ID, x=x, y=y, z=z, mapObjName=mapObjName })
    end

    if button.internal == "MANAGE" then
        local newName
        local restockHrs
        local store = self.storeObj
        if store then
            if self:isBeingManaged() then
                store.isBeingManaged = false
                newName = self.manageStoreName:getInternalText()
                restockHrs = tonumber(self.restockHours:getInternalText())
                self.storeObj.name = newName
            else
                self.manageStoreName:setText(store.name)
                store.isBeingManaged = true
            end
            sendClientCommand("shop", "setStoreIsBeingManaged", {isBeingManaged=store.isBeingManaged, storeID=store.ID, storeName=newName, restockHrs=restockHrs})
        end
    end

    if button.internal == "ADDSTOCK" then
        local store = self.storeObj
        if not store then return end
        if not self:isBeingManaged() then return end
        if not self.addStockBtn.enable then return end

        if not self:validateAddStockEntry() then return end

        local newEntry = self.addStockEntry:getInternalText()
        if not newEntry then return end

        if self.categorySet.selected[1] == true then
            newEntry = "category:"..newEntry
        else
            local script = getScriptManager():getItem(newEntry)
            if script then newEntry = script:getFullName() end
        end

        local price = 0
        if self.addStockPrice.enable and self.addStockPrice:getInternalText() then price = tonumber(self.addStockPrice:getInternalText()) end

        local quantity = 0
        if self.addStockQuantity.enable and self.addStockQuantity:getInternalText() then quantity = tonumber(self.addStockQuantity:getInternalText()) end

        local buybackRate = 0
        if self.addStockBuyBackRate.enable and self.addStockBuyBackRate:getInternalText() then buybackRate = tonumber(self.addStockBuyBackRate:getInternalText()) end

        local reselling = self.resell.selected[1]

        sendClientCommand("shop", "listNewItem", { isBeingManaged=store.isBeingManaged, alwaysShow = (self.alwaysShow.selected[1] or false),
        item=newEntry, price=price, quantity=quantity, buybackRate=buybackRate, reselling=reselling, storeID=store.ID, x=x, y=y, z=z, mapObjName=mapObjName })
    end

    if button.internal == "CANCEL" then
        self:setVisible(false)
        self:removeFromUIManager()
    end

    if button.internal == "PURCHASE" then self:finalizeDeal() end


    if button.internal == "IMPORT_EXPORT_CANCEL" then
        self.importBtn:setTitle(getText("IGUI_IMPORT"))
        self.importBtn.toggled = false
    end


    if button.internal == "IMPORT_EXPORT_STORES" then

        if self.importBtn.toggled then
            self.importBtn.toggled = false
            self.importBtn:setTitle(getText("IGUI_IMPORT"))
            local tbl = _internal.stringToTable(self.importText:getText())

            if (not tbl) or (type(tbl)~="table") then
                print("ERROR: STORES MASS EXPORT FAILED.")
                return
            end

            sendClientCommand("shop", "ImportStores", {stores=tbl})
            --if getDebug() then print("FINAL:\n".._internal.tableToString(tbl)) end

        else

            self.importText:setText(_internal.tableToString(CLIENT_STORES))
            self.importBtn:setTitle(getText("IGUI_EXPORT"))
            self.importBtn.toggled = true
        end

    end
end


function storeWindow:finalizeDeal()
    if not self.storeObj then return end
    local itemToPurchase = {}
    local itemsToSell = {}

    for i,v in ipairs(self.yourCartData.items) do
        if type(v.item) == "string" then
            table.insert(itemToPurchase, v.item)
        else
            local itemType, _, _ = self:rtrnTypeIfValid(v.item)
            if itemType then
                if isMoneyType(itemType) then
                    local value = v.item:getModData().value
                    local pID = self.player:getModData().wallet_UUID
                    sendClientCommand("shop", "transferFunds", {giver=nil, give=value, receiver=pID, receive=nil})
                else
                    table.insert(itemsToSell, itemType)
                end
                ---@type IsoPlayer|IsoGameCharacter|IsoMovingObject|IsoObject
                self.player:getInventory():Remove(v.item)
            end
        end
    end

    local walletID = getOrSetWalletID(self.player)
    if not walletID then print("ERROR: finalizeDeal: No Wallet ID for "..self.player:getUsername()..", aborting.") return end
    self.yourCartData:clear()

    sendClientCommand(self.player,"shop", "processOrder", { playerID=walletID, storeID=self.storeObj.ID, buying=itemToPurchase, selling=itemsToSell })
end


function storeWindow:RestoreLayout(name, layout) ISLayoutManager.DefaultRestoreWindow(self, layout) end
function storeWindow:SaveLayout(name, layout) ISLayoutManager.DefaultSaveWindow(self, layout) end

function storeWindow:new(x, y, width, height, player, storeObj, mapObj)
    local o = {}
    x = getCore():getScreenWidth() / 2 - (width / 2)
    y = getCore():getScreenHeight() / 2 - (height / 2)
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
    o.mapObject = mapObj
    o.storeObj = storeObj
    o.moveWithMouse = true
    o.selectedItem = nil
    o.pendingRequest = false
    storeWindow.instance = o
    return o
end


function storeWindow:onBrowse(storeObj, mapObj)
    if storeWindow.instance and storeWindow.instance:isVisible() then
        storeWindow.instance:setVisible(false)
        storeWindow.instance:removeFromUIManager()
    end

    local itemDictionary = getItemDictionary()
    sendClientCommand("shop", "updateItemDictionary", { itemsToCategories=itemDictionary.itemsToCategories })

    triggerEvent("SHOPPING_ClientModDataReady")

    local ui = storeWindow:new(50,50,555,555, getPlayer(), storeObj, mapObj)
    ui:initialise()
    ui:addToUIManager()
end


