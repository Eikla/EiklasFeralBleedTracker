local ADDON_NAME, addon = ...

local CreateFrame = CreateFrame
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local IsPlayerSpell = IsPlayerSpell
local IsStealthed = IsStealthed
local ceil = math.ceil

local playerClass = select(2, UnitClass("player"))
addon.playerClass = playerClass

addon.frame = addon.frame or CreateFrame("Frame")
addon.trackerOrder = { "rake", "moonfire", "rip", "primal_wrath" }
addon.trackerDefs = {
	rake = {
		id = "rake",
		label = "Rake",
		snapshotKey = "rake",
		anchorSpellIDs = { 1822 },
		castSpellIDs = { 1822 },
		auraSpellID = 1822,
		defaultEnabled = true,
	},
	moonfire = {
		id = "moonfire",
		label = "Moonfire",
		snapshotKey = "moonfire",
		anchorSpellIDs = { 155580, 155625 },
		castSpellIDs = { 155580, 155625 },
		auraSpellID = 155625,
		defaultEnabled = true,
	},
	rip = {
		id = "rip",
		label = "Rip",
		snapshotKey = "rip",
		anchorSpellIDs = { 1079 },
		castSpellIDs = { 1079 },
		auraSpellID = 1079,
		defaultEnabled = true,
	},
	primal_wrath = {
		id = "primal_wrath",
		label = "Primal Wrath",
		snapshotKey = "rip",
		anchorSpellIDs = { 285381 },
		castSpellIDs = { 285381 },
		auraSpellID = 1079,
		defaultEnabled = false,
	},
}

addon.defaults = {
	enabled = true,
	previewMode = false,
	fontFace = "FRIZQT__",
	fontSize = 20,
	fontFlags = "OUTLINE",
	colors = {
		strong = { 0, 1, 0 },
		equal = { 1, 1, 1 },
		weak = { 1, 0.65, 0.65 },
	},
	trackers = {
		rake = {
			enabled = true,
			attachToSpell = true,
			offsetX = 0,
			offsetY = -18,
			manualPoint = "CENTER",
			manualRelativePoint = "CENTER",
			manualX = -180,
			manualY = 40,
		},
		moonfire = {
			enabled = true,
			attachToSpell = true,
			offsetX = 0,
			offsetY = -18,
			manualPoint = "CENTER",
			manualRelativePoint = "CENTER",
			manualX = -60,
			manualY = 40,
		},
		rip = {
			enabled = true,
			attachToSpell = true,
			offsetX = 0,
			offsetY = -18,
			manualPoint = "CENTER",
			manualRelativePoint = "CENTER",
			manualX = 60,
			manualY = 40,
		},
		primal_wrath = {
			enabled = false,
			attachToSpell = true,
			offsetX = 0,
			offsetY = -18,
			manualPoint = "CENTER",
			manualRelativePoint = "CENTER",
			manualX = 180,
			manualY = 40,
		},
	},
}

addon.state = addon.state or {
	activeDots = {},
	stealthed = false,
	tfStrength = 1.15,
	tfDuration = 10,
	glorped = false,
	initialized = false,
	unlockMode = false,
	anchorCache = {},
}

local trackedCastSpellIDs = {}
for trackerID, def in pairs(addon.trackerDefs) do
	for _, spellID in ipairs(def.castSpellIDs) do
		trackedCastSpellIDs[spellID] = trackerID
	end
end

local function copyDefaults(source, target)
	for key, value in pairs(source) do
		if type(value) == "table" then
			target[key] = target[key] or {}
			copyDefaults(value, target[key])
		elseif target[key] == nil then
			target[key] = value
		end
	end
	return target
end

local function hasValues(tbl)
	for _ in pairs(tbl) do
		return true
	end
	return false
end

function addon:GetDB()
	EiklasFeralBleedTrackerDB = EiklasFeralBleedTrackerDB or {}
	self.db = copyDefaults(self.defaults, EiklasFeralBleedTrackerDB)
	return self.db
end

function addon:IsPreviewActive()
	return self.db and self.db.previewMode or self.state.unlockMode
end

function addon:IsFeralSpec()
	if playerClass ~= "DRUID" then
		return false
	end

	local specIndex = GetSpecialization()
	if not specIndex then
		return false
	end

	local specID = GetSpecializationInfo(specIndex)
	return specID == 103
end

function addon:IsRuntimeActive()
	return self.db and self.db.enabled and self:IsFeralSpec()
end

function addon:IsTrackerSpellKnown(trackerID)
	if trackerID == "moonfire" then
		return IsPlayerSpell(155580)
	end
	if trackerID == "primal_wrath" then
		return IsPlayerSpell(285381)
	end
	return true
end

function addon:IsTrackerConfigured(trackerID)
	local trackerDB = self.db and self.db.trackers and self.db.trackers[trackerID]
	return trackerDB and trackerDB.enabled
