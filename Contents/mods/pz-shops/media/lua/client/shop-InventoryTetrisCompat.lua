if not getActivatedMods():contains("INVENTORY_TETRIS") then return end

require "InventoryTetris/ItemGrid/Model/ItemStack.lua"
require "shop-wallet.lua"
local _internal = require "shop-shared"


local addItem = ItemStack.addItem
function ItemStack.addItem(stack, item)

    if not (item and item:isInPlayerInventory() and _internal.isMoneyType(item:getFullType()) and ItemStack.isSameType(stack, item)) then
        addItem(stack, item)
        return
    end

    local player = getPlayer()
    local finalStackItem

    local itemValue = item:getModData().value
    local stackItems = ItemStack.getAllItems(stack, player:getInventory())

    local stackValue = 0

    for n=#stackItems, 1, -1 do
        local i = stackItems[n]
        stackValue = stackValue+i:getModData().value
        if not finalStackItem then
            finalStackItem = i
        else
            safelyRemoveMoney(i, player)
        end
    end
    safelyRemoveMoney(item, player)

    generateMoneyValue(finalStackItem, stackValue+itemValue, true)
end