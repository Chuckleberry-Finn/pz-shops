require "shop-window"

local CONTEXT_HANDLER = {}

---@param mapObject MapObjects|IsoObject
function CONTEXT_HANDLER.browseStore(worldObjects, playerObj, mapObject, storeObj)
    if not storeObj then
        if not (isAdmin() or isCoopHost() or getDebug()) then print(" ERROR: non-admin accessed context menu meant for assigning shops.") return end
    end
    storeWindow:onBrowse(storeObj, mapObject)
end


function CONTEXT_HANDLER.generateContextMenu(playerID, context, worldObjects)
    local playerObj = getSpecificPlayer(playerID)
    local square

    for _,v in ipairs(worldObjects) do square = v:getSquare() end
    if not square then return end

    if (math.abs(playerObj:getX()-square:getX())>2) or (math.abs(playerObj:getY()-square:getY())>2) then return end

    local validObjects = {}
    local validObjectCount = 0

    triggerEvent("SHOPPING_ClientModDataReady")

    for i=0,square:getObjects():size()-1 do
        ---@type IsoObject|MapObjects
        local object = square:getObjects():get(i)
        if object and (not instanceof(object, "IsoWorldInventoryObject")) then

            if object:getModData().storeObjID then
                local storeObj = CLIENT_STORES[object:getModData().storeObjID]
                if not storeObj then object:getModData().storeObjID = nil end
            end

            if object:getModData().storeObjID or (isAdmin() or isCoopHost() or getDebug()) then
                validObjects[object] = CLIENT_STORES[object:getModData().storeObjID] or false
                validObjectCount = validObjectCount+1
            end
        end
    end

    local currentMenu = context
    if validObjectCount > 0 then
        if validObjectCount>1 then
            local mainMenu = context:addOptionOnTop(getText("ContextMenu_STORES"), worldObjects, nil)
            local subMenu = ISContextMenu:getNew(context)
            context:addSubMenu(mainMenu, subMenu)
            currentMenu = subMenu
        end

        for mapObject,storeObject in pairs(validObjects) do
            local objectName = _internal.getMapObjectDisplayName(mapObject)
            if objectName then
                local contextText = objectName.." [ "..getText("ContextMenu_ASSIGN_STORE").." ]"
                if storeObject then
                    contextText = getText("ContextMenu_SHOP_AT").." "..(storeObject.name or objectName)
                end
                currentMenu:addOptionOnTop(contextText, worldObjects, CONTEXT_HANDLER.browseStore, playerObj, mapObject, storeObject)
            end
        end
    end

end
Events.OnFillWorldObjectContextMenu.Add(CONTEXT_HANDLER.generateContextMenu)