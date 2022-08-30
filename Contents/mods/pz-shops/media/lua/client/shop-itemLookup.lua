local itemDictionary = {}
itemDictionary.categories = {}

itemDictionary.f3cPartition = {} -- first 3 characters

function getItemDictionary() return itemDictionary end

function itemDictionary.assemble()
    local allItems = ScriptManager.instance:getAllItems()

    for i=0, allItems:size()-1 do
        ---@type Item
        local itemScript = allItems:get(i)
        local itemModule = itemScript:getModuleName()
        if not itemScript:getObsolete() and not itemScript:isHidden() and itemModule ~= "Moveables" then

            local itemType = itemScript:getName()
            local first3Char = string.lower(string.sub(itemType,1,3))
            local itemModuleType = itemScript:getFullName()
            local displayCategory = itemScript:getDisplayCategory()
            
            if not itemDictionary.categories[displayCategory] then itemDictionary.categories[displayCategory] = string.lower(displayCategory) end

            if first3Char and first3Char ~= "" then
                if not itemDictionary.f3cPartition[first3Char] then itemDictionary.f3cPartition[first3Char] = {} end
                itemDictionary.f3cPartition[first3Char][itemModuleType] = true
            end

        end
    end
end
Events.OnGameBoot.Add(itemDictionary.assemble)

function findMatchesFromItemDictionary(input)
    local inputF3Char = string.sub(input,1,3)
    local partitionMatches = itemDictionary.f3cPartition[inputF3Char]
    if not partitionMatches then return end
    print("inputF3Char: "..inputF3Char)
    for type,_ in pairs(partitionMatches) do print(" -- "..type) end
end
