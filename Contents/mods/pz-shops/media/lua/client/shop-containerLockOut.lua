local ISInventoryPage_dropItemsInContainer = ISInventoryPage.dropItemsInContainer
function ISInventoryPage:dropItemsInContainer(button)
    local container = self.mouseOverButton and self.mouseOverButton.inventory or nil
    local allow = true

    local mapObj = container:getParent()
    if mapObj then
        local storeObjID = mapObj:getModData().storeObjID
        if storeObjID then
            local storeObj = CLIENT_STORES[storeObjID]
            allow = false
            if storeObj.isBeingManaged and (isAdmin() or isCoopHost() or getDebug()) then allow = true end
        end
    end
    if allow then ISInventoryPage_dropItemsInContainer(self, button)
    else
        if ISMouseDrag.draggingFocus then
            ISMouseDrag.draggingFocus:onMouseUp(0,0)
            ISMouseDrag.draggingFocus = nil
            ISMouseDrag.dragging = nil
        end
        self:refreshWeight()
        return true
    end
end


local function containerLockOut(UI, STEP)
    if STEP == "buttonsAdded" then

        for index,containerButton in ipairs(UI.backpacks) do
            local mapObj = containerButton.inventory:getParent()
            if mapObj then

                local canView = true

                local storeObjID = mapObj:getModData().storeObjID
                if storeObjID then--and (not (isAdmin() or isCoopHost() or getDebug())) then
                    local storeObj = CLIENT_STORES[storeObjID]
                    if storeObj.isBeingManaged and (isAdmin() or isCoopHost() or getDebug()) then canView = true end
                    canView = false
                end

                if not canView then
                    containerButton.onclick = nil
                    containerButton.onmousedown = nil
                    containerButton.onMouseUp = nil
                    containerButton.onRightMouseDown = nil
                    containerButton:setOnMouseOverFunction(nil)
                    containerButton:setOnMouseOutFunction(nil)
                    containerButton.textureOverride = getTexture("media/ui/lock.png")
                end

            end
        end
    end
end
Events.OnRefreshInventoryWindowContainers.Add(containerLockOut)