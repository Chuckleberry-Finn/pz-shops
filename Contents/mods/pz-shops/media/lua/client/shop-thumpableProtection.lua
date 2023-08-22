local function testCanThump(object, playerObj)
    if not object then return false end
    local objectModData = object:getModData()
    if objectModData then
        local storeObjID = objectModData.storeObjID
        if storeObjID then
            local storeObj = CLIENT_STORES[storeObjID]
            if storeObj then return false end
        end
    end
    return true
end

--LuaEventManager.triggerEvent("OnWeaponHitThumpable", player, weapon, thump)
---@param weapon HandWeapon
---@param thump IsoThumpable
local function onWeaponHitThumpable(player, weapon, thump)
    if weapon and testCanThump(thump, player) then
        local dmg = weapon:getDoorDamage()
        thump:setHealth(thump:getHealth()+dmg)
    end
end
Events.OnWeaponHitThumpable.Add(onWeaponHitThumpable)