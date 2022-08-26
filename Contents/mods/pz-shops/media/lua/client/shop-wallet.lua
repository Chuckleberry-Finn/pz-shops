require "client/XpSystem/ISUI/ISCharacterInfo"
require "shop-globalModDataClient"
require "ISUI/ISInventoryPaneContextMenu"
require "ISUI/ISTextBox"

local moneyTypes = {"Money"}

local trueKeyed, _moneyTypes
if not trueKeyed then
    _moneyTypes = {}
    for _,type in pairs(moneyTypes) do _moneyTypes[type] = true end
    trueKeyed = true
end

local function modifyScript()
    for type,_ in pairs(_moneyTypes) do
        ---@type Item
        local script = getScriptManager():getItem(type)
        local weight = SandboxVars.ShopsAndTraders.MoneyWeight
        if script then script:setActualWeight(weight) end
    end
end
Events.OnGameBoot.Add(modifyScript)


---@param playerObj IsoPlayer|IsoGameCharacter|IsoMovingObject|IsoObject
function getOrSetWalletID(playerID,playerObj)
    if not playerObj then return end
    local playerModData = playerObj:getModData()
    if not playerModData then print("WARN: Player created without modData - can't append wallet.") return end
    if not playerModData.wallet_UUID then
        print("- No Player wallet_UUID - generating now.")
        playerModData.wallet_UUID = getRandomUUID()
    end
    print("playerModData.wallet_UUID: "..playerModData.wallet_UUID)
    sendClientCommand("shop", "getOrSetWallet", {playerID=playerModData.wallet_UUID,steamID=playerObj:getSteamID()})
    return playerModData.wallet_UUID
end
Events.OnCreatePlayer.Add(getOrSetWalletID)


