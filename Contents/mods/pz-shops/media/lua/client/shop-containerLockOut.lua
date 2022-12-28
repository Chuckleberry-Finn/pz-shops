require "ISUI/ISInventoryPane"
require "ISUI/ISInventoryPage"

---Validates if the mapObject can be interacted with
local function canInteractWithContents(mapObject)
    if not mapObject then return true end

    local canView = true
    local mapObjectModData = mapObject:getModData()
    if mapObjectModData then
        local storeObjID = mapObjectModData.storeObjID
        if storeObjID then
            local storeObj = CLIENT_STORES[storeObjID]
            canView = false
            if storeObj and storeObj.isBeingManaged and (isAdmin() or isCoopHost() or getDebug()) then canView = true end
        end
    end

    return canView
end


---Prevents transfer from or to a locked container
local ISInventoryTransferAction_isValid = ISInventoryTransferAction.isValid
function ISInventoryTransferAction:isValid()
    if self.destContainer and self.srcContainer then
        if canInteractWithContents(self.destContainer:getParent()) and canInteractWithContents(self.srcContainer:getParent()) then
            return ISInventoryTransferAction_isValid(self)
        end
    end
end


---Prevents dragging items out of a locked container
local ISInventoryPage_dropItemsInContainer = ISInventoryPage.dropItemsInContainer
function ISInventoryPage:dropItemsInContainer(button)
    local container = self.mouseOverButton and self.mouseOverButton.inventory or nil
    local allow = true

    if container then
        local mapObj = container:getParent()
        if mapObj then allow = canInteractWithContents(mapObj) end
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


---Slides the inventory page over to the next available page
local ISInventoryPage_update = ISInventoryPage.update
function ISInventoryPage:update()
    ISInventoryPage_update(self)
    if not self.onCharacter then
        -- If the currently-selected container is locked to the player, select another container.
        local object = self.inventory and self.inventory:getParent() or nil
        if object and #self.backpacks > 1 and instanceof(object, "IsoThumpable") and (not canInteractWithContents(object)) then
            local currentIndex = self:getCurrentBackpackIndex()
            local unlockedIndex = self:prevUnlockedContainer(currentIndex, false)
            if unlockedIndex == -1 then
                unlockedIndex = self:nextUnlockedContainer(currentIndex, false)
            end
            if unlockedIndex ~= -1 then
                local playerObj = getSpecificPlayer(self.player)
                if playerObj:getJoypadBind() ~= -1 then
                    self.backpackChoice = unlockedIndex
                end
                self:selectContainer(self.backpacks[unlockedIndex])
            end
        end
    end
end


---Places the lock texture over the button and prevents it from working
local function containerLockOut(UI, STEP)
    if STEP == "buttonsAdded" then
        local firstOpen
        for index,containerButton in ipairs(UI.backpacks) do
            local mapObj = containerButton.inventory:getParent()
            if mapObj then

                local canView = canInteractWithContents(mapObj)

                if not canView then
                    if containerButton then
                        containerButton.onclick = nil
                        containerButton.onmousedown = nil
                        containerButton.onMouseUp = nil
                        containerButton.onRightMouseDown = nil
                        containerButton:setOnMouseOverFunction(nil)
                        containerButton:setOnMouseOutFunction(nil)
                        containerButton.textureOverride = getTexture("media/ui/lock.png")
                    end
                else
                    firstOpen = firstOpen or index
                end
            end
        end
        UI.inventoryPane.inventory = UI.backpacks[firstOpen or #UI.backpacks].inventory
    end
end
Events.OnRefreshInventoryWindowContainers.Add(containerLockOut)
