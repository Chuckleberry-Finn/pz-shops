local itemFields = {}

---@param item InventoryItem|DrainableComboItem|Clothing|Food|AlarmClock|AlarmClockClothing|MapItem|InventoryContainer|Literature|HandWeapon
function itemFields.gatherFields(item)

    local fields
    fields = fields or {}

    ---name - ignore if original
    local name = item:getName()
    local script = item:getScriptItem()

    if (not script) or script and script:getDisplayName()~=name then
        fields.name = name
    end

    ---Original name vs Current Name
    --if (this.name != null && !this.name.equals(this.originalName))

    local currentUses = item:getCurrentUses()
    if currentUses ~= 1 then
        fields.uses = currentUses
    end

    if item:IsDrainable() then
        local usedDelta = item:getUsedDelta()
        if usedDelta < 1 then
            fields.usedDelta = usedDelta
        end
    end

    local condition = item:getCondition()
    if condition ~= item:getConditionMax() then
        fields.condition = condition
    end

    ---Item Visual
    -- if (this.visual != null)

    if item:isCustomColor() then
        local c = item:getColor()
        local r = c:getR()
        local g = c:getG()
        local b = c:getB()
        local a = c:getAlpha()
        if r~=1 or g~=1 or b~=1 then
            fields.color = {r=r,g=g,b=b,a=a}
        end
    end

    local capacity = item:getItemCapacity()
    if capacity ~= -1 then
        fields.capacity = capacity
    end

    if item:hasModData() then
        fields.modData = item:getModData()
    end

    local activated = item:isActivated()
    if activated then
        fields.activated = activated
    end

    local repaired = item:getHaveBeenRepaired()
    if repaired ~= 1 then
        fields.repaired = repaired
    end


    ---byteData (???)
    --if (this.byteData != null) {var6.addFlags(16);this.byteData.rewind();var1.putInt(this.byteData.limit());var1.put(this.byteData);this.byteData.flip();}

    --[[
    local extraItems = item:getExtraItems()
    if extraItems and extraItems:size() > 0 then
        local extraItemsTable = {}
        for i=0, extraItems:size()-1 do
            local eI = extraItems:get(i)
            if eI then
                table.insert(extraItemsTable, eI)
            end
        end
        fields.extraItems = extraItemsTable
    end
    --]]

    local customName = item:isCustomName()
    if customName then
        fields.customName = customName
    end

    local customWeight = item:isCustomWeight()
    if customWeight then
        fields.customWeight = customWeight
    end
    ---customWeight
    --if (this.isCustomWeight()) {var6.addFlags(128);var1.putFloat(this.isCustomWeight() ? this.getActualWeight() : -1.0F);}

    local keyId = item:getKeyId()
    if keyId ~= -1 then
        fields.keyId = keyId
    end

    local taintedWater = item:isTaintedWater()
    if taintedWater then
        fields.taintedWater = taintedWater
    end

    local remoteControlID = item:getRemoteControlID()
    local remoteRange = item:getRemoteRange()
    if remoteControlID ~= -1 or remoteRange ~= 0 then
        fields.remoteControlID = remoteControlID
        fields.remoteRange = remoteRange
    end

    local colorR, colorG, colorB = item:getColorRed(), item:getColorGreen(), item:getColorBlue()
    if colorR ~= 1 or colorG ~= 1 or colorB ~= 1 then
        fields.colorR = colorR
        fields.colorG = colorG
        fields.colorB = colorB
    end

    ---Worker appears unused (?)
    --if (this.worker != null) {var6.addFlags(4096);GameWindow.WriteString(var1, this.getWorker());}

    local wetCooldown = item:getWetCooldown()
    if wetCooldown ~= -1 then
        fields.wetCooldown = wetCooldown
    end

    ---stash mao has no getter
    --if (this.stashMap != null)

    ---isInfected not used
    --      if (this.isInfected())

    local currentAmmoCount = item:getCurrentAmmoCount()
    if currentAmmoCount ~= 0 then
        fields.currentAmmoCount = currentAmmoCount
    end

    ---Part of hotbar logic - should ignore
    --if (this.attachedSlot != -1)
    --if (this.attachedSlotType != null)
    --if (this.attachedToModel != null)

    local maxCapacity = item:getMaxCapacity()
    if maxCapacity ~= -1 then
        fields.maxCapacity = maxCapacity
    end

    if item:isRecordedMedia() then
        fields.recordedMediaIndex = item:getRecordedMediaIndex()
    end

    ---probably fine to ignore(?)
    --if (this.worldZRotation > -1)

    ---No getter for world scale (used for fishes maybe?)
    --      if (this.worldScale != 1.0F)

    ---Not sure if this is use-able
    --local initialised = item:isInitialised()
    --if initialised then fields.initialised = initialised end

    if instanceof(item, "Clothing") then
        fields.spriteName = item:getSpriteName()
        fields.dirtyness = item:getDirtyness()
        fields.bloodLevel = item:getBloodLevel()
        fields.wetness = item:getWetness()

        ---hashmap
        --      if (this.patches != null) {
        --         var3.addFlags(32);
        --         var1.put((byte)this.patches.size());
        --         Iterator var4 = this.patches.keySet().iterator();
        --
        --         while(var4.hasNext()) {
        --            int var5 = (Integer)var4.next();
        --            var1.put((byte)var5);
        --            ((Clothing.ClothingPatch)this.patches.get(var5)).save(var1, false);
        --         }
        --      }
    end


    if instanceof(item, "Food") then
        fields.age = item:getAge()
        fields.lastAged = item:getLastAged()
        fields.calories = item:getCalories()
        fields.proteins = item:getProteins()
        fields.lipids = item:getLipids()
        fields.carbohydrates = item:getCarbohydrates()
        fields.hungChange = item:getHungChange()
        fields.baseHunger = item:getBaseHunger()
        fields.unhappyChange = item:getUnhappyChange()
        fields.boredomChange = item:getBoredomChange()
        fields.thirstChange = item:getThirstChange()
        fields.heat = item:getHeat()
        fields.LastCookMinute = item:getLastCookMinute()
        fields.CookingTime = item:getCookingTime()
        fields.Cooked = item:isCooked()
        fields.Burnt = item:isBurnt()
        fields.IsCookable = item:isCookable()
        fields.bDangerousUncooked = item:isbDangerousUncooked()
        fields.poisonDetectionLevel = item:getPoisonDetectionLevel()

        local spices = item:getSpices()
        if spices and spices:size() > 0 then
            local spicesTable = {}
            for i=0, spices:size()-1 do
                local s = spices:get(i)
                if s then
                    table.insert(spicesTable, s)
                end
            end
            fields.spices = spicesTable
        end

        fields.PoisonPower = item:getPoisonPower()
        fields.Chef = item:getChef()
        fields.OffAge = item:getOffAge()
        fields.OffAgeMax = item:getOffAgeMax()
        fields.painReduction = item:getPainReduction()
        fields.fluReduction = item:getFluReduction()
        fields.ReduceFoodSickness = item:getReduceFoodSickness()
        --fields.Poison = item:isPoison()
        fields.UseForPoison = item:getUseForPoison()
        fields.freezingTime = item:getFreezingTime()
        fields.isFrozen = item:isFrozen()
        --fields.LastFrozenUpdate ---No getter
        fields.rottenTime = item:getRottenTime()
        fields.compostTime = item:getCompostTime()
        fields.cookedInMicrowave = item:isCookedInMicrowave()
        fields.fatigueChange = item:getFatigueChange()
        fields.endChange = item:getEndChange()
    end


    if instanceof(item, "HandWeapon") then

        fields.maxRange = item:getMaxRange()
        fields.minRangeRanged = item:getMinRangeRanged()
        fields.ClipSize = item:getClipSize()
        fields.minDamage = item:getMinDamage()
        fields.maxDamage = item:getMaxDamage()
        fields.RecoilDelay = item:getRecoilDelay()
        fields.aimingTime = item:getAimingTime()
        fields.reloadTime = item:getReloadTime()
        fields.hitChance = item:getHitChance()
        fields.minAngle = item:getMinAngle()

        fields.scope = item:getScope():getFullType()
        fields.clip = item:getClip():getFullType()
        fields.recoilPad = item:getRecoilPad():getFullType()
        fields.sling = item:getSling():getFullType()
        fields.stock = item:getStock():getFullType()
        fields.canon = item:getCanon():getFullType()

        fields.explosionTimer = item:getExplosionTimer()
        fields.maxAngle = item:getMaxAngle()

        fields.bloodLevel = item:getBloodLevel()

        fields.containsClip = item:isContainsClip()
        fields.roundChambered = item:isRoundChambered()
        fields.jammed = item:isJammed()

        fields.weaponSprite = item:getWeaponSprite()
    end

    if instanceof(item, "InventoryContainer") then
        ---no getter for container ID - can't really save containers
        --TODO: When selling InventoryContainer make it dump the contents out?
        --fields.containerID = item:getContainer().ID
        fields.weightReduction = item:getWeightReduction()
    end


    if instanceof(item, "Literature") then
        fields.numberOfPages = item:getNumberOfPages()
        fields.alreadyReadPages = item:getAlreadyReadPages()
        fields.canBeWrite = item:CanBeWrite() ---???
        ---hashmap
        --fields.customPages = hashmap < int, string >
        fields.lockedBy = item:getLockedBy()
    end


    if instanceof(item, "MapItem") then
        fields.mapID = item:getMapID()
        ---Symbols are their own class -- check paperAPI for how I copied symbol sets
        --fields.symbols = item:getSymbols()
    end

    if instanceof(item, "AlarmClockClothing") then
        fields.hour = item:getHour()
        fields.minute = item:getMinute()
        fields.alarmSet = item:isAlarmSet()
        --fields.ringSince ---No Getter
    end

    if instanceof(item, "AlarmClock") then
        fields.hour = item:getHour()
        fields.minute = item:getMinute()
        fields.alarmSet = item:isAlarmSet()
        --fields.ringSince ---No Getter
    end

    ---@type Moveable
    local movable = instanceof(item, "Moveable") and item
    if movable then
        fields = fields or {}
        fields.worldSprite = movable:getWorldSprite()
        if movable:isLight() then
            fields.usesBattery = movable:isLightUseBattery()
            fields.hasBattery = movable:isLightHasBattery()
            fields.lightBulb = movable:getLightBulbItem()
            fields.lightPower = movable:getLightPower()
            fields.lightDelta = movable:getLightDelta()
            fields.lightR = movable:getLightR()
            fields.lightG = movable:getLightG()
            fields.lightB = movable:getLightB()
        end
    end

    return fields
