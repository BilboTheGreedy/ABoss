local ADDON, ns = ...

local defaults = {
	locked = true,
	bars = true,
	emphasize = true,
	emphasizeAt = 8,
	warnings = true,
	sound = "RAID_WARNING",
	countdown = true,
	announce = true,
	readycheck = true,
	width = 220,
	height = 18,
	grow = "DOWN",
	normal = { scale = 1, default = { "CENTER", "CENTER", 320, 60 } },
	emph = { scale = 1.3, default = { "CENTER", "CENTER", 0, -120 } },
	text = { scale = 1, default = { "CENTER", "CENTER", 0, 180 } },
	window = { scale = 1 },
	history = {},
}

ACore.New(ADDON, ns, { db = "ABossDB", defaults = defaults })

function ns.Now()
	return GetTime and GetTime() or 0
end

function ns.Clock(seconds)
	seconds = math.max(0, math.floor(seconds + 0.5))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
	end
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

function ns.Plain(v, kind)
	if v == nil or ns.IsSecret(v) then return nil end
	if kind and type(v) ~= kind then return nil end
	return v
end

ns.SOUNDS = {
	{ "RAID_WARNING", "Raid warning", 8959 },
	{ "READY_CHECK", "Ready check", 8960 },
	{ "ALARM_CLOCK_WARNING_3", "Alarm", 12889 },
	{ "MAP_PING", "Map ping", 3175 },
	{ "IG_QUEST_LIST_OPEN", "Soft click", 875 },
	{ "NONE", "No sound" },
}

function ns.Sound(key)
	key = key or (ns.db and ns.db.sound) or "RAID_WARNING"
	if key == "NONE" or not PlaySound then return end
	local id = SOUNDKIT and SOUNDKIT[key]
	if not id then
		for _, s in ipairs(ns.SOUNDS) do
			if s[1] == key then id = s[3] end
		end
	end
	if id then pcall(PlaySound, id, "Master") end
end

function ns.GroupChannel()
	if IsInRaid and IsInRaid() then return "RAID" end
	if IsInGroup and IsInGroup() then return "PARTY" end
	return nil
end

function ns.Say(text)
	local channel = ns.GroupChannel()
	if not channel or not ns.db.announce then return false end
	if InCombatLockdown and InCombatLockdown() then return false end
	local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
	if not send then return false end
	return pcall(send, text, channel)
end

ACore.Register({
	name = "ABoss",
	title = "ABoss",
	slash = "/aboss",
	desc = "encounter timers and warnings",
	toggle = function() ns.OpenOptions() end,
})
