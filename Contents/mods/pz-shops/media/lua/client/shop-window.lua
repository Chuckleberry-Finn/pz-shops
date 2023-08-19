require "ISUI/ISPanelJoypad"
require "shop-globalModDataClient"
require "shop-wallet"
require "luautils"
require "shop-itemDictionary"
require "TimedActions/ISInventoryTransferAction"
local _internal = require "shop-shared"

---@class storeWindow : ISPanel
storeWindow = ISPanelJoypad:derive("storeWindow")
storeWindow.messages = {}
storeWindow.CoolDownMessage = 300
storeWindow.MaxItems = 20


function storeWindow:getItemTypesInStoreContainer(itemType)
    ---@type IsoObject
    local worldObject = self.worldObject
    if not worldObject then return end

    local container = worldObject:getContainer()
    if not container then return end

    local items = container:getAllType(itemType)
    if items then return items end
end


function storeWindow:getAvailableStock(listing)
    if not self.storeObj or not listing then return end
    if self.storeObj.ownerID then

        if listing.reselling==false then return 0 end

        local stock = self:getItemTypesInStoreContainer(listing.item)
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
    local listings = self.storeObj.listings
    for i,v in ipairs(self.storeStockData.items) do
        if not v.height then v.height = self.storeStockData.itemheight end

        local listing = listings[v.item]

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

        local showListing = itemReselling and availableItem and validItem

        if listing.alwaysShow==true then showListing = true end
        local managing = (self:isBeingManaged() and _internal.canManageStore(self.storeObj,self.player))

        if showListing or managing then
            if y >= y0 and y < y0 + v.height then return i end
            y0 = y0 + v.height
        end
    end
    return -1
end


function storeWindow:onStoreItemDoubleClick()
    if self:isBeingManaged() then
        local row = self:storeItemRowAt(self.storeStockData:getMouseY())
        if not self.storeStockData.items[row] then return end
        local item = self.storeStockData.items[row].item

        self.storeStockData:removeItemByIndex(self.storeStockData.selected)

        self.addStockEntry:setText("")
        self.addStockPrice:setText("")
        self.addStockBuyBackRate:setText("")

        self.alwaysShow.selected[1] = false
        self.resell.selected[1] = true
        self.addStockQuantity:setText("")

        sendClientCommand("shop", "removeListing", { item=item, storeID=self.storeObj.ID })
        return
    end
end


function storeWindow:addItemToYourStock(itemType, store, x, y, z, worldObjName, item, worldObject)

    sendClientCommand("shop", "listNewItem",
            { isBeingManaged=store.isBeingManaged, alwaysShow = false,
              item=itemType, price=0, quantity=0, buybackRate=0, reselling=false,
              storeID=store.ID, x=x, y=y, z=z, worldObjName=worldObjName })

    if worldObject and item then
        local worldObjectContainer = worldObject:getContainer()
        if worldObjectContainer then

            local action = ISInventoryTransferAction:new(self.player, item, self.player:getInventory(), worldObjectContainer)
            action.shopTransaction=true
            ISTimedActionQueue.add(action)
        end
    end
end



function storeWindow:yourStockingMouseUp(x, y)
    local store = self.parent.storeObj
    if (not self.parent:isBeingManaged()) or (not _internal.canManageStore(store,self.parent.player)) then return end
    if self.vscroll then self.vscroll.scrolling = false end
    if ISMouseDrag.dragging then

        local worldObject = self.parent.worldObject
        local woX, woY, woZ, worldObjName = worldObject:getX(), worldObject:getY(), worldObject:getZ(), _internal.getWorldObjectName(worldObject)

        local counta = 1
        for i,v in ipairs(ISMouseDrag.dragging) do

            counta = 1
            if instanceof(v, "InventoryItem") then
                ---@type InventoryItem
                local item = v
                local itemType = item:getFullType()
                self.parent:addItemToYourStock(itemType, store, woX, woY, woZ, worldObjName, v, worldObject)

            else
                if v.invPanel.collapsed[v.name] then
                    counta = 1
                    for i2,v2 in ipairs(v.items) do
                        if counta > 1 then
                            local item = v2
                            local itemType = item:getFullType()
                            self.parent:addItemToYourStock(itemType, store, woX, woY, woZ, worldObjName, v2, worldObject)
                        end
                        counta = counta + 1
                    end
                end
            end
        end
    end
