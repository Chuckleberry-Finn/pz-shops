local itemDictionary = {}
itemDictionary.categories = {}
itemDictionary.partition = {} -- first 3 characters

function getItemDictionary() return itemDictionary end

function itemDictionary.addToPartition(input,itemType)
    if input and input ~= "" then
        if not itemDictionary.partition[input] then itemDictionary.partition[input] = {} end
        itemDictionary.partition[input][itemType]=string.lower(itemType)
    end
end

function itemDictionary.assemble()
    local allItems = ScriptManager.instance:getAllItems()

    for i=0, allItems:size()-1 do
        ---@type Item
        local itemScript = allItems:get(i)
        local itemModule = itemScript:getModuleName()
        if not itemScript:getObsolete() and not itemScript:isHidden() and itemModule ~= "Moveables" then

            local displayCategory = itemScript:getDisplayCategory()
            if displayCategory and not itemDictionary.categories[displayCategory] then itemDictionary.categories[displayCategory] = string.lower(displayCategory) end
            
            local itemType = itemScript:getName()
            local itemModuleType = itemScript:getFullName()
            
            local first3CharItemType = string.lower(string.sub(itemType,1,3))
            itemDictionary.addToPartition(first3CharItemType,itemModuleType)

            local first3CharItemModule = string.lower(string.sub(itemModule,1,3))
            itemDictionary.addToPartition(first3CharItemModule,itemModuleType)
        end
    end
end
Events.OnGameBoot.Add(itemDictionary.assemble)

function findMatchesFromItemDictionary(input)
    local inputLower = string.lower(input)
    local inputLowerCut = string.sub(inputLower,1,3)
    local partitionMatches = itemDictionary.partition[inputLowerCut]
    if not partitionMatches then return end

    local foundMatches = {}

    for type,typeLower in pairs(partitionMatches) do
        --print(" -- "..type)
        if string.find(typeLower,inputLower) then
            print(" -- "..type)
            table.insert(foundMatches, type)
        end
    end

    return foundMatches
end
