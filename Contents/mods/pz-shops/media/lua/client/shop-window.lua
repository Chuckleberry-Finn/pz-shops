require "ISUI/ISPanelJoypad"
require "shop-globalModDataClient"

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
        if (listings[v.item].available ~= 0) or self:isBeingManaged() then
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
        if not isClient() then self:refresh() end
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


function storeWindow:initialise()
    ISPanelJoypad.initialise(self)
    local btnWid = 100
    local btnHgt = 25
    local padBottom = 10
    local listWidh = (self.width / 2) - 15
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
    self.addStockEntry:initialise()
    self.addStockEntry:instantiate()
    self.addStockEntry.font = UIFont.Medium
    self:addChild(self.addStockEntry)

    self.addStockPrice = ISTextEntryBox:new("0", self.addStockEntry.x+10, self.addStockEntry.y+self.addStockEntry.height+3, 30, self.addStockBtn.height)
    self.addStockPrice.font = UIFont.Small
    self.addStockPrice:initialise()
    self.addStockPrice:instantiate()
    self:addChild(self.addStockPrice)

    self.addStockQuantity = ISTextEntryBox:new("0", self.addStockPrice.x+self.addStockPrice.width+20, self.addStockPrice.y, 30, self.addStockBtn.height)
    self.addStockQuantity.font = UIFont.Small
    self.addStockQuantity:initialise()
    self.addStockQuantity:instantiate()
    self:addChild(self.addStockQuantity)

    self.addStockBuyBackRate = ISTextEntryBox:new("0", self.addStockQuantity.x+self.addStockQuantity.width+20, self.addStockQuantity.y, 30, self.addStockBtn.height)
    self.addStockBuyBackRate.font = UIFont.Small
    self.addStockBuyBackRate:initialise()
    self.addStockBuyBackRate:instantiate()
    self:addChild(self.addStockBuyBackRate)

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

    self.assignComboBox = ISComboBox:new((self.width/2)-(acbWidth/2)+(delBtnW/4)+2, (self.height/2)-1, acbWidth, 22)--, nil, nil, nil, nil)
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
end


function storeWindow:populateComboList()
    self.assignComboBox:clear()
    self.assignComboBox:addOptionWithData("BLANK", false)
    for ID,DATA in pairs(CLIENT_STORES) do self.assignComboBox:addOptionWithData(DATA.name, ID) end
    self.assignComboBox.selected = 1
end

function storeWindow:isBeingManaged()
    if self.storeObj and self.storeObj.isBeingManaged then return true end
    return false
end


