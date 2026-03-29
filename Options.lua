local ADDON_NAME, addon = ...

local title = "Eikla's Feral Bleed Tracker"

local function refreshEverything()
	addon:GetDB()
	addon:RefreshAll(true)
end

local function registerBoolean(category, key, label, tooltip, defaultValue, getter, setter)
	local setting = Settings.RegisterProxySetting(category, key, "boolean", label, defaultValue, getter, setter)
	Settings.CreateCheckbox(category, setting, tooltip)
end

local function registerSlider(category, key, label, tooltip, defaultValue, minValue, maxValue, step, getter, setter, formatter)
	local setting = Settings.RegisterProxySetting(category, key, "number", label, defaultValue, getter, setter)
	local options = Settings.CreateSliderOptions(minValue, maxValue, step)
	options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, formatter or function(value)
		return tostring(value)
	end)
	Settings.CreateSlider(category, setting, options, tooltip)
end

local function registerDropdown(category, key, label, tooltip, defaultValue, getter, setter, buildOptions)
	local setting = Settings.RegisterProxySetting(category, key, "string", label, defaultValue, getter, setter)
	Settings.CreateDropdown(category, setting, buildOptions, tooltip)
end

local root = CreateFrame("Frame", ADDON_NAME .. "OptionsRoot", InterfaceOptionsFramePanelContainer)
root.name = title

root.title = root:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
root.title:SetPoint("TOPLEFT", 7, -22)
root.title:SetText(title)

root.divider = root:CreateTexture(nil, "ARTWORK")
root.divider:SetAtlas("Options_HorizontalDivider", true)
root.divider:SetPoint("TOP", 0, -50)

root.description = root:CreateFontString(nil, "ARTWORK", "GameFontNormal")
root.description:SetPoint("TOPLEFT", root.divider, "BOTTOMLEFT", 0, -20)
root.description:SetWidth(700)
root.description:SetJustifyH("LEFT")
root.description:SetText("Tracks Midnight-style bleed snapshot percentages for Feral Druids. Use spell-frame mode to attach to Blizzard/default cooldown viewers or compatible cooldown addons, or switch individual trackers to free-move mode and drag them anywhere.")

root.status = root:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
root.status:SetPoint("TOPLEFT", root.description, "BOTTOMLEFT", 0, -20)
root.status:SetWidth(700)
root.status:SetJustifyH("LEFT")

root.unlockButton = CreateFrame("Button", nil, root, "UIPanelButtonTemplate")
root.unlockButton:SetSize(190, 24)
root.unlockButton:SetPoint("TOPLEFT", root.status, "BOTTOMLEFT", 0, -18)
root.unlockButton:SetText("Unlock Free-Position Trackers")
root.unlockButton:SetScript("OnClick", function()
		addon:StartUnlockMode()
	end)

root.lockButton = CreateFrame("Button", nil, root, "UIPanelButtonTemplate")
root.lockButton:SetSize(120, 24)
root.lockButton:SetPoint("LEFT", root.unlockButton, "RIGHT", 12, 0)
root.lockButton:SetText("Lock Trackers")
root.lockButton:SetScript("OnClick", function()
		addon:StopUnlockMode()
	end)

root.resetButton = CreateFrame("Button", nil, root, "UIPanelButtonTemplate")
root.resetButton:SetSize(140, 24)
root.resetButton:SetPoint("LEFT", root.lockButton, "RIGHT", 12, 0)
root.resetButton:SetText("Reset All Positions")
root.resetButton:SetScript("OnClick", function()
		addon:ResetAllTrackerPositions()
	end)

root.moveHelp = root:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
root.moveHelp:SetPoint("TOPLEFT", root.unlockButton, "BOTTOMLEFT", 0, -10)
root.moveHelp:SetWidth(700)
root.moveHelp:SetJustifyH("LEFT")
root.moveHelp:SetText("Only trackers set to free-move mode can be dragged. Spell-frame trackers stay attached to their matching spell icon and use the X/Y offset sliders from their tracker section.")

