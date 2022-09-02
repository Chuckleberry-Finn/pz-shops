---Credit to Konijima (Konijima#9279) for clearing up networking :thumbsup:

require "shop-commandsClientToServer"

GLOBAL_STORES = {}
GLOBAL_WALLETS = {}

local function shopsModDataInit(isNewGame)

    GLOBAL_STORES = ModData.getOrCreate("STORES")
    GLOBAL_WALLETS = ModData.getOrCreate("WALLETS")

    if not isNewGame then triggerEvent("SHOPPING_ServerModDataReady") end
end

Events.OnInitGlobalModData.Add(shopsModDataInit)
