require "Actions/ActionATM.lua"
local _internal = require "shop-shared"
require "shop-wallet.lua"

function ActionATM:perform()
	if self.sound then self.character:getEmitter():stopSound(self.sound) end
	
	if SandboxVars.ICurrency.MaxMoneyPerATM ~=0 then
		-- Use
		local amount = ZombRand(SandboxVars.ICurrency.MinMoneyPerATM, SandboxVars.ICurrency.MaxMoneyPerATM)

		if amount ~= 0 then
			local square = self.target:getSquare()
			self.character:Say("+" .. amount .. "$")

			local moneyTypes = _internal.getMoneyTypes()
			local type = moneyTypes[ZombRand(#moneyTypes)+1]
			local money = InventoryItemFactory.CreateItem(type)
			generateMoneyValue(money, amount, true)
			self.character:getInventory():AddItem(money)

			---self.character:getInventory():AddItems("Base.Money", amount)

			getSoundManager():PlayWorldSound("IC_MetalSnap", self.character:getCurrentSquare(), 1, 25, 2, true)
			addSound(self.character, square:getX(), square:getY(), square:getZ(), 25, 100)
			self.target:getModData().usedAge = self.currentAge
			self.target:transmitModData()
			self.blowtorch:setDelta(self.blowtorch:getDelta() - 0.1)
		end
	end

    ISBaseTimedAction.perform(self) -- Mandatory, performs core functions
end