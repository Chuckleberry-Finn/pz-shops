if not getActivatedMods():contains("INVENTORY_TETRIS") then return end

require "InventoryTetris/Events"
require "InventoryTetris/ItemGrid/UI/Grid/ItemGridUI_rendering"
require "Notloc/NotUtil"
require "shop-wallet.lua"
local _internal = require "shop-shared"

--ItemGridUI.registerItemHoverColor(TetrisItemCategory.AMMO, TetrisItemCategory.MAGAZINE, ItemGridUI.GENERIC_ACTION_COLOR)

local shopsMoneyHandler = {}

function shopsMoneyHandler.validate(eventData, droppedStack, fromInventory, targetStack, targetInventory, playerNum)
    ---@type InventoryItem
    local dropItem = droppedStack.items[1]
    ---@type InventoryItem
    local targetItem = targetStack.items[1]

    if not dropItem or not targetItem then return false end

    if not _internal.isMoneyType(dropItem:getFullType()) then return false end
    if not _internal.isMoneyType(targetItem:getFullType()) then return false end

    if not dropItem:isInPlayerInventory() or not targetItem:isInPlayerInventory() then return false end

    return true
end

function shopsMoneyHandler.call(eventData, droppedStack, fromInventory, targetStack, targetInventory, playerNum)
    local moneyTarget = targetStack.items
    local moneyDropped = droppedStack.items

    if moneyTarget[1]:getFullType() ~= moneyDropped[1]:getFullType() then return end

    local playerObj = getSpecificPlayer(playerNum)
    local finalStackItem = moneyTarget[1]
    local stackValue = finalStackItem:getModData().value

    for n=#moneyTarget, 2, -1 do
        local i = moneyTarget[n]
        if finalStackItem ~= i then
            stackValue = stackValue+i:getModData().value
            safelyRemoveMoney(i, playerObj)
        end
    end

    for n=#moneyDropped, 2, -1 do
        local i = moneyDropped[n]
        if finalStackItem ~= i then
            stackValue = stackValue+i:getModData().value
            safelyRemoveMoney(i, playerObj)
        end
    end

    generateMoneyValue(finalStackItem, stackValue, true)
end


require("InventoryTetris/TetrisItemData")
function shopsMoneyHandler.itemPackChanges()
    local itemPack = { ["Base.Money"] = { ["height"] = 1, ["width"] = 1, ["maxStackSize"] = 1, }, }
    TetrisItemData.registerItemDefinitions(itemPack)
end
Events.OnGameBoot.Add(shopsMoneyHandler.itemPackChanges)


--[[
local shopsMoneyValueLabel = {}
shopsMoneyValueLabel.fontHeight = getTextManager():getFontHeight(UIFont.NewSmall)
---@param item InventoryItem
function shopsMoneyValueLabel.call(eventData, drawingContext, item, gridStack, x, y, width, height, playerObj)

    local right = x+width
    local bottom = y+height-shopsMoneyValueLabel.fontHeight-1

    local stackValue = item:getName()
    drawingContext:drawTextRight(stackValue, right, bottom, 1, 1, 1, 1, UIFont.NewSmall)
end
--]]


local ticks = 0
function shopsMoneyHandler.initiate()
    ticks = ticks+1
    if TetrisEvents or ticks > 500 then
        if TetrisEvents then
            TetrisEvents.OnStackDroppedOnStack:add(shopsMoneyHandler)
            --TetrisEvents.OnPostRenderGridItem:add(shopsMoneyValueLabel)
        end
        Events.OnTickEvenPaused.Remove(shopsMoneyHandler.initiate)
    end
end

Events.OnTickEvenPaused.Add(shopsMoneyHandler.initiate)
