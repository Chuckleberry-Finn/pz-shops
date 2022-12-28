require "ISObjectClickHandler"

local clickHandler = {}

---Validates if the mapObject can be interacted with
function clickHandler.canInteract(mapObject)
    if not mapObject then return true end

    local canView = true
    local mapObjectModData = mapObject:getModData()
    if mapObjectModData then
        local storeObjID = mapObjectModData.storeObjID
        if storeObjID then
            local storeObj = GLOBAL_STORES[storeObjID]
            canView = false
            if storeObj and storeObj.isBeingManaged and (isAdmin() or isCoopHost() or getDebug()) then canView = true end
        end
    end

    return canView
end

local ISObjectClickHandler_doClick = ISObjectClickHandler.doClick
function ISObjectClickHandler.doClick(object, x, y)
    if clickHandler.canInteract(object) then ISObjectClickHandler_doClick(object, x, y) end
end

return clickHandler


