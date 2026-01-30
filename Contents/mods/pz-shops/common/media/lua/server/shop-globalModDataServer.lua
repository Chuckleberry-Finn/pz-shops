---Credit to Konijima (Konijima#9279) for clearing up networking :thumbsup:

require "shop-commandsClientToServer"
local _internal = require "shop-shared"

GLOBAL_STORES = {}
GLOBAL_WALLETS = {}

local shopsLoaded = false

local function countEntries(t)
    local n = 0
    for _ in pairs(t) do n = n+1 end
    return n
end

-- In SP/local-coop CLIENT_ and GLOBAL_ point at the same tables, so any
-- key-level mutation to GLOBAL_ is automatically visible via CLIENT_.
local function syncGlobalToClientIfSP()
    if not isClient() and not isServer() then
        CLIENT_STORES = GLOBAL_STORES
        CLIENT_WALLETS = GLOBAL_WALLETS
    end
end

local function shopsLoadFromFiles()
    local saveName = getCurrentSaveName()
    if not saveName or saveName == "" then return end

    shopsLoaded = true
    Events.OnTick.Remove(shopsLoadFromFiles)

    local wallets = WALLET_HANDLER.loadFromFile()
    if wallets then
        GLOBAL_WALLETS = wallets
        print("[Shop] Loaded wallets from shopsAndTradersWallets.json ("..countEntries(GLOBAL_WALLETS).." entries)")
    end

    local stores = STORE_HANDLER.loadFromFile()
    if stores then
        GLOBAL_STORES = stores
        print("[Shop] Loaded stores from shopsAndTradersData.json ("..countEntries(GLOBAL_STORES).." entries)")
    end

    syncGlobalToClientIfSP()
end

local function shopsModDataInit(isNewGame)
    local saveName = getCurrentSaveName()
    if saveName and saveName ~= "" then
        shopsLoadFromFiles()
    else
        Events.OnTick.Add(shopsLoadFromFiles)
    end
end

Events.OnInitGlobalModData.Add(shopsModDataInit)
