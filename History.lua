local _, ns = ...
local UI = ns.UI
local C = UI.colors

local History = {}
ns.History = History

local current
local frame

function History.Current()
	return current
end

local function start(id, name, difficulty, size)
	id = ns.Plain(id, "number")
	if not id then return end
	current = {
		id = id, name = ns.Plain(name, "string") or ("Encounter " .. id),
		difficulty = ns.Plain(difficulty, "number"), size = ns.Plain(size, "number"), began = ns.Now(),
	}
	ns.Bars.Stop("pull")
	ns.Bars.Stop("break")
	ns:Fire("ENCOUNTER_BEGIN", current)
end

local function finish(id, name, _, _, success)
	id = ns.Plain(id, "number")
	local fight = current
	current = nil
	ns:Fire("ENCOUNTER_OVER")
	if not id then return end
	local length = fight and fight.id == id and (ns.Now() - fight.began) or nil
	local label = ns.Plain(name, "string") or (fight and fight.name) or ("Encounter " .. id)
	local rec = ns.db.history[id]
	if not rec then
		rec = { name = label, kills = 0, wipes = 0 }
		ns.db.history[id] = rec
	end
	rec.name = label
	rec.last = time and time() or 0
	local won = ns.Plain(success)
	won = won == 1 or won == true
	if won then
		rec.kills = rec.kills + 1
		local line = label .. " defeated"
		if length then
			line = line .. " in " .. ns.Clock(length)
			if rec.best and length < rec.best then
				line = line .. "  (new best, was " .. ns.Clock(rec.best) .. ")"
			elseif rec.best then
				line = line .. "  (best " .. ns.Clock(rec.best) .. ")"
			end
			if not rec.best or length < rec.best then rec.best = length end
			rec.lastLength = length
		end
		ns.Print(line)
		ns.Messages.Show(label .. " defeated", "good", false)
	else
		rec.wipes = rec.wipes + 1
		local line = "Wipe on " .. label
		if length then line = line .. " after " .. ns.Clock(length) end
		ns.Print(line)
	end
	History.Refresh()
end

ns:On("ENCOUNTER_START", function(...) pcall(start, ...) end)
ns:On("ENCOUNTER_END", function(...)
	local ok, err = pcall(finish, ...)
	if not ok then
		current = nil
		ns.Bars.StopAll("tl")
	end
end)

local function rows()
	local out = {}
	for id, rec in pairs(ns.db.history) do
		out[#out + 1] = { id = id, rec = rec }
	end
	table.sort(out, function(a, b)
		local la, lb = a.rec.last or 0, b.rec.last or 0
		if la ~= lb then return la > lb end
		return a.id < b.id
	end)
	return out
end
History.Rows = rows

local function createRow(list)
	local row = CreateFrame("Button", nil, list)
	row.hl = UI.Fill(row, C.hover, "HIGHLIGHT")
	row.when = UI.Text(row, "GameFontDisableSmall", "RIGHT", C.dim)
	row.when:SetPoint("RIGHT", -8, 0)
	row.when:SetWidth(90)
	row.best = UI.Text(row, "GameFontHighlightSmall", "RIGHT")
	row.best:SetPoint("RIGHT", row.when, "LEFT", -8, 0)
	row.best:SetWidth(60)
	row.wipes = UI.Text(row, "GameFontHighlightSmall", "RIGHT", { 0.9, 0.4, 0.4 })
	row.wipes:SetPoint("RIGHT", row.best, "LEFT", -8, 0)
	row.wipes:SetWidth(50)
	row.kills = UI.Text(row, "GameFontHighlightSmall", "RIGHT", { 0.4, 0.85, 0.45 })
	row.kills:SetPoint("RIGHT", row.wipes, "LEFT", -8, 0)
	row.kills:SetWidth(50)
	row.name = UI.Text(row, "GameFontHighlight")
	row.name:SetPoint("LEFT", 10, 0)
	row.name:SetPoint("RIGHT", row.kills, "LEFT", -8, 0)
	row:RegisterForClicks("RightButtonUp")
	row:SetScript("OnClick", function(self)
		local d = self.data
		if not d then return end
		UI.Menu(self, {
			{ text = d.rec.name, title = true },
			{ text = "Forget this boss", func = function()
				ns.db.history[d.id] = nil
				History.Refresh()
			end },
		})
	end)
	return row
end

local function updateRow(row, d)
	local rec = d.rec
	row.name:SetText(rec.name)
	row.kills:SetText(rec.kills)
	row.wipes:SetText(rec.wipes)
	row.best:SetText(rec.best and ns.Clock(rec.best) or "-")
	row.when:SetText(rec.last and rec.last > 0 and date and date("%d %b %H:%M", rec.last) or "")
end

local function build()
	frame = UI.Window("ABossHistory", "ABoss", 520, 420, ns.db.window)
	local options = UI.Button(frame.bar, "Options", function() ns.OpenOptions(frame.bar) end)
	options:SetPoint("RIGHT", frame.close, "LEFT", -6, 0)
	local head = CreateFrame("Frame", nil, frame.body)
	head:SetPoint("TOPLEFT")
	head:SetPoint("TOPRIGHT")
	head:SetHeight(22)
	UI.Fill(head, { 0.075, 0.08, 0.1, 1 })
	local function col(text, right, width)
		local fs = UI.Text(head, "GameFontDisableSmall", "RIGHT", C.dim)
		fs:SetPoint("RIGHT", -right, 0)
		fs:SetWidth(width)
		fs:SetText(text)
	end
	col("Last", 16, 90)
	col("Best", 114, 60)
	col("Wipes", 182, 50)
	col("Kills", 240, 50)
	local boss = UI.Text(head, "GameFontDisableSmall", "LEFT", C.dim)
	boss:SetPoint("LEFT", 10, 0)
	boss:SetText("Boss")
	local list = UI.List(frame.body, 22, createRow, updateRow)
	list:SetPoint("TOPLEFT", 0, -24)
	list:SetPoint("BOTTOMRIGHT", 0, 2)
	frame.list = list
	frame.empty = UI.Text(frame.body, "GameFontDisable", "CENTER", C.dim)
	frame.empty:SetPoint("CENTER")
	frame.empty:SetText("No boss fights recorded yet.")
end

function History.Refresh()
	if not frame or not frame:IsShown() then return end
	local data = rows()
	frame.list:SetData(data, true)
	frame.empty:SetShown(#data == 0)
end

function History.Toggle()
	if not frame then build() end
	if frame:IsShown() then
		frame:Hide()
	else
		frame:Show()
		History.Refresh()
	end
end
