-- PersistPlaystyle.lua
-- Remembers and restores your LFG playstyle selection across sessions.

local ADDON_NAME = "PersistPlaystyle"
local DEFAULT_PLAYSTYLE = "Relaxed"

local PLAYSTYLE_IDS = {
	["Learning"]      = 1,
	["Relaxed"]       = 2,
	["Competitive"]   = 3,
	["Carry Offered"] = 4,
}

local VALID_PLAYSTYLES = {
	["Learning"]      = true,
	["Relaxed"]       = true,
	["Competitive"]   = true,
	["Carry Offered"] = true,
}

-------------------------------------------------------------------------------
-- Saved-variable initialisation
-------------------------------------------------------------------------------
local function InitDB()
	if type(PersistPlaystyleDB) ~= "table" then
		PersistPlaystyleDB = {}
	end
	if not VALID_PLAYSTYLES[PersistPlaystyleDB.playstyle] then
		PersistPlaystyleDB.playstyle = DEFAULT_PLAYSTYLE
	end
end

-------------------------------------------------------------------------------
-- Apply the saved text to the dropdown button
-------------------------------------------------------------------------------
local function ApplySavedPlaystyle()
	local entryCreation = LFGListFrame and LFGListFrame.EntryCreation
	-- Ensure the frame exists and is actually open/visible
	if not entryCreation or not entryCreation:IsShown() then return end

	local saved = PersistPlaystyleDB.playstyle or DEFAULT_PLAYSTYLE
	local styleID = PLAYSTYLE_IDS[saved]

	if styleID then
		-- 1. Set the internal state (this fixes the "List Group" button being greyed out)
		entryCreation.generalPlaystyle = styleID

		-- 2. Update the visual text on the dropdown button
		entryCreation.PlayStyleDropdown:SetText(saved)

		-- 3. Force the UI to re-evaluate if the form is complete
		LFGListEntryCreation_UpdateValidState(entryCreation)
	end
end

-------------------------------------------------------------------------------
-- Hook: watch for the creation panel opening and intercept SetText
-------------------------------------------------------------------------------
local hooked = false

local function HookCreationPanel()
	if hooked then return end

	local dropdown = LFGListFrame and LFGListFrame.EntryCreation and LFGListFrame.EntryCreation.PlayStyleDropdown
	if not dropdown then return end

	-- Save whenever Blizzard (or the user) changes the dropdown text
	hooksecurefunc(dropdown, "SetText", function(self, text)
		if VALID_PLAYSTYLES[text] then
			PersistPlaystyleDB.playstyle = text
		end
	end)

	-- Restore whenever the create panel opens
	LFGListFrame.EntryCreation:HookScript("OnShow", function()
		C_Timer.After(0, ApplySavedPlaystyle)
	end)

	hooked = true
end

-------------------------------------------------------------------------------
-- Event frame
-------------------------------------------------------------------------------
local frame = CreateFrame("Frame")

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
		InitDB()
	elseif event == "PLAYER_ENTERING_WORLD" then
		HookCreationPanel()
	end
end)

-------------------------------------------------------------------------------
-- Slash command: /pps
--   /pps          → print current saved playstyle
--   /pps relaxed  → override saved playstyle
-------------------------------------------------------------------------------
SLASH_PERSISTPLAYSTYLE1 = "/pps"
SlashCmdList["PERSISTPLAYSTYLE"] = function(msg)
	msg = strtrim(msg or "")
	if msg == "" then
		print("|cff00ccff[PersistPlaystyle]|r Saved playstyle: " .. (PersistPlaystyleDB.playstyle or DEFAULT_PLAYSTYLE))
		return
	end

	for label in pairs(VALID_PLAYSTYLES) do
		if label:lower() == msg:lower() then
			PersistPlaystyleDB.playstyle = label
			print("|cff00ccff[PersistPlaystyle]|r Playstyle set to: " .. label)
			ApplySavedPlaystyle()
			return
		end
	end

	print("|cff00ccff[PersistPlaystyle]|r Unknown playstyle. Valid options: Learning, Relaxed, Competitive, Carry Offered")
end

print("|cff00ccff[PersistPlaystyle]|r loaded. Use /pps to check or change your saved playstyle.")
