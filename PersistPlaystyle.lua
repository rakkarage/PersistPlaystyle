-- 💾 PersistPlaystyle: Remembers and restores your LFG playstyle selection across sessions.

local _addonName = ...

local _frame = CreateFrame("Frame")

local _hooked = false

local DEFAULT_PLAYSTYLE = "Relaxed"
local PLAYSTYLE_DATA = { ["Learning"] = 1, ["Relaxed"] = 2, ["Competitive"] = 3, ["Carry Offered"] = 4 }

local function ApplySavedPlaystyle()
	local ec = LFGListFrame and LFGListFrame.EntryCreation
	if not ec or not ec:IsShown() then return end

	local saved = PersistPlaystyleDB.playstyle or DEFAULT_PLAYSTYLE
	local styleID = PLAYSTYLE_DATA[saved]
	if not styleID then return end

	ec.generalPlaystyle = styleID
	ec.PlayStyleDropdown:SetText(saved)
	if LFGListEntryCreation_UpdateValidState then
		LFGListEntryCreation_UpdateValidState(ec)
	end
end

local function SaveCurrentPlaystyle()
	local ec = LFGListFrame and LFGListFrame.EntryCreation
	if not ec then return end

	local current = ec.PlayStyleDropdown:GetText()
	if current and PLAYSTYLE_DATA[current] then
		PersistPlaystyleDB.playstyle = current
	end
end

local function InitializeHooks()
	if _hooked then return end

	local ec = LFGListFrame and LFGListFrame.EntryCreation
	if not ec then return end

	ec:HookScript("OnShow", function()
		C_Timer.After(0, ApplySavedPlaystyle)
	end)

	ec:HookScript("OnHide", SaveCurrentPlaystyle)

	_hooked = true
end

_frame:RegisterEvent("ADDON_LOADED")
_frame:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" and name == _addonName then
		PersistPlaystyleDB = PersistPlaystyleDB or {}
		if not PLAYSTYLE_DATA[PersistPlaystyleDB.playstyle] then
			PersistPlaystyleDB.playstyle = DEFAULT_PLAYSTYLE
		end

		InitializeHooks()
	elseif event == "ADDON_LOADED" and name == "Blizzard_LFGUI" then
		InitializeHooks()
	end
end)
