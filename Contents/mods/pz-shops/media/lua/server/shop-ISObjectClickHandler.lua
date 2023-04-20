require "ISObjectClickHandler"
local _internal = require "shop-shared"

local clickHandler = {}

---Validates if the worldObject can be interacted with
function clickHandler.canInteract(worldObject)
    if not worldObject then return true end

    local canView = true
    local worldObjectModData = worldObject:getModData()
    if worldObjectModData then
        local storeObjID = worldObjectModData.storeObjID
        if storeObjID then
            local storeObj = GLOBAL_STORES[storeObjID]
            canView = false

            if storeObj and _internal.canManageStore(storeObj,getSpecificPlayer(0)) then canView = true end
        end
    end

    return canView
end

local ISObjectClickHandler_doClick = ISObjectClickHandler.doClick
function ISObjectClickHandler.doClick(object, x, y)
    if clickHandler.canInteract(object) then ISObjectClickHandler_doClick(object, x, y) end
end

return clickHandler


