local crossRefMods = {
    ["BetterSortCC"]="ItemTweaker_Copy_CC",
}
local loadedModIDs = {};
local activeModIDs = getActivatedMods()
for i=1, activeModIDs:size() do
    local modID = activeModIDs:get(i-1)
    if crossRefMods[modID] and not loadedModIDs[modID] then
        require (crossRefMods[modID])
        loadedModIDs[modID] = true
    end
end


local itemDictionary = {}
itemDictionary.categories = {}
itemDictionary.partition = {} -- first 3 characters


---NEEDED FOR BETTER SORTING TO WORK IN MP
itemDictionary.itemsToCategories = {}


function getItemDictionary() return itemDictionary end


function itemDictionary.addToPartition(partitionID, result, searchKey)

    if not partitionID or not result or not searchKey then return end

    local input = string.lower(string.sub(searchKey,1,3))
    if input and input ~= "" then
        if not itemDictionary.partition[input] then itemDictionary.partition[input] = {} end
        if not itemDictionary.partition[input][partitionID] then itemDictionary.partition[input][partitionID] = {} end
        itemDictionary.partition[input][partitionID][tostring(searchKey)]=result
    end
end

itemDictionary.pushedToServer = false
function itemDictionary.assemble(pushToServer)

    ---NEEDED FOR BETTER SORTING TO WORK IN MP
    if isServer() or itemDictionary.pushedToServer then return end

    local allItems = getScriptManager():getAllItems()
    for i=0, allItems:size()-1 do
        ---@type Item
        local itemScript = allItems:get(i)
        local itemModule = itemScript:getModuleName()
        if not itemScript:getObsolete() and not itemScript:isHidden() and itemModule ~= "Moveables" then

            local itemModuleType = itemScript:getFullName()
            --itemDictionary.addToPartition("type", itemModuleType, itemScript:getName()) -- type
            itemDictionary.addToPartition("type", itemModuleType, itemModuleType) -- module.type
            itemDictionary.addToPartition("name", itemModuleType, itemScript:getDisplayName()) -- name

            --print("type: "..itemScript:getName().."("..itemModuleType..")  "..itemScript:getDisplayName())

            local displayCategory = itemScript:getDisplayCategory() -- category
            itemDictionary.itemsToCategories[itemModuleType] = displayCategory ---NEEDED FOR BETTER SORTING TO WORK IN MP
            itemDictionary.addToPartition("category", itemModuleType, displayCategory)
            itemDictionary.categories[displayCategory] = true

        end
    end

    if isClient() then
        sendClientCommand("shop", "updateItemDictionary", { itemsToCategories=itemDictionary.itemsToCategories })
        itemDictionary.pushedToServer = true
    end
end


function itemDictionary.sanitizeString(str)
    str = str:gsub("[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1") -- escape pattern
    return str
end


function findMatchesFromItemDictionary(input, partitionID)
    local inputLower = string.lower(input)
    local inputLowerCut = string.sub(inputLower,1,3)

    local partitionMatches = itemDictionary.partition[inputLowerCut]
    if not partitionMatches then return end

    local foundMatches, matchesToTypes = {}, {}
    local sanitizedInputLower = itemDictionary.sanitizeString(inputLower)
    for partition,data in pairs(partitionMatches) do
        if (not partitionID) or (partitionID and partition==partitionID) then
            for searchKey,type in pairs(data) do
                if string.find(string.lower(searchKey),sanitizedInputLower) then
                    table.insert(foundMatches, searchKey)
                    matchesToTypes[searchKey] = type
                end
            end
        end
    end
    return foundMatches, matchesToTypes
end


function isValidItemDictionaryCategory(input)
    if itemDictionary.categories[input] then return true end
    return false
end

--Events.OnLoad.Add(itemDictionary.assemble)
--if isServer() then Events.OnGameBoot.Add(itemDictionary.assemble) end