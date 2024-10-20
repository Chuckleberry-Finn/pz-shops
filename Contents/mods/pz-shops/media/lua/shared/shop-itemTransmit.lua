local itemTransmit = {}

local itemFields = require "shop-itemFields"

---@param playerObj IsoPlayer|IsoGameCharacter
function itemTransmit.doIt(itemsToTransmit, playerObj)
    if #itemsToTransmit <= 0 then return end
    if isServer() then sendServerCommand(playerObj, "shop", "transmitItems", {items=itemsToTransmit}) return end

    for _,data in pairs(itemsToTransmit) do
        local itemType = data.item
        local fields = data.fields

        local item = InventoryItemFactory.CreateItem(itemType)

        if fields then
            local fieldFunc = itemFields.getFieldAssociatedFunctions(item)
            for field,func in pairs(fieldFunc) do
                local value = fields[field]
                if value then

                    local specialFunc = itemFields.specials[func]
                    if specialFunc then
                        local valid = specialFunc(item, value)
                        if (not valid) then specialFunc = false end
                    end

                    local associatedFunc = (not specialFunc) and item[func]
                    if associatedFunc and value then
                        associatedFunc(item, value)
                    end
                end
            end
        end

        playerObj:getInventory():AddItem(item)
    end
end

return itemTransmit