local function printTable(tbl)
    local output = ""
    for k,v in pairs(tbl) do
        if type(v)=="table" then output = output.."\n\[\""..k.."\"\] = {"..printTable(v).."}, "
        else output = output.."\n"..k.." = "..tostring(v)..", "
        end
    end
    return output
end

function printStoresOutput()
    print("STORES:")
    print(printTable(CLIENT_STORES))
end