end


function storeWindow:setStockInput(listing)
    if not self:isBeingManaged() then return end

    local option = self.addStockSearchPartition:getOptionData(self.addStockSearchPartition.selected)
    local text

    local SM = getScriptManager()
    local script = SM:getItem(listing.item)
    if script then

        if self.tempStockSearchPartitionData then
            self.addStockSearchPartition:selectData(self.tempStockSearchPartitionData)
            option = self.tempStockSearchPartitionData
            self.tempStockSearchPartitionData = nil
        end

        if option == "category" then
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
    self.addStockPrice:setText(tostring(listing.price))
    self.addStockBuyBackRate:setText(tostring(listing.buybackRate))

    self.alwaysShow.selected[1] = listing.alwaysShow
    self.resell.selected[1] = listing.reselling

    local isCategory = not getScriptManager():getItem(listing.item)

    if isCategory then
        self.addStockQuantity:setText("")
    else
        self.addStockQuantity:setText(tostring(listing.stock))
    end
end


function storeWindow:onStoreItemSelected()
    local row = self:storeItemRowAt(self.storeStockData:getMouseY())
    if not self.storeStockData.items[row] then return end
    local item = self.storeStockData.items[row].item

    local listing = self.storeObj.listings[item]

    if self:isBeingManaged() then self:setStockInput(listing) return end

    if #self.yourCartData.items >= self.MaxItems then return end
    local inCart = 0
    for _,v in pairs(self.yourCartData.items) do if v.item == item then inCart = inCart+1 end end

    local availableStock = self:getAvailableStock(listing)

    if self.storeObj and ((availableStock >= inCart+1) or (availableStock == -1)) then
        local script = getScriptManager():getItem(item)
        local scriptName = script:getDisplayName()
        self.yourCartData:addItem(scriptName, item)
    end
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


function storeWindow:setResellOrSell()
    local resellOrSell = "IGUI_RESELL"
    if self.storeObj and self.storeObj.ownerID then resellOrSell = "IGUI_SELL" end
    self.resell.options[1] = getText(resellOrSell)
    self.resell.tooltip = getText(resellOrSell.."_TOOLTIP")
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


