require "Moveables/ISMoveableSpriteProps"

local function testCanScrap(object, playerObj)
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



local function checkCanScrapStore(module, func, playerObj, object)
    local result, chance, perkName = func(module, playerObj)
    result.canScrap = testCanScrap(object, playerObj)
    return result, chance, perkName
end


local _thumpCanScrapObject = ISThumpableSpriteProps.canScrapObject
function ISThumpableSpriteProps:canScrapObject(playerObj)
    local result, chance, perkName = checkCanScrapStore(self, _thumpCanScrapObject, playerObj, self.object)
    return result, chance, perkName
end


local _moveableCanScrapObject = ISMoveableSpriteProps.canScrapObject
function ISMoveableSpriteProps:canScrapObject(playerObj)
    local result, chance, perkName = checkCanScrapStore(self, _moveableCanScrapObject, playerObj, self.object)
    return result, chance, perkName
end



local function getCanScrapInfoPanelDesc(_object, _player, infoTable)
    local bR,bG,bB = ISMoveableSpriteProps.bhc:getR()*255, ISMoveableSpriteProps.bhc:getG()*255, ISMoveableSpriteProps.bhc:getB()*255
    if testCanScrap(_object, _player)==false then
        infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, "- "..getText("IGUI_CantDisassembleStore"), bR,bG,bB )
    end
end


local _getThumpableInfoPanelDescription = ISThumpableSpriteProps.getInfoPanelDescription
function ISThumpableSpriteProps:getInfoPanelDescription(_square, _object, _player, _mode)
    local infoTable = _getThumpableInfoPanelDescription(self, _square, _object, _player, _mode)
    getCanScrapInfoPanelDesc(_object, _player, infoTable)
    return infoTable
end


local _getMoveableInfoPanelDescription = ISMoveableSpriteProps.getInfoPanelDescription
function ISMoveableSpriteProps:getInfoPanelDescription(_square, _object, _player, _mode)
    local infoTable = _getMoveableInfoPanelDescription(self, _square, _object, _player, _mode)
    getCanScrapInfoPanelDesc(_object, _player, infoTable)
    return infoTable
end