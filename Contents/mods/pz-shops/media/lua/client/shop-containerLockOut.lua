--triggerEvent("OnRefreshInventoryWindowContainers", self, "buttonsAdded")
local function containerLockOut(UI)
    local found = false
    local foundIndex = -1
    for index,containerButton in ipairs(UI.backpacks) do

        not (isAdmin() or isCoopHost() or getDebug())

        if containerButton.inventory == UI.inventoryPane.inventory then
            containerButton.onclick = nil
            containerButton.onmousedown = nil
            containerButton:setOnMouseOverFunction(nil)
            containerButton:setOnMouseOutFunction(nil)
            containerButton.textureOverride = getTexture("media/ui/lock.png")
        end
    end
end
Events.OnRefreshInventoryWindowContainers.Add(containerLockOut)