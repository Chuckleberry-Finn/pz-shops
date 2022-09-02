--require "ISUI/ISInventoryPane"
--require "ISUI/ISInventoryPage"

--[[
local DraggedItems = ISInventoryPaneDraggedItems
local DraggedItems_getDropContainer = DraggedItems.getDropContainer
function DraggedItems:getDropContainer()
    local playerInv = getPlayerInventory(self.playerNum)
    local playerLoot = getPlayerLoot(self.playerNum)



    if not playerInv or not playerLoot then
        return nil
    end
    if playerInv.mouseOverButton then
        return playerInv.mouseOverButton.inventory, "button"
    end
    if playerInv.inventoryPane:isMouseOver() then
        return playerInv.inventoryPane.inventory, "inventory"
    end
    if playerLoot.mouseOverButton then
        return playerLoot.mouseOverButton.inventory, "button"
    end
    if playerLoot.inventoryPane:isMouseOver() then
        return playerLoot.inventoryPane.inventory, "loot"
    end

    local mx = getMouseX()
    local my = getMouseY()
    local uis = UIManager.getUI()
    local mouseOverUI = nil
    for i=0,uis:size()-1 do
        local ui = uis:get(i)
        if ui:isPointOver(mx, my) then
            mouseOverUI = ui
            break
        end
    end
    if not mouseOverUI then
        return ISInventoryPage.GetFloorContainer(self.playerNum), "floor"
    end

    return nil
end
--]]

--[[
local ISInventoryPage_dropItemsInContainer = ISInventoryPage.dropItemsInContainer
function ISInventoryPage:dropItemsInContainer(button)
    local container = self.mouseOverButton and self.mouseOverButton.inventory or nil
    local allow = true

    print("aaa")

    local mapObj = container:getParent()
    if mapObj then
        local storeObjID = mapObj:getModData().storeObjID
        if storeObjID then
            local storeObj = CLIENT_STORES[storeObjID]
            allow = false
            if storeObj.isBeingManaged and (isAdmin() or isCoopHost() or getDebug()) then allow = true end
        end
    end

    print("bbb")

    if allow then ISInventoryPage_dropItemsInContainer(self, button)
        print("ccc")
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
--]]

--[[
local function validStoreObject(mapObject)
    local canView = true
    local storeObjID = mapObject:getModData().storeObjID
    if storeObjID then
        local storeObj = CLIENT_STORES[storeObjID]
        if storeObj.isBeingManaged and (isAdmin() or isCoopHost() or getDebug()) then canView = true end
        canView = false
    end
    return canView
end


local function containerLockOut(UI, STEP)
    if STEP == "buttonsAdded" then

        for index,containerButton in ipairs(UI.backpacks) do
            local mapObj = containerButton.inventory:getParent()
            if mapObj then

                local canView = validStoreObject(mapObj)

                if not canView then
                    containerButton.onclick = nil
                    containerButton.onmousedown = nil
                    containerButton.onMouseUp = nil
                    containerButton.onRightMouseDown = nil
                    containerButton:setOnMouseOverFunction(nil)
                    containerButton:setOnMouseOutFunction(nil)
                    containerButton.textureOverride = getTexture("media/ui/lock.png")

                    UI.removeChild(containerButton)
                    UI.backpacks[index] = nil
                end

            end
        end
    end
end
Events.OnRefreshInventoryWindowContainers.Add(containerLockOut)
--]]