end

function addon:ShouldShowTracker(trackerID)
	if not self:IsTrackerConfigured(trackerID) then
		return false
	end

	if self:IsPreviewActive() then
		return true
	end

	if not self:IsRuntimeActive() then
		return false
	end

	return self:IsTrackerSpellKnown(trackerID)
end

function addon:GetTrackerColor(colorKey)
	local colors = self.db.colors
	local color = colors[colorKey] or colors.equal
	return color[1], color[2], color[3]
end

function addon:GetTargetKey()
	local target = UnitGUID("target")

	if type(issecretvalue) == "function" and target and issecretvalue(target) and C_NamePlate and C_NamePlate.GetNamePlateForUnit then
		target = C_NamePlate.GetNamePlateForUnit("target")
	end

	if type(issecretvalue) == "function" and target and issecretvalue(target) then
		target = "glorp"
		if not self.state.glorped then
			self.state.glorped = true
			print("Eikla's Feral Bleed Tracker: target identity is restricted, multi-target snapshot storage may be less accurate.")
		end
	end

	return target
end

function addon:HasAuraBySpellID(unit, spellID, filter)
	if AuraUtil and AuraUtil.FindAuraBySpellID then
		return AuraUtil.FindAuraBySpellID(spellID, unit, filter) ~= nil
	end

	if unit == "player" and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
		return C_UnitAuras.GetPlayerAuraBySpellID(spellID) ~= nil
	end

	return false
end

function addon:IsTigerFuryActive()
	return self:HasAuraBySpellID("player", 5217, "HELPFUL")
end

function addon:GetCurrentStrength(trackerID)
	local value = 1

	if self:IsTigerFuryActive() then
		value = value * self.state.tfStrength
	end

	if trackerID == "rake" and self.state.stealthed then
		value = value * 1.6
	end

	return value
end

function addon:PruneTargetSnapshots(targetKey)
	local dots = self.state.activeDots[targetKey]
	if dots and not hasValues(dots) then
		self.state.activeDots[targetKey] = nil
	end
end

function addon:ClearSnapshot(snapshotKey, targetKey)
	local resolvedTarget = targetKey or self:GetTargetKey()
	if not resolvedTarget then
		return
	end

	local dots = self.state.activeDots[resolvedTarget]
	if not dots then
		return
	end

	dots[snapshotKey] = nil
	self:PruneTargetSnapshots(resolvedTarget)
end

function addon:ApplySnapshot(snapshotKey, trackerID)
	if not self:IsRuntimeActive() then
		return
	end

	local targetKey = self:GetTargetKey()
	if not targetKey then
		return
	end

	self.state.activeDots[targetKey] = self.state.activeDots[targetKey] or {}
	self.state.activeDots[targetKey][snapshotKey] = self:GetCurrentStrength(trackerID)
	self:RefreshAll()
end

function addon:SyncTargetSnapshots()
	if not self:IsRuntimeActive() or not UnitExists("target") then
		return
	end

	local targetKey = self:GetTargetKey()
	if not targetKey or not self.state.activeDots[targetKey] then
		return
	end

	local dots = self.state.activeDots[targetKey]
	if not self:HasAuraBySpellID("target", 1822, "HARMFUL|PLAYER") then
		dots.rake = nil
	end
	if not self:HasAuraBySpellID("target", 155625, "HARMFUL|PLAYER") then
		dots.moonfire = nil
	end
	if not self:HasAuraBySpellID("target", 1079, "HARMFUL|PLAYER") then
		dots.rip = nil
	end

	self:PruneTargetSnapshots(targetKey)
end

function addon:GetDisplayInfo(trackerID)
	if self:IsPreviewActive() then
		local preview = {
			rake = { "125", "strong" },
			moonfire = { "110", "strong" },
			rip = { "95", "weak" },
			primal_wrath = { "95", "weak" },
		}
		local info = preview[trackerID] or { "---", "equal" }
		return info[1], info[2]
	end

	if not self:IsRuntimeActive() then
		return nil
	end

	if not UnitExists("target") then
		return "---", "equal"
	end

	local targetKey = self:GetTargetKey()
	if not targetKey then
		return "---", "equal"
	end

	local def = self.trackerDefs[trackerID]
	local dots = self.state.activeDots[targetKey]
	local currentStrength = dots and dots[def.snapshotKey] or nil
	if not currentStrength or currentStrength <= 0 then
		return "---", "equal"
	end

	local newStrength = self:GetCurrentStrength(trackerID)
	local percent = ceil((newStrength / currentStrength) * 100)
	if percent > 100 then
		return tostring(percent), "strong"
	end
	if percent < 100 then
		return tostring(percent), "weak"
	end
	return tostring(percent), "equal"
end

