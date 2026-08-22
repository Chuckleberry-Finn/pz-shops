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

function shopMarkerSystem.defineMarkers()
    if not shopMarkerSystem.needDefine then return end

    shopMarkerSystem.markers = {}
    for shopID,storeObj in pairs(CLIENT_STORES) do
        if storeObj and storeObj.locations then
            shopMarkerSystem.markers[shopID] = {}
            for locID, locData in pairs(storeObj.locations) do
                local x, y, z = locData.x, locData.y, locData.z
                local tabelTop = locData.tabelTop
                local zOffset = tabelTop and 0.20 or 0
                local objName = locData.objName
                shopMarkerSystem.markers[shopID][locID] = { x=x, y=y, z=z+zOffset, objName=objName }
            end
        end
    end
    shopMarkerSystem.needDefine = false
end


function shopMarkerSystem.render(zza)
    local player = getSpecificPlayer(0)
    if not player then return end

    shopMarkerSystem.defineMarkers()
    local pX, pY, pZ = player:getX(), player:getY(), player:getZ()
    local zoom = getCore():getZoom(0)/2
    local mouseX, mouseY = getMouseX(), getMouseY()
    local now = getTimestampMs()
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
                    local sx1, sy1 = ISCoordConversion.ToScreen(shopX, shopY, pZ+0.25+shopZOffset)
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
                    getRenderer():render(shopMarkerSystem.textures["shop"..zDiff], x1, y1, x2, y2, x3, y3, x4, y4, 1, 1, 1, 0.75 * scale/2, nil)

                    local markerKey = shopID.."_"..locID
                    local mouseOverIcon = mouseX >= x1 and mouseX <= x3 and mouseY >= y1 and mouseY <= y3
                    if mouseOverIcon then
                        local hoverStart = shopMarkerSystem.hovered[markerKey] or now
                        shopMarkerSystem.hovered[markerKey] = hoverStart
                        if now - hoverStart >= shopMarkerSystem.hoverDelayMs then
                            local storeObj = CLIENT_STORES[shopID]
                            local shopName = storeObj and storeObj.name
                            if shopName then
                                local tm = getTextManager()
                                local nameY = y1 - tm:getFontHeight(UIFont.Small) - 2
                                tm:DrawStringCentre(UIFont.Small, sx1, nameY, shopName, 1, 1, 1, 1)
                            end
                        end
                    else
                        shopMarkerSystem.hovered[markerKey] = nil
                    end
                end

            else
                coord.objCheck = nil
            end

        end
    end
end


return shopMarkerSystem
