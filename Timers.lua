local _, ns = ...

local Timers = {}
ns.Timers = Timers

local function seconds(text)
	if not text then return nil end
	local m, s = text:match("^(%d+):(%d+)$")
	if m then return tonumber(m) * 60 + tonumber(s) end
	local n, unit = text:match("^(%d+%.?%d*)([ms]?)$")
	if not n then return nil end
	n = tonumber(n)
	if unit == "m" then n = n * 60 end
	return n
end
Timers.Seconds = seconds

local function startPull(n, quiet)
	ns.Bars.Start("pull", "Pull", n, "Interface\\Icons\\Ability_Warrior_Charge", {
		color = "pull", count = true, plain = false,
		onDone = function() ns.Messages.Show("Pull!", "good") end,
	})
	if not quiet then ns.Messages.Show("Pull in " .. math.floor(n + 0.5), "info", false) end
end

function Timers.Pull(n)
	n = n or 10
	if n <= 0 then
		local had = ns.Bars.Stop("pull")
		if C_PartyInfo and C_PartyInfo.DoCountdown and ns.GroupChannel() then pcall(C_PartyInfo.DoCountdown, 0) end
		if had then
			ns.Messages.Show("Pull cancelled", 1, false)
			ns.Say("Pull cancelled")
		end
		return
	end
	n = math.min(n, 60)
	if C_PartyInfo and C_PartyInfo.DoCountdown and ns.GroupChannel() then
		local ok, sent = pcall(C_PartyInfo.DoCountdown, n)
		if ok and sent ~= false then
			Timers.pending = ns.Now()
			startPull(n)
			return
		end
	end
	startPull(n)
	ns.Say("Pull in " .. math.floor(n + 0.5))
end

local PREFIX = "ABoss"

local function share(text)
	local channel = ns.GroupChannel()
	if not channel or not ns.db.sync then return end
	if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then return end
	pcall(C_ChatInfo.SendAddonMessage, PREFIX, text, channel)
end

function Timers.Break(minutes, from)
	if not minutes or minutes <= 0 then
		if ns.Bars.Stop("break") then
			ns.Messages.Show("Break cancelled", 1, false)
			if not from then
				ns.Say("Break cancelled")
				share("break 0")
			end
		end
		return
	end
	minutes = math.min(minutes, 60)
	if from then
		ns.Bars.Start("break", "Break", minutes * 60, "Interface\\Icons\\INV_Drink_07", {
			color = "rest", plain = true,
			onDone = function() ns.Messages.Show("Break is over", "good") end,
		})
		ns.Messages.Show("Break: " .. ns.Clock(minutes * 60), "info", false)
		return
	end
	share("break " .. math.floor(minutes * 60 + 0.5))
	ns.Bars.Start("break", "Break", minutes * 60, "Interface\\Icons\\INV_Drink_07", {
		color = "rest", plain = true,
		onDone = function()
			ns.Messages.Show("Break is over", "good")
			ns.Say("Break is over")
		end,
	})
	local label = (minutes == math.floor(minutes)) and tostring(minutes) or string.format("%.1f", minutes)
	ns.Messages.Show("Break: " .. label .. " min", "info", false)
	ns.Say("Break for " .. label .. " min")
end

local custom = 0
function Timers.Custom(secs, text)
	if not secs or secs <= 0 then return false end
	custom = custom + 1
	text = (text and text ~= "") and text or "Timer"
	ns.Bars.Start("custom" .. custom, text, secs, "Interface\\Icons\\INV_Misc_PocketWatch_01", {
		color = "custom",
		onDone = function() ns.Messages.Show(text, "info") end,
	})
	return true
end

ns:On("START_PLAYER_COUNTDOWN", function(_, left, total)
	left = ns.Plain(left, "number")
	total = ns.Plain(total, "number") or left
	if not left or left <= 0 then return end
	if Timers.pending and ns.Now() - Timers.pending < 2 then
		Timers.pending = nil
		return
	end
	startPull(left, false)
end)

local function own(sender)
	local me = UnitName and UnitName("player")
	if ns.IsSecret(me) or type(me) ~= "string" then return false end
	return sender == me or sender:match("^([^-]+)") == me
end

local function trusted(sender)
	if not (IsInRaid and IsInRaid()) then return true end
	local short = Ambiguate and Ambiguate(sender, "short") or sender
	if UnitIsGroupLeader and UnitIsGroupLeader(short) then return true end
	if UnitIsGroupAssistant and UnitIsGroupAssistant(short) then return true end
	return false
end

ns:On("CHAT_MSG_ADDON", function(prefix, text, channel, sender)
	if ns.IsSecret(prefix) or prefix ~= PREFIX or not ns.db.sync then return end
	if ns.IsSecret(text) or ns.IsSecret(channel) or ns.IsSecret(sender) then return end
	if type(text) ~= "string" or type(sender) ~= "string" then return end
	if channel ~= "PARTY" and channel ~= "RAID" then return end
	if own(sender) or not trusted(sender) then return end
	local n = tonumber(text:match("^break (%d+)$"))
	if n then Timers.Break(math.min(n, 3600) / 60, sender) end
end)

ns:Listen("LOGIN", function()
	if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
		pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
	end
end)

ns:On("CANCEL_PLAYER_COUNTDOWN", function()
	if ns.Bars.Stop("pull") then ns.Messages.Show("Pull cancelled", 1, false) end
end)

ns:On("READY_CHECK", function(_, duration)
	if not ns.db.readycheck then return end
	duration = ns.Plain(duration, "number") or 30
	ns.Bars.Start("ready", "Ready check", duration, "Interface\\RaidFrame\\ReadyCheck-Waiting", { color = "rest", plain = true })
end)

ns:On("READY_CHECK_FINISHED", function() ns.Bars.Stop("ready") end)

SLASH_ABOSSPULL1 = "/pull"
SLASH_ABOSSPULL2 = "/apull"
SlashCmdList["ABOSSPULL"] = function(msg)
	msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "" then
		Timers.Pull(10)
		return
	end
	local n = seconds(msg)
	if not n then
		ns.Print("usage: /pull 10  (0 cancels)")
		return
	end
	Timers.Pull(n)
end

SLASH_ABOSSBREAK1 = "/break"
SLASH_ABOSSBREAK2 = "/abreak"
SlashCmdList["ABOSSBREAK"] = function(msg)
	msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local n = tonumber(msg)
	if msg == "" then n = 5 end
	if not n then
		ns.Print("usage: /break 5  (minutes, 0 cancels)")
		return
	end
	Timers.Break(n)
end

SLASH_ABOSSBAR1 = "/abar"
SlashCmdList["ABOSSBAR"] = function(msg)
	msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local first, rest = msg:match("^(%S+)%s*(.*)$")
	if not Timers.Custom(seconds(first), rest) then
		ns.Print("usage: /abar 30 text   or   /abar 1:30 text")
	end
end
