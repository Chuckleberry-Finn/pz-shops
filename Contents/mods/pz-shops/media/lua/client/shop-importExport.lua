local function recursiveTablePrint(object,nesting)
    nesting = nesting or 0
    local text = ""..string.rep("  ", nesting)
    if type(object) == 'table' then
        local s = "{ \n"
        for k,v in pairs(object) do
            s = s..string.rep("  ", nesting+1).."\["..k.."\] = "..recursiveTablePrint(v,nesting+1)..",\n"
        end
        text = s..string.rep("  ", nesting).."}\n"
    else
        text = tostring(object) end
    return text
end

function printStoresOutput()
    print("STORES:")
    print("\n"..recursiveTablePrint(CLIENT_STORES))
end

