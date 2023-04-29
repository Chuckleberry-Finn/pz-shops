require "ISUI/ISCraftingUI"
local _internal = require "shop-shared"


local _GetItemInstance = ISCraftingUI.GetItemInstance
function ISCraftingUI:GetItemInstance(itemType)

    local item = _GetItemInstance(self, itemType)

    if item and _internal.isMoneyType(itemType) then
        item:setName(item:getScriptItem():getDisplayName())
    end

    return item
end