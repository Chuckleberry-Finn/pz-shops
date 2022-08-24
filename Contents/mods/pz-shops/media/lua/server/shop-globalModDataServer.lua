---Credit to Konijima (Konijima#9279) for clearing up networking :thumbsup:
if isClient() then return end
require "shop-commandsClientToServer"

GLOBAL_STORES = {}
GLOBAL_WALLETS = {}

local function shopsModDataInit(isNewGame)

    GLOBAL_STORES = ModData.getOrCreate("STORES")
    GLOBAL_WALLETS = ModData.getOrCreate("WALLETS")

    triggerEvent("SHOPPING_ServerModDataReady", isNewGame)
end

Events.OnInitGlobalModData.Add(shopsModDataInit)
