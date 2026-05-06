local SpamGuard = CreateFrame("Frame")

-- =========================
-- CONFIG
-- =========================
SpamGuard.config = {
    channelName = "world",         -- Channel to monitor (case-insensitive)
    timeWindow = 30,               -- Seconds to track repeats
    repeatThreshold = 3,           -- How many repeats trigger whisper
    whisperMessage = "Hey! You're posting that quite often. Please avoid spamming 🙂",
    ignoreSelf = true,
}

-- =========================
-- INTERNAL DATA
-- =========================
SpamGuard.messages = {}
SpamGuard.lastWhisper = {}

-- =========================
-- UTIL
-- =========================
local function normalize(msg)
    return string.lower(msg):gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")
end

local function getTime()
    return time()
end

local function isSameChannel(channelName)
    return string.find(string.lower(channelName or ""), SpamGuard.config.channelName)
end

-- =========================
-- CORE LOGIC
-- =========================
function SpamGuard:CheckMessage(player, message)
    local now = getTime()
    local key = player .. ":" .. normalize(message)

    if not self.messages[key] then
        self.messages[key] = {}
    end

    table.insert(self.messages[key], now)

    -- Remove old timestamps
    local validTimes = {}
    for _, t in ipairs(self.messages[key]) do
        if now - t <= self.config.timeWindow then
            table.insert(validTimes, t)
        end
    end
    self.messages[key] = validTimes

    -- Check threshold
    if #validTimes >= self.config.repeatThreshold then
        -- Prevent spam whispering
        if not self.lastWhisper[player] or (now - self.lastWhisper[player] > self.config.timeWindow) then
            SendChatMessage(self.config.whisperMessage, "WHISPER", nil, player)
            self.lastWhisper[player] = now

            print("|cffff5555[SpamGuard]|r Whispered " .. player .. " for repeated messages.")
        end
    end
end

-- =========================
-- EVENT HANDLING
-- =========================
SpamGuard:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_CHANNEL" then
        local message, player, _, _, _, _, _, _, channelName = ...

        if not isSameChannel(channelName) then return end

        if self.config.ignoreSelf and player == UnitName("player") then return end

        self:CheckMessage(player, message)
    end
end)

SpamGuard:RegisterEvent("CHAT_MSG_CHANNEL")

-- =========================
-- SLASH COMMANDS
-- =========================
SLASH_SPAMGUARD1 = "/sg"
SlashCmdList["SPAMGUARD"] = function(msg)
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")

    if cmd == "channel" then
        SpamGuard.config.channelName = arg
        print("SpamGuard: Channel set to", arg)

    elseif cmd == "time" then
        SpamGuard.config.timeWindow = tonumber(arg) or 30
        print("SpamGuard: Time window set to", SpamGuard.config.timeWindow)

    elseif cmd == "repeat" then
        SpamGuard.config.repeatThreshold = tonumber(arg) or 3
        print("SpamGuard: Repeat threshold set to", SpamGuard.config.repeatThreshold)

    elseif cmd == "msg" then
        SpamGuard.config.whisperMessage = arg
        print("SpamGuard: Whisper message updated.")

    else
        print("|cffffcc00SpamGuard Commands:|r")
        print("/sg channel <name>")
        print("/sg time <seconds>")
        print("/sg repeat <count>")
        print("/sg msg <message>")
    end
end