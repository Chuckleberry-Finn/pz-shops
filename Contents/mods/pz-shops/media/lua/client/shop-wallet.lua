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

    local walletBalance = getWalletBalance(self.player)
    local transferAmount = math.floor((walletBalance*(SandboxVars.ShopsAndTraders.PercentageDropOnDeath/100) * 10) / 10)

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

function ISSliderBox:initialise()
    ISTextBox.initialise(self)
    print("ISSliderBox:new: item:"..tostring(item).." player:"..tostring(player))
    local x,y,w,margin = 10,10,self.width-30,5
    local maxValue = 0
    if self.item then maxValue = self.item:getModData().value
    else maxValue = getWalletBalance(self.player) end

    self.slider = ISSliderPanel:new(self.entry.x, self.entry.y, w-margin, 20, self)
    self.slider:setValues( 1, maxValue, 1, 10, true)
    self.slider:setCurrentValue(math.floor(maxValue/2),true)
    self.slider:initialise()
    self.slider:instantiate()
    self:addChild(self.slider)
    self.slider:setVisible(true)
    self.entry:setVisible(false)
end


function ISSliderBox:new(x, y, width, height, text, onclick, player, item)
    local o = {}
    print("ISSliderBox:new: item:"..tostring(item).." player:"..tostring(player))
    o = ISTextBox:new(x, y, width, height, text, "", o, onclick, nil, player, item)
    setmetatable(o, self)
    self.__index = self
    o.item = item
    o.player = player
    if ISSliderBox.instance and ISSliderBox.instance:isVisible() then
        ISSliderBox.instance:setVisible(false)
        ISSliderBox.instance:removeFromUIManager()
    end

    ISSliderBox.instance = o
    return o
end


local function onSplitStackClick(button, player, item)

    print("onSplitStackClick: item:"..tostring(item).." player:"..tostring(player))

    if button.internal == "OK" and button.parent.entry:getText() and button.parent.entry:getText() ~= "" then
        local transferValue = self.slider:getCurrentValue()

        if item and _moneyTypes[item:getType()] and item:getModData() and item:getModData().value > 0 then
            item:getModData().value = item:getModData().value-transferValue
        end

        if not item then
            local playerModData = self.player:getModData()
            sendClientCommand("shop", "transferFunds", {giver=playerModData.wallet_UUID, give=transferValue, receiver=nil, receive=nil})
        end

        local type = moneyTypes[ZombRand(#moneyTypes)+1]
        local money = InventoryItemFactory.CreateItem(type)
        money:getModData().value = transferValue
        if money then player:getInventory():AddItem(money)
        else print("ERROR: Split/Withdraw Wallet: No money object created.") end
    end
end


---@param item InventoryItem|Literature
local function onSplitStack(item, player)
    print("onSplitStack: item:"..tostring(item).." player:"..tostring(player))

    local title = "IGUI_SPLIT"
    if not item then title = "IGUI_WITHDRAW" end

    local slider = ISSliderBox:new(0, 0, 280, 100, getText(title), onSplitStackClick, player, item)
    slider:initialise()
    slider:addToUIManager()
end


local _refreshContainer = ISInventoryPane.refreshContainer
function ISInventoryPane:refreshContainer()
    _refreshContainer(self)
    for _, entry in ipairs(self.itemslist) do
        local item = entry.items[1]
        if item ~= nil and _moneyTypes[item:getType()] and item:getModData() and (not item:getModData().value) then
            local value = math.floor(((ZombRand(150,2600)/100) * 10) / 10)
            item:getModData().value = value
        end
    end
end


local function addContext(player, context, items)
    for _, v in ipairs(items) do

        local item = v
        if not instanceof(v, "InventoryItem") then item = v.items[1] end

        if _moneyTypes[item:getType()] then
            local itemValue = item:getModData().value
            if itemValue and itemValue>1 then
                print("onSplitStack: item:"..tostring(item).." player:"..tostring(player))
                context:addOption(getText("IGUI_SPLIT"), item, onSplitStack, player)
            end
        end
    end
end
Events.OnPreFillInventoryObjectContextMenu.Add(addContext)


function ISCharacterScreen:withdraw(button) onSplitStack(nil, self.char) end

local ISCharacterScreen_initialise = ISCharacterScreen.initialise
function ISCharacterScreen:initialise()
    ISCharacterScreen_initialise(self)
    self.withdraw = ISButton:new(0, 0, 20, 20, string.lower(getText("IGUI_WITHDRAW")), self, ISCharacterScreen.withdraw)
    self.withdraw.font = UIFont.NewSmall
    self.withdraw.textColor = { r = 1, g = 1, b = 1, a = 0.7 }
    self.withdraw.borderColor = { r = 1, g = 1, b = 1, a = 0.7 }
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
    self:drawText(walletBalanceLine, self.withdraw.x, self.literatureButton.y+32, 1, 1, 1, 1, UIFont.Small)
end