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
itemDictionary.itemsToCategories = {}
itemDictionary.partition = {} -- first 3 characters


function getItemDictionary() return itemDictionary end


function itemDictionary.addToPartition(result, searchKey)
    local input = string.lower(string.sub(searchKey,1,3))
    if input and input ~= "" then
        if not itemDictionary.partition[input] then itemDictionary.partition[input] = {} end
        itemDictionary.partition[input][searchKey]=result
    end
end


function itemDictionary.assemble()
    local allItems = getScriptManager():getAllItems()
    for i=0, allItems:size()-1 do
        ---@type Item
        local itemScript = allItems:get(i)
        local itemModule = itemScript:getModuleName()
        if not itemScript:getObsolete() and not itemScript:isHidden() and itemModule ~= "Moveables" then

            local itemModuleType = itemScript:getFullName()
            itemDictionary.addToPartition(itemModuleType, itemModuleType)
            itemDictionary.addToPartition(itemModuleType, itemScript:getDisplayName())

            local displayCategory = itemScript:getDisplayCategory()
            itemDictionary.itemsToCategories[itemModuleType] = displayCategory
            if displayCategory and not itemDictionary.categories[displayCategory] then itemDictionary.categories[displayCategory] = string.lower(displayCategory) end

            itemDictionary.addToPartition(itemModuleType, displayCategory)
            itemDictionary.categories[displayCategory] = true

            itemDictionary.addToPartition(itemModuleType, itemScript:getName())
        end
    end
end
Events.OnGameBoot.Add(itemDictionary.assemble)

--    IGUI_invpanel_Type = "Type",
--    IGUI_invpanel_Category = "Category",
--    IGUI_Name = "Name",

function findMatchesFromItemDictionary(input)
    local inputLower = string.lower(input)
    local inputLowerCut = string.sub(inputLower,1,3)
    local partitionMatches = itemDictionary.partition[inputLowerCut]
    if not partitionMatches then return end
    local foundMatches, matchesToTypes = {}, {}
    for searchKey,type in pairs(partitionMatches) do
        if string.find(string.lower(searchKey),inputLower) then
            table.insert(foundMatches, searchKey)
            matchesToTypes[searchKey] = type
        end
    end
    return foundMatches, matchesToTypes
end

function isValidItemDictionaryCategory(input)
    if itemDictionary.categories[input] then return true end
    return false
end