require "ISUI/ISTradingUI"
require "shop-window"

local ISTradingUI_initialise = ISTradingUI.initialise
function ISTradingUI:initialise()
    ISTradingUI_initialise(self)

    local newListLength = self.yourOfferDatas.height-20

    self.yourOfferDatas.height = newListLength
    self.yourOfferDatas:initialise()
    self.yourOfferDatas:instantiate()
    self:addChild(self.yourOfferDatas)

    self.hisOfferDatas.height = newListLength
    self.hisOfferDatas:initialise()
    self.hisOfferDatas:instantiate()
    self:addChild(self.hisOfferDatas)

    local halfOfList = self.yourOfferDatas.width/2

    self.transferFunds = ISTextEntryBox:new("0", self.yourOfferDatas.x+halfOfList, self.yourOfferDatas.y+newListLength-1, halfOfList, 20)
    self.transferFunds:initialise()
    self.transferFunds:instantiate()
    self.transferFunds.font = UIFont.Small
    self:addChild(self.transferFunds)

    self.walletFunds = ISPanel:new(self.yourOfferDatas.x, self.transferFunds.y, self.transferFunds.width, self.transferFunds.height)
    self.walletFunds.borderColor = self.borderColor
    self.walletFunds.backgroundColor = self.backgroundColor
    self.walletFunds:initialise()
    self.walletFunds:instantiate()
    self:addChild(self.walletFunds)

    self.offeredFunds = ISPanel:new(self.hisOfferDatas.x, self.transferFunds.y, self.transferFunds.width*2, self.transferFunds.height)
    self.offeredFunds.borderColor = self.borderColor
    self.offeredFunds.backgroundColor = self.backgroundColor
    self.offeredFunds:initialise()
    self.offeredFunds:instantiate()
    self:addChild(self.offeredFunds)

    self.blocker = ISPanel:new(self.yourOfferDatas.x+1, self.transferFunds.y+1, self.yourOfferDatas.width-2, self.transferFunds.height-2)
    self.blocker.moveWithMouse = true
    self.blocker.textColor = { r = 0, g = 0, b = 0, a = 0.9 }
    self.blocker.borderColor = { r = 0, g = 0, b = 0, a = 0.9 }
    self.blocker.backgroundColor = { r = 0, g = 0, b = 0, a = 0.9 }
    self.blocker:initialise()
    self.blocker:instantiate()
    self:addChild(self.blocker)

    self.setOfferedAmount = 0
end


local ISTradingUI_render = ISTradingUI.render
function ISTradingUI:render()

    local color = {r=1, g=1, b=1, a=0.9}

    local walletBalance = getWalletBalance(self.player)
    local walletBalanceLine = _internal.numToCurrency(walletBalance)
    self.walletFunds:drawText(walletBalanceLine, 10, 2, color.r, color.g, color.b, color.a, self.font)

    local currentInput = tonumber(self.transferFunds:getInternalText():match("0*(%d+)")) or 0
    local offerAmount = math.min(walletBalance, math.max(0,currentInput))
    local offeredAmountTxt = tostring(offerAmount)
    if self.transferFunds:getInternalText() ~= offeredAmountTxt then self.transferFunds:setText(offeredAmountTxt) end
    
    sendClientCommand("shop", "changeTransferOffer", {onlineID=self.otherPlayer:getOnlineID(), amount=offerAmount})

    local offerText = getText("IGUI_OFFERING")..": ".._internal.numToCurrency(self.setOfferedAmount)
    self.offeredFunds:drawText(offerText, 10, 2, color.r, color.g, color.b, color.a, self.font)

    ISTradingUI_render(self)

    self.blocker:bringToTop()

    if self.blockingMessage or self.blockingMessage2 or self.sealOffer.selected[1] then
        self.blocker:setVisible(true)
    else
        self.blocker:setVisible(false)
    end
end


local ISTradingUI_updateButtons = ISTradingUI.updateButtons
function ISTradingUI:updateButtons()
    ISTradingUI_updateButtons(self)

    local offeredAmount = tonumber(self.transferFunds:getInternalText()) or 0
    local otherOffer = self.setOfferedAmount

    if #self.yourOfferDatas.items > 0 or #self.hisOfferDatas.items > 0 or otherOffer > 0 or offeredAmount > 0 then
        self.acceptDeal.enable = true
        self.acceptDeal.tooltip = nil
    end
end

local ISTradingUI_finalizeDeal = ISTradingUI.finalizeDeal
function ISTradingUI:finalizeDeal()

    local offeredAmount = tonumber(self.transferFunds:getInternalText()) or 0
    local otherOffer = self.setOfferedAmount

    local playerID = self.player:getModData().wallet_UUID
    local otherIO = self.otherPlayer:getModData().wallet_UUID

    sendClientCommand("shop", "transferFunds", {giver=playerID, give=offeredAmount, receiver=otherIO, receive=otherOffer})
    ISTradingUI_finalizeDeal(self)
end
