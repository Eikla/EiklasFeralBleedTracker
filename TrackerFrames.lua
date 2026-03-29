local ADDON_NAME, addon = ...

local CreateFrame = CreateFrame
local UIParent = UIParent

local function setTrackerBackdrop(frame, shown)
	if shown then
		frame.bg:SetColorTexture(0.05, 0.05, 0.05, 0.55)
		frame.border:SetColorTexture(0.1, 0.8, 0.2, 0.9)
	else
		frame.bg:SetColorTexture(0, 0, 0, 0)
		frame.border:SetColorTexture(0, 0, 0, 0)
	end
end

function addon:CreateTrackerFrames()
	if self.trackerFrames then
		return
	end

	self.trackerFrames = {}

	for _, trackerID in ipairs(self.trackerOrder) do
		local def = self.trackerDefs[trackerID]
		local frame = CreateFrame("Button", ADDON_NAME .. "_" .. trackerID, UIParent)
		frame.__EFBTTracker = true
		frame.trackerID = trackerID
		frame:SetSize(130, 30)
		frame:SetClampedToScreen(true)
		frame:SetMovable(true)
		frame:RegisterForDrag("LeftButton")
		frame:SetFrameStrata("DIALOG")

		frame.bg = frame:CreateTexture(nil, "BACKGROUND")
		frame.bg:SetAllPoints()
		frame.border = frame:CreateTexture(nil, "BORDER")
		frame.border:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
		frame.border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)

		frame.value = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
		frame.value:SetPoint("CENTER")

		frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		frame.label:SetPoint("BOTTOM", frame, "TOP", 0, 2)
		frame.label:SetText(def.label)

		frame:SetScript("OnDragStart", function(selfFrame)
			if addon.state.unlockMode and not addon.db.trackers[selfFrame.trackerID].attachToSpell then
				selfFrame:StartMoving()
			end
		end)
		frame:SetScript("OnDragStop", function(selfFrame)
			selfFrame:StopMovingOrSizing()
			addon:SaveManualPosition(selfFrame.trackerID)
		end)

		setTrackerBackdrop(frame, false)
		frame:Hide()
		self.trackerFrames[trackerID] = frame
	end
end

function addon:ApplyFonts()
	local fontPath = "Fonts\\" .. (self.db.fontFace or "FRIZQT__") .. ".TTF"
	local fontFlags = self.db.fontFlags

	for _, trackerID in ipairs(self.trackerOrder) do
		local frame = self.trackerFrames[trackerID]
		frame.value:SetFont(fontPath, self.db.fontSize or 20, fontFlags ~= "" and fontFlags or nil)
	end
end

function addon:ApplyManualPosition(trackerID)
	local frame = self.trackerFrames[trackerID]
	local trackerDB = self.db.trackers[trackerID]

	frame:SetPoint(
		trackerDB.manualPoint or "CENTER",
		UIParent,
		trackerDB.manualRelativePoint or "CENTER",
		trackerDB.manualX or 0,
		trackerDB.manualY or 0
	)
end

function addon:ApplyTrackerPosition(trackerID, forceAnchors)
	local frame = self.trackerFrames[trackerID]
	local trackerDB = self.db.trackers[trackerID]

	frame:ClearAllPoints()
	if trackerDB.attachToSpell then
		local anchor = self:GetAnchorFrameForTracker(trackerID, forceAnchors)
		if anchor then
			frame:SetPoint("CENTER", anchor, "CENTER", trackerDB.offsetX or 0, trackerDB.offsetY or 0)
			return
		end
	end

	self:ApplyManualPosition(trackerID)
end

function addon:SaveManualPosition(trackerID)
	local frame = self.trackerFrames[trackerID]
	local trackerDB = self.db.trackers[trackerID]
	local point, _, relativePoint, x, y = frame:GetPoint(1)

	trackerDB.manualPoint = point or "CENTER"
	trackerDB.manualRelativePoint = relativePoint or "CENTER"
	trackerDB.manualX = x or 0
	trackerDB.manualY = y or 0
end

function addon:ResetTrackerPosition(trackerID)
	self:GetDB()

	local defaults = self.defaults.trackers[trackerID]
	local trackerDB = self.db.trackers[trackerID]

	trackerDB.manualPoint = defaults.manualPoint
	trackerDB.manualRelativePoint = defaults.manualRelativePoint
	trackerDB.manualX = defaults.manualX
	trackerDB.manualY = defaults.manualY
	trackerDB.offsetX = defaults.offsetX
	trackerDB.offsetY = defaults.offsetY

	self.state.anchorCache[trackerID] = nil
	self:RefreshAll(true)
end

function addon:ResetAllTrackerPositions()
	self:GetDB()

	for _, trackerID in ipairs(self.trackerOrder) do
		local defaults = self.defaults.trackers[trackerID]
		local trackerDB = self.db.trackers[trackerID]

		trackerDB.manualPoint = defaults.manualPoint
		trackerDB.manualRelativePoint = defaults.manualRelativePoint
		trackerDB.manualX = defaults.manualX
		trackerDB.manualY = defaults.manualY
		trackerDB.offsetX = defaults.offsetX
		trackerDB.offsetY = defaults.offsetY
		self.state.anchorCache[trackerID] = nil
	end
	self:RefreshAll(true)
end

function addon:StartUnlockMode()
	self:GetDB()
	self.state.unlockMode = true
	self:RefreshAll(true)
end

function addon:StopUnlockMode()
	self:GetDB()
	self.state.unlockMode = false
	self:RefreshAll(true)
end

function addon:RefreshTrackers(forceAnchors)
	self:ApplyFonts()

	for _, trackerID in ipairs(self.trackerOrder) do
		local frame = self.trackerFrames[trackerID]
		local showTracker = self:ShouldShowTracker(trackerID)

		if showTracker then
			self:ApplyTrackerPosition(trackerID, forceAnchors)

			local text, colorKey = self:GetDisplayInfo(trackerID)
			local r, g, b = self:GetTrackerColor(colorKey or "equal")
			frame.value:SetText(text or "---")
			frame.value:SetTextColor(r, g, b)
			if self.state.unlockMode or self.db.previewMode then
				frame.label:Show()
			else
				frame.label:Hide()
			end
			setTrackerBackdrop(frame, self.state.unlockMode)
			frame:EnableMouse(self.state.unlockMode and not self.db.trackers[trackerID].attachToSpell)
			frame:Show()
		else
			frame:EnableMouse(false)
			frame:Hide()
		end
	end
end
