local _, ns = ...
local UI = ns.UI
local C = UI.colors

local Bars = { active = {}, byId = {} }
ns.Bars = Bars

local anchors = {}
local pool = {}
local ticker

local COLORS = {
	[0] = { 1, 0.82, 0 },
	[1] = { 1, 0.5, 0.1 },
	[2] = { 0.9, 0.2, 0.2 },
	pull = { 0.3, 0.8, 0.35 },
	rest = { 0.35, 0.65, 1 },
	custom = { 0.7, 0.55, 1 },
}

local function anchor(key)
	local a = anchors[key]
	if a then return a end
	a = CreateFrame("Frame", key == "emph" and "ABossEmphasis" or "ABossBars", UIParent)
	a:SetSize(ns.db.width, 16)
	a:SetFrameStrata("MEDIUM")
	UI.Movable(a, ns.db[key])
	a.handle = CreateFrame("Button", nil, a)
	a.handle:SetAllPoints(a)
	UI.Fill(a.handle, { 1, 0.82, 0, 0.25 })
	UI.Border(a.handle, C.accent)
	a.handle.label = UI.Text(a.handle, "GameFontHighlightSmall", "CENTER")
	a.handle.label:SetPoint("CENTER")
	a.handle.label:SetText(key == "emph" and "Emphasised bars" or "Timer bars")
	a.handle:RegisterForDrag("LeftButton")
	a.handle:SetScript("OnDragStart", function() a:StartMoving() end)
	a.handle:SetScript("OnDragStop", function() a:StopDrag() end)
	a.handle:SetShown(not ns.db.locked)
	anchors[key] = a
	return a
end

local function acquire()
	local f = table.remove(pool)
	if f then return f end
	f = UI.Bar(UIParent, ns.db.height)
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetPoint("RIGHT", f, "LEFT", -2, 0)
	f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	UI.Border(f, { 0, 0, 0, 1 })
	return f
end

