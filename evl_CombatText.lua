local addonName, addon = ...

local spreeSounds = {
	[3] = "Killing_Spree",
	[4] = "Dominating",
	[5] = "Mega_Kill",
	[6] = "Unstoppable",
	[7] = "Wicked_Sick",
	[8] = "Monster_Kill",
	[9] = "Ludicrous_Kill",
	[10] = "God_Like",
	[11] = "Holy_Shit"
}

local multiSounds = {
	[2] = "Double_Kill",
	[3] = "Triple_Kill",
}

local path = "Interface\\AddOns\\" .. addonName .. "\\sounds\\%s.mp3"
local multiKillDecayTime = 11.5
local killingStreak = 0
local multiKill = 0
local lastKillTime = 0
local executeThreshold
local executeMessage
local previousHealth

local pendingSound

local bit_band = bit.band
local bit_bor = bit.bor

local hasFlag = function(flags, flag)
	return bit_band(flags, flag) == flag
end

local onEvent = function(self, event, ...)
	addon[event](self, event, ...)
end

local lastUpdate = 0
local onUpdate = function(self, elapsed)
	lastUpdate = lastUpdate + elapsed
	
	if lastUpdate > 2 then
		lastUpdate = 0
		
		if pendingSound then
			PlaySoundFile(pendingSound)
			pendingSound = nil
		end
	end
end

local playSounds = function()
	local multiFileName = multiSounds[math.min(3, multiKill)]
	local spreeFileName = spreeSounds[math.min(11, killingStreak)]

	if multiFileName then
		PlaySoundFile(string.format(path, multiFileName))
	end

	if spreeFileName then
		local spreeFilePath = string.format(path, spreeFileName)

		if not multiFileName then
			PlaySoundFile(spreeFilePath)
		else
			pendingSound = spreeFilePath
		end
	end
end

function addon:ADDON_LOADED(event, addonName)
	-- Override default Blizzard colors if present
	if addonName == "Blizzard_CombatText" then
		-- We could set the table but we just want to change color and Blizzard frequently changes this format
		COMBAT_TEXT_TYPE_INFO["ENTERING_COMBAT"].r = 0.1
		COMBAT_TEXT_TYPE_INFO["ENTERING_COMBAT"].g = 0.1
		COMBAT_TEXT_TYPE_INFO["ENTERING_COMBAT"].b = 1
		COMBAT_TEXT_TYPE_INFO["LEAVING_COMBAT"].r = 0.1
		COMBAT_TEXT_TYPE_INFO["LEAVING_COMBAT"].g = 0.1
		COMBAT_TEXT_TYPE_INFO["LEAVING_COMBAT"].b = 1
		COMBAT_TEXT_TYPE_INFO["COMBO_POINTS"].r = 0.7
		COMBAT_TEXT_TYPE_INFO["COMBO_POINTS"].g = 0.7
		COMBAT_TEXT_TYPE_INFO["COMBO_POINTS"].b = 1
		
		-- Override default Blizzard strings
		ENTERING_COMBAT = "Fight!"
		LEAVING_COMBAT = "Ninja Time!"
		HEALTH_LOW = "Low Health"

		self:UnregisterEvent("ADDON_LOADED")
	end
end

function addon:PLAYER_TARGET_CHANGED()
	previousHealth = 0
end

function addon:PLAYER_DEAD()
	killingStreak = 0
end

function addon:COMBAT_LOG_EVENT_UNFILTERED(event, timestamp, eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, ...)
	-- Killing blows
	if eventType == "PARTY_KILL" and hasFlag(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) and hasFlag(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) then
		if COMBAT_TEXT_TYPE_INFO then
			CombatText_AddMessage("Killing Blow! (" .. destName .. ")", COMBAT_TEXT_SCROLL_FUNCTION, .7, .7, 1, nil, nil)
		end

		local now = GetTime()
		
		if lastKillTime + multiKillDecayTime > now then
			multiKill = multiKill + 1
		else
			multiKill = 1
		end
		
		lastKillTime = now
		killingStreak = killingStreak + 1
		playSounds()
	-- Interrupts
	elseif eventType == "SPELL_INTERRUPT" and hasFlag(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) then
		local spellID, spellName, spellSchool, extraSpellID, extraSpellName, extraSpellSchool = ...
		CombatText_AddMessage(format("%s Interrupted!", extraSpellName), COMBAT_TEXT_SCROLL_FUNCTION, .1, .1, 1, nil, nil)
	end
end

function addon:UNIT_HEALTH(event, unit)
	if executeThreshold and unit == "target" and UnitCanAttack("player", unit) then
		local value, max = UnitHealth(unit), UnitHealthMax(unit)
		local threshold = max * executeThreshold
		
		if (previousHealth == 0 or previousHealth > threshold) and value < threshold then
			CombatText_AddMessage("Execute!", COMBAT_TEXT_SCROLL_FUNCTION, 1, .1, .1, nil, nil)
		end
		
		previousHealth = value
	end
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", onEvent)
frame:SetScript("OnUpdate", onUpdate)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")

-- Execute range notification, currently only implemented for rogues
local playerClass = select(2, UnitClass("player"))

-- Assassination's Murderous Intent
if playerClass == "ROGUE" and GetPrimaryTalentTree() == 1 then
	executeThreshold = 0.35
	executeMessage = "Execute!"
	
	frame:RegisterEvent("UNIT_HEALTH")
end