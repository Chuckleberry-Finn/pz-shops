require "ISObjectClickHandler"
require "shop-window"

local function validStoreObject(mapObject)
    local canView = true
    local storeObjID = mapObject:getModData().storeObjID
    if storeObjID then
        local storeObj = GLOBAL_STORES[storeObjID]
        canView = false
        if storeObj and storeObj.isBeingManaged and (isAdmin() or isCoopHost() or getDebug()) then canView = true end
    end
    return canView
end

local ISObjectClickHandler_doClick = ISObjectClickHandler.doClick
function ISObjectClickHandler.doClick(object, x, y)

    local storeObjID = object and object:getModData().storeObjID
    local vanillaClick = true
    if storeObjID and validStoreObject(object)==false then vanillaClick=false end

    if vanillaClick==true then
        ISObjectClickHandler_doClick(object, x, y)
    else
        local storeObj = GLOBAL_STORES[storeObjID]
        if storeObj then storeWindow:onBrowse(storeObj, object) end
    end
end