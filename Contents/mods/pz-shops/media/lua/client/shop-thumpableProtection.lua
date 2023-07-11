--LuaEventManager.triggerEvent("OnWeaponHitThumpable", player, weapon, thump)
---@param weapon HandWeapon
---@param thump IsoThumpable
local function onWeaponHitThumpable(player, weapon, thump)
    local dmg = weapon:getDoorDamage()
    thump:setHealth(thump:getHealth()+dmg)
end
Events.OnWeaponHitThumpable.Add(onWeaponHitThumpable)