-- 💾 PersistPlaystyle: Remembers and restores your LFG playstyle selection across sessions.

local addonName, ns = ...

local PersistPlaystyle = {}
PersistPlaystyle.__index = PersistPlaystyle

PersistPlaystyle.DEFAULT_PLAYSTYLE = "Relaxed"
PersistPlaystyle.PLAYSTYLE_IDS = { ["Learning"] = 1, ["Relaxed"] = 2, ["Competitive"] = 3, ["Carry Offered"] = 4 }

function PersistPlaystyle:InitDB()
	if type(PersistPlaystyleDB) ~= "table" then PersistPlaystyleDB = {} end
	if not self.PLAYSTYLE_IDS[PersistPlaystyleDB.playstyle] then PersistPlaystyleDB.playstyle = self.DEFAULT_PLAYSTYLE end
end

function PersistPlaystyle:ApplySavedPlaystyle()
	local ec = LFGListFrame and LFGListFrame.EntryCreation
	if not ec or not ec:IsShown() then return end
	local saved = PersistPlaystyleDB.playstyle or self.DEFAULT_PLAYSTYLE
	local styleID = self.PLAYSTYLE_IDS[saved]
	if styleID then
		ec.generalPlaystyle = styleID
		ec.PlayStyleDropdown:SetText(saved)
		LFGListEntryCreation_UpdateValidState(ec)
	end
end

function PersistPlaystyle:HookCreationPanel()
	if self._hooked then return end
	local dd = LFGListFrame and LFGListFrame.EntryCreation and LFGListFrame.EntryCreation.PlayStyleDropdown
	if not dd then return end
	hooksecurefunc(dd, "SetText", function(_, text)
		if PersistPlaystyle.PLAYSTYLE_IDS[text] then PersistPlaystyleDB.playstyle = text end
	end)
	LFGListFrame.EntryCreation:HookScript("OnShow", function() C_Timer.After(0, function() self:ApplySavedPlaystyle() end) end)
	self._hooked = true
end

function PersistPlaystyle:OnEvent(event, arg1)
	if event == "ADDON_LOADED" and arg1 == addonName then
		self:InitDB()
	elseif event == "PLAYER_ENTERING_WORLD" then
		self:HookCreationPanel()
	end
end

function PersistPlaystyle:Enable()
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("ADDON_LOADED")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:SetScript("OnEvent", function(_, event, arg1) self:OnEvent(event, arg1) end)
end

PersistPlaystyle:Enable()
