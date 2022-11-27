require "ISUI/ISInventoryPane"
require "ISUI/ISInventoryPage"


local function validStoreObject(mapObject)
    local canView = true
    if mapObject then
        local mapObjectModData = mapObject:getModData()
        if mapObjectModData then
            local storeObjID = mapObjectModData.storeObjID
            if storeObjID then
                local storeObj = CLIENT_STORES[storeObjID]
                canView = false
                if storeObj.isBeingManaged and (isAdmin() or isCoopHost() or getDebug()) then canView = true end
            end
        end
    end
    return canView
end


local ISInventoryTransferAction_isValid = ISInventoryTransferAction.isValid
function ISInventoryTransferAction:isValid()
    if self.destContainer and self.srcContainer then
        if validStoreObject(self.destContainer:getParent()) and validStoreObject(self.srcContainer:getParent()) then
            return ISInventoryTransferAction_isValid(self)
        end
    end
end


local ISInventoryPage_dropItemsInContainer = ISInventoryPage.dropItemsInContainer
function ISInventoryPage:dropItemsInContainer(button)
    local container = self.mouseOverButton and self.mouseOverButton.inventory or nil
    local allow = true

    if container then
        local mapObj = container:getParent()
        if mapObj then
            local storeObjID = mapObj:getModData().storeObjID
            if storeObjID then allow = validStoreObject(mapObj) end
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


local ISInventoryPage_update = ISInventoryPage.update
function ISInventoryPage:update()
    ISInventoryPage_update(self)
    if not self.onCharacter then
        -- If the currently-selected container is locked to the player, select another container.
        local object = self.inventory and self.inventory:getParent() or nil
        if object and #self.backpacks > 1 and instanceof(object, "IsoThumpable") and (not validStoreObject(object)) then
            local currentIndex = self:getCurrentBackpackIndex()
            local unlockedIndex = self:prevUnlockedContainer(currentIndex, false)
            if unlockedIndex == -1 then
                unlockedIndex = self:nextUnlockedContainer(currentIndex, false)
            end
            if unlockedIndex ~= -1 then
                if playerObj:getJoypadBind() ~= -1 then
                    self.backpackChoice = unlockedIndex
                end
                self:selectContainer(self.backpacks[unlockedIndex])
            end
        end
    end
end


local function containerLockOut(UI, STEP)
    if STEP == "buttonsAdded" then

        for index,containerButton in ipairs(UI.backpacks) do
            local mapObj = containerButton.inventory:getParent()
            if mapObj then

                local canView = validStoreObject(mapObj)

                if not canView and containerButton then
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
