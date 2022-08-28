local itemDictionary = {}
itemDictionary.categories = {}
itemDictionary.fcPartition = {}

function getItemDictionary() return itemDictionary end

function itemDictionary.assemble()
    local allItems = ScriptManager.instance:getAllItems()

    for i=0, allItems:size()-1 do
        ---@type Item
        local itemScript = allItems:get(i)
        local itemType = itemScript:getName()
        local firstChar = string.sub(itemType,1,1)
        local itemModuleType = itemScript:getFullName()
        --local itemModule = itemScript:getModuleName()

        local displayCategory = itemScript:getDisplayCategory()
        itemDictionary.categories[displayCategory] = true

        if firstChar and firstChar ~= "" then
            itemDictionary.fcPartition[firstChar] = {}
            itemDictionary.fcPartition[firstChar][itemModuleType] = true
            itemDictionary.fcPartition[firstChar][itemType] = true
        end
    end
end
Events.OnGameBoot.Add(itemDictionary.assemble)