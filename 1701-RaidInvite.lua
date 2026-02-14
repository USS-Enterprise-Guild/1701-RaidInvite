-- 1701-RaidInvite: Raid invite manager with approval UI
-- Shows a window listing players who whisper "inv" with Name and Class
-- Raid leader/assist can Invite or Decline each request

local ADDON_PREFIX = "|cff00ff00[1701-RaidInvite]|r "
local MAX_ROWS = 10
local ROW_HEIGHT = 22
local WINDOW_WIDTH = 380

local pendingInvites = {}
local rows = {}

-- Class colors (vanilla WoW)
local CLASS_COLORS = {
    ["Warrior"] = "c79c6e",
    ["Paladin"] = "f58cba",
    ["Hunter"] = "abd473",
    ["Rogue"] = "fff569",
    ["Priest"] = "ffffff",
    ["Shaman"] = "0070de",
    ["Mage"] = "69ccf0",
    ["Warlock"] = "9482c9",
    ["Druid"] = "ff7d0a",
}

local function ColorText(text, hexColor)
    if hexColor then
        return "|cff" .. hexColor .. text .. "|r"
    end
    return text
end

-- Forward declaration
local UpdateDisplay

-- ============================================================
-- Main window
-- ============================================================
local mainFrame = CreateFrame("Frame", "RaidInviteFrame", UIParent)
mainFrame:SetWidth(WINDOW_WIDTH)
mainFrame:SetHeight(100)
mainFrame:SetPoint("TOP", UIParent, "TOP", 0, -100)
mainFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
mainFrame:SetBackdropColor(0, 0, 0, 0.9)
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", function() this:StartMoving() end)
mainFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
mainFrame:SetFrameStrata("DIALOG")
mainFrame:Hide()

-- Title
local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", mainFrame, "TOP", 0, -16)
title:SetText("Raid Invites")

-- Close button
local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -3, -3)

-- Column headers
local hdrName = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hdrName:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 20, -38)
hdrName:SetText("Name")
hdrName:SetTextColor(1, 0.82, 0)

local hdrClass = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hdrClass:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 140, -38)
hdrClass:SetText("Class")
hdrClass:SetTextColor(1, 0.82, 0)

-- Invite All button
local invAllBtn = CreateFrame("Button", "RaidInviteAllBtn", mainFrame, "UIPanelButtonTemplate")
invAllBtn:SetWidth(90)
invAllBtn:SetHeight(20)
invAllBtn:SetText("Invite All")
invAllBtn:SetScript("OnClick", function()
    for i = table.getn(pendingInvites), 1, -1 do
        InviteByName(pendingInvites[i].name)
        DEFAULT_CHAT_FRAME:AddMessage(ADDON_PREFIX .. "Invited " .. pendingInvites[i].name)
    end
    pendingInvites = {}
    UpdateDisplay()
end)

-- Decline All button
local decAllBtn = CreateFrame("Button", "RaidInviteDecAllBtn", mainFrame, "UIPanelButtonTemplate")
decAllBtn:SetWidth(90)
decAllBtn:SetHeight(20)
decAllBtn:SetText("Decline All")
decAllBtn:SetScript("OnClick", function()
    local count = table.getn(pendingInvites)
    pendingInvites = {}
    UpdateDisplay()
    DEFAULT_CHAT_FRAME:AddMessage(ADDON_PREFIX .. "Declined " .. count .. " request(s).")
end)

