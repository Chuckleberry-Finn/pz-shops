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


function _internal.jsonEncode(val, depth)
    depth = depth or 0
    local t = type(val)
    if val == nil then return "null"
    elseif t == "boolean" then return val and "true" or "false"
    elseif t == "number" then return tostring(val)
    elseif t == "string" then
        return '"'..val:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t')..'"'
    elseif t == "table" then
        local n = 0
        for _ in pairs(val) do n = n+1 end
        if n == 0 then return "{}" end
        local indent = string.rep("  ", depth+1)
        local closing = string.rep("  ", depth)
        if n == #val then
            local parts = {}
            for i=1,n do parts[i] = indent.._internal.jsonEncode(val[i], depth+1) end
            return "[\n"..table.concat(parts, ",\n").."\n"..closing.."]"
        else
            local parts = {}
            for k,v in pairs(val) do
                table.insert(parts, indent.._internal.jsonEncode(tostring(k)).." : ".._internal.jsonEncode(v, depth+1))
            end
            return "{\n"..table.concat(parts, ",\n").."\n"..closing.."}"
        end
    end
    return "null"
end


local jp = {}

function jp.skip(p)
    while p.pos <= p.len do
        local b = p.str:byte(p.pos)
        if b==32 or b==9 or b==10 or b==13 then p.pos=p.pos+1 else break end
    end
end

function jp.parseString(p)
    p.pos = p.pos+1
    local parts = {}
    while p.pos <= p.len do
        local c = p.str:sub(p.pos,p.pos)
        if c == '"' then p.pos=p.pos+1 return table.concat(parts)
        elseif c == '\\' then
            p.pos = p.pos+1
            local e = p.str:sub(p.pos,p.pos)
            if     e=='"'  then parts[#parts+1]='"'
            elseif e=='\\'then parts[#parts+1]='\\'
            elseif e=='/'  then parts[#parts+1]='/'
            elseif e=='n'  then parts[#parts+1]='\n'
            elseif e=='r'  then parts[#parts+1]='\r'
            elseif e=='t'  then parts[#parts+1]='\t'
            else                parts[#parts+1]=e end
            p.pos = p.pos+1
        else parts[#parts+1]=c p.pos=p.pos+1 end
    end
    error("unterminated string")
end

function jp.parseObject(p)
    p.pos = p.pos+1
    local t = {}
    jp.skip(p)
    if p.str:sub(p.pos,p.pos)=='}' then p.pos=p.pos+1 return t end
    while p.pos <= p.len do
        jp.skip(p)
        local key = jp.parseString(p)
        jp.skip(p)
        p.pos = p.pos+1
        jp.skip(p)
        t[key] = jp.parseValue(p)
        jp.skip(p)
        local c = p.str:sub(p.pos,p.pos)
        p.pos = p.pos+1
        if c=='}' then return t elseif c~=',' then error("expected ',' or '}'") end
    end
    error("unterminated object")
end

function jp.parseArray(p)
    p.pos = p.pos+1
    local t = {}
    jp.skip(p)
    if p.str:sub(p.pos,p.pos)==']' then p.pos=p.pos+1 return t end
    while p.pos <= p.len do
        jp.skip(p)
        t[#t+1] = jp.parseValue(p)
        jp.skip(p)
        local c = p.str:sub(p.pos,p.pos)
        p.pos = p.pos+1
        if c==']' then return t elseif c~=',' then error("expected ',' or ']'") end
    end
    error("unterminated array")
end

function jp.parseValue(p)
    jp.skip(p)
    local c = p.str:sub(p.pos,p.pos)
    if c=='"' then return jp.parseString(p)
    elseif c=='{' then return jp.parseObject(p)
    elseif c=='[' then return jp.parseArray(p)
    elseif p.str:sub(p.pos,p.pos+3)=="null"  then p.pos=p.pos+4 return nil
    elseif p.str:sub(p.pos,p.pos+3)=="true"  then p.pos=p.pos+4 return true
    elseif p.str:sub(p.pos,p.pos+4)=="false" then p.pos=p.pos+5 return false
    else
        local numStr = p.str:match("^-?%d+%.?%d*[eE]?[+%-]?%d*", p.pos)
        if numStr then p.pos=p.pos+#numStr return tonumber(numStr) end
        error("unexpected character '"..c.."' at pos "..p.pos)
    end
end

function _internal.jsonDecode(str)
    if not str or str == "" then return nil, "empty input" end
    local p = {str=str, pos=1, len=#str}
    local ok, result = pcall(jp.parseValue, p)
    if not ok then return nil, result end
    return result
end


function _internal.getSavePath(namespace, filename)
    local fullPath = getCurrentSaveName()
    if not fullPath or fullPath == "" then return filename end
    local sep = getFileSeparator()
    local parts = {}
    for part in fullPath:gmatch("[^%" .. sep .. "]+") do
        table.insert(parts, part)
    end
    if #parts < 2 then return filename end
    local saveName = parts[#parts - 1] .. sep .. parts[#parts]
    return namespace .. sep .. saveName .. sep .. filename
end


return _internal
