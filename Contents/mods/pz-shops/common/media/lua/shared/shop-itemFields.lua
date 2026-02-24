local itemFields = {}

---@param i string
function itemFields.gatherFields(i, purgeHidden)

    if not i then return end

    ---@type InventoryItem|DrainableComboItem|Clothing|Food|AlarmClock|AlarmClockClothing|MapItem|InventoryContainer|Literature|HandWeapon
    local item = instanceof(i, "InventoryItem") and i
    local category

    if (not item) and type(i) == "string" then

        local _category = i:gsub("category:","")
        category = _category and isValidItemDictionaryCategory(_category) and _category
        if not category then
            item = instanceItem(i)
        else
            local dict = getItemDictionary()
            local dictType = dict.categoryExample[category]
            item = instanceItem(dictType)
        end
    end

    if not item then return end

    local fields = {}
    local hidden_fields = {}

    ---name - ignore if original
    local name = item:getDisplayName()
    local script = item:getScriptItem()

    fields.name = name
    if (script and script:getDisplayName()==name) then
        hidden_fields.name = true
    end

    ---Original name vs Current Name
    --if (this.name != null && !this.name.equals(this.originalName))

    local currentUses = item:getCurrentUses()
    fields.uses = currentUses
    if not (currentUses ~= 1) then
        hidden_fields.uses = true
    end

    if item:IsDrainable() then
        local usedDelta = item:getUsedDelta()
        fields.usedDelta = usedDelta
        if not (usedDelta < 1) then
            hidden_fields.usedDelta = true
        end
    end

    local condition = item:getCondition()
    fields.condition = condition
    if condition == script:getConditionMax() then
        hidden_fields.condition = true
    end

    local broken = item:isBroken()
    fields.broken = broken
    if not broken then
        hidden_fields.broken = true
    end

    ---Item Visual
    -- if (this.visual != null)

    if item:isCustomColor() then
        local c = item:getColor()
        local r = c:getR()
        local g = c:getG()
        local b = c:getB()
        local a = c:getAlpha()

        fields.color = {r=r,g=g,b=b,a=a}
        if not (r~=1 or g~=1 or b~=1) then
            hidden_fields.color = true
        end
    else
        fields.color = ""
        hidden_fields.color = true
    end

    local capacity = item:getItemCapacity()
    fields.capacity = capacity
    if (capacity == -1) then
        hidden_fields.capacity = true
    end

    if item:hasModData() then
        fields.modData = item:getModData()
    else
        fields.modData = ""
        hidden_fields.modData = true
    end

    local activated = item:isActivated()
    fields.activated = activated
    if not activated then
        hidden_fields.activated = true
    end

    local repaired = item:getHaveBeenRepaired()
    fields.repaired = repaired
    if (repaired == 1) then
        hidden_fields.repaired = true
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
    fields.customName = customName
    if not customName then
        hidden_fields.customName = true
    end

    local customWeight = item:isCustomWeight()
    fields.customWeight = customWeight
    if not customWeight then
        hidden_fields.customWeight = true
    end
    ---customWeight
    --if (this.isCustomWeight()) {var6.addFlags(128);var1.putFloat(this.isCustomWeight() ? this.getActualWeight() : -1.0F);}

    local keyId = item:getKeyId()
    fields.keyId = keyId
    if (keyId == -1) then
        hidden_fields.keyId = true
    end

    local remoteControlID = item:getRemoteControlID()
    local remoteRange = item:getRemoteRange()
    fields.remoteControlID = remoteControlID
    fields.remoteRange = remoteRange
    if (remoteControlID == -1 and remoteRange == 0) then
        hidden_fields.remoteControlID = true
        hidden_fields.remoteRange = true
    end

    local colorR, colorG, colorB = item:getColorRed(), item:getColorGreen(), item:getColorBlue()
    fields.colorR = colorR
    fields.colorG = colorG
    fields.colorB = colorB
    if colorR == 1 then hidden_fields.colorR = true end
    if colorG == 1 then hidden_fields.colorG = true end
    if colorB == 1 then hidden_fields.colorB = true end

    ---Worker appears unused (?)
    --if (this.worker != null) {var6.addFlags(4096);GameWindow.WriteString(var1, this.getWorker());}

    --[[
    local wetCooldown = item:getWetCooldown()
    fields.wetCooldown = wetCooldown
    if not (wetCooldown ~= -1) then
        hidden_fields.wetCooldown = true
    end
    --]]

    local infected = item:isInfected()
    fields.infected = infected
    if not infected then hidden_fields.infected = true end

    ---stash map has no getter
    --if (this.stashMap != null)

    local currentAmmoCount = item:getCurrentAmmoCount()
    fields.currentAmmoCount = currentAmmoCount
    if (currentAmmoCount == 0) then hidden_fields.currentAmmoCount = true end

    ---Part of hotbar logic - should ignore
    --if (this.attachedSlot != -1)
    --if (this.attachedSlotType != null)
    --if (this.attachedToModel != null)

    local maxCapacity = item:getMaxCapacity()
    fields.maxCapacity = maxCapacity
    if (maxCapacity == -1) then hidden_fields.maxCapacity = true end

    if item:isRecordedMedia() then fields.recordedMediaIndex = item:getRecordedMediaIndex() end

    ---probably fine to ignore(?)
    --if (this.worldZRotation > -1)

    ---No getter for world scale (used for fishes maybe?)
    --      if (this.worldScale != 1.0F)

    ---Not sure if this is use-able
    --local initialised = item:isInitialised()
    --if initialised then fields.initialised = initialised end

    if item:hasSharpness() then
        local sharpness = item:getSharpness()
        fields.sharpness = sharpness
        if sharpness >= 1.0 then hidden_fields.sharpness = true end
    end

    if item:hasQuality() then
        local quality = item:getQuality()
        fields.quality = quality
        if quality == 0 then hidden_fields.quality = true end
    end

    local headCond = item:getHeadCondition()
    if headCond > 0 then
        fields.headCondition = headCond
        if headCond >= item:getHeadConditionMax() then hidden_fields.headCondition = true end
    end

    if instanceof(item, "Clothing") then

        local spriteName = item:getSpriteName()
        fields.spriteName = spriteName
        if spriteName == script:getSpriteName() then
            hidden_fields.spriteName = true
        end

        local dirtiness = item:getDirtiness()
        fields.dirtiness = dirtiness
        if dirtiness <= 0 then
            hidden_fields.dirtiness = true
        end

        local bloodLevel = item:getBloodLevel()
        fields.bloodLevel = bloodLevel
        if bloodLevel <= 0 then
            hidden_fields.bloodLevel = true
        end

        local wetness = item:getWetness()
        fields.wetness = wetness
        if wetness <= 0 then
            hidden_fields.wetness = true
        end

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

        local age = item:getAge() or 0
        fields.age = age
        if age <= 0 then
            hidden_fields.age = true
        end

        fields.calories = item:getCalories()
        fields.proteins = item:getProteins()
        fields.lipids = item:getLipids()
        fields.carbohydrates = item:getCarbohydrates()
        fields.fatigueChange = item:getFatigueChange()
        fields.endChange = item:getEndChange()
        fields.hungChange = item:getHungChange()
        fields.baseHunger = item:getBaseHunger()
        fields.unhappyChange = item:getUnhappyChange()
        fields.boredomChange = item:getBoredomChange()
        fields.thirstChange = item:getThirstChange()

        local heat = item:getHeat()
        fields.heat = heat
        if heat == 1 then
            hidden_fields.heat = true
        end

        local LastCookMinute = item:getLastCookMinute()
        fields.LastCookMinute = LastCookMinute
        if LastCookMinute <= 0 then
            hidden_fields.LastCookMinute = true
        end

        local CookingTime = item:getCookingTime()
        fields.CookingTime = CookingTime
        if CookingTime <= 0 then
            hidden_fields.CookingTime = true
        end

        local Cooked = item:isCooked()
        fields.Cooked = Cooked
        if not Cooked then
            hidden_fields.Cooked = true
        end

        local Burnt = item:isBurnt()
        fields.Burnt = Burnt
        if not Burnt then
            hidden_fields.Burnt = true
        end

        fields.IsCookable = item:isCookable()

        local bDangerousUncooked = item:isbDangerousUncooked()
        fields.bDangerousUncooked = bDangerousUncooked
        if not bDangerousUncooked then
            hidden_fields.bDangerousUncooked = true
        end

        local tainted = item:isTainted()
        fields.tainted = tainted
        if not tainted then
            hidden_fields.tainted = true
        end

        local poisonDetectionLevel = item:getPoisonDetectionLevel()
        fields.poisonDetectionLevel = poisonDetectionLevel
        if poisonDetectionLevel == -1 then
            hidden_fields.poisonDetectionLevel = true
        end

        local spicesTable = {}
        local spices = item:getSpices()
        if spices then
            for i=0, spices:size()-1 do
                local s = spices:get(i)
                if s then table.insert(spicesTable, s) end
            end
        end
        fields.spices = spicesTable
        hidden_fields.spices = (#spicesTable == 0)

        local PoisonPower = item:getPoisonPower()
        fields.PoisonPower = PoisonPower
        if PoisonPower <= 0 then
            hidden_fields.PoisonPower = true
        end

        local chef = item:getChef()
        if chef then
            fields.Chef = item:getChef()
        else
            fields.Chef = ""
            hidden_fields.Chef = true
        end

        local OffAge = item:getOffAge()
        fields.OffAge = OffAge
        if OffAge == 1000000000 then
            hidden_fields.OffAge = true
        end

        local OffAgeMax = item:getOffAgeMax()
        fields.OffAgeMax = OffAgeMax
        if OffAgeMax == 1000000000 then
            hidden_fields.OffAgeMax = true
        end

        local painReduction = item:getPainReduction()
        fields.painReduction = painReduction
        if painReduction == 0 then
            hidden_fields.painReduction = true
        end

        local fluReduction = item:getFluReduction()
        fields.fluReduction = fluReduction
        if fluReduction == 0 then
            hidden_fields.fluReduction = true
        end

        local ReduceFoodSickness = item:getReduceFoodSickness()
        fields.ReduceFoodSickness = ReduceFoodSickness
        if ReduceFoodSickness == 0 then
            hidden_fields.ReduceFoodSickness = true
        end
        --fields.Poison = item:isPoison()

        local UseForPoison = item:getUseForPoison()
        fields.UseForPoison = UseForPoison
        if UseForPoison == 0 then
            hidden_fields.UseForPoison = true
        end

        local freezingTime = item:getFreezingTime()
        fields.freezingTime = freezingTime
        if freezingTime == 0 then
            hidden_fields.freezingTime = true
        end

        local isFrozen = item:isFrozen()
        fields.isFrozen = isFrozen
        if isFrozen == false then
            hidden_fields.isFrozen = true
        end

        local rottenTime = item:getRottenTime()
        fields.rottenTime = rottenTime
        if rottenTime == 0 then
            hidden_fields.rottenTime = true
        end

        local compostTime = item:getCompostTime()
        fields.compostTime = compostTime
        if compostTime == 0 then
            hidden_fields.compostTime = true
        end

        local cookedInMicrowave = item:isCookedInMicrowave()
        fields.cookedInMicrowave = cookedInMicrowave
        if cookedInMicrowave == false then
            hidden_fields.cookedInMicrowave = true
        end
    end


    if instanceof(item, "HandWeapon") then

        fields.maxRange = item:getMaxRange()
        hidden_fields.maxRange = (script:getMaxRange() == fields.maxRange)

        fields.minRangeRanged = item:getMinRangeRanged()
        hidden_fields.minRangeRanged = (fields.minRangeRanged == 0)

        fields.ClipSize = item:getClipSize()
        hidden_fields.ClipSize = (fields.ClipSize == 0)

        fields.minDamage = item:getMinDamage()
        hidden_fields.minDamage = (fields.minDamage == 0.4)

        fields.maxDamage = item:getMaxDamage()
        hidden_fields.maxDamage = (script:getMaxDamage() == fields.maxDamage)

        fields.RecoilDelay = item:getRecoilDelay()
        hidden_fields.RecoilDelay = (fields.RecoilDelay == 0)

        fields.aimingTime = item:getAimingTime()
        hidden_fields.aimingTime = (fields.aimingTime == 0)

        fields.reloadTime = item:getReloadTime()
        hidden_fields.reloadTime = (fields.reloadTime == 0)

        fields.hitChance = item:getHitChance()
        hidden_fields.hitChance = (fields.hitChance == 0)

        fields.minAngle = item:getMinAngle()
        hidden_fields.minAngle = (script:getMinAngle() == fields.minAngle)


        local partsTable = {}
        local hasParts = false
        local weaponParts = item:getAllWeaponParts()
        for idx=0, weaponParts:size()-1 do
            local part = weaponParts:get(idx)
            if part then partsTable[part:getPartType()] = part:getFullType() hasParts = true end
        end
        fields.weaponParts = partsTable
        hidden_fields.weaponParts = not hasParts

        local explosionTimer = item:getExplosionTimer()
        fields.explosionTimer = explosionTimer
        if explosionTimer == 0 then
            hidden_fields.explosionTimer = true
        end

        --[[
        local maxAngle = item:getMaxAngle()
        fields.maxAngle = maxAngle
        --]]

        local bloodLevel = item:getBloodLevel()
        fields.bloodLevel = bloodLevel
        if bloodLevel <= 0 then
            hidden_fields.bloodLevel = true
        end

        fields.containsClip = item:isContainsClip()
        fields.roundChambered = item:isRoundChambered()
        fields.jammed = item:isJammed()

        local weaponSprite = item:getWeaponSprite()
        fields.weaponSprite = item:getWeaponSprite()
        if weaponSprite == script:getWeaponSprite() then
            hidden_fields.weaponSprite = true
        end

    end

    if instanceof(item, "InventoryContainer") then
        ---no getter for container ID - can't really save containers
        --TODO: When selling InventoryContainer make it dump the contents out?
        --fields.containerID = item:getContainer().ID

        fields.weightReduction = item:getWeightReduction()

        local bloodLevel = item:getBloodLevel()
        fields.bloodLevel = bloodLevel
        if bloodLevel <= 0 then
            hidden_fields.bloodLevel = true
        end
    end


    if instanceof(item, "Literature") then
        fields.numberOfPages = item:getNumberOfPages()
        fields.alreadyReadPages = item:getAlreadyReadPages()
        fields.canBeWrite = item:canBeWrite() ---???
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

    if item:isFluidContainer() then
        local fc = item:getFluidContainer()
        if fc then
            local amount = fc:getAmount()
            local cap    = fc:getCapacity()
            fields.fluidAmount   = amount
            fields.fluidCapacity = cap
            local pFluid = fc:getPrimaryFluid()
            fields.fluidType = pFluid and pFluid:getName() or ""

            if amount == cap then hidden_fields.fluidAmount = true end
            if fields.fluidType == "" then hidden_fields.fluidType = true end
            hidden_fields.fluidCapacity = true
        end
    end

    if purgeHidden then
        local to_remove = {}

        for field, value in pairs(fields) do
            if hidden_fields[field] then
                table.insert(to_remove, field)
            end
        end

        for _, field in pairs(to_remove) do
            fields[field] = nil
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

---@param item HandWeapon
---@param parts table
function itemFields.specials.setWeaponParts(item, parts)
    if type(parts) ~= "table" then return false end
    for pType, fullType in pairs(parts) do
        local part = instanceItem(fullType)
        if part then
            item:attachWeaponPart(part, true)
        else
            print("[Shop] setWeaponParts: could not spawn '"..tostring(fullType).."' for slot '"..tostring(pType).."'")
        end
    end
    return true
end


---@param item InventoryItem
---@param amount number
function itemFields.specials.setFluidAmount(item, amount)
    if not item:isFluidContainer() then return false end
    local fc = item:getFluidContainer()
    if not fc then return false end
    local fluid = fc:getPrimaryFluid()
    if not fluid then return false end
    local clamped = math.max(0, math.min(fc:getCapacity(), amount))
    fc:empty()
    if clamped > 0 then fc:addFluid(fluid, clamped) end
    return true
end


---@param item InventoryItem
---@param fluidName string
function itemFields.specials.setFluidType(item, fluidName)
    if not item:isFluidContainer() then return false end
    local fc = item:getFluidContainer()
    if not fc then return false end
    local currentAmount = fc:getAmount()
    fc:empty()
    if fluidName and fluidName ~= "" then
        local fluid = Fluid.getFluidByName(fluidName)
        if fluid then
            fc:addFluid(fluid, currentAmount)
        else
            print("[itemFields] WARN: setFluidType: unknown fluid '"..tostring(fluidName).."' — container emptied.")
            return false
        end
    end
    return true
end


---@param item InventoryItem|DrainableComboItem|Clothing|Food|AlarmClock|AlarmClockClothing|MapItem|InventoryContainer|Literature|HandWeapon
function itemFields.getFieldAssociatedFunctions(item)

    local fields = {}

    fields.name = "setName"
    fields.usedDelta = "setUsedDelta"
    fields.condition = "setCondition"
    fields.broken = "setBroken"
    fields.color = "setColor"
    fields.modData = "setModData"
    fields.capacity = "setItemCapacity"
    fields.activated = "setActivated"
    fields.repaired = "setHaveBeenRepaired"
    fields.customName = "setCustomName"
    fields.customWeight = "setCustomWeight"
    fields.keyId = "setKeyId"
    fields.tainted = "setTainted"
    fields.remoteControlID = "setRemoteControlID"
    fields.remoteRange = "setRemoteRange"
    fields.colorR = "setColorRed"
    fields.colorG = "setColorGreen"
    fields.colorB = "setColorBlue"
    --fields.wetCooldown = "setWetCooldown"
    fields.currentAmmoCount = "setCurrentAmmoCount"
    fields.maxCapacity = "setMaxCapacity"
    fields.recordedMediaIndex = "setRecordedMediaIndex"
    fields.infected = "setInfected"
    fields.sharpness      = "setSharpness"
    fields.quality        = "setQuality"
    fields.headCondition  = "setHeadCondition"

    ---@type Moveable
    local movable = instanceof(item, "Moveable") and item
    if movable then
        fields.worldSprite = "ReadFromWorldSprite"
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
        fields.dirtiness = "setDirtiness"
        fields.bloodLevel = "setBloodLevel"
        fields.wetness = "setWetness"
    end


    ---@type InventoryContainer
    local invCont = instanceof(item, "InventoryContainer") and item
    if invCont then
        fields.weightReduction = "setWeightReduction"
    end


    ---@type Literature
    local literature = instanceof(item, "Literature") and item
    if literature then
        fields.numberOfPages = "setNumberOfPages"
        fields.alreadyReadPages = "setAlreadyReadPages"
        fields.canBeWrite = "setCanBeWrite"
        fields.lockedBy = "setLockedBy"
    end


    ---@type MapItem
    local map = instanceof(item, "MapItem") and item
    if map then
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


    if item:isFluidContainer() then
        fields.fluidAmount = "setFluidAmount"
        fields.fluidType   = "setFluidType"
        ---fluidCapacity is script-defined, intentionally omitted
    end


    ---type HandWeapon
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

        fields.weaponParts = "setWeaponParts"

        fields.explosionTimer = "setExplosionTimer"
        --fields.maxAngle = "setMaxAngle"
        fields.bloodLevel = "setBloodLevel"
        fields.containsClip = "setContainsClip"
        fields.roundChambered = "setRoundChambered"
        fields.jammed = "setJammed"
        fields.weaponSprite = "setWeaponSprite"
    end


    return fields
end


---Evaluates a conditional expression stored as a listing field value against an item's
---actual field value. Non-string exprs are compared by equality (with shallow table
---support for color etc.). String exprs support:
---   >N  <N  >=N  <=N  !N  (numeric comparisons)
---   N~M                    (inclusive range)
---   bare string            (exact string equality)
---@param expr    any  The value stored in the listing field (may be a conditional string)
---@param itemVal any  The value read from the actual item
---@return boolean
function itemFields.parseConditional(expr, itemVal)

    if type(expr) ~= "string" then
        ---Exact match. For tables (e.g. color = {r,g,b,a}) do a shallow compare.
        if type(expr) == "table" and type(itemVal) == "table" then
            for k, v in pairs(expr) do
                if itemVal[k] ~= v then return false end
            end
            return true
        end
        return expr == itemVal
    end

    ---Range:  "N~M"
    local lo, hi = expr:match("^([%d%.%-]+)~([%d%.%-]+)$")
    if lo and hi then
        lo, hi = tonumber(lo), tonumber(hi)
        local v = tonumber(itemVal)
        return v ~= nil and (v >= lo and v <= hi)
    end

    ---Operator: >=  <=  >  <  !
    local op, rhs = expr:match("^([><!][=]?)([%d%.%-]+)$")
    if op and rhs then
        rhs = tonumber(rhs)
        local v = tonumber(itemVal)
        if not v or not rhs then return false end
        if op == ">"  then return v >  rhs end
        if op == "<"  then return v <  rhs end
        if op == ">=" then return v >= rhs end
        if op == "<=" then return v <= rhs end
        if op == "!"  then return v ~= rhs end
    end

    ---Fall back to string equality
    return tostring(itemVal) == expr
end


return itemFields
