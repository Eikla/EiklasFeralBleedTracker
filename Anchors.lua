local _, addon = ...

local ipairs = ipairs
local pairs = pairs
local UIParent = UIParent

local function frameMatchesSpell(frame, spellID)
	if not frame or frame == UIParent then
		return false
	end

	if frame.__EFBTTracker then
		return false
	end

	if frame.IsForbidden and frame:IsForbidden() then
		return false
	end

	if frame.cooldownInfo and frame.cooldownInfo.spellID == spellID then
		return true
	end

	if frame.spellID == spellID then
		return true
	end

	if frame.GetSpellID and frame:GetSpellID() == spellID then
		return true
	end

	if frame.action and C_ActionBar and C_ActionBar.GetButtonSpell then
		local actionSpellID = C_ActionBar.GetButtonSpell(frame.action)
		if actionSpellID == spellID then
			return true
		end
	end

	return false
end

local function isAnchorUsable(frame)
	if not frame then
		return false
	end
	if frame.IsForbidden and frame:IsForbidden() then
		return false
	end
	if frame.IsVisible and not frame:IsVisible() then
		return false
	end
	return true
end

function addon:FindSpellAnchorFrame(spellIDs)
	local knownViewers = {
		_G.BuffIconCooldownViewer,
		_G.EssentialCooldownViewer,
		_G.UtilityCooldownViewer,
	}

	for _, viewer in ipairs(knownViewers) do
		if viewer then
			for _, child in ipairs({ viewer:GetChildren() }) do
				for _, spellID in ipairs(spellIDs) do
					if frameMatchesSpell(child, spellID) then
						return child
					end
				end
			end
		end
	end

	local frame = EnumerateFrames()
	while frame do
		if frame ~= UIParent then
			for _, spellID in ipairs(spellIDs) do
				if frameMatchesSpell(frame, spellID) then
					return frame
				end
			end
		end
		frame = EnumerateFrames(frame)
	end

	return nil
end

function addon:GetCachedAnchor(trackerID)
	local frame = self.state.anchorCache[trackerID]
	if isAnchorUsable(frame) then
		return frame
	end
	self.state.anchorCache[trackerID] = nil
	return nil
end

function addon:GetAnchorFrameForTracker(trackerID, forceRefresh)
	if not forceRefresh then
		local cached = self:GetCachedAnchor(trackerID)
		if cached then
			return cached
		end
	end

	local def = self.trackerDefs[trackerID]
	local anchor = self:FindSpellAnchorFrame(def.anchorSpellIDs)
	if isAnchorUsable(anchor) then
		self.state.anchorCache[trackerID] = anchor
		return anchor
	end

	self.state.anchorCache[trackerID] = nil
	return nil
end
