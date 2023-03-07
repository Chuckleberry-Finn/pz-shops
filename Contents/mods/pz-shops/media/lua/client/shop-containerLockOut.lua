require "ISUI/ISInventoryPane"
require "ISUI/ISInventoryPage"

local containerLockOut = {}

---Validates if the worldObject can be interacted with
function containerLockOut.canInteract(worldObject)
    if not worldObject then return true end

    local canView = true
    local worldObjectModData = worldObject:getModData()
    if worldObjectModData then
        local storeObjID = worldObjectModData.storeObjID
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
        if containerLockOut.canInteract(self.destContainer:getParent()) and containerLockOut.canInteract(self.srcContainer:getParent()) then
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
        local worldObj = container:getParent()
        if worldObj then allow = containerLockOut.canInteract(worldObj) end
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


---Slides the inventory page over to the next available page when scrolling up
local ISInventoryPage_prevUnlockedContainer = ISInventoryPage.prevUnlockedContainer
function ISInventoryPage:prevUnlockedContainer(index, wrap)
    local _index = ISInventoryPage_prevUnlockedContainer(self, index, wrap)
    if _index ~= -1 then
        local backpack = self.backpacks[_index]
        local object = backpack.inventory:getParent()
        if not containerLockOut.canInteract(object) then
            return self:prevUnlockedContainer(_index, true)
        end
    end
    return _index
end


---Slides the inventory page over to the next available page when scrolling down
local ISInventoryPage_nextUnlockedContainer = ISInventoryPage.nextUnlockedContainer
function ISInventoryPage:nextUnlockedContainer(index, wrap)
    local _index = ISInventoryPage_nextUnlockedContainer(self, index, wrap)
    if _index ~= -1 then
        local backpack = self.backpacks[_index]
        local object = backpack.inventory:getParent()
        if not containerLockOut.canInteract(object) then
            return self:nextUnlockedContainer(_index, true)
        end
    end
    return _index
end


---Slides the inventory page over to the next available page on update
local ISInventoryPage_update = ISInventoryPage.update
function ISInventoryPage:update()
    ISInventoryPage_update(self)
    if not self.onCharacter then
        -- If the currently-selected container is locked to the player, select another container.
        local object = self.inventory and self.inventory:getParent() or nil
        if object and #self.backpacks > 1 and (not containerLockOut.canInteract(object)) then
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
local function hideButtons(UI, STEP)
    if STEP == "end" and (not UI.onCharacter) then

        for index,containerButton in ipairs(UI.backpacks) do
            local worldObj = containerButton.inventory:getParent()
            if worldObj then

                local canView = containerLockOut.canInteract(worldObj)

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
                end
            end
        end
    end
end

Events.OnRefreshInventoryWindowContainers.Add(hideButtons)

return containerLockOut