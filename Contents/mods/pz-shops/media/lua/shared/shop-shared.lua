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


function _internal.generateMoneyValue_clientWorkAround(item, value, force)
    generateMoneyValue(item, value, force)
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
    if props:Is("CustomName") then
        local name = props:Val("CustomName")
        if props:Is("GroupName") then name = props:Val("GroupName") .. " " .. name end
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
        if type(object) == "string" then
            local escaped = tostring(object):gsub('\\','\\\\'):gsub('"','\\"')
            text = "\""..escaped.."\""
        else text = tostring(object)
        end
    end
    return text
end


local sp = {}

function sp.skip(p)
    while p.pos <= p.len do
        local b = p.str:byte(p.pos)
        if b==32 or b==9 or b==10 or b==13 then p.pos=p.pos+1 else break end
    end
end

function sp.parseString(p)
    p.pos = p.pos+1
    local parts = {}
    while p.pos <= p.len do
        local c = p.str:sub(p.pos,p.pos)
        if c == '"' then p.pos=p.pos+1 return table.concat(parts)
        elseif c == '\\' then
            p.pos = p.pos+1
            parts[#parts+1] = p.str:sub(p.pos,p.pos)
            p.pos = p.pos+1
        else parts[#parts+1]=c p.pos=p.pos+1 end
    end
    error("unterminated string literal")
end

function sp.parseTable(p)
    p.pos = p.pos+1
    local t = {}
    sp.skip(p)
    if p.str:sub(p.pos,p.pos)=='}' then p.pos=p.pos+1 return t end
    while p.pos <= p.len do
        sp.skip(p)
        if p.str:sub(p.pos,p.pos) ~= "[" then error("expected '[' to start a key at position "..p.pos) end
        p.pos = p.pos+1
        sp.skip(p)
        if p.str:sub(p.pos,p.pos) ~= '"' then error("expected string key at position "..p.pos) end
        local key = sp.parseString(p)
        sp.skip(p)
        if p.str:sub(p.pos,p.pos) ~= "]" then error("expected ']' at position "..p.pos) end
        p.pos = p.pos+1
        sp.skip(p)
        if p.str:sub(p.pos,p.pos) ~= "=" then error("expected '=' at position "..p.pos) end
        p.pos = p.pos+1
        sp.skip(p)
        t[key] = sp.parseValue(p)
        sp.skip(p)
        local c = p.str:sub(p.pos,p.pos)
        p.pos = p.pos+1
        if c=='}' then return t elseif c~=',' then error("expected ',' or '}' at position "..p.pos) end
        sp.skip(p)
        if p.str:sub(p.pos,p.pos)=='}' then p.pos=p.pos+1 return t end
    end
    error("unterminated table")
end

function sp.parseValue(p)
    sp.skip(p)
    local c = p.str:sub(p.pos,p.pos)
    if c=='{' then return sp.parseTable(p)
    elseif c=='"' then return sp.parseString(p)
    elseif p.str:sub(p.pos,p.pos+3)=="true"  then p.pos=p.pos+4 return true
    elseif p.str:sub(p.pos,p.pos+4)=="false" then p.pos=p.pos+5 return false
    elseif p.str:sub(p.pos,p.pos+2)=="nil"   then p.pos=p.pos+3 return nil
    else
        local numStr = p.str:match("^%-?%d+%.?%d*[eE]?[%+%-]?%d*", p.pos)
        if numStr and #numStr > 0 then
            p.pos = p.pos+#numStr
            local n = tonumber(numStr)
            if not n then error("invalid number literal '"..numStr.."' at position "..p.pos) end
            return n
        end
        error("unexpected token at position "..p.pos)
    end
end

function _internal.stringToTable(inputstr)
    if type(inputstr) ~= "string" then
        return false, "input is not a string"
    end

    local p = {str=inputstr, pos=1, len=#inputstr}
    local ok, data = pcall(sp.parseValue, p)
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