function storeWindow:drawCart(y, item, alt)
    local texture
    local itemType
    if type(item.item) == "string" then
        itemType = item.item
        local script = getScriptManager():getItem(item.item)
        texture = script:getNormalTexture()
    else
        itemType = item.item:getType()
        texture = item.item:getTex()
    end

    local color = {r=1, g=1, b=1, a=0.9}
    local storeObj = self.parent.storeObj

    if storeObj and not storeObj.listings[itemType] then color = {r=1, g=0, b=0, a=0.6} end

    self:drawRectBorder(0, (y), self:getWidth(), self.itemheight - 1, 0.9, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    self:drawTextureScaledAspect(texture, 5, y+3, 22, 22, color.a, color.r, color.g, color.b)
    self:drawText(item.text, 32, y+6, color.r, color.g, color.b, color.a, self.font)

    local balanceDiff = 0
    if storeObj and storeObj.listings[itemType] then
        if type(item.item) == "string" then balanceDiff = storeObj.listings[itemType].price
        else balanceDiff = 0-(storeObj.listings[itemType].price*(storeObj.listings[itemType].buybackRate/100)) end

        local balanceColor = {r=1, g=1, b=1, a=0.9}
        if balanceDiff > 0 then
            balanceDiff = "-"..getText("IGUI_CURRENCY")..tostring(balanceDiff)
            balanceColor = {r=1, g=0.2, b=0.2, a=0.9}

        elseif balanceDiff < 0 then
            balanceDiff = "+"..getText("IGUI_CURRENCY")..tostring(math.abs(balanceDiff))
            balanceColor = {r=0.2, g=1, b=0.2, a=0.9}
        else
            balanceDiff = " "..getText("IGUI_CURRENCY")..tostring(balanceDiff)
        end

        local costDiff_x = getTextManager():MeasureStringX(self.font,balanceDiff)+30
        self:drawText(balanceDiff, (self.x+self.width)-costDiff_x, y+6, balanceColor.r, balanceColor.g, balanceColor.b, balanceColor.a, self.font)
    end

    return y + self.itemheight
end


function storeWindow:drawStock(y, item, alt)
    local texture
    if type(item.item) == "string" then
        local script = getScriptManager():getItem(item.item)
        texture = script:getNormalTexture()
    else texture = item.item:getTex() end

    local color = {r=1, g=1, b=1, a=0.9}

    local storeObj = self.parent.storeObj
    if storeObj and storeObj.listings[item.item] then
        if (storeObj.listings[item.item].available ~= 0) or (self.parent:isBeingManaged() and (isAdmin() or isCoopHost() or getDebug())) then

            local inCart = 0
            for k,v in pairs(self.parent.yourCartData.items) do if v.item == item.item then inCart = inCart+1 end end
            local availableTemp = storeObj.listings[item.item].available-inCart
            if availableTemp == 0 then color = {r=0.7, g=0.7, b=0.7, a=0.3} end

            self:drawRectBorder(0, (y), self:getWidth(), self.itemheight - 1, 0.9, self.borderColor.r, self.borderColor.g, self.borderColor.b)

            self:drawTextureScaledAspect(texture, 5, y+3, 22, 22, color.a, color.r, color.g, color.b)

            local displayText = item.text
            if (self.parent:isBeingManaged() and (isAdmin() or isCoopHost() or getDebug())) then
                displayText = displayText.." [x"..storeObj.listings[item.item].stock.."]".." ["..storeObj.listings[item.item].buybackRate.."%]"
            end

            self:drawText(displayText, 32, y+6, color.r, color.g, color.b, color.a, self.font)

            return y + self.itemheight
        end
    end
    return y
end


function storeWindow:displayStoreStock()

    self.storeStockData:clear()

    local storeObj = self.storeObj
    if not storeObj then return end
    local scriptManager = getScriptManager()

    local currency = getText("IGUI_CURRENCY")

    for _,listing in pairs(storeObj.listings) do
        local script = scriptManager:getItem(listing.item)
        local scriptName = script:getDisplayName()

        local price = currency..listing.price
        if listing.price <= 0 then price = getText("IGUI_FREE") end

        local inCart = 0
        for k,v in pairs(self.yourCartData.items) do if v.item == listing.item then inCart = inCart+1 end end
        local availableTemp = listing.available-inCart

        local stock = " ("..availableTemp.."/"..math.max(listing.available, listing.stock)..")"
        if listing.stock == -1 then stock = "" end

        self.storeStockData:addItem(price.." "..scriptName..stock, listing.item)
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

    if not self.player or not self.mapObject or (math.abs(self.player:getX()-self.mapObject:getX())>2) or (math.abs(self.player:getY()-self.mapObject:getY())>2) then
        self:setVisible(false)
        self:removeFromUIManager()
        return
    end

    for i,v in ipairs(self.yourCartData.items) do
        if type(v.item) ~= "string" then
            if luautils.haveToBeTransfered(self.player, v.item) then
                self:removeItem(v)
                break
            end
            if self.storeObj and not self.storeObj.listings[v.item:getType()] then
                self:removeItem(v)
                break
            end
        end
    end
end


function storeWindow:removeItem(item) self.yourCartData:removeItem(item.text) end


function storeWindow:validateElementColor(e)
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
        e.textColor = { r = 1, g = 0, b = 0, a = 0.9 }
    end
end


function storeWindow:getOrderTotal()
    local totalForTransaction = 0
    for i,v in ipairs(self.yourCartData.items) do
        if type(v.item) ~= "string" then
            local itemListing = self.storeObj.listings[v.item:getType()]
            if itemListing then totalForTransaction = totalForTransaction-(itemListing.price*(itemListing.buybackRate/100)) end
        else
            local itemListing = self.storeObj.listings[v.item]
            if itemListing then totalForTransaction = totalForTransaction+itemListing.price end
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
    local textForTotal = tostring(math.abs(totalForTransaction))
    local tColor = balanceColor.normal
    textForTotal = getText("IGUI_CURRENCY")..textForTotal
    if totalForTransaction < 0 then tColor, textForTotal = balanceColor.green, "+"..textForTotal
    elseif totalForTransaction > 0 then tColor, textForTotal = balanceColor.red, "-"..textForTotal
    else textForTotal = " "..textForTotal end
    local xOffset = getTextManager():MeasureStringX(self.font, textForTotal)+15
    self:drawText(textForTotal, w-xOffset+5, y+(fontH/2), tColor.r, tColor.g, tColor.b, tColor.a, self.font)
    self:drawRectBorder(x, y+4, w, h, 0.9, self.borderColor.r, self.borderColor.g, self.borderColor.b)

    self:drawRect(x, y+h+8, w, h, 0.9, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
    local walletBalance = getWalletBalance(self.player)
    local walletBalanceLine = getText("IGUI_WALLETBALANCE")..": "..getText("IGUI_CURRENCY")..tostring(walletBalance)
    local bColor = balanceColor.normal
    if (walletBalance-totalForTransaction) < 0 then bColor = balanceColor.red end
    self:drawText(walletBalanceLine, x+10, y+h+4+(fontH/2), bColor.r, bColor.g, bColor.b, bColor.a, self.font)

    local walletBalanceAfter = walletBalance-totalForTransaction
    local sign = " "
    if walletBalanceAfter < 0 then sign = "-" end
    local wbaText = sign..getText("IGUI_CURRENCY")..tostring(math.abs(walletBalanceAfter))
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
            if restockingIn then self:drawTextRight(getText("IGUI_RESTOCK_HR", restockingIn), self.width-10, 10, 1,1,1,0.8, UIFont.NewSmall) end
        end

    else

        self:validateElementColor(self.addStockPrice)
        local color = self.addStockPrice.textColor
        self:drawText(getText("IGUI_CURRENCY"), self.addStockPrice.x-12, self.addStockPrice.y, color.r,color.g,color.b,color.a, UIFont.Small)

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

    self.assignComboBox.enable = false
    self.aBtnCopy.enable = false
    self.aBtnConnect.enable = false
    self.aBtnDel.enable = false

    if not self.storeObj then
        self.assignComboBox.enable = true
        self.aBtnCopy.enable = true
        if self.assignComboBox.selected~=1 then
            self.aBtnConnect.enable = true
            self.aBtnDel.enable = true
        end
        return
    end

    if (isAdmin() or isCoopHost() or getDebug()) then
        self.manageBtn.enable = true
        if self:isBeingManaged() then
            self.clearStore.enable = true
            --local newItem = self.addStockEntry:getInternalText()
            --if self.storeObj.listings[newItem] then return end
            self.addStockBtn.enable = true
        end
    end
end


function storeWindow:render()

    if self.mapObject and self.mapObject:getModData().storeObjID then self.storeObj = CLIENT_STORES[self.mapObject:getModData().storeObjID] end
    if self.storeObj and self.mapObject and not self.mapObject:getModData().storeObjID then self.storeObj = nil end

    self:updateButtons()
    self:updateTooltip()

    self:displayStoreStock()
    self:displayOrderTotal()

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
    if not (self.storeObj) then blocked = true end

    local shouldSeeStorePresetOptions = (not self.storeObj) and (isAdmin() or isCoopHost() or getDebug())
    self.assignComboBox:setVisible(shouldSeeStorePresetOptions)
    self.aBtnConnect:setVisible(shouldSeeStorePresetOptions)
    self.aBtnDel:setVisible(shouldSeeStorePresetOptions)
    self.aBtnCopy:setVisible(shouldSeeStorePresetOptions)

    self.addStockBtn:setVisible(managed and not blocked)
    self.manageStoreName:setVisible(managed and not blocked)
    self.addStockEntry:setVisible(managed and not blocked)
    self.addStockPrice:setVisible(managed and not blocked)
    self.addStockQuantity:setVisible(managed and not blocked)
    self.addStockBuyBackRate:setVisible(managed and not blocked)
    self.clearStore:setVisible(managed and not blocked)
    self.restockHours:setVisible(managed and not blocked)

    self.manageStoreName:isEditable(not blocked)
    self.addStockEntry:isEditable(not blocked)
    self.addStockPrice:isEditable(not blocked)
    self.addStockQuantity:isEditable(not blocked)
    self.addStockBuyBackRate:isEditable(not blocked)

    local purchaseValid = (getWalletBalance(self.player)-self:getOrderTotal()) >= 0
    self.purchase.enable = (not managed and not blocked and #self.yourCartData.items>0 and purchaseValid)
    local gb = 1
    if not purchaseValid then gb = 0 end
    self.purchase.textColor = { r = 1, g = gb, b = gb, a = 0.7 }
    self.purchase.borderColor = { r = 1, g = gb, b = gb, a = 0.7 }

    if self.addStockBtn:isVisible() then

        local elements = {self.addStockBtn, self.addStockEntry, self.addStockPrice, self.addStockQuantity, self.addStockBuyBackRate}

        self.addStockEntry.enable = not (self.addStockEntry:getInternalText()=="" or not getScriptManager():getItem(self.addStockEntry:getInternalText()))
        --local newItem = self.addStockEntry:getInternalText()
        --if self.storeObj.listings[newItem] then self.addStockEntry.enable = false end

        self.addStockPrice.enable = (self.addStockPrice:getInternalText()=="" or tonumber(self.addStockPrice:getInternalText()))
        self.addStockQuantity.enable = (self.addStockQuantity:getInternalText()=="" or tonumber(self.addStockQuantity:getInternalText()))

        local convertedBuyBackRate = tonumber(self.addStockBuyBackRate:getInternalText())
        self.addStockBuyBackRate.enable = (self.addStockBuyBackRate:getInternalText()=="" or (convertedBuyBackRate and (convertedBuyBackRate < 100 or convertedBuyBackRate > 0)))
        self.addStockBtn.enable = (self.addStockEntry.enable and self.addStockPrice.enable and self.addStockQuantity.enable and self.addStockBuyBackRate.enable)

        for _,e in pairs(elements) do self:validateElementColor(e) end
    end

    self.blocker:setVisible(blocked)
    self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    self.no:bringToTop()
    self.assignComboBox:bringToTop()
    self.aBtnConnect:bringToTop()
    self.aBtnDel:bringToTop()
    self.aBtnCopy:bringToTop()
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
        if not isClient() then self:refresh() end
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

        local newItem = self.addStockEntry:getInternalText()
        if newItem then
            --if self.storeObj.listings[newItem] then return end
            local script = getScriptManager():getItem(newItem)
            if script then

                local price = 0
                if self.addStockPrice.enable and self.addStockPrice:getInternalText() then price = tonumber(self.addStockPrice:getInternalText()) end

                local quantity = 0
                if self.addStockQuantity.enable and self.addStockQuantity:getInternalText() then quantity = tonumber(self.addStockQuantity:getInternalText()) end

                local buybackRate = 0
                if self.addStockBuyBackRate.enable and self.addStockBuyBackRate:getInternalText() then buybackRate = tonumber(self.addStockBuyBackRate:getInternalText()) end

                --self.storeStockData:addItem("$"..price.." "..newItem.." (x"..quantity..")", newItem)
                sendClientCommand("shop", "listNewItem", { isBeingManaged=store.isBeingManaged,
                item=newItem, price=price, quantity=quantity, buybackRate=buybackRate, storeID=store.ID, x=x, y=y, z=z, mapObjName=mapObjName })
                if not isClient() then self:refresh() end
            end
        end
    end

    if button.internal == "CANCEL" then
        self:setVisible(false)
        self:removeFromUIManager()
    end

    if button.internal == "PURCHASE" then
        self:finalizeDeal()
    end
end


function storeWindow:finalizeDeal()
    if not self.storeObj then return end
    local itemToPurchase = {}
    local itemsToSell = {}

    for i,v in ipairs(self.yourCartData.items) do
        if type(v.item) == "string" then
            table.insert(itemToPurchase, v.item) --listing
        else
            table.insert(itemsToSell, v.item:getType()) --selling
            ---@type IsoPlayer|IsoGameCharacter|IsoMovingObject|IsoObject
            self.player:getInventory():Remove(v.item)
        end
    end

    local walletID = getOrSetWalletID(nil,self.player)
    if not walletID then print("ERROR: finalizeDeal: No Wallet ID for "..self.player:getUsername()..", aborting.") return end
    self.yourCartData:clear()
    sendClientCommand(self.player,"shop", "processOrder", { playerID=walletID, storeID=self.storeObj.ID, buying=itemToPurchase, selling=itemsToSell })
    if not isClient() then self:refresh() end
end


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
    o.moveWithMouse = false
    o.selectedItem = nil
    o.pendingRequest = false
    storeWindow.instance = o
    return o
end


local reopenNextTick--{false,false}
function storeWindow:onBrowse(storeObj, mapObj)
    if storeWindow.instance and storeWindow.instance:isVisible() then
        storeWindow.instance:setVisible(false)
        storeWindow.instance:removeFromUIManager()
    end

    triggerEvent("SHOPPING_ClientModDataReady", true)

    reopenNextTick = nil
    local ui = storeWindow:new(50,50,500,500, getPlayer(), storeObj, mapObj)
    ui:initialise()
    ui:addToUIManager()
end

function storeWindow:refresh(additional)
    if self.mapObject then
        reopenNextTick = {enabled=false,obj=self.mapObject,time=2+(additional or 0)}
        self:setVisible(false)
        self:removeFromUIManager()
        reopenNextTick.enabled = true
    end
end

local function reopenNextTickFunc()
    if storeWindow.instance and storeWindow.instance:isVisible() then return end
    if reopenNextTick and reopenNextTick.obj and reopenNextTick.time and reopenNextTick.enabled then
        reopenNextTick.time = reopenNextTick.time-1
        if reopenNextTick.time<=0 then
            local storeID = reopenNextTick.obj:getModData().storeObjID
            storeWindow:onBrowse(CLIENT_STORES[storeID], reopenNextTick.obj)
        end
    end
end
Events.OnPlayerUpdate.Add(reopenNextTickFunc)


