---Credit to Konijima (Konijima#9279) for clearing up networking :thumbsup:
require "shop-commandsServerToClient"
require "shop-shared"

CLIENT_STORES = {}
CLIENT_WALLETS = {}

local function initGlobalModData(isNewGame)

    if isClient() then
        if ModData.exists("STORES") then ModData.remove("STORES") end
        if ModData.exists("WALLETS") then ModData.remove("WALLETS") end
    end

    CLIENT_STORES = ModData.getOrCreate("STORES")
    CLIENT_WALLETS = ModData.getOrCreate("WALLETS")

    triggerEvent("SHOPPING_ClientModDataReady")
end
Events.OnInitGlobalModData.Add(initGlobalModData)


---@param name string
---@param data table
local function receiveGlobalModData(name, data)
    if name == "STORES" then
        _internal.copyAgainst(CLIENT_STORES,data)
    elseif name == "WALLETS" then
        _internal.copyAgainst(CLIENT_WALLETS,data)
    end
end
Events.OnReceiveGlobalModData.Add(receiveGlobalModData)


function getWalletBalance(player)
    local walletBalance = 0
    if player and player:getModData() then
        local pID = player:getModData().wallet_UUID
        if pID then
            local wallet = CLIENT_WALLETS[pID]
            if wallet then walletBalance = wallet.amount end
        end
    end
    return walletBalance
end