---@param playerObj IsoPlayer|IsoGameCharacter|IsoMovingObject|IsoObject
local function onPlayerDeath(playerObj)
    local playerModData = playerObj:getModData()
    if not playerModData then print("WARN: Player without modData.") return end
    if not playerModData.wallet_UUID then print("- No Player wallet_UUID.") return end

    local walletBalance = getWalletBalance(playerObj)
    local transferAmount = math.floor((walletBalance*(SandboxVars.ShopsAndTraders.PercentageDropOnDeath/100) * 100) / 100)

    if transferAmount > 0 then
        sendClientCommand("shop", "transferFunds", {giver=playerModData.wallet_UUID, give=transferAmount, receiver=nil, receive=nil})
        local type = moneyTypes[ZombRand(#moneyTypes)+1]

        local money = InventoryItemFactory.CreateItem(type)
        money:getModData().value = transferAmount
        if money then playerObj:getInventory():AddItem(money)
        else print("ERROR: Split/Withdraw Wallet: No money object created.") end
    end
end
Events.OnPlayerDeath.Add(onPlayerDeath)




---@class ISSliderBox : ISTextBox
ISSliderBox = ISTextBox:derive("ISSliderBox")

function ISSliderBox:onValueChange(val)
    local title = "IGUI_SPLIT"
    if not self.item then title = "IGUI_WITHDRAW" end
    local value = math.floor(((val) * 100)/100)
    self.text = getText(title)..": "..getText("IGUI_CURRENCY")..tostring(val)
end

function ISSliderBox:initialise()
    ISTextBox.initialise(self)

    local x,y,w,margin = 10,10,self.width-30,5
    local maxValue = 0
    if self.item then maxValue = self.item:getModData().value
    else maxValue = getWalletBalance(self.playerObj) end

    local halfMax = math.floor(((maxValue/2)*100)/100)
    self.slider = ISSliderPanel:new(self.entry.x, self.entry.y, w-margin, 20, self, ISSliderBox.onValueChange)
    self.slider:setValues( 0.01, maxValue, 0.01, 0.1, true)
    self.slider:setCurrentValue(halfMax)
    self.slider:initialise()
    self.slider:instantiate()
    self:addChild(self.slider)
    self.slider:setVisible(true)
    self.entry:setVisible(false)
end



function ISSliderBox:new(x, y, width, height, text, onclick, playerObj, item)
    if ISSliderBox.instance and ISSliderBox.instance:isVisible() then
        ISSliderBox.instance:setVisible(false)
        ISSliderBox.instance:removeFromUIManager()
    end
    local o = {}
    print("ISSliderBox:new: item:"..tostring(item).." player:"..tostring(playerObj))
    o = ISTextBox:new(x, y, width, height, text, "", o, onclick, nil, playerObj, item)
    setmetatable(o, self)
    self.__index = self
    o.item = item
    o.playerObj = playerObj
    ISSliderBox.instance = o
    return o
end


function ISSliderBox:onClick(button, playerObj, item)
    if button.internal == "OK" then
        local transferValue = button.parent.slider:getCurrentValue()

        if item and _moneyTypes[item:getType()] and item:getModData() and item:getModData().value > 0 then
            item:getModData().value = item:getModData().value-transferValue
        end

        if not item then
            local playerModData = playerObj:getModData()
            sendClientCommand("shop", "transferFunds", {giver=playerModData.wallet_UUID, give=transferValue, receiver=nil, receive=nil})
        end

        local type = moneyTypes[ZombRand(#moneyTypes)+1]
        local money = InventoryItemFactory.CreateItem(type)
        money:getModData().value = transferValue
        if money then playerObj:getInventory():AddItem(money)
        else print("ERROR: Split/Withdraw Wallet: No money object created.") end
    end
end


---@param item InventoryItem|Literature
local function onSplitStack(item, player, x, y)
    local slider = ISSliderBox:new(x, y, 280, 100, "", ISSliderBox.onClick, player, item)
    slider:initialise()
    slider:addToUIManager()
end


local _refreshContainer = ISInventoryPane.refreshContainer
function ISInventoryPane:refreshContainer()
    _refreshContainer(self)
    for _, entry in ipairs(self.itemslist) do
        local item = entry.items[1]
        if item ~= nil and _moneyTypes[item:getType()] and item:getModData() and (not item:getModData().value) then
            local value = math.floor(((ZombRand(150,2600)/100) * 100) / 100)
            item:getModData().value = value
        end
    end
end


local function addContext(playerID, context, items)
    local playerObj = getSpecificPlayer(playerID)
    for _, v in ipairs(items) do
        local item = v
        if not instanceof(v, "InventoryItem") then item = v.items[1] end
        if _moneyTypes[item:getType()] then
            local itemValue = item:getModData().value
            if itemValue and itemValue>1 then context:addOption(getText("IGUI_SPLIT"), item, onSplitStack, playerObj) end
        end
    end
end
Events.OnPreFillInventoryObjectContextMenu.Add(addContext)


function ISCharacterScreen:withdraw(button)
    onSplitStack(nil, self.char, ISCharacterInfoWindow.instance.x+button.x+button.width+10, ISCharacterInfoWindow.instance.y+button.y+button.height+15)
end

function ISCharacterScreen:moneyMouseOut(x, y)
    self.withdraw:setTitle(string.lower(getText("IGUI_WITHDRAW")))
end
function ISCharacterScreen:moneyMouseOver(x, y)
    if not self.withdraw.mouseOver or not self.withdraw.onmouseover then return end

    if self.vscroll then self.vscroll.scrolling = false end
    local money = false
    if ISMouseDrag.dragging then
        for i,v in ipairs(ISMouseDrag.dragging) do
            if instanceof(v, "InventoryItem") and _moneyTypes[v:getType()] then money = true break
            else if v.invPanel.collapsed[v.name] then for i2,v2 in ipairs(v.items) do if _moneyTypes[v2:getType()] then money = true break end end end
            end
        end
        if money then self.withdraw:setTitle(string.lower(getText("IGUI_DEPOSIT"))) end
    end
end


function ISCharacterScreen:depositMoney(moneyItem)
    local playerModData = self.char:getModData()
    local value = moneyItem:getModData().value
    sendClientCommand("shop", "transferFunds", {giver=nil, give=value, receiver=playerModData.wallet_UUID, receive=nil})
    self.char:getInventory():Remove(moneyItem)
end


function ISCharacterScreen:depositOnMouseUp(x, y)
    if self.vscroll then self.vscroll.scrolling = false end
    local counta = 1
    if ISMouseDrag.dragging then
        for i,v in ipairs(ISMouseDrag.dragging) do
            counta = 1
            if instanceof(v, "InventoryItem") and _moneyTypes[v:getType()] then self.parent:depositMoney(v)
            else
                if v.invPanel.collapsed[v.name] then
                    counta = 1
                    for i2,v2 in ipairs(v.items) do
                        if counta > 1 and _moneyTypes[v2:getType()] then self.parent:depositMoney(v2) end
                        counta = counta + 1
                    end
                end
            end
        end
    else
        self.parent:withdraw(self)
    end
end


local ISCharacterScreen_initialise = ISCharacterScreen.initialise
function ISCharacterScreen:initialise()
    ISCharacterScreen_initialise(self)
    self.withdraw = ISButton:new(0, 0, 20, 20, string.lower(getText("IGUI_WITHDRAW")), self, nil)
    self.withdraw.font = UIFont.NewSmall
    self.withdraw.textColor = { r = 1, g = 1, b = 1, a = 0.7 }
    self.withdraw.borderColor = { r = 1, g = 1, b = 1, a = 0.7 }
    self.withdraw.onMouseUp = self.depositOnMouseUp
    self.withdraw:setOnMouseOverFunction(self.moneyMouseOver)
    self.withdraw:setOnMouseOutFunction(self.moneyMouseOut)
    self.withdraw:initialise()
    self.withdraw:instantiate()
    self:addChild(self.withdraw)
end

local ISCharacterScreen_render = ISCharacterScreen.render
function ISCharacterScreen:render()
    ISCharacterScreen_render(self)
    self.withdraw:setX(self.avatarX+self.avatarWidth+25)
    self.withdraw:setY(self.literatureButton.y+52)
    local walletBalance = getWalletBalance(self.char)
    local walletBalanceLine = getText("IGUI_WALLETBALANCE")..": "..getText("IGUI_CURRENCY")..tostring(walletBalance)
    self:drawTextCentre(walletBalanceLine, self.withdraw.x, self.literatureButton.y+32, 1, 1, 1, 1, UIFont.Small)
end