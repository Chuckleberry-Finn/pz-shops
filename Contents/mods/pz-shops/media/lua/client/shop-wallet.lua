require "client/XpSystem/ISUI/ISCharacterInfo"
require "shop-globalModDataClient"

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

function deleteWallet(playerObj)
    local playerModData = playerObj:getModData()
    if not playerModData then print("WARN: Player without modData.") return end
    if not playerModData.wallet_UUID then print("- No Player wallet_UUID.") return end
    sendClientCommand("shop", "scrubWallet", {playerID=playerModData.wallet_UUID})
end

Events.OnPlayerDeath.Add(getOrSetWalletID)


local ISCharacterScreen_render = ISCharacterScreen.render
function ISCharacterScreen:render()
    ISCharacterScreen_render(self)
    local walletBalance = getWalletBalance(self.char)
    local walletBalanceLine = getText("IGUI_WALLETBALANCE")..": "..getText("IGUI_CURRENCY")..tostring(walletBalance)
    self:drawText(walletBalanceLine, self.avatarX+self.avatarWidth+25, 50, 1, 1, 1, 1, UIFont.Small)
end