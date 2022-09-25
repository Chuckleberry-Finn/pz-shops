---internal functions for handling tables more object-like (copy/new/etc)
_internal = {}

function _internal.floorCurrency(n) return math.floor(n*100)/100 end
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


function _internal.getMapObjectName(obj)
    if not obj then return nil end
    if not obj:getSprite() then return nil end
    local props = obj:getSprite():getProperties()
    if props:Is("CustomName") then
        local name = props:Val("CustomName")
        if props:Is("GroupName") then name = props:Val("GroupName") .. " " .. name end
        return name
    end
    return nil
end


function _internal.getMapObjectDisplayName(obj)
    local nameFound = _internal.getMapObjectName(obj)
    if nameFound then return Translator.getMoveableDisplayName(nameFound) end
end


function _internal.tableToString(object,nesting)
    nesting = nesting or 0
    local text = ""..string.rep("  ", nesting)
    if type(object) == 'table' then
        local s = "{\n"
        for k,v in pairs(object) do
            s = s..string.rep("  ", nesting+1).."\[\""..k.."\"\] = ".._internal.tableToString(v,nesting+1)..",\n"
        end
        text = s..string.rep("  ", nesting).."}"
    else
        if type(object) == "string" then text = "\""..tostring(object).."\""
        else text = tostring(object)
        end
    end
    return text
end


function _internal.stringToTable(inputstr, sep)
    sep = sep or '%[.-%,}'
    local t={}
    inputstr = inputstr:gsub("  ", "")
    inputstr = inputstr:gsub("\n", "")

    for str in string.gmatch(inputstr, sep) do
        local header = string.match(str, "%[\"(.-)\"%] =")
        local body = string.match(str, "= (.*)")
        if body then
            if string.sub(body, 1, 1)=="{" and string.sub(body,string.len(body))=="}" then
                body = _internal.stringToTable(body, "([^,]+)")
            else
                if body == "false" then body = false
                elseif body == "true" then body = true
                elseif body == tostring(tonumber(body)) then body = tonumber(body)
                else body = body:gsub("\"", "")
                end
            end
        end
        if header~=nil and body~=nil then  t[header] = body end
    end
    return t
end