require "shop-window"
local _internal = require "shop-shared"

local CONTEXT_HANDLER = {}

---@param worldObject IsoObject
function CONTEXT_HANDLER.browseStore(worldObjects, playerObj, worldObject, storeObj, ignoreCapacityCheck)
    storeWindow:onBrowse(storeObj, worldObject, playerObj, ignoreCapacityCheck)
end


function CONTEXT_HANDLER.preGenerateContextMenu(playerID, context, worldObjects, test)
    local playerObj = getSpecificPlayer(playerID)
    local square

    if _internal.isAdminHostDebug() then sendClientCommand(playerObj,"shop", "ImportStores", {}) end

    for _,v in ipairs(worldObjects) do square = v:getSquare() end
    if not square then return end

    if (math.abs(playerObj:getX()-square:getX())>2) or (math.abs(playerObj:getY()-square:getY())>2) then return end

    for i=0,square:getObjects():size()-1 do
        ---@type IsoObject
        local object = square:getObjects():get(i)
        if object and (not instanceof(object, "IsoWorldInventoryObject")) then

            local objStoreID = object:getModData().storeObjID
            if objStoreID then
                --local storeObj = CLIENT_STORES[objStoreID]
                --if not storeObj then
                local x, y, z, worldObjName = object:getX(), object:getY(), object:getZ(), _internal.getWorldObjectName(object)
                sendClientCommand("shop", "checkMapObject", { storeID=objStoreID, x=x, y=y, z=z, worldObjName=worldObjName })
                --end
            end
        end
    end
end
Events.OnPreFillWorldObjectContextMenu.Add(CONTEXT_HANDLER.preGenerateContextMenu)


function CONTEXT_HANDLER.generateContextMenu(playerID, context, worldObjects, test)
    local playerObj = getSpecificPlayer(playerID)
    local square

    for _,v in ipairs(worldObjects) do square = v:getSquare() end
    if not square then return end

    if (math.abs(playerObj:getX()-square:getX())>2) or (math.abs(playerObj:getY()-square:getY())>2) then return end

    local validObjects = {}
    local validObjectCount = 0

    for i=0,square:getObjects():size()-1 do
        ---@type IsoObject
        local object = square:getObjects():get(i)
        if object and (not instanceof(object, "IsoWorldInventoryObject")) then

            if object:getModData().storeObjID or (_internal.isAdminHostDebug()) then
                validObjects[object] = CLIENT_STORES[object:getModData().storeObjID] and object:getModData().storeObjID or false
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

        for worldObject,storeObjectID in pairs(validObjects) do
            local objectName = _internal.getWorldObjectDisplayName(worldObject)
            if objectName then
                local contextText-- = nil

                local storeObject = CLIENT_STORES[storeObjectID]
                if storeObject then
                    contextText = getText("ContextMenu_SHOP_AT").." "..(storeObject.name or objectName)

                elseif worldObject:getModData().storeObjID then
                    contextText = getText("ContextMenu_SHOP_AT").." "..objectName

                elseif _internal.isAdminHostDebug() then
                    contextText = objectName.." [ "..getText("ContextMenu_ASSIGN_STORE").." ]"
                end

                if contextText then
                    local option = currentMenu:addOptionOnTop(contextText, worldObjects, CONTEXT_HANDLER.browseStore, playerObj, worldObject, storeObject, true)
                    if isClient() and option and storeObject then

                        local worldObjSquare = worldObject and worldObject:getSquare()
                        if (SandboxVars.ShopsAndTraders.ShopsRequirePower == true) and worldObjSquare then
                            if (not worldObjSquare:haveElectricity()) and (not getWorld():isHydroPowerOn()) then

                                option.notAvailable = true
                                if _internal.canManageStore(storeObject,playerObj) then option.notAvailable = false end

                                local tooltip = ISWorldObjectContextMenu.addToolTip()
                                local text = getText("IGUI_SHOP_NEEDS_POWER")
                                tooltip:setName(text)
                                tooltip.description = text
                                option.toolTip = tooltip
                            end
                        end

                        if not storeWindow.checkMaxShopperCapacity(storeObject, worldObject, playerObj) then
                            option.notAvailable = true
                            local tooltip = ISWorldObjectContextMenu.addToolTip()
                            local text = getText("IGUI_CURRENTLY_IN_USE")
                            tooltip:setName(text)
                            tooltip.description = text
                            option.toolTip = tooltip
                        end
                    end
                end
            end
        end
    end

end
Events.OnFillWorldObjectContextMenu.Add(CONTEXT_HANDLER.generateContextMenu)