-- PersistPlaystyle.lua
-- Remembers and restores your LFG playstyle selection across sessions.

local ADDON_NAME = "PersistPlaystyle"
local DEFAULT_PLAYSTYLE = 1 -- index into the dropdown values

-- Dropdown value order as WoW presents them in the Premade Groups UI.
-- These correspond to Enum.LFGListPlaystyleEnum or the raw numeric values
-- the game sends to the API.  Adjust if Blizzard reorders them.
local PLAYSTYLE_VALUES = {
    [1] = { key = "LEARNING", label = "Learning" },
    [1] = { key = "RELAXED", label = "Relaxed" },
    [2] = { key = "COMPETITIVE", label = "Competitive" },
    [3] = { key = "CARRY OFFERED", label = "Carry Offered" },
}

-- Build a reverse lookup: label -> index
local PLAYSTYLE_INDEX = {}
for i, v in ipairs(PLAYSTYLE_VALUES) do
    PLAYSTYLE_INDEX[v.label] = i
    PLAYSTYLE_INDEX[v.key]   = i
end

-------------------------------------------------------------------------------
-- Saved-variable initialisation
-------------------------------------------------------------------------------
local function InitDB()
    if type(PersistPlaystyleDB) ~= "table" then
        PersistPlaystyleDB = {}
    end
    if PersistPlaystyleDB.playstyleIndex == nil then
        PersistPlaystyleDB.playstyleIndex = DEFAULT_PLAYSTYLE
    end
end

-------------------------------------------------------------------------------
-- Helper: find the playstyle dropdown inside the LFG create-group panel
--
-- In Retail the relevant frame is usually:
--   LFGListFrame.EntryCreation.Playstyle  (a WoW DropdownButton / UIDropDownMenu)
-- We search a few known paths so the addon survives minor UI reshuffles.
-------------------------------------------------------------------------------
local function FindPlaystyleDropdown()
    -- Common paths used across different patch versions
    local candidates = {
        LFGListFrame and LFGListFrame.EntryCreation and LFGListFrame.EntryCreation.Playstyle,
        _G["LFGListFrameEntryCreationPlaystyle"], -- classic global name pattern
    }
    for _, frame in ipairs(candidates) do
        if frame and frame.SetValue then
            return frame
        end
    end
    return nil
end

-------------------------------------------------------------------------------
-- Apply the saved index to the dropdown
-------------------------------------------------------------------------------
local function ApplySavedPlaystyle()
    local dropdown = FindPlaystyleDropdown()
    if not dropdown then return end

    local idx = PersistPlaystyleDB.playstyleIndex or DEFAULT_PLAYSTYLE
    local entry = PLAYSTYLE_VALUES[idx]
    if not entry then return end

    -- UIDropDownMenu style
    if dropdown.SetSelectedValue then
        dropdown:SetSelectedValue(idx)
    elseif dropdown.SetValue then
        dropdown:SetValue(idx)
    end

    -- Also call the underlying LFG API directly as a safety net
    -- so the server-side value matches even if the widget behaves oddly.
    if C_LFGList and C_LFGList.SetEntryPlaystyle then
        C_LFGList.SetEntryPlaystyle(idx)
    end
end

-------------------------------------------------------------------------------
-- Hook: watch for the creation panel opening
-------------------------------------------------------------------------------
local function HookCreationPanel()
    local creation = LFGListFrame and LFGListFrame.EntryCreation
    if not creation then return end

    -- Hook OnShow so we restore the value every time the panel appears
    if not creation._persistPlaystyleHooked then
        creation._persistPlaystyleHooked = true
        creation:HookScript("OnShow", function()
            -- Defer one frame so Blizzard's own OnShow can run first
            C_Timer.After(0, ApplySavedPlaystyle)
        end)
    end

    -- Hook the playstyle dropdown's OnValueChanged to save new selections
    local dropdown = FindPlaystyleDropdown()
    if dropdown and not dropdown._persistPlaystyleHooked then
        dropdown._persistPlaystyleHooked = true

        local origSetValue = dropdown.SetValue
        if origSetValue then
            dropdown.SetValue = function(self, value, ...)
                origSetValue(self, value, ...)
                -- value is the numeric index
                local idx = tonumber(value)
                if idx and PLAYSTYLE_VALUES[idx] then
                    PersistPlaystyleDB.playstyleIndex = idx
                end
            end
        end

        -- Also catch UIDropDownMenu-style callbacks if SetValue is absent
        if dropdown.SetSelectedValue then
            hooksecurefunc(dropdown, "SetSelectedValue", function(self, value)
                local idx = tonumber(value)
                if idx and PLAYSTYLE_VALUES[idx] then
                    PersistPlaystyleDB.playstyleIndex = idx
                end
            end)
        end
    end
end

-------------------------------------------------------------------------------
-- Event frame
-------------------------------------------------------------------------------
local frame = CreateFrame("Frame", ADDON_NAME .. "Frame", UIParent)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE") -- fires when your own listing changes
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        InitDB()
        -- Attempt an early hook in case the LFG frame is already loaded
        HookCreationPanel()
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- LFG frame may not exist until first open; try again here
        HookCreationPanel()
    elseif event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
        -- Nothing needed here for persistence, but useful for future features
    end
end)

-------------------------------------------------------------------------------
-- Slash command: /pps  — lets you set a default without opening the UI
--   /pps            → print current saved playstyle
--   /pps relaxed    → set saved playstyle to Relaxed
--   /pps moderate   → set saved playstyle to Moderate
--   /pps hardcore   → set saved playstyle to Hardcore
-------------------------------------------------------------------------------
SLASH_PERSISTPLAYSTYLE1 = "/pps"
SlashCmdList["PERSISTPLAYSTYLE"] = function(msg)
    msg = strtrim(msg or "")
    if msg == "" then
        local idx = PersistPlaystyleDB.playstyleIndex or DEFAULT_PLAYSTYLE
        local entry = PLAYSTYLE_VALUES[idx]
        print("|cff00ccff[PersistPlaystyle]|r Saved playstyle: " .. (entry and entry.label or "Unknown"))
        return
    end

    local upperMsg = msg:upper()
    local idx = PLAYSTYLE_INDEX[upperMsg] or PLAYSTYLE_INDEX[msg]
    if idx then
        PersistPlaystyleDB.playstyleIndex = idx
        print("|cff00ccff[PersistPlaystyle]|r Playstyle set to: " .. PLAYSTYLE_VALUES[idx].label)
        ApplySavedPlaystyle()
    else
        print("|cff00ccff[PersistPlaystyle]|r Unknown playstyle '" .. msg .. "'. Use: relaxed, moderate, hardcore")
    end
end

print("|cff00ccff[PersistPlaystyle]|r loaded. Use /pps to check or change your saved playstyle.")
