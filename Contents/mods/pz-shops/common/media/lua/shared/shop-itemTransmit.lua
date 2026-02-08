local itemTransmit = {}

local itemFields = require "shop-itemFields"

---@param playerObj IsoPlayer|IsoGameCharacter
function itemTransmit.doIt(itemsToTransmit, playerObj)
    if #itemsToTransmit <= 0 then return end
    
    if isClient() and not isServer() then return end

    for _, data in pairs(itemsToTransmit) do
        local itemType = data.item
        local fields = data.fields

        itemType = string.find(itemType, "Moveables.") and "Moveables.Moveable" or itemType

        local item = instanceItem(itemType)
        
        if not item then
            print("[Shop] Failed to create item: " .. tostring(itemType))
        else
            if fields then
                local fieldFunc = itemFields.getFieldAssociatedFunctions(item)
                for field, func in pairs(fieldFunc) do
                    local value = fields[field]
                    if value then
                        local specialFunc = itemFields.specials[func]
                        if specialFunc then
                            local valid = specialFunc(item, value)
                            if not valid then specialFunc = false end
                        end

                        local associatedFunc = (not specialFunc) and item[func]
                        if associatedFunc and value then
                            associatedFunc(item, value)
                        end
                    end
                end
            end

            playerObj:getInventory():AddItem(item)
            
            syncItemModData(playerObj, item)
            sendAddItemToContainer(playerObj:getInventory(), item)
        end
    end
end

return itemTransmit
