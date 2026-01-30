---Credit to Konijima (Konijima#9279) for clearing up networking :thumbsup:

require "shop-commandsClientToServer"
local _internal = require "shop-shared"

GLOBAL_STORES = {}
GLOBAL_WALLETS = {}

local function shopsModDataInit(isNewGame)

    local fromWallets = WALLET_HANDLER.loadFromFile()
    if fromWallets then
        GLOBAL_WALLETS = fromWallets
        local count = 0
        for _ in pairs(GLOBAL_WALLETS) do count = count+1 end
        print("[Shop] Loaded wallets from shopsAndTradersWallets.json ("..count.." entries)")
    else
        GLOBAL_WALLETS = {}
    end

    local fromFile = STORE_HANDLER.loadFromFile()
    if fromFile then
        GLOBAL_STORES = fromFile
        local count = 0
        for _ in pairs(GLOBAL_STORES) do count = count+1 end
        print("[Shop] Loaded stores from shopsAndTradersData.json ("..count.." entries)")
    else
        GLOBAL_STORES = {}
    end
end

Events.OnInitGlobalModData.Add(shopsModDataInit)