function storeWindow:initialise()
    ISPanelJoypad.initialise(self)
    local btnWid = 100
    local btnHgt = 25
    local padBottom = 10
    local listWidh = (self.width / 2)-15
    local listHeight = (self.height*0.6)

    local storeName = "new store"
    if self.storeObj then storeName = self.storeObj.name end

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
    self.storeStockData:setOnMouseDoubleClick(self, self.onStoreItemDoubleClick)
    self.storeStockData.itemheight = 30
    self.storeStockData.selected = 0
    self.storeStockData.joypadParent = self
    self.storeStockData.font = UIFont.NewSmall
    self.storeStockData.doDrawItem = self.drawStock
    self.storeStockData.onMouseUp = self.yourStockingMouseUp
    self.storeStockData.drawBorder = true
    self:addChild(self.storeStockData)

    self:displayStoreStock()

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

    local addSearchX = self.addStockBuyBackRate.x+self.addStockBuyBackRate.width+10
    self.addStockSearchPartition = ISComboBox:new(addSearchX, self.addStockBuyBackRate.y, self.width-addSearchX-10, 18)
    self.addStockSearchPartition.borderColor = { r = 1, g = 1, b = 1, a = 0.4 }
    self.addStockSearchPartition.onChange = storeWindow.addItemEntryChange
    self.addStockSearchPartition:initialise()
    self.addStockSearchPartition:instantiate()
    self:addChild(self.addStockSearchPartition)
    self.addStockSearchPartition:addOptionWithData(getText("IGUI_Name"), "name")
    self.addStockSearchPartition:addOptionWithData(getText("IGUI_invpanel_Type"), "type")
    self.addStockSearchPartition:addOptionWithData(getText("IGUI_invpanel_Category"), "category")

    local addStockListY = self.addStockPrice.height+self.addStockPrice.y+5
    local addStockListW = self.width-self.addStockBuyBackRate.width-self.addStockBuyBackRate.x+8
    self.addStockList = ISScrollingListBox:new(self.addStockEntry.x, addStockListY, addStockListW, self.height-addStockListY-10)
    self.addStockList:initialise()
    self.addStockList:instantiate()
    self.addStockList:setOnMouseDownFunction(self, self.onAddStockListSelected)
    self.addStockList.itemheight = getTextManager():getFontHeight(UIFont.NewSmall)+4
    self.addStockList.selected = 0
    self.addStockList.labels = {}
    self.addStockList.joypadParent = self
    self.addStockList.font = UIFont.NewSmall
    self.addStockList.doDrawItem = self.drawAddStockList
    self.addStockList.onMouseUp = self.addStockListMouseUp
    self.addStockList.drawBorder = true
    self:addChild(self.addStockList)

    self.resell = ISTickBox:new(self.addStockBuyBackRate.x+self.addStockBuyBackRate.width+10, self.addStockSearchPartition.y+self.addStockSearchPartition.height+2, 18, 18, "", self, nil)
    self.resell.textColor = { r = 1, g = 0, b = 0, a = 0.7 }
    self.resell.tooltip = getText("IGUI_RESELL_TOOLTIP")
    self.resell:initialise()
    self.resell:instantiate()
    self.resell.selected[1] = SandboxVars.ShopsAndTraders.TradersResellItems
    self.resell:addOption(getText("IGUI_RESELL"))
    self:setResellOrSell()
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

    self.manageBtn = ISButton:new((self.width/2)-45, 77-btnHgt, 70, 20, getText("IGUI_MANAGESTORE"), self, storeWindow.onClick)
    self.manageBtn.internal = "MANAGE"
    self.manageBtn:initialise()
    self.manageBtn:instantiate()
    self:addChild(self.manageBtn)

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
    self:addChild(self.importText)

end


function storeWindow:populateComboList()
    self.assignComboBox:clear()
    self.assignComboBox:addOptionWithData("BLANK", false)
    for ID,DATA in pairs(CLIENT_STORES) do
        if not DATA.ownerID then
            self.assignComboBox:addOptionWithData(DATA.name, ID)
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
        local itemScript = getScriptManager():getItem(item)
        if itemScript then itemType = item end

        return itemType, false, itemCat
    else
        if self.player and luautils.haveToBeTransfered(self.player, item) then return false, "IGUI_NOTRADE_OUTSIDEINV" end
        if (item:getCondition()/item:getConditionMax())<0.75 or item:isBroken() then return false, "IGUI_NOTRADE_DAMAGED" end
        itemType = item:getFullType()
        if (_internal.isMoneyType(itemType) and item:getModData().value) then
            if SandboxVars.ShopsAndTraders.ShopsUseCash >= 2 then return false,"IGUI_NOTRADE_NOCASH" end
            return itemType
        end

        itemCat = item:getDisplayCategory()

        if storeObj and itemType then

            local listing = storeObj.listings[itemType]
            if not listing and itemCat then listing = storeObj.listings["category:"..tostring(itemCat)] end
            if not listing then return false, "IGUI_NOTRADE_INVALIDTYPE" end
            if listing then

                if listing.buybackRate > 0 then return itemType, false, itemCat
                else
                    return itemType, "IGUI_NOTRADE_ONLYSELL"
                end

            end
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
        local listing = storeObj.listings[itemType] or storeObj.listings["category:"..tostring(itemCat)] or _internal.isMoneyType(itemType)
        if listing then
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