function addon:RefreshOptionsStatusText()
	if not root.status then
		return
	end

	local lines = {}
	if self.playerClass ~= "DRUID" then
		lines[#lines + 1] = "Status: inactive. The addon only tracks while you are on a Druid."
	elseif not self.db.enabled then
		lines[#lines + 1] = "Status: disabled in settings."
	elseif self:IsFeralSpec() then
		lines[#lines + 1] = "Status: active for Feral."
	else
		lines[#lines + 1] = "Status: inactive. Switch to Feral to enable tracking."
	end

	if self.db.previewMode then
		lines[#lines + 1] = "Preview mode is on. Trackers will stay visible with sample values."
	end
	if self.state.unlockMode then
		lines[#lines + 1] = "Free-position trackers are currently unlocked."
	end

	root.status:SetText(table.concat(lines, "\n"))
end

root:SetScript("OnShow", function()
	addon:GetDB()
	addon:RefreshOptionsStatusText()
end)

local rootCategory = Settings.RegisterCanvasLayoutCategory(root, title)
addon.optionsCategoryID = rootCategory:GetID()

local generalCategory = Settings.RegisterVerticalLayoutSubcategory(rootCategory, "General")
local appearanceCategory = Settings.RegisterVerticalLayoutSubcategory(rootCategory, "Appearance")
local trackerCategories = {}

registerBoolean(
	generalCategory,
	"efbt_enabled",
	"Enable addon",
	"Turns runtime tracking on or off.",
	addon.defaults.enabled,
	function()
		return addon:GetDB().enabled
	end,
	function(value)
		addon.db.enabled = value
		refreshEverything()
	end
)

registerBoolean(
	generalCategory,
	"efbt_preview_mode",
	"Preview mode",
	"Shows sample values so you can configure fonts and positions even without an active target.",
	addon.defaults.previewMode,
	function()
		return addon:GetDB().previewMode
	end,
	function(value)
		addon.db.previewMode = value
		refreshEverything()
	end
)

registerSlider(
	appearanceCategory,
	"efbt_font_size",
	"Font size",
	"Controls the shared font size for all trackers.",
	addon.defaults.fontSize,
	8,
	40,
	1,
	function()
		return addon:GetDB().fontSize
	end,
	function(value)
		addon.db.fontSize = value
		refreshEverything()
	end,
	function(value)
		return string.format("%d px", value)
	end
)

registerDropdown(
	appearanceCategory,
	"efbt_font_face",
	"Font face",
	"Built-in game font used by tracker text.",
	addon.defaults.fontFace,
	function()
		return addon:GetDB().fontFace
	end,
	function(value)
		addon.db.fontFace = value
		refreshEverything()
	end,
	function()
		local container = Settings.CreateControlTextContainer()
		container:Add("FRIZQT__", "Friz Quadrata")
		container:Add("ARIALN", "Arial Narrow")
		container:Add("MORPHEUS", "Morpheus")
		container:Add("SKURRI", "Skurri")
		return container:GetData()
	end
)

registerDropdown(
	appearanceCategory,
	"efbt_font_flags",
	"Outline",
	"Outline style applied to tracker text.",
	addon.defaults.fontFlags,
	function()
		return addon:GetDB().fontFlags
	end,
	function(value)
		addon.db.fontFlags = value
		refreshEverything()
	end,
	function()
		local container = Settings.CreateControlTextContainer()
		container:Add("", "None")
		container:Add("OUTLINE", "Outline")
		container:Add("THICKOUTLINE", "Thick Outline")
		return container:GetData()
	end
)

local trackerTitles = {
	rake = "Rake",
	moonfire = "Moonfire",
	rip = "Rip",
	primal_wrath = "Primal Wrath",
}

for _, trackerID in ipairs(addon.trackerOrder) do
	local trackerLabel = trackerTitles[trackerID]
	local category = Settings.RegisterVerticalLayoutSubcategory(rootCategory, trackerLabel)
	trackerCategories[#trackerCategories + 1] = category

	registerBoolean(
		category,
		"efbt_" .. trackerID .. "_enabled",
		"Enable " .. trackerLabel .. " tracker",
		"Shows or hides this tracker.",
		addon.defaults.trackers[trackerID].enabled,
		function()
			return addon:GetDB().trackers[trackerID].enabled
		end,
		function(value)
			addon.db.trackers[trackerID].enabled = value
			refreshEverything()
		end
	)

	registerBoolean(
		category,
		"efbt_" .. trackerID .. "_attach",
		"Attach to spell frame",
		"When enabled, this tracker will anchor itself to the matching spell icon when one is available.",
		addon.defaults.trackers[trackerID].attachToSpell,
		function()
			return addon:GetDB().trackers[trackerID].attachToSpell
		end,
		function(value)
			addon.db.trackers[trackerID].attachToSpell = value
			addon.state.anchorCache[trackerID] = nil
			refreshEverything()
		end
	)

	registerSlider(
		category,
		"efbt_" .. trackerID .. "_offset_x",
		"Attached X offset",
		"Horizontal offset used while attached to a spell frame.",
		addon.defaults.trackers[trackerID].offsetX,
		-80,
		80,
		1,
		function()
			return addon:GetDB().trackers[trackerID].offsetX
		end,
		function(value)
			addon.db.trackers[trackerID].offsetX = value
			refreshEverything()
		end,
		function(value)
			return string.format("%d", value)
		end
	)

	registerSlider(
		category,
		"efbt_" .. trackerID .. "_offset_y",
		"Attached Y offset",
		"Vertical offset used while attached to a spell frame.",
		addon.defaults.trackers[trackerID].offsetY,
		-80,
		80,
		1,
		function()
			return addon:GetDB().trackers[trackerID].offsetY
		end,
		function(value)
			addon.db.trackers[trackerID].offsetY = value
			refreshEverything()
		end,
		function(value)
			return string.format("%d", value)
		end
	)
end

Settings.RegisterAddOnCategory(rootCategory)
Settings.RegisterAddOnCategory(generalCategory)
Settings.RegisterAddOnCategory(appearanceCategory)
for _, category in ipairs(trackerCategories) do
	Settings.RegisterAddOnCategory(category)
end

function addon:OpenOptions()
	if not self.optionsCategoryID then
		return
	end

	Settings.OpenToCategory(self.optionsCategoryID)
end
