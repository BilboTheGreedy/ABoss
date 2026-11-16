local _, ns = ...
local UI = ns.UI

local function apply()
	ns.Bars.Apply()
	ns.Messages.Apply()
end

function ns.Test()
	local B = ns.Bars
	B.StopAll("test")
	B.Start("test1", "Tank hit", 12, "Interface\\Icons\\Ability_Warrior_ShieldBash", { color = 1 })
	B.Start("test2", "Raid damage", 20, "Interface\\Icons\\Spell_Fire_Fireball02", { color = 0 })
	B.Start("test3", "Deadly cast", 9, "Interface\\Icons\\Spell_Shadow_ShadowBolt", { color = 2 })
	B.Start("test4", "Adds", 34, "Interface\\Icons\\Ability_Hunter_BeastCall", { color = 0 })
	B.Start("test5", "Enrage", 75, "Interface\\Icons\\Ability_Druid_Enrage", { color = 2 })
	ns.Messages.Show("Test warning", 1)
	ns.After(1.5, function() ns.Messages.Show("Deadly test warning", 2) end)
end

function ns.OptionEntries()
	local db = ns.db
	local entries = {
		{ text = "ABoss", title = true },
		{ text = db.locked and "Unlock to move" or "Lock in place", func = function()
			db.locked = not db.locked
			apply()
		end },
		{ text = "Run a test", func = ns.Test },
		{ text = "Boss history", func = function() ns.History.Toggle() end },
		{ text = "Show", title = true },
		UI.Check(db, "bars", "Timer bars", function(on)
			if not on then ns.Bars.StopAll() end
		end),
		UI.Check(db, "emphasize", "Enlarge bars about to finish", apply),
		UI.Check(db, "warnings", "Warning text", apply),
		UI.Check(db, "countdown", "Count the last 5 seconds of a pull", apply),
		UI.Check(db, "readycheck", "Ready check bar", apply),
		UI.Check(db, "announce", "Announce pull and break to the group", apply),
		{ text = "Bars grow", title = true },
		{ text = "Down", checked = db.grow == "DOWN", func = function() db.grow = "DOWN" apply() end },
		{ text = "Up", checked = db.grow == "UP", func = function() db.grow = "UP" apply() end },
		{ text = "Bar width", title = true },
	}
	for _, w in ipairs({ 180, 220, 260, 320 }) do
		entries[#entries + 1] = { text = tostring(w), checked = db.width == w, func = function() db.width = w apply() end }
	end
	entries[#entries + 1] = { text = "Bar height", title = true }
	for _, h in ipairs({ 14, 18, 22, 26 }) do
		entries[#entries + 1] = { text = tostring(h), checked = db.height == h, func = function() db.height = h apply() end }
	end
	entries[#entries + 1] = { text = "Warning sound", title = true }
	for _, s in ipairs(ns.SOUNDS) do
		entries[#entries + 1] = {
			text = s[2], checked = db.sound == s[1], keep = true,
			func = function()
				db.sound = s[1]
				ns.Sound()
			end,
		}
	end
	local scale = UI.ScaleEntries(db.normal, apply)
	scale[1].text = "Bar size"
	for _, e in ipairs(scale) do entries[#entries + 1] = e end
	return entries
end

function ns.OpenOptions(anchor)
	UI.Menu(anchor or UIParent, ns.OptionEntries())
end

SLASH_ABOSS1 = "/aboss"
SlashCmdList["ABOSS"] = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "test" then
		ns.Test()
	elseif msg == "unlock" or msg == "move" then
		ns.db.locked = false
		apply()
	elseif msg == "lock" then
		ns.db.locked = true
		apply()
	elseif msg == "history" then
		ns.History.Toggle()
	elseif msg == "reset" then
		ns.db.normal.pos, ns.db.emph.pos, ns.db.text.pos = nil, nil, nil
		apply()
	elseif msg == "stop" then
		ns.Bars.StopAll()
	else
		ns.OpenOptions()
	end
end