function storeWindow:drawStock(y, item, alt)
    local texture, script, validCategory = nil, nil, nil
    if type(item.item) == "string" then
        script = getScriptManager():getItem(item.item)
        if script then
            texture = script:getNormalTexture()
        else
            validCategory = isValidItemDictionaryCategory(item.item:gsub("category:",""))
        end
    else
        texture = item.item:getTex()
    end

    local color = {r=1, g=1, b=1, a=0.9}

    local storeObj = self.parent.storeObj
    if storeObj then
        local listing = storeObj.listings[item.item]
        if listing then

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

                if not string.match(item.item, "category:") then
                    local inCart = 0
                    for _,v in pairs(self.parent.yourCartData.items) do if v.item == item.item then inCart = inCart+1 end end
                    local availableTemp = availableStock-inCart

                    if storeObj.ownerID and listing.reselling==false and listing.buybackRate>0 then availableTemp = 1 end

                    if availableTemp <= 0 then color = {r=0.7, g=0.7, b=0.7, a=0.3} end
                end

                local extra = ""
                if (not texture) and (not validCategory) then extra = "\[!\] " end

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

    local managed = self:isBeingManaged() and _internal.canManageStore(storeObj,self.player)

    for _,listing in pairs(storeObj.listings) do

        local script = scriptManager:getItem(listing.item)
        local itemDisplayName = listing.item
        if script then itemDisplayName = script:getDisplayName() end

        local isCategoryListingAndIsValid = (string.match(listing.item, "category:") and isValidItemDictionaryCategory(listing.item:gsub("category:","")))

        local inCart = 0
        for _,v in pairs(self.yourCartData.items) do if v.item == listing.item then inCart = inCart+1 end end

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
    for _,v in ipairs(self.yourCartData.items) do if v.item == item then add = false break end end
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
    if not self.player or not self.worldObject or (math.abs(self.player:getX()-self.worldObject:getX())>2) or (math.abs(self.player:getY()-self.worldObject:getY())>2) then
        self:setVisible(false)
        self:removeFromUIManager()
        return
    end
end


function storeWindow:removeItem(item) self.yourCartData:removeItem(item.text) end


function storeWindow:validateElementColor(e)
    if not e then return end
    if e==self.addStockQuantity and self.addStockSearchPartition:getOptionData(self.addStockSearchPartition.selected)=="category" then
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
    local invalidOrder = false
    local itemListedInCart = false

    for i,v in ipairs(self.yourCartData.items) do
        local itemType, reason, itemCat = self:rtrnTypeIfValid(v.item)
        if itemType then
            if reason then invalidOrder = true end
            if type(v.item) ~= "string" then
                if _internal.isMoneyType(itemType) then
                    totalForTransaction = totalForTransaction-(v.item:getModData().value)
                else
                    local itemListing = self.storeObj.listings[itemType] or self.storeObj.listings["category:"..tostring(itemCat)]
                    if itemListing then
                        itemListedInCart = true
                        totalForTransaction = totalForTransaction-(itemListing.price*(itemListing.buybackRate/100))
                    end
                end
            else
                local itemListing = self.storeObj.listings[v.item]
                if itemListing then
                    itemListedInCart = true
                    totalForTransaction = totalForTransaction+itemListing.price
                end
            end
        end
    end

    if not itemListedInCart then invalidOrder = true end
    return totalForTransaction, invalidOrder
end

