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


function _internal.clipStrTbl(inputstr)
    if string.sub(inputstr, 1, 1)=="{" and string.sub(inputstr,string.len(inputstr))=="}" then
        inputstr = inputstr:sub(2)--delete first char
        inputstr = inputstr:sub(1, -3)--delete the last 2 char
        return inputstr
    end
end


function _internal.stringToTable(inputstr)
    local t={}
    inputstr = inputstr:gsub("  ", "")
    inputstr = inputstr:gsub("\n", "")
    inputstr = _internal.clipStrTbl(inputstr) or inputstr
    print("inputstr: "..inputstr)
    local header, body = string.match(inputstr, "%[\"(.-)\"%] ="), string.match(inputstr, "= (.*)")
    print(" > header: "..tostring(header)..", body:"..tostring(body))
    if body then
        local bodyContainsTbl = _internal.clipStrTbl(body)
        if bodyContainsTbl then
            body = bodyContainsTbl
            local newBody = {}
            local subBodyStr
            for str in string.gmatch(body, "([^,]+)") do
                print(" >> str: "..str.." ; subBodyStr: "..tostring(subBodyStr))
                if string.find(str, "{") or subBodyStr then
                    print(" >>>> str: "..str.." ; subBodyStr: "..tostring(subBodyStr))
                    subBodyStr = (subBodyStr or "")..str..","
                    print(" >1>> str: "..str.." ; subBodyStr: "..tostring(subBodyStr))
                end
                if string.find(str, "}") then
                    str = (subBodyStr or "")..str
                    subBodyStr = nil
                    print(" >2>> str: "..str.." ; subBodyStr: "..tostring(subBodyStr))
                end
                if not subBodyStr then for k,v in pairs(_internal.stringToTable(str)) do newBody[k] = v end end
            end
            body = newBody
        else
            if body == "false" then body = false
            elseif body == "true" then body = true
            elseif body == tostring(tonumber(body)) then body = tonumber(body)
            else body = body:gsub("\"", "")
            end
        end
    end
    if header~=nil and body~=nil then t[header] = body end
    return t
end

---local tblTbl = load("return "..tblStr)()

--[[

_internal = {} function _internal.clipStrTbl(inputstr) if string.sub(inputstr, 1, 1)=="{" and string.sub(inputstr,string.len(inputstr))=="}" then inputstr = inputstr:sub(2) inputstr = inputstr:sub(1, -3) return inputstr end end

function _internal.stringToTable(inputstr)
    local t={}
    inputstr = inputstr:gsub("  ", "")
    inputstr = inputstr:gsub("\n", "")
    inputstr = _internal.clipStrTbl(inputstr) or inputstr
    print("inputstr: "..inputstr)
    local header, body = string.match(inputstr, "%[\"(.-)\"%] ="), string.match(inputstr, "= (.*)")
    print(" > header: "..tostring(header)..", body:"..tostring(body))
    if body then
        local bodyContainsTbl = _internal.clipStrTbl(body)
        if bodyContainsTbl then
            body = bodyContainsTbl
            local newBody = {}
            local subBodyStr
            for str in string.gmatch(body, "([^,]+)") do
                print(" >> str: "..str.." ; subBodyStr: "..tostring(subBodyStr))
                if string.find(str, "{") or subBodyStr then
                    print(" >>>> str: "..str.." ; subBodyStr: "..tostring(subBodyStr))
                    subBodyStr = (subBodyStr or "")..str..","
                    print(" >1>> str: "..str.." ; subBodyStr: "..tostring(subBodyStr))
                end
                if string.find(str, "}") then
                    str = (subBodyStr or "")..str
                    subBodyStr = nil
                    print(" >2>> str: "..str.." ; subBodyStr: "..tostring(subBodyStr))
                end
                if not subBodyStr then for k,v in pairs(_internal.stringToTable(str)) do newBody[k] = v end end
            end
            body = newBody
        else
            if body == "false" then body = false
            elseif body == "true" then body = true
            elseif body == tostring(tonumber(body)) then body = tonumber(body)
            else body = body:gsub("\"", "")
            end
        end
    end
    if header~=nil and body~=nil then t[header] = body end
    return t
end

local tblStr = [[{["a"] = {["aa"] = 1, ["bb"] = "text-2", ["cc"] = true, ["dd"] = {["name"] = "text-name", ["price"] = 11,},},}]]
--local tblTbl = _internal.stringToTable(tblStr) function dump(o) if type(o) == 'table' then local s = '{ ' for k,v in pairs(o) do if type(k) ~= 'number' then k = '"'..k..'"' end s = s .. '['..k..'] = ' .. dump(v) .. ',' end return s .. '} ' else return tostring(o) end end print(dump(tblTbl))