local function release(bar)
	local f = bar.frame
	if not f then return end
	f:Hide()
	f:ClearAllPoints()
	bar.frame = nil
	pool[#pool + 1] = f
end

local function remaining(bar, now)
	if bar.paused then return bar.left or 0 end
	return bar.expires - now
end

local function layout()
	local now = ns.Now()
	local list = Bars.active
	table.sort(list, function(a, b)
		if a.secret ~= b.secret then return b.secret and true or false end
		local ra, rb = remaining(a, now), remaining(b, now)
		if ra ~= rb then return ra < rb end
		return a.order < b.order
	end)
	local counts = { normal = 0, emph = 0 }
	local db = ns.db
	for _, bar in ipairs(list) do
		local key = bar.emph and "emph" or "normal"
		local a = anchor(key)
		local f = bar.frame
		local h = db.height
		local step = h + 3
		local offset = 18 + counts[key] * step
		f:SetParent(a)
		f:SetSize(db.width - h - 2, h)
		f.icon:SetSize(h, h)
		f:ClearAllPoints()
		if db.grow == "UP" then
			f:SetPoint("BOTTOMRIGHT", a, "TOPRIGHT", 0, offset - 16)
		else
			f:SetPoint("TOPRIGHT", a, "BOTTOMRIGHT", 0, -(offset - 16))
		end
		f:Show()
		counts[key] = counts[key] + 1
	end
end

local function paint(bar)
	local f = bar.frame
	local c = COLORS[bar.color] or COLORS[0]
	f:SetColor(c[1], c[2], c[3], 0.9)
	f.left:SetText(bar.text)
	if bar.icon ~= nil then
		f.icon:SetTexture(bar.icon)
		f.icon:Show()
	else
		f.icon:Hide()
	end
	f:SetAlpha(bar.paused and 0.55 or 1)
end

local function drop(bar)
	Bars.byId[bar.id] = nil
	for i, b in ipairs(Bars.active) do
		if b == bar then
			table.remove(Bars.active, i)
			break
		end
	end
	release(bar)
end

local function tick()
	local now = ns.Now()
	local changed = false
	local db = ns.db
	for i = #Bars.active, 1, -1 do
		local bar = Bars.active[i]
		if not bar.secret then
			local left = remaining(bar, now)
			if left <= 0 and not bar.paused then
				local done = bar.onDone
				drop(bar)
				changed = true
				if done then done(bar) end
			else
				bar.frame:SetValue(left)
				if left >= 60 then
					bar.frame.right:SetText(ns.Clock(left))
				else
					bar.frame.right:SetFormattedText("%.1f", left)
				end
				if db.emphasize and not bar.emph and not bar.plain and left <= db.emphasizeAt then
					bar.emph = true
					changed = true
				end
				if bar.count and not bar.paused then
					local whole = math.ceil(left)
					if whole ~= bar.lastCount then
						bar.lastCount = whole
						if whole <= 5 and whole >= 1 and db.countdown then ns.Messages.Count(whole) end
					end
				end
			end
		end
	end
	if changed then layout() end
	if #Bars.active == 0 and ticker then ticker:Hide() end
end

local function ensureTicker()
	if not ticker then
		ticker = CreateFrame("Frame")
		local acc = 0
		ticker:SetScript("OnUpdate", function(_, dt)
			acc = acc + (dt or 0)
			if acc < 0.04 then return end
			acc = 0
			tick()
		end)
	end
	ticker:Show()
end

local order = 0
function Bars.Start(id, text, duration, icon, opts)
	if not ns.db or not ns.db.bars then return nil end
	opts = opts or {}
	Bars.Stop(id)
	order = order + 1
	local bar = {
		id = id, text = text, icon = icon, color = opts.color or 0, count = opts.count,
		plain = opts.plain, onDone = opts.onDone, order = order,
	}
	bar.frame = acquire()
	local dur = ns.Plain(duration, "number")
	if dur then
		local left = ns.Plain(opts.remaining, "number") or dur
		if left <= 0 then
			release(bar)
			return nil
		end
		bar.duration = math.max(dur, left)
		bar.expires = ns.Now() + left
		bar.frame:SetMinMaxValues(0, bar.duration)
		bar.frame:SetValue(left)
	else
		bar.secret = true
		bar.expires = 0
		bar.frame.right:SetText("")
		local done = false
		if opts.timer and bar.frame.SetTimerDuration then
			done = pcall(bar.frame.SetTimerDuration, bar.frame, opts.timer)
		end
		if not done then
			bar.frame:SetMinMaxValues(0, 1)
			bar.frame:SetValue(1)
		end
	end
	paint(bar)
	Bars.active[#Bars.active + 1] = bar
	Bars.byId[id] = bar
	layout()
	ensureTicker()
	return bar
end

function Bars.Stop(id)
	local bar = Bars.byId[id]
	if not bar then return false end
	drop(bar)
	layout()
	return true
end

function Bars.StopAll(prefix)
	for i = #Bars.active, 1, -1 do
		local bar = Bars.active[i]
		if not prefix or (type(bar.id) == "string" and bar.id:sub(1, #prefix) == prefix) then drop(bar) end
	end
	layout()
end

function Bars.Pause(id)
	local bar = Bars.byId[id]
	if not bar or bar.paused then return end
	bar.left = bar.secret and 0 or (bar.expires - ns.Now())
	bar.paused = true
	paint(bar)
end

function Bars.Resume(id)
	local bar = Bars.byId[id]
	if not bar or not bar.paused then return end
	bar.paused = false
	if not bar.secret then bar.expires = ns.Now() + (bar.left or 0) end
	paint(bar)
end

function Bars.Has(id)
	return Bars.byId[id] ~= nil
end

function Bars.Remaining(id)
	local bar = Bars.byId[id]
	if not bar or bar.secret then return nil end
	return remaining(bar, ns.Now())
end

function Bars.Apply()
	if not ns.db then return end
	for key, a in pairs(anchors) do
		a:SetWidth(ns.db.width)
		a:Restore()
		a.handle:SetShown(not ns.db.locked)
	end
	if not ns.db.locked then
		anchor("normal")
		anchor("emph")
	end
	if not ns.db.emphasize then
		for _, bar in ipairs(Bars.active) do bar.emph = false end
	end
	layout()
end

Bars.Tick = tick
ns:Listen("LOGIN", Bars.Apply)
