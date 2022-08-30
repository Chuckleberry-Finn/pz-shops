local itemDictionary = {}
itemDictionary.categories = {}
itemDictionary.partition = {} -- first 3 characters

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
            
            local displayCategory = itemScript:getDisplayCategory()
            if not itemDictionary.categories[displayCategory] then itemDictionary.categories[displayCategory] = string.lower(displayCategory) end
            
            if first3Char and first3Char ~= "" then
                if not itemDictionary.partition[first3Char] then itemDictionary.partition[first3Char] = {} end
                local itemModuleType = itemScript:getFullName()
                table.insert(itemDictionary.partition[first3Char], itemModuleType)
            end

        end
    end
end
Events.OnGameBoot.Add(itemDictionary.assemble)

function findMatchesFromItemDictionary(input)
    local inputChar = string.lower(string.sub(input,1,3))
    local partitionMatches = itemDictionary.partition[inputChar]
    if not partitionMatches then return end
    print("inputChar: "..inputChar)
    for _,type in pairs(partitionMatches) do print(" -- "..type) end
end