function storeWindow:getPurchaseTotal()
    local totalForPurchase = 0
    for i,v in ipairs(self.yourCartData.items) do
        local itemType, _, itemCat = self:rtrnTypeIfValid(v.item)
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

    local credit = wallet.credit or {}
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
        self:validateElementColor(self.addStockPrice)
        local color = self.addStockPrice.textColor
        self:drawText(getText("IGUI_CURRENCY_PREFIX"), self.addStockPrice.x-12, self.addStockPrice.y, color.r,color.g,color.b,color.a, font)
        self:drawText(" "..getText("IGUI_CURRENCY_SUFFIX"), self.addStockPrice.x+self.addStockPrice.width+12, self.addStockPrice.y, color.r,color.g,color.b,color.a, font)

        if self.addStockQuantity:isVisible() then
            self:validateElementColor(self.addStockQuantity)
            color = self.addStockQuantity.textColor
            self:drawText(getText("IGUI_STOCK"), self.addStockQuantity.x-12, self.addStockQuantity.y, color.r,color.g,color.b,color.a, font)
        end

        self:validateElementColor(self.addStockBuyBackRate)
        color = self.addStockBuyBackRate.textColor
        self:drawText(getText("IGUI_RATE"), self.addStockBuyBackRate.x-14, self.addStockBuyBackRate.y, color.r,color.g,color.b,color.a, font)

        if self.storeObj then
            local ownerID = self.storeObj.ownerID
            if ownerID then
                local prefix, suffix = getText("IGUI_CURRENCY_PREFIX"), getText("IGUI_CURRENCY_SUFFIX")
                self:drawTextRight(prefix, self.restockHours.x-6, self.restockHours.y, 0.9,0.2,0.2,0.9, UIFont.Medium)
            end
        end

    else

        local storeName = "No Name Set"
        if self.storeObj then storeName = self.storeObj.name end
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
    self:drawText(stockText, stockTextX, self.storeStockData.y-20, 1,1,1,1, font)
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
    self.alwaysShow.enable = false
    self.resell.enable = false
    self.addStockList.enable = false

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

    if _internal.canManageStore(self.storeObj,self.player) then
        self.manageBtn.enable = true
        if self:isBeingManaged() then
            self.clearStore.enable = true
            self.addStockBtn.enable = true
            self.addStockSearchPartition.enable = true
            self.alwaysShow.enable = true
            self.resell.enable = true
            self.addStockList.enable = true
        end
    end
end