end

itemFields.specials = {}


---@param item InventoryItem|DrainableComboItem|Clothing|Food|AlarmClock|AlarmClockClothing|MapItem|InventoryContainer|Literature|HandWeapon
function itemFields.specials.setColor(item, color)
    local col = Color.new(color.r, color.g, color.b, color.a)
    item:setColor(col)
    return true
end

---@param item InventoryItem|DrainableComboItem|Clothing|Food|AlarmClock|AlarmClockClothing|MapItem|InventoryContainer|Literature|HandWeapon
function itemFields.specials.setModData(item, data)
    item:copyModData(data)
    return true
end

---@param item InventoryItem|DrainableComboItem|Clothing|Food|AlarmClock|AlarmClockClothing|MapItem|InventoryContainer|Literature|HandWeapon
function itemFields.specials.setSpiceTable(item, data)
    local spices = ArrayList.new()
    for _,spice in pairs(data) do spices:add(spice) end
    item:setSpices(spices)
    return true
end

---@param item InventoryItem|DrainableComboItem|Clothing|Food|AlarmClock|AlarmClockClothing|MapItem|InventoryContainer|Literature|HandWeapon
function itemFields.specials.setScopeWithType(item, data)
    local part = InventoryItemFactory.CreateItem(data)
    if part then item:setScope(part) end
    return true
