require "BuildingObjects/ISDestroyCursor"
local _internal = require "shop-shared"

local _canDestroy = ISDestroyCursor.canDestroy
function ISDestroyCursor:canDestroy(object)

    local original = _canDestroy(self, object)

    local objectModData = object:getModData()
    if objectModData then
        local storeObjID = objectModData.storeObjID
        if storeObjID then
            local storeObj = GLOBAL_STORES[storeObjID]
            if storeObj then--and not _internal.canManageStore(storeObj,self.character) then
                return false
            end
        end
    end

    return original
end