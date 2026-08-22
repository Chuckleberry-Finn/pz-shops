local shopMarkerSystem = {}

shopMarkerSystem.textures = {
    shop = getTexture("media/textures/ui/shopMarker.png"),
    shop_up = getTexture("media/textures/ui/shopMarker_up.png"),
    shop_down = getTexture("media/textures/ui/shopMarker_down.png"),
}

shopMarkerSystem.markers = {}

shopMarkerSystem.needDefine = true

shopMarkerSystem.hoverDelayMs = 30
shopMarkerSystem.hovered = {}
shopMarkerSystem.pendingNameDraws = {}
shopMarkerSystem.movementState = {lastX=nil, lastY=nil, lastCheckTime=0, isMoving=false}

shopMarkerSystem.stackIncrement = 0.33

function shopMarkerSystem.isPlayerMoving(player)
    local now = getTimestampMs()
    local state = shopMarkerSystem.movementState
    if now == state.lastCheckTime then return state.isMoving end
    state.lastCheckTime = now

    local pX, pY = player:getX(), player:getY()
    if state.lastX then
        state.isMoving = (pX ~= state.lastX) or (pY ~= state.lastY)
    else
        state.isMoving = false
    end
    state.lastX, state.lastY = pX, pY
    return state.isMoving
end

function shopMarkerSystem.defineMarkers()
    if not shopMarkerSystem.needDefine then return end

    shopMarkerSystem.markers = {}
    local squareOccupancy = {}
    for shopID,storeObj in pairs(CLIENT_STORES) do
        if storeObj and storeObj.locations then
            shopMarkerSystem.markers[shopID] = {}

            local locIDs = {}
            for locID in pairs(storeObj.locations) do
                table.insert(locIDs, locID)
            end
            table.sort(locIDs)

            for i=1, #locIDs do
                local locID = locIDs[i]
                local locData = storeObj.locations[locID]
                local x, y, z = locData.x, locData.y, locData.z
                local tabelTop = locData.tabelTop
                local isWallMounted = locData.isWallMounted
                local zOffset = tabelTop and 0.25 or (isWallMounted and 0.6 or 0.05)

                local squareKey = x.."_"..y.."_"..math.floor(z)
                local stackIndex = squareOccupancy[squareKey] or 0
                squareOccupancy[squareKey] = stackIndex + 1

                local objName = locData.objName
                shopMarkerSystem.markers[shopID][locID] = { x=x, y=y, z=z+zOffset+(stackIndex*shopMarkerSystem.stackIncrement), objName=objName }
            end
        end
    end
    shopMarkerSystem.needDefine = false
end


function shopMarkerSystem.drawMarkerQuad(zDiff, x1, y1, x2, y2, x3, y3, x4, y4, alpha)
    getRenderer():render(shopMarkerSystem.textures["shop"..zDiff], x1, y1, x2, y2, x3, y3, x4, y4, 1, 1, 1, alpha, nil)
end


function shopMarkerSystem.checkHover(markerKey, shopID, worldX, worldY, projectionHeight)
    local player = getSpecificPlayer(0)
    if not player then return end

    local pZ = player:getZ()
    local height = projectionHeight or (pZ + 0.25)
    local mouseX, mouseY = getMouseX(), getMouseY()
    local mouseWorldX = screenToIsoX(0, mouseX, mouseY, height)
    local mouseWorldY = screenToIsoY(0, mouseX, mouseY, height)

    local dxWorld = mouseWorldX - worldX
    local dyWorld = mouseWorldY - worldY
    local hoverWorldRadius = 0.6
    local mouseOverIcon = (dxWorld*dxWorld + dyWorld*dyWorld) <= (hoverWorldRadius*hoverWorldRadius)
    local now = getTimestampMs()

    if mouseOverIcon then
        local hoverStart = shopMarkerSystem.hovered[markerKey] or now
        shopMarkerSystem.hovered[markerKey] = hoverStart
            local storeObj = CLIENT_STORES[shopID]
            local shopName = storeObj and storeObj.name
        if (not shopMarkerSystem.isPlayerMoving(player)) and now - hoverStart >= shopMarkerSystem.hoverDelayMs then
            if shopName then
                local alreadyQueued = false
                for _,pending in ipairs(shopMarkerSystem.pendingNameDraws) do
                    if pending.name == shopName then
                        alreadyQueued = true
                        break
                    end
                end
                if not alreadyQueued then
                    local uiX = math.floor(isoToScreenX(0, worldX, worldY, height) + 0.5)
                    local uiY = math.floor(isoToScreenY(0, worldX, worldY, height) - 30 + 0.5)
                    table.insert(shopMarkerSystem.pendingNameDraws, {x=uiX, y=uiY, name=shopName})
                end
            end
        end
    else
        shopMarkerSystem.hovered[markerKey] = nil
    end
end


function shopMarkerSystem.render(zza)

    local player = getSpecificPlayer(0)
    if not player then return end

    shopMarkerSystem.defineMarkers()
    local pX, pY, pZ = player:getX(), player:getY(), player:getZ()
    local zoom = getCore():getZoom(0)/2

    for shopID,locations in pairs(shopMarkerSystem.markers) do
        for locID, coord in pairs(locations) do
            local shopX, shopY, shopZ, shopZOffset = coord.x, coord.y, math.floor(coord.z), (coord.z % 1)

            local square = getSquare(shopX, shopY, shopZ)
            if square then

                if (not coord.objCheck) then
                    local foundShop
                    for i=0,square:getObjects():size()-1 do
                        ---@type IsoObject
                        local object = square:getObjects():get(i)
                        local objShopID = object:getModData().storeObjID
                        if objShopID and objShopID == shopID then
                            foundShop = object
                        end
                    end

                    if foundShop then
                        shopMarkerSystem.markers[shopID][locID].objCheck = true
                    else
                        shopMarkerSystem.markers[shopID][locID] = nil
                    end
                else
                    local projectionHeight = pZ+0.25+shopZOffset
                    local sx1, sy1 = ISCoordConversion.ToScreen(shopX, shopY, projectionHeight)
                    local zDiff = (shopZ > pZ and "_up") or (shopZ < pZ and "_down") or ""
                    local distX = math.abs(shopX - pX)
                    local distY = math.abs(shopY - pY)
                    local distance = math.sqrt(distX * distX + distY * distY)
                    local normalized = math.min(distance / 50, 1)
                    local scale = 1 + (7 - 1) * normalized
                    local size = math.max(24, math.min(96, 48 * zoom * scale))
                    local x1, y1 = sx1-(size/2), sy1-(size/2)
                    local x2, y2 = sx1+(size/2), sy1-(size/2)
                    local x3, y3 = sx1+(size/2), sy1+(size/2)
                    local x4, y4 = sx1-(size/2), sy1+(size/2)
                    shopMarkerSystem.drawMarkerQuad(zDiff, x1, y1, x2, y2, x3, y3, x4, y4, 0.75 * scale/2)

                    local markerKey = shopID.."_"..locID
                    shopMarkerSystem.checkHover(markerKey, shopID, shopX, shopY, projectionHeight)
                end

            else
                coord.objCheck = nil
            end

        end
    end
end


function shopMarkerSystem.renderHoverNames()
    for _,pending in ipairs(shopMarkerSystem.pendingNameDraws) do
        local tm = getTextManager()
        local nameY = pending.y - tm:getFontHeight(UIFont.Small) - 2
        tm:DrawStringCentre(UIFont.Small, pending.x, nameY, pending.name, 1, 1, 1, 1)
    end
    shopMarkerSystem.pendingNameDraws = {}
end


return shopMarkerSystem
