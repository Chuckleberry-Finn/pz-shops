local itemFields = {}

---@param item InventoryItem
function itemFields.gatherFields(item)

    local fields

    ---@type InventoryItem
    fields = fields or {}

    ---name - ignore if original
    local name = item:getName()
    local script = item:getScriptItem()
    if (not script) or script and script:getDisplayName()~=name then
        fields.name = name
    end

    --if currentName and currentName~=item:originalName

    --      if (this.name != null && !this.name.equals(this.originalName)) {
    --         var6.addFlags(8);
    --         GameWindow.WriteString(var1, this.name);
    --      }


    --      if (this.uses != 1) {
    --         var3.addFlags(1);
    --         if (this.uses > 32767) {
    --            var1.putShort((short)32767);
    --         } else {
    --            var1.putShort((short)this.uses);
    --         }
    --      }
    --
    --      if (this.IsDrainable() && ((DrainableComboItem)this).getUsedDelta() < 1.0F) {
    --         var3.addFlags(2);
    --         float var4 = ((DrainableComboItem)this).getUsedDelta();
    --         byte var5 = (byte)((byte)((int)(var4 * 255.0F)) + -128);
    --         var1.put(var5);
    --      }
    --
    --      if (this.Condition != this.ConditionMax) {
    --         var3.addFlags(4);
    --         var1.put((byte)this.getCondition());
    --      }
    --
    --      if (this.visual != null) {
    --         var3.addFlags(8);
    --         this.visual.save(var1);
    --      }
    --
    --      if (this.isCustomColor() && (this.col.r != 1.0F || this.col.g != 1.0F || this.col.b != 1.0F || this.col.a != 1.0F)) {
    --         var3.addFlags(16);
    --         var1.put(Bits.packFloatUnitToByte(this.getColor().r));
    --         var1.put(Bits.packFloatUnitToByte(this.getColor().g));
    --         var1.put(Bits.packFloatUnitToByte(this.getColor().b));
    --         var1.put(Bits.packFloatUnitToByte(this.getColor().a));
    --      }
    --
    --      if (this.itemCapacity != -1.0F) {
    --         var3.addFlags(32);
    --         var1.putFloat(this.itemCapacity);
    --      }
    --
    --      if (this.table != null && !this.table.isEmpty()) {
    --         var6.addFlags(1);
    --         this.table.save(var1);
    --      }
    --
    --      if (this.isActivated()) {
    --         var6.addFlags(2);
    --      }
    --
    --      if (this.haveBeenRepaired != 1) {
    --         var6.addFlags(4);
    --         var1.putShort((short)this.getHaveBeenRepaired());
    --      }
    --
    --      if (this.name != null && !this.name.equals(this.originalName)) {
    --         var6.addFlags(8);
    --         GameWindow.WriteString(var1, this.name);
    --      }
    --
    --      if (this.byteData != null) {
    --         var6.addFlags(16);
    --         this.byteData.rewind();
    --         var1.putInt(this.byteData.limit());
    --         var1.put(this.byteData);
    --         this.byteData.flip();
    --      }
    --
    --      if (this.extraItems != null && this.extraItems.size() > 0) {
    --         var6.addFlags(32);
    --         var1.putInt(this.extraItems.size());
    --
    --         for(int var7 = 0; var7 < this.extraItems.size(); ++var7) {
    --            var1.putShort(WorldDictionary.getItemRegistryID((String)this.extraItems.get(var7)));
    --         }
    --      }
    --
    --      if (this.isCustomName()) {
    --         var6.addFlags(64);
    --      }
    --
    --      if (this.isCustomWeight()) {
    --         var6.addFlags(128);
    --         var1.putFloat(this.isCustomWeight() ? this.getActualWeight() : -1.0F);
    --      }
    --
    --      if (this.keyId != -1) {
    --         var6.addFlags(256);
    --         var1.putInt(this.getKeyId());
    --      }
    --
    --      if (this.isTaintedWater()) {
    --         var6.addFlags(512);
    --      }
    --
    --      if (this.remoteControlID != -1 || this.remoteRange != 0) {
    --         var6.addFlags(1024);
    --         var1.putInt(this.getRemoteControlID());
    --         var1.putInt(this.getRemoteRange());
    --      }
    --
    --      if (this.colorRed != 1.0F || this.colorGreen != 1.0F || this.colorBlue != 1.0F) {
    --         var6.addFlags(2048);
    --         var1.put(Bits.packFloatUnitToByte(this.colorRed));
    --         var1.put(Bits.packFloatUnitToByte(this.colorGreen));
    --         var1.put(Bits.packFloatUnitToByte(this.colorBlue));
    --      }
    --
    --      if (this.worker != null) {
    --         var6.addFlags(4096);
    --         GameWindow.WriteString(var1, this.getWorker());
    --      }
    --
    --      if (this.wetCooldown != -1.0F) {
    --         var6.addFlags(8192);
    --         var1.putFloat(this.wetCooldown);
    --      }
    --
    --      if (this.isFavorite()) {
    --         var6.addFlags(16384);
    --      }
    --
    --      if (this.stashMap != null) {
    --         var6.addFlags(32768);
    --         GameWindow.WriteString(var1, this.stashMap);
    --      }
    --
    --      if (this.isInfected()) {
    --         var6.addFlags(65536);
    --      }
    --
    --      if (this.currentAmmoCount != 0) {
    --         var6.addFlags(131072);
    --         var1.putInt(this.currentAmmoCount);
    --      }
    --
    --      if (this.attachedSlot != -1) {
    --         var6.addFlags(262144);
    --         var1.putInt(this.attachedSlot);
    --      }
    --
    --      if (this.attachedSlotType != null) {
    --         var6.addFlags(524288);
    --         GameWindow.WriteString(var1, this.attachedSlotType);
    --      }
    --
    --      if (this.attachedToModel != null) {
    --         var6.addFlags(1048576);
    --         GameWindow.WriteString(var1, this.attachedToModel);
    --      }
    --
    --      if (this.maxCapacity != -1) {
    --         var6.addFlags(2097152);
    --         var1.putInt(this.maxCapacity);
    --      }
    --
    --      if (this.isRecordedMedia()) {
    --         var6.addFlags(4194304);
    --         var1.putShort(this.recordedMediaIndex);
    --      }
    --
    --      if (this.worldZRotation > -1) {
    --         var6.addFlags(8388608);
    --         var1.putInt(this.worldZRotation);
    --      }
    --
    --      if (this.worldScale != 1.0F) {
    --         var6.addFlags(16777216);
    --         var1.putFloat(this.worldScale);
    --      }
    --
    --      if (this.isInitialised) {
    --         var6.addFlags(33554432);
    --      }
    --
    --      if (!var6.equals(0)) {
    --         var3.addFlags(64);
    --         var6.write();
    --      } else {
    --         var1.position(var6.getStartPosition());
    --      }
    --
    --      var3.write();
    --      var3.release();
    --      var6.release();
    --   }

    ---@type Clothing
    --   public void save(ByteBuffer var1, boolean var2) throws IOException {
    --      super.save(var1, var2);
    --      BitHeaderWrite var3 = BitHeader.allocWrite(BitHeader.HeaderSize.Byte, var1);
    --      if (this.getSpriteName() != null) {
    --         var3.addFlags(1);
    --         GameWindow.WriteString(var1, this.getSpriteName());
    --      }
    --
    --      if (this.dirtyness != 0.0F) {
    --         var3.addFlags(2);
    --         var1.putFloat(this.dirtyness);
    --      }
    --
    --      if (this.bloodLevel != 0.0F) {
    --         var3.addFlags(4);
    --         var1.putFloat(this.bloodLevel);
    --      }
    --
    --      if (this.wetness != 0.0F) {
    --         var3.addFlags(8);
    --         var1.putFloat(this.wetness);
    --      }
    --
    --      if (this.lastWetnessUpdate != 0.0F) {
    --         var3.addFlags(16);
    --         var1.putFloat(this.lastWetnessUpdate);
    --      }
    --
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
    --
    --      var3.write();
    --      var3.release();
    --   }

    ---@type Food

    --      var1.putFloat(this.Age);
    --      var1.putFloat(this.LastAged);

    --      if (this.calories != 0.0F || this.proteins != 0.0F || this.lipids != 0.0F || this.carbohydrates != 0.0F) {
    --         var1.putFloat(this.calories);
    --         var1.putFloat(this.proteins);
    --         var1.putFloat(this.lipids);
    --         var1.putFloat(this.carbohydrates);
    --      }
    --
    --      if (this.hungChange != 0.0F) { var1.putFloat(this.hungChange); }
    --      if (this.baseHunger != 0.0F) { var1.putFloat(this.baseHunger); }
    --      if (this.unhappyChange != 0.0F) { var1.putFloat(this.unhappyChange); }
    --      if (this.boredomChange != 0.0F) { var1.putFloat(this.boredomChange); }
    --      if (this.thirstChange != 0.0F) { var1.putFloat(this.thirstChange); }
    --
    --      BitHeaderWrite var4 = BitHeader.allocWrite(BitHeader.HeaderSize.Integer, var1);
    --      if (this.Heat != 1.0F) {
    --         var1.putFloat(this.Heat);
    --      }
    --
    --      if (this.LastCookMinute != 0) {
    --         var1.putInt(this.LastCookMinute);
    --      }
    --
    --      if (this.CookingTime != 0.0F) {
    --         var1.putFloat(this.CookingTime);
    --      }
    --
    --      if (this.Cooked) { }
    --      if (this.Burnt) { }
    --
    --      if (this.IsCookable) {}
    --
    --      if (this.bDangerousUncooked) {}
    --
    --      if (this.poisonDetectionLevel != -1) {var1.put((byte)this.poisonDetectionLevel);}
    --
    --      if (this.spices != null) {
    --         var1.put((byte)this.spices.size());
    --         Iterator var5 = this.spices.iterator();
    --         while(var5.hasNext()) {
    --            String var6 = (String)var5.next();
    --            GameWindow.WriteString(var1, var6);
    --         }
    --      }
    --
    --      if (this.PoisonPower != 0) { var1.put((byte)this.PoisonPower); }
    --      if (this.Chef != null) { GameWindow.WriteString(var1, this.Chef); }
    --      if ((double)this.OffAge != 1.0E9D) { var1.putInt(this.OffAge); }
    --      if ((double)this.OffAgeMax != 1.0E9D) { var1.putInt(this.OffAgeMax); }
    --      if (this.painReduction != 0.0F) { var1.putFloat(this.painReduction); }
    --      if (this.fluReduction != 0) { var1.putInt(this.fluReduction); }
    --      if (this.ReduceFoodSickness != 0) { var1.putInt(this.ReduceFoodSickness); }
    --      if (this.Poison) { }
    --      if (this.UseForPoison != 0) { var1.putShort((short)this.UseForPoison); }
    --      if (this.freezingTime != 0.0F) { var1.putFloat(this.freezingTime);}
    --      if (this.isFrozen()) {}
    --      if (this.LastFrozenUpdate != 0.0F) { var1.putFloat(this.LastFrozenUpdate);}
    --      if (this.rottenTime != 0.0F) {var1.putFloat(this.rottenTime);}
    --      if (this.compostTime != 0.0F) {var1.putFloat(this.compostTime);}
    --      if (this.cookedInMicrowave) {}
    --      if (this.fatigueChange != 0.0F) {var1.putFloat(this.fatigueChange);}
    --      if (this.endChange != 0.0F) {var1.putFloat(this.endChange);}


    ---@type HandWeapon
    --  public void save(ByteBuffer var1, boolean var2) throws IOException {
    --      super.save(var1, var2);
    --      BitHeaderWrite var3 = BitHeader.allocWrite(BitHeader.HeaderSize.Integer, var1);
    --      if (this.maxRange != 1.0F) {
    --         var3.addFlags(1);
    --         var1.putFloat(this.maxRange);
    --      }
    --
    --      if (this.minRangeRanged != 0.0F) {
    --         var3.addFlags(2);
    --         var1.putFloat(this.minRangeRanged);
    --      }
    --
    --      if (this.ClipSize != 0) {
    --         var3.addFlags(4);
    --         var1.putInt(this.ClipSize);
    --      }
    --
    --      if (this.minDamage != 0.4F) {
    --         var3.addFlags(8);
    --         var1.putFloat(this.minDamage);
    --      }
    --
    --      if (this.maxDamage != 1.5F) {
    --         var3.addFlags(16);
    --         var1.putFloat(this.maxDamage);
    --      }
    --
    --      if (this.RecoilDelay != 0) {
    --         var3.addFlags(32);
    --         var1.putInt(this.RecoilDelay);
    --      }
    --
    --      if (this.aimingTime != 0) {
    --         var3.addFlags(64);
    --         var1.putInt(this.aimingTime);
    --      }
    --
    --      if (this.reloadTime != 0) {
    --         var3.addFlags(128);
    --         var1.putInt(this.reloadTime);
    --      }
    --
    --      if (this.HitChance != 0) {
    --         var3.addFlags(256);
    --         var1.putInt(this.HitChance);
    --      }
    --
    --      if (this.minAngle != 0.5F) {
    --         var3.addFlags(512);
    --         var1.putFloat(this.minAngle);
    --      }
    --
    --      if (this.getScope() != null) {
    --         var3.addFlags(1024);
    --         var1.putShort(this.getScope().getRegistry_id());
    --      }
    --
    --      if (this.getClip() != null) {
    --         var3.addFlags(2048);
    --         var1.putShort(this.getClip().getRegistry_id());
    --      }
    --
    --      if (this.getRecoilpad() != null) {
    --         var3.addFlags(4096);
    --         var1.putShort(this.getRecoilpad().getRegistry_id());
    --      }
    --
    --      if (this.getSling() != null) {
    --         var3.addFlags(8192);
    --         var1.putShort(this.getSling().getRegistry_id());
    --      }
    --
    --      if (this.getStock() != null) {
    --         var3.addFlags(16384);
    --         var1.putShort(this.getStock().getRegistry_id());
    --      }
    --
    --      if (this.getCanon() != null) {
    --         var3.addFlags(32768);
    --         var1.putShort(this.getCanon().getRegistry_id());
    --      }
    --
    --      if (this.getExplosionTimer() != 0) {
    --         var3.addFlags(65536);
    --         var1.putInt(this.getExplosionTimer());
    --      }
    --
    --      if (this.maxAngle != 1.0F) {
    --         var3.addFlags(131072);
    --         var1.putFloat(this.maxAngle);
    --      }
    --
    --      if (this.bloodLevel != 0.0F) {
    --         var3.addFlags(262144);
    --         var1.putFloat(this.bloodLevel);
    --      }
    --
    --      if (this.containsClip) {
    --         var3.addFlags(524288);
    --      }
    --
    --      if (this.roundChambered) {
    --         var3.addFlags(1048576);
    --      }
    --
    --      if (this.isJammed) {
    --         var3.addFlags(2097152);
    --      }
    --
    --      if (!StringUtils.equals(this.weaponSprite, this.getScriptItem().getWeaponSprite())) {
    --         var3.addFlags(4194304);
    --         GameWindow.WriteString(var1, this.weaponSprite);
    --      }
    --
    --      var3.write();
    --      var3.release();
    --   }

    ---@type InventoryContainer
    --   public void save(ByteBuffer var1, boolean var2) throws IOException {
    --      super.save(var1, var2);
    --      var1.putInt(this.container.ID);
    --      var1.putInt(this.weightReduction);
    --      this.container.save(var1);
    --   }

    ---@type Literature
    --  public void save(ByteBuffer var1, boolean var2) throws IOException {
    --      super.save(var1, var2);
    --      BitHeaderWrite var3 = BitHeader.allocWrite(BitHeader.HeaderSize.Byte, var1);
    --      byte var4 = 0;
    --      if (this.numberOfPages >= 127 && this.numberOfPages < 32767) {
    --         var4 = 1;
    --      } else if (this.numberOfPages >= 32767) {
    --         var4 = 2;
    --      }
    --
    --      if (this.numberOfPages != -1) {
    --         var3.addFlags(1);
    --         if (var4 == 1) {
    --            var3.addFlags(2);
    --            var1.putShort((short)this.numberOfPages);
    --         } else if (var4 == 2) {
    --            var3.addFlags(4);
    --            var1.putInt(this.numberOfPages);
    --         } else {
    --            var1.put((byte)this.numberOfPages);
    --         }
    --      }
    --
    --      if (this.alreadyReadPages != 0) {
    --         var3.addFlags(8);
    --         if (var4 == 1) {
    --            var1.putShort((short)this.alreadyReadPages);
    --         } else if (var4 == 2) {
    --            var1.putInt(this.alreadyReadPages);
    --         } else {
    --            var1.put((byte)this.alreadyReadPages);
    --         }
    --      }
    --
    --      if (this.canBeWrite) {
    --         var3.addFlags(16);
    --      }
    --
    --      if (this.customPages != null && this.customPages.size() > 0) {
    --         var3.addFlags(32);
    --         var1.putInt(this.customPages.size());
    --         Iterator var5 = this.customPages.values().iterator();
    --
    --         while(var5.hasNext()) {
    --            String var6 = (String)var5.next();
    --            GameWindow.WriteString(var1, var6);
    --         }
    --      }
    --
    --      if (this.lockedBy != null) {
    --         var3.addFlags(64);
    --         GameWindow.WriteString(var1, this.getLockedBy());
    --      }
    --
    --      var3.write();
    --      var3.release();
    --   }

    ---@type MapItem
    --   public void save(ByteBuffer var1, boolean var2) throws IOException {
    --      super.save(var1, var2);
    --      GameWindow.WriteString(var1, this.m_mapID);
    --      this.m_symbols.save(var1);
    --   }

    ---@type AlarmClockClothing
    --    public void save(ByteBuffer var1, boolean var2) throws IOException {
    --        super.save(var1, var2);
    --        var1.putInt(this.alarmHour);
    --        var1.putInt(this.alarmMinutes);
    --        var1.put((byte)(this.alarmSet ? 1 : 0));
    --        var1.putFloat((float)this.ringSince);
    --    }


    ---@type AlarmClock
    --   public void save(ByteBuffer var1, boolean var2) throws IOException {
    --      super.save(var1, var2);
    --      var1.putInt(this.alarmHour);
    --      var1.putInt(this.alarmMinutes);
    --      var1.put((byte)(this.alarmSet ? 1 : 0));
    --      var1.putFloat((float)this.ringSince);
    --   }

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


function itemFields.getFieldAssociatedFunctions(item)

    local fields

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

    return fields
end


return itemFields