require "ISObjectClickHandler"

local function validStoreObject(mapObject)
    local canView = true
    local storeObjID = mapObject:getModData().storeObjID
    if storeObjID then
        local storeObj = GLOBAL_STORES[storeObjID]
        if storeObj.isBeingManaged and (isAdmin() or isCoopHost() or getDebug()) then canView = true end
        canView = false
    end
    return canView
end

local ISObjectClickHandler_doClick = ISObjectClickHandler.doClick
function ISObjectClickHandler.doClick(object, x, y)
    local allow = true
    if object then
        local storeObjID = object:getModData().storeObjID
        if storeObjID then allow = validStoreObject(object) end
    end
    if allow then ISObjectClickHandler_doClick(object, x, y) end
end