end

---@param item InventoryItem|DrainableComboItem|Clothing|Food|AlarmClock|AlarmClockClothing|MapItem|InventoryContainer|Literature|HandWeapon
function itemFields.specials.setClipWithType(item, data)
    local part = InventoryItemFactory.CreateItem(data)
    if part then item:setClip(part) end
    return true
end

---@param item InventoryItem|DrainableComboItem|Clothing|Food|AlarmClock|AlarmClockClothing|MapItem|InventoryContainer|Literature|HandWeapon
function itemFields.specials.setRecoilPadWithType(item, data)
    local part = InventoryItemFactory.CreateItem(data)
    if part then item:setRecoilpad(part) end
    return true
end

---@param item InventoryItem|DrainableComboItem|Clothing|Food|AlarmClock|AlarmClockClothing|MapItem|InventoryContainer|Literature|HandWeapon
function itemFields.specials.setSlingWithType(item, data)
    local part = InventoryItemFactory.CreateItem(data)
    if part then item:setSling(part) end
    return true
end

---@param item InventoryItem|DrainableComboItem|Clothing|Food|AlarmClock|AlarmClockClothing|MapItem|InventoryContainer|Literature|HandWeapon
function itemFields.specials.setStockWithType(item, data)
    local part = InventoryItemFactory.CreateItem(data)
    if part then item:setStock(part) end
    return true