-- ============================================================
-- Update display
-- ============================================================
UpdateDisplay = function()
    -- Hide all rows
    for i = 1, MAX_ROWS do
        if rows[i] then
            rows[i].frame:Hide()
        end
    end

    local count = table.getn(pendingInvites)

    if count == 0 then
        mainFrame:Hide()
        return
    end

    local shown = count
    if shown > MAX_ROWS then shown = MAX_ROWS end

    -- Resize: header area (55) + rows + bottom buttons (35)
    mainFrame:SetHeight(55 + shown * ROW_HEIGHT + 35)

    for i = 1, shown do
        local invite = pendingInvites[i]

        -- Create row UI on first use
        if not rows[i] then
            local row = {}
            row.frame = CreateFrame("Frame", nil, mainFrame)
            row.frame:SetWidth(WINDOW_WIDTH - 30)
            row.frame:SetHeight(ROW_HEIGHT)

            row.name = row.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.name:SetPoint("LEFT", row.frame, "LEFT", 5, 0)
            row.name:SetWidth(110)
            row.name:SetJustifyH("LEFT")

            row.class = row.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.class:SetPoint("LEFT", row.frame, "LEFT", 125, 0)
            row.class:SetWidth(75)
            row.class:SetJustifyH("LEFT")

            row.inviteBtn = CreateFrame("Button", "RIInvBtn" .. i, row.frame, "UIPanelButtonTemplate")
            row.inviteBtn:SetWidth(55)
            row.inviteBtn:SetHeight(18)
            row.inviteBtn:SetPoint("LEFT", row.frame, "LEFT", 210, 0)
            row.inviteBtn:SetText("Invite")

            row.declineBtn = CreateFrame("Button", "RIDecBtn" .. i, row.frame, "UIPanelButtonTemplate")
            row.declineBtn:SetWidth(55)
            row.declineBtn:SetHeight(18)
            row.declineBtn:SetPoint("LEFT", row.frame, "LEFT", 270, 0)
            row.declineBtn:SetText("Decline")

            rows[i] = row
        end

        local row = rows[i]
        row.frame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -(50 + (i - 1) * ROW_HEIGHT))

        -- Name colored by class
        local color = invite.class and CLASS_COLORS[invite.class] or nil
        row.name:SetText(ColorText(invite.name, color))

        -- Class label
        if invite.class then
            row.class:SetText(ColorText(invite.class, color))
        else
            row.class:SetText("|cff888888...|r")
        end

        -- Button callbacks (use frame field to pass index into vanilla Lua 5.0 handler)
        row.inviteBtn.idx = i
        row.inviteBtn:SetScript("OnClick", function()
            local inv = pendingInvites[this.idx]
            if inv then
                InviteByName(inv.name)
                DEFAULT_CHAT_FRAME:AddMessage(ADDON_PREFIX .. "Invited " .. inv.name)
                table.remove(pendingInvites, this.idx)
                UpdateDisplay()
            end
        end)

        row.declineBtn.idx = i
        row.declineBtn:SetScript("OnClick", function()
            local inv = pendingInvites[this.idx]
            if inv then
                DEFAULT_CHAT_FRAME:AddMessage(ADDON_PREFIX .. "Declined " .. inv.name)
                table.remove(pendingInvites, this.idx)
                UpdateDisplay()
            end
        end)

        row.frame:Show()
    end

    -- Position bottom buttons
    invAllBtn:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 55, 12)
    decAllBtn:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -55, 12)

    mainFrame:Show()
end

-- ============================================================
-- Helpers
-- ============================================================
local function IsPending(name)
    for i = 1, table.getn(pendingInvites) do
        if pendingInvites[i].name == name then
            return true
        end
    end
    return false
end

local function AddPendingInvite(name)
    if IsPending(name) then return end
    table.insert(pendingInvites, { name = name, class = nil })
    -- Query /who to resolve class
    SendWho("n-" .. name)
    UpdateDisplay()
end

-- ============================================================
-- Event handling
-- ============================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("CHAT_MSG_WHISPER")
eventFrame:RegisterEvent("WHO_LIST_UPDATE")

eventFrame:SetScript("OnEvent", function()
    if event == "CHAT_MSG_WHISPER" then
        local message = string.lower(arg1)
        local sender = arg2

        if not string.find(message, "^inv") then
            return
        end

        -- Must be in a raid with leader or assist
        if GetNumRaidMembers() == 0 then
            return
        end
        if not (IsRaidLeader() or IsRaidOfficer()) then
            return
        end

        AddPendingInvite(sender)

    elseif event == "WHO_LIST_UPDATE" then
        -- Match who results to pending invites that are missing class
        local numWho = GetNumWhoResults()
        for i = 1, numWho do
            local name, guild, level, race, class = GetWhoInfo(i)
            for j = 1, table.getn(pendingInvites) do
                if pendingInvites[j].name == name and not pendingInvites[j].class then
                    pendingInvites[j].class = class
                end
            end
        end
        UpdateDisplay()
    end
end)

-- ============================================================
-- Slash commands: /ri or /raidinvite
-- ============================================================
SLASH_RAIDINVITE1 = "/raidinvite"
SLASH_RAIDINVITE2 = "/ri"
SlashCmdList["RAIDINVITE"] = function(msg)
    if msg == "clear" then
        pendingInvites = {}
        UpdateDisplay()
        DEFAULT_CHAT_FRAME:AddMessage(ADDON_PREFIX .. "Cleared all pending invites.")
    else
        if table.getn(pendingInvites) > 0 then
            mainFrame:Show()
        else
            DEFAULT_CHAT_FRAME:AddMessage(ADDON_PREFIX .. "No pending invite requests.")
        end
    end
end

DEFAULT_CHAT_FRAME:AddMessage(ADDON_PREFIX .. "Loaded | /ri to show window")