function addon:RefreshTalents()
	self.state.tfStrength = 1.15
	self.state.tfDuration = 10

	local activeConfigID = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
	local strengthModifiers = {
		[103173] = 0.06,
		[103168] = 0.10,
	}
	local durationModifiers = {
		[103169] = 5,
		[103186] = 5,
	}

	if activeConfigID and C_Traits and C_Traits.GetNodeInfo then
		for _, nodeID in ipairs({ 82110, 82107, 82122 }) do
			local nodeInfo = C_Traits.GetNodeInfo(activeConfigID, nodeID)
			if nodeInfo and nodeInfo.entryIDsWithCommittedRanks then
				for _, entryID in ipairs(nodeInfo.entryIDsWithCommittedRanks) do
					local ranks = nodeInfo.ranksPurchased or 0
					if strengthModifiers[entryID] then
						self.state.tfStrength = self.state.tfStrength + (ranks * strengthModifiers[entryID])
					end
					if durationModifiers[entryID] then
						self.state.tfDuration = self.state.tfDuration + (ranks * durationModifiers[entryID])
					end
				end
			end
		end
	end

	self:RefreshAll(true)
end

function addon:HandleStealthUpdate()
	if self.stealthTimer then
		self.stealthTimer:Cancel()
		self.stealthTimer = nil
	end

	if IsStealthed() then
		self.state.stealthed = true
		self:RefreshAll()
		return
	end

	self.stealthTimer = C_Timer.NewTimer(0.05, function()
		addon.state.stealthed = false
		addon:RefreshAll()
	end)
	self:RefreshAll()
end

function addon:RefreshAll(forceAnchors)
	if not self.state.initialized or not self.trackerFrames then
		return
	end

	if self:IsRuntimeActive() then
		self:SyncTargetSnapshots()
	end

	self:RefreshTrackers(forceAnchors)

	if self.RefreshOptionsStatusText then
		self:RefreshOptionsStatusText()
	end
end

function addon:DelayedTalentRefresh(delaySeconds)
	C_Timer.After(delaySeconds or 0.1, function()
		if addon.state.initialized then
			addon:RefreshTalents()
		end
	end)
end

function addon:Initialize()
	if self.state.initialized then
		return
	end

	self:GetDB()
	self.state.initialized = true
	self.state.stealthed = IsStealthed() or false

	self:CreateTrackerFrames()
	self:RefreshTalents()
	self:RefreshAll(true)

	if not self.state.anchorTicker then
		self.state.anchorTicker = C_Timer.NewTicker(1, function()
			if addon.state.initialized then
				addon:RefreshAll(true)
			end
		end)
	end
end

SLASH_EIKLASFERALBLEEDTRACKER1 = "/efbt"
SlashCmdList.EIKLASFERALBLEEDTRACKER = function(msg)
	local cmd = (msg or ""):lower():match("^%s*(.-)%s*$")
	if cmd == "unlock" then
		addon:StartUnlockMode()
		return
	end
	if cmd == "lock" then
		addon:StopUnlockMode()
		return
	end
	if addon.OpenOptions then
		addon:OpenOptions()
	else
		print("Eikla's Feral Bleed Tracker: options are not ready yet.")
	end
end

addon.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
addon.frame:RegisterEvent("PLAYER_TARGET_CHANGED")
addon.frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
addon.frame:RegisterEvent("PLAYER_TALENT_UPDATE")
addon.frame:RegisterEvent("SPELLS_CHANGED")
addon.frame:RegisterEvent("TRAIT_CONFIG_UPDATED")
addon.frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
addon.frame:RegisterEvent("UNIT_AURA")
addon.frame:RegisterEvent("UPDATE_STEALTH")
addon.frame:SetScript("OnEvent", function(_, event, ...)
	if event == "PLAYER_ENTERING_WORLD" then
		addon:Initialize()
		return
	end

	if not addon.state.initialized then
		return
	end

	if event == "PLAYER_TARGET_CHANGED" then
		addon:RefreshAll(true)
	elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
		local unit = ...
		if unit == "player" then
			addon:DelayedTalentRefresh(0.1)
		end
	elseif event == "PLAYER_TALENT_UPDATE" or event == "SPELLS_CHANGED" or event == "TRAIT_CONFIG_UPDATED" then
		addon:DelayedTalentRefresh(0.1)
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		local unit, _, spellID = ...
		if unit ~= "player" then
			return
		end

		local trackerID = trackedCastSpellIDs[spellID]
		if trackerID then
			addon:ApplySnapshot(addon.trackerDefs[trackerID].snapshotKey, trackerID)
		elseif spellID == 5217 then
			addon:RefreshAll()
		elseif spellID == 384255 then
			addon:DelayedTalentRefresh(0.5)
		end
	elseif event == "UNIT_AURA" then
		local unit = ...
		if unit == "player" or unit == "target" then
			addon:RefreshAll()
		end
	elseif event == "UPDATE_STEALTH" then
		addon:HandleStealthUpdate()
	end
end)
