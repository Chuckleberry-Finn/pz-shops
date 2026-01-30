local function testCanThump(object, playerObj)
    if not object then return false end
    local objectModData = object:getModData()
    if objectModData then
        local storeObjID = objectModData.storeObjID
        if storeObjID then return false end
    end
    return true
end

--LuaEventManager.triggerEvent("OnWeaponHitThumpable", player, weapon, thump)
---@param weapon HandWeapon
---@param thump IsoThumpable
local function onWeaponHitThumpable(player, weapon, thump)
    if player and weapon and thump and instanceof(thump, "IsoThumpable") and testCanThump(thump, player) then
        local dmg = weapon:getDoorDamage()
        thump:setHealth(thump:getHealth()+dmg)
    end
end
Events.OnWeaponHitThumpable.Add(onWeaponHitThumpable)