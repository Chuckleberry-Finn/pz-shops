---Credit to Konijima (Konijima#9279) for clearing up networking :thumbsup:
require "shop-commandsServerToClient"

CLIENT_STORES = {}
CLIENT_WALLETS = {}


local function initGlobalModData(isNewGame)

    if not isClient() then
        CLIENT_STORES = ModData.getOrCreate("STORES")
        CLIENT_WALLETS = ModData.getOrCreate("WALLETS")
    end

end
Events.OnInitGlobalModData.Add(initGlobalModData)