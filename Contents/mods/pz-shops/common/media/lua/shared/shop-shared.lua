---internal functions for handling tables more object-like (copy/new/etc)
local _internal = {}

local moneyTypes = {"Base.Money"}

local _moneyTypes
function _internal.validateMoneyTypes()
    if not _moneyTypes then
        _moneyTypes = {}
        for _,type in pairs(moneyTypes) do _moneyTypes[type] = true end
    end
end


_internal.valuedMoney = {}
---@param item InventoryItem
function _internal.generateMoneyValue(item, value, force)
    if item ~= nil and _internal.isMoneyType(item:getFullType()) and (not _internal.valuedMoney[item] or force) then

        if (not item:getModData().value) or force then

            local min = (SandboxVars.ShopsAndTraders.MoneySpawnMin or 1.5)*100
            local max = (SandboxVars.ShopsAndTraders.MoneySpawnMax or 25)*100

            value = value or ((ZombRand(min,max)/100)*100)/100
            item:getModData().value = value
            item:setName(_internal.numToCurrency(value))
        end
        item:setActualWeight(SandboxVars.ShopsAndTraders.MoneyWeight*item:getModData().value)

        --if isServer() or not isClient() then syncItemModData(item) end
        ---unclear what to sync here
    end
    _internal.valuedMoney[item] = true
end


function _internal.checkObjectForShop(object)
    if object and (not instanceof(object, "IsoWorldInventoryObject")) then
        local objStoreID = object:getModData().storeObjID
        local x, y, z, worldObjName = object:getX(), object:getY(), object:getZ(), _internal.getWorldObjectName(object)

        if objStoreID then
            sendClientCommand("shop", "checkMapObject", { storeID=objStoreID, x=x, y=y, z=z, worldObjName=worldObjName })
        else
            sendClientCommand("shop", "checkLocation", { x=x, y=y, z=z, worldObjName=worldObjName })
        end
    end
end


function _internal.getMoneyTypes()
    _internal.validateMoneyTypes()
    return moneyTypes
end

function _internal.isMoneyType(itemType)
    _internal.validateMoneyTypes()
    return _moneyTypes[itemType]
end


function _internal.floorCurrency(n)
    return Math.round(n*100)/100
end
function _internal.numToCurrency(n)
    local formatted = string.format("%.2f", _internal.floorCurrency(n))
    formatted = formatted:gsub("%.00", "")
    return getText("IGUI_CURRENCY_PREFIX")..formatted.." "..getText("IGUI_CURRENCY_SUFFIX")
end

function _internal.copyAgainst(tableA,tableB)
    if not tableA or not tableB then return end
    for key,value in pairs(tableB) do tableA[key] = value end
    for key,_ in pairs(tableA) do if not tableB[key] then tableA[key] = nil end end
end


function _internal.getWorldObjectName(obj)
    if not obj then return "No-Object-Error" end
    if not obj:getSprite() then
        return obj:getObjectName()
    end

    local props = obj:getSprite():getProperties()
    if props:get("CustomName") then
        local name = props:get("CustomName")
        local groupName = name and props:get("GroupName")
        if groupName then
            name = groupName .. " " .. name
        end
        return name
    end
    return "IsoObject"
end


function _internal.getWorldObjectDisplayName(obj)
    local nameFound = _internal.getWorldObjectName(obj)
    if nameFound then
        local translatedName = Translator.getMoveableDisplayName(nameFound)
        return translatedName
    end
end


function _internal.isAdminHostDebug()
    if (not isClient()) and (not isServer()) then return true end
    if (isAdmin() or isCoopHost() or getDebug()) then return true end
    return false
end


function _internal.canManageStore(storeObj,player)
    if _internal.isAdminHostDebug() then return true end
    if not storeObj then return false end
    if not player then return false end
    local shopOwnerID = storeObj.ownerID
    local playerUsername = player:getUsername()
    if playerUsername and shopOwnerID and playerUsername==shopOwnerID then return true end
    if storeObj.managerIDs and storeObj.managerIDs[playerUsername] then return true end
    return false
end


function _internal.tableToString(object,nesting)
    nesting = nesting or 0
    local indent = "    "
    local text = ""..string.rep(indent, nesting)
    if type(object) == 'table' then
        local s = "{\n"
        for k,v in pairs(object) do
            s = s..string.rep(indent, nesting+1).."\[\""..k.."\"\] = ".._internal.tableToString(v,nesting+1)..",\n"
        end
        text = s..string.rep(indent, nesting).."}"
    else
        if type(object) == "string" then text = "\""..tostring(object).."\""
        else text = tostring(object)
        end
    end
    return text
end


function _internal.stringToTable(inputstr)

    local tblTbl, err = loadstring("return "..inputstr)
    if not tblTbl then
        return false, err
    end

    local ok, data = pcall(tblTbl)
    if not ok then
        return false, data
    end

    return data
end

---@param container ItemContainer
function _internal.isValidContainer(container)
    if not container then
        return false
    end

    local shopContainers = SandboxVars.ShopsAndTraders.ShopContainers
    if (not shopContainers) or shopContainers == "" then return true end

    local containerName = _internal.getWorldObjectName(container:getParent())
    for shopContainer in string.gmatch(shopContainers, "([^,]+)") do
        if containerName == shopContainer then
            return true
        end
    end

    return false
end

return _internal