function storeWindow:validateAddStockEntry()
    local entryText = tostring(self.addStockEntry:getInternalText())
    if not entryText or entryText=="" then return false end

    local matches, matchesToType = findMatchesFromItemDictionary(entryText, self.addStockSearchPartition:getOptionData(self.addStockSearchPartition.selected))
    if not matches then return false end

    --print("matches: #:"..#matches.."   "..tostring(matches))
    --for k,v in pairs(matches) do print("<"..k.."><"..v..">") end
    --print("---")
    --for k,v in pairs(matchesToType) do print("<"..k.."><"..v..">") end

    local script = matchesToType[entryText]
    if script and getScriptManager():getItem(script) then return true end

    --print("no script: "..tostring(entryText))

    return false
end


function storeWindow:render()

    local worldObjModData
    if self.worldObject then
        worldObjModData = self.worldObject:getModData()
        if worldObjModData and worldObjModData.storeObjID then
            self.storeObj = CLIENT_STORES[worldObjModData.storeObjID]
            self:setResellOrSell()
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
        self:populateComboList()
        blocked = true
    end


    local shouldSeeStorePresetOptions = (not self.storeObj) and _internal.isAdminHostDebug()

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
    self.addStockQuantity:setVisible((not self.storeObj or (self.storeObj and not self.storeObj.ownerID)) and managed and not blocked)
    self.addStockBuyBackRate:setVisible(managed and not blocked)
    self.clearStore:setVisible(managed and not blocked)
    self.restockHours:setVisible(managed and not blocked)
    self.addStockSearchPartition:setVisible(managed and not blocked)
    self.alwaysShow:setVisible(managed and not blocked)
    self.resell:setVisible(managed and not blocked)
    self.addStockList:setVisible(managed and not blocked)

    self.manageStoreName:isEditable(not blocked)
    self.addStockEntry:isEditable(not blocked)
    self.addStockPrice:isEditable(not blocked)
    self.addStockQuantity:isEditable(not blocked and (self.addStockSearchPartition:getOptionData(self.addStockSearchPartition.selected)~="category"))
    self.addStockBuyBackRate:isEditable(not blocked)
    self.importText:isEditable(shouldSeeStorePresetOptions and self.importBtn.toggled)

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

        if self.addStockSearchPartition:getOptionData(self.addStockSearchPartition.selected)=="category" then self.addStockQuantity:setText("") end

        local convertedBuyBackRate = tonumber(self.addStockBuyBackRate:getInternalText())
        self.addStockBuyBackRate.enable = (self.addStockBuyBackRate:getInternalText()=="" or (convertedBuyBackRate and (convertedBuyBackRate < 100 or convertedBuyBackRate > 0)))
        self.addStockBtn.enable = (self.addStockEntry.enable and self.addStockPrice.enable and (self.addStockQuantity.enable or self.addStockSearchPartition:getOptionData(self.addStockSearchPartition.selected)=="category") and self.addStockBuyBackRate.enable)

        for _,e in pairs(elements) do self:validateElementColor(e) end
    end

    self.blocker:setVisible(blocked)
    if blocked and (not self.importText:isVisible()) then
        local blockingMessage = getText("IGUI_STOREBEINGMANAGED")
        self.blocker:drawText(blockingMessage, self.width/2 - (getTextManager():MeasureStringX(UIFont.Medium, blockingMessage) / 2), (self.height / 3) - 5, 1,1,1,1, UIFont.Medium)
        local uiButtons = {self.no, self.assignComboBox, self.aBtnConnect, self.aBtnDel, self.aBtnCopy, self.importBtn, self.importCancel, self.importText}
        for _,btn in pairs(uiButtons) do btn:bringToTop() end
    end

    self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
end


function storeWindow:onClick(button)

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
    end

    if button.internal == "CLEAR_STORE" and self.storeObj and self:isBeingManaged() then
        local tempWorldObj = self.worldObject
        local playerOwnedStore = self.storeObj and self.storeObj.ownerID
        sendClientCommand("shop", "clearStoreFromWorldObj", { storeID=self.storeObj.ID, x=x, y=y, z=z, worldObjName=worldObjName })
        
        if tempWorldObj and playerOwnedStore then
            ---@type ItemContainer
            local tempWorldObjCont = tempWorldObj:getContainer()
            if tempWorldObjCont then tempWorldObjCont:AddItem("ShopsAndTraders.ShopDeed") end
        end
    end

    if button.internal == "MANAGE" then
        local newName
        local restockHrs
        local store = self.storeObj
        if store then
            if self:isBeingManaged() then
                store.isBeingManaged = false
                newName = self.manageStoreName:getInternalText()
                if not self.storeObj.ownerID then
                    restockHrs = tonumber(self.restockHours:getInternalText()) or 1
                    restockHrs = math.max(1,restockHrs)
                end
                self.storeObj.name = newName
            else
                self.manageStoreName:setText(store.name)
                store.isBeingManaged = true
            end
            sendClientCommand("shop", "setStoreIsBeingManaged", {isBeingManaged=store.isBeingManaged, storeID=store.ID, storeName=newName, restockHrs=restockHrs})

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

        local matches, matchesToType = findMatchesFromItemDictionary(newEntry, self.addStockSearchPartition:getOptionData(self.addStockSearchPartition.selected))
        if not matches then return end

        if isValidItemDictionaryCategory(newEntry) then
            newEntry = "category:"..newEntry
        else
            local scriptType = matchesToType[newEntry]
            if not scriptType then return end

            local script = getScriptManager():getItem(scriptType)
            newEntry = script:getFullName()
        end

        local price = 0
        if self.addStockPrice.enable and self.addStockPrice:getInternalText() then price = tonumber(self.addStockPrice:getInternalText()) end

        local quantity = 0
        if self.addStockQuantity.enable and self.addStockQuantity:getInternalText() then quantity = tonumber(self.addStockQuantity:getInternalText()) end

        local buybackRate = 0
        if self.addStockBuyBackRate.enable and self.addStockBuyBackRate:getInternalText() then buybackRate = tonumber(self.addStockBuyBackRate:getInternalText()) end

        local reselling = self.resell.selected[1]

        sendClientCommand("shop", "listNewItem", { isBeingManaged=store.isBeingManaged, alwaysShow = (self.alwaysShow.selected[1] or false),
        item=newEntry, price=price, quantity=quantity, buybackRate=buybackRate, reselling=reselling, storeID=store.ID, x=x, y=y, z=z, worldObjName=worldObjName })
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

    if button.internal == "EXPORT_CLIPBOARD" then
        Clipboard.setClipboard(_internal.tableToString(CLIENT_STORES))
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

    local walletID = getOrSetWalletID(self.player)
    if not walletID then print("ERROR: finalizeDeal: No Wallet ID for "..self.player:getUsername()..", aborting.") return end

    local purchaseTotal = self:getPurchaseTotal()
    local moneyItemValueUsed = 0

    local worldObjectCont = self.worldObject and self.worldObject:getContainer()

    local counts = {}
    for i,v in ipairs(self.yourCartData.items) do
        if type(v.item) == "string" then
            if self.storeObj.ownerID then

                local storeStock = self:getItemTypesInStoreContainer(v.item)
                if storeStock then
                    counts[v.item] = (counts[v.item] or -1) + 1
                    local item = storeStock:get(counts[v.item])
                    if item then
                        local action = ISInventoryTransferAction:new(self.player, item, worldObjectCont, self.player:getInventory(), 0)
                        action.shopTransaction=true
                        ISTimedActionQueue.add(action)
                    end
                end
            end
            table.insert(itemToPurchase, v.item)
        else
            local itemType, _, _ = self:rtrnTypeIfValid(v.item)
            if itemType then
                local removeItem, isMoney = false, false
                if _internal.isMoneyType(itemType) then
                    local moneyAmount = v.item:getModData().value

                    if purchaseTotal > 0 then
                        local remainder = math.max(0, moneyAmount-purchaseTotal)
                        local moneyNeeded = math.min(purchaseTotal, moneyAmount)

                        moneyItemValueUsed = moneyItemValueUsed+moneyNeeded
                        purchaseTotal = purchaseTotal-moneyNeeded

                        if remainder <= 0 then
                            removeItem = true
                            isMoney = true
                        else
                            generateMoneyValue(v.item, remainder, true)
                        end
                    end
                else
                    removeItem = true
                    table.insert(itemsToSell, itemType)
                end

                ---@type IsoPlayer|IsoGameCharacter|IsoMovingObject|IsoObject
                if removeItem then
                    if (not isMoney) and self.storeObj.ownerID then
                        if worldObjectCont then
                            local action = ISInventoryTransferAction:new(self.player, v.item, self.player:getInventory(), worldObjectCont, 0)
                            action.shopTransaction=true
                            ISTimedActionQueue.add(action)
                        end
                    else
                        self.player:getInventory():Remove(v.item)
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

function storeWindow:new(x, y, width, height, player, storeObj, worldObj)
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
    o.worldObject = worldObj
    o.storeObj = storeObj
    o.moveWithMouse = true
    o.selectedItem = nil
    o.pendingRequest = false
    storeWindow.instance = o
    return o
end


function storeWindow:onBrowse(storeObj, worldObj)
    if storeWindow.instance and storeWindow.instance:isVisible() then
        storeWindow.instance:setVisible(false)
        storeWindow.instance:removeFromUIManager()
    end

    getOrSetWalletID(getPlayer())

    local ui = storeWindow:new(50,50,555,555, getPlayer(), storeObj, worldObj)
    ui:initialise()
    ui:addToUIManager()
end


