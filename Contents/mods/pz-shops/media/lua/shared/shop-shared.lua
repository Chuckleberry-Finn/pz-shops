---internal functions for handling tables more object-like (copy/new/etc)
_internal = {}

function _internal.floorCurrency(n) return math.floor(n*100)/100 end
function _internal.numToCurrency(n) return string.format("%.2f", _internal.floorCurrency(n)) end

function _internal.copyAgainst(tableA,tableB)
    if not tableA or not tableB then return end

    for key,value in pairs(tableB) do
        tableA[key] = value
    end

    for key,_ in pairs(tableA) do
        if not tableB[key] then
            tableA[key] = nil
        end
    end
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