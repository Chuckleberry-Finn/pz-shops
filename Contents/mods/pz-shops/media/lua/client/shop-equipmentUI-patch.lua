if not getActivatedMods():contains("EQUIPMENT_UI") then return end
print("PATCHING: pz-shops-and-traders = EQUIPMENT_UI")

require "shop-window"

local function patchFunction(item, playerNum)

    local storeWindow = storeWindow.instance
    if not storeWindow then return end

    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj or playerObj ~= storeWindow.player then return end

    if storeWindow.yourCartData and storeWindow.yourCartData:isMouseOver() then storeWindow:addItemToYourCart(item) end
end

local WeaponSlot_dropOrUnequip = WeaponSlot.dropOrUnequip
function WeaponSlot:dropOrUnequip()
    WeaponSlot_dropOrUnequip(self)
    local item = self:getHandItem()
    patchFunction(item, self.playerNum)
end

local HotbarSlot_dropOrUnequip = HotbarSlot.dropOrUnequip
function HotbarSlot:dropOrUnequip()
    HotbarSlot_dropOrUnequip(self)
    local item = self:getItem()
    patchFunction(item, self.playerNum)
end

local EquipmentSuperSlot_dropOrUnequip = EquipmentSuperSlot.dropOrUnequip
function EquipmentSuperSlot:dropOrUnequip()
    EquipmentSuperSlot_dropOrUnequip(self)
    local item = self:getTopItem()
    patchFunction(item, self.playerNum)
end

local EquipmentSlot_dropOrUnequip = EquipmentSlot.dropOrUnequip
function EquipmentSlot:dropOrUnequip()
    EquipmentSlot_dropOrUnequip(self)
    local item = self.item
    patchFunction(item, self.playerNum)
end