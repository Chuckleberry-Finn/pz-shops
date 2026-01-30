if not ActionSafe then return end

require "Actions/ActionSafe.lua"
local _internal = require "shop-shared"
require "shop-wallet.lua"


function ActionSafe:perform()
	if self.sound then self.character:getEmitter():stopSound(self.sound) end

	if SandboxVars.ICurrency.MaxMoneyPerSafe ~=0 then
		-- Use
		local amount = ZombRand(SandboxVars.ICurrency.MinMoneyPerSafe, SandboxVars.ICurrency.MaxMoneyPerSafe)

		if amount ~= 0 then
			local square = self.target:getSquare()
			self.character:Say("+" .. amount .. "$")
			getSoundManager():PlayWorldSound("IC_MetalSnap", self.character:getCurrentSquare(), 1, 25, 2, true)
			addSound(self.character, square:getX(), square:getY(), square:getZ(), 25, 100)
			self.target:getModData().usedAge = self.currentAge
			self.target:transmitModData()

			local moneyTypes = _internal.getMoneyTypes()
			local type = moneyTypes[ZombRand(#moneyTypes)+1]

			if amount > 100 then 
				local change = amount % 100

				local money = InventoryItemFactory.CreateItem(type)
				generateMoneyValue(money, change, true)
				self.character:getInventory():AddItem(money)

				--self.character:getInventory():AddItems("Base.Money", change)

				local stacks = amount / 100
				self.character:getInventory():AddItems("ICurrency.MoneyStack", stacks)
			else

				local money = InventoryItemFactory.CreateItem(type)
				generateMoneyValue(money, amount, true)
				self.character:getInventory():AddItem(money)

				--self.character:getInventory():AddItems("Base.Money", amount)
			end

			self.blowtorch:setDelta(self.blowtorch:getDelta() - 0.1)
		end
	end

    ISBaseTimedAction.perform(self) -- Mandatory, performs core functions
end