end

---@param item InventoryItem|DrainableComboItem|Clothing|Food|AlarmClock|AlarmClockClothing|MapItem|InventoryContainer|Literature|HandWeapon
function itemFields.specials.setCanonWithType(item, data)
    local part = InventoryItemFactory.CreateItem(data)
    if part then item:setCanon(part) end
    return true
end


---@param item InventoryItem|DrainableComboItem|Clothing|Food|AlarmClock|AlarmClockClothing|MapItem|InventoryContainer|Literature|HandWeapon
function itemFields.getFieldAssociatedFunctions(item)

    local fields

    fields.name = "setName"
    fields.usedDelta = 'setUsedDelta'
    fields.condition = "setCondition"

    fields.color = "setColor"
    fields.modData = "setModData"

    fields.capacity = "setItemCapacity"
    fields.activated = "setActivated"
    fields.repaired = "setHaveBeenRepaired"
    fields.customName = "setCustomName"
    fields.customWeight = "setCustomWeight"
    fields.keyId = "setKeyId"
    fields.taintedWater = "setTaintedWater"
    fields.remoteControlID = "setRemoteControlID"
    fields.remoteRange = "setRemoteRange"
    fields.colorR = "setColorRed"
    fields.colorG = "setColorGreen"
    fields.colorB = "setColorBlue"
    fields.wetCooldown = "setWetCooldown"
    fields.currentAmmoCount = "setCurrentAmmoCount"
    fields.maxCapacity = "setMaxCapacity"
    fields.recordedMediaIndex = "setRecordedMediaIndex"

    ---@type Moveable
    local movable = instanceof(item, "Moveable") and item
    if movable then
        fields = fields or {}
        fields.worldSprite = "setWorldSprite"
        fields.isLight = "setLight"
        fields.usesBattery = "setLightUseBattery"
        fields.hasBattery = "setLightHasBattery"
        fields.lightBulb = "setLightBulbItem"
        fields.lightPower = "setLightPower"
        fields.lightDelta = "setLightDelta"
        fields.lightR = "setLightR"
        fields.lightG = "setLightG"
        fields.lightB = "setLightB"
    end


    ---@type Clothing
    local clothing = instanceof(item, "Clothing") and item
    if clothing then
        fields.spriteName = "setSpriteName"
        fields.dirtyness = "setDirtyness"
        fields.bloodLevel = "setBloodLevel"
        fields.wetness = "setWetness"
    end


    ---@type InventoryContainer
    local invCont = instanceof(item, "InventoryContainer") and item
    if invCont then
        fields = fields or {}
        fields.weightReduction = "setWeightReduction"
    end


    ---@type Literature
    local literature = instanceof(item, "Literature") and item
    if literature then
        fields = fields or {}
        fields.numberOfPages = "setNumberOfPages"
        fields.alreadyReadPages = "setAlreadyReadPages"
        fields.canBeWrite ="setCanBeWrite"
        fields.lockedBy = "setLockedBy"
    end


    ---@type MapItem
    local map = instanceof(item, "MapItem") and item
    if map then
        fields = fields or {}
        fields.mapID = "setMapID"
    end


    ---@type AlarmClock|AlarmClockClothing
    local alarm = (instanceof(item, "AlarmClock") or instanceof(item, "AlarmClockClothing")) and item
    if alarm then
        fields.hour = "setHour"
        fields.minute = "setMinute"
        fields.alarmSet = "setAlarmSet"
    end

    ---type Food
    local food = instanceof(item, "Food") and item
    if food then
        fields.age = "setAge"
        fields.lastAged = "setLastAged"
        fields.calories = "setCalories"
        fields.proteins = "setProteins"
        fields.lipids = "setLipids"
        fields.carbohydrates = "setCarbohydrates"
        fields.hungChange = "setHungChange"
        fields.baseHunger = "setBaseHunger"
        fields.unhappyChange = "setUnhappyChange"
        fields.boredomChange = "setBoredomChange"
        fields.thirstChange = "setThirstChange"
        fields.heat = "setHeat"
        fields.LastCookMinute = "setLastCookMinute"
        fields.CookingTime = "setCookingTime"
        fields.Cooked = "setCooked"
        fields.Burnt = "setBurnt"
        fields.IsCookable = "setIsCookable"
        fields.bDangerousUncooked = "setbDangerousUncooked"
        fields.poisonDetectionLevel = "setPoisonDetectionLevel"
        fields.spices = "setSpiceTable"
        fields.PoisonPower = "setPoisonPower"
        fields.Chef = "setChef"
        fields.OffAge = "setOffAge"
        fields.OffAgeMax = "setOffAgeMax"
        fields.painReduction = "setPainReduction"
        fields.fluReduction = "setFluReduction"
        fields.ReduceFoodSickness = "setReduceFoodSickness"
        --fields.Poison = item:isPoison()
        fields.UseForPoison = "setUseForPoison"
        fields.freezingTime = "setFreezingTime"
        fields.isFrozen = "setFrozen"
        --fields.LastFrozenUpdate ---No getter
        fields.rottenTime = "setRottenTime"
        fields.compostTime = "setCompostTime"
        fields.cookedInMicrowave = "setCookedInMicrowave"
        fields.fatigueChange = "setFatigueChange"
        fields.endChange = "setEndChange"
    end


    ---type Food
    local weapon = instanceof(item, "HandWeapon") and item
    if weapon then

        fields.maxRange = "setMaxRange"
        fields.minRangeRanged = "setMinRangeRanged"
        fields.ClipSize = "setClipSize"
        fields.minDamage = "setMinDamage"
        fields.maxDamage = "setMaxDamage"
        fields.RecoilDelay = "setRecoilDelay"
        fields.aimingTime = "setAimingTime"
        fields.reloadTime = "setReloadTime"
        fields.hitChance = "setHitChance"
        fields.minAngle = "setMinAngle"

        fields.scope = "setScopeWithType"
        fields.clip = "setClipWithType"
        fields.recoilPad = "setRecoilPadWithType"
        fields.sling = "setSlingWithType"
        fields.stock = "setStockWithType"
        fields.canon = "setCanonWithType"

        fields.explosionTimer = "setExplosionTimer"
        fields.maxAngle = "setMaxAngle"
        fields.bloodLevel = "setBloodLevel"
        fields.containsClip = "setContainsClip"
        fields.roundChambered = "setRoundChambered"
        fields.jammed = "setJammed"
        fields.weaponSprite = "setWeaponSprite"
    end


    return fields
end


return itemFields
