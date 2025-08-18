require "Actions/ActionCashRegister.lua"
local _internal = require "shop-shared"
require "shop-wallet.lua"

function ActionCashRegister:perform()
	if SandboxVars.ICurrency.MaxMoneyPerRegister ~=0 then
		local modData = self.target:getModData()
		local square = self.target:getSquare()
		local currentAge = GameTime:getInstance():getWorldAgeHours()
		if (SandboxVars.ICurrency.ResetTime == -1 and modData.usedAge) or (modData.usedAge and modData.usedAge + SandboxVars.ICurrency.ResetTime > currentAge) then 
			self.character:Say(getText("IGUI_RegisterWasOpen"))
			return 
		end 

		-- Use
		local amount = ZombRand(SandboxVars.ICurrency.MinMoneyPerRegister, SandboxVars.ICurrency.MaxMoneyPerRegister)
		if amount ~= 0 then 
			self.character:Say("+" .. amount .. "$")

			local moneyTypes = _internal.getMoneyTypes()
			local type = moneyTypes[ZombRand(#moneyTypes)+1]
			local money = InventoryItemFactory.CreateItem(type)
			generateMoneyValue(money, amount, true)
			self.character:getInventory():AddItem(money)

			---self.character:getInventory():AddItems("Base.Money", amount)

			getSoundManager():PlayWorldSound("IC_CashRegister", self.character:getCurrentSquare(), 0, 10, 1, true)
			addSound(self.character, square:getX(), square:getY(), square:getZ(), 10, 100)
			modData.usedAge = currentAge
			self.target:transmitModData()
		end
	end

    ISBaseTimedAction.perform(self) -- Mandatory, performs core functions
end