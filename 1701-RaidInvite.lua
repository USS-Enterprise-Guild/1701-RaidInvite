-- 1701-RaidInvite: Auto-invite players who whisper "inv" or "invite"
-- Only works when you have raid leader or assist

local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_WHISPER")

frame:SetScript("OnEvent", function()
    local message = string.lower(arg1)
    local sender = arg2

    -- Check if message is or starts with "inv" or "invite"
    if not (string.find(message, "^inv") or string.find(message, "^invite")) then
        return
    end

    -- Check if we're in a raid
    if GetNumRaidMembers() == 0 then
        return
    end

    -- Check if we have leader or assist
    if not (IsRaidLeader() or IsRaidOfficer()) then
        return
    end

    -- Invite the player
    InviteByName(sender)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[1701-RaidInvite]|r Invited " .. sender)
end)

DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[1701-RaidInvite]|r Loaded - whisper 'inv' or 'invite' for raid invite")
