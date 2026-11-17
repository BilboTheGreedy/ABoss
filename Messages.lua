local _, ns = ...
local UI = ns.UI
local C = UI.colors

local Messages = {}
ns.Messages = Messages

local frame
local lines = {}
local HOLD, FADE = 3.5, 1
local COLORS = {
	[0] = { 1, 0.82, 0 },
	[1] = { 1, 0.5, 0.1 },
	[2] = { 1, 0.2, 0.2 },
	good = { 0.3, 0.9, 0.4 },
	info = { 0.9, 0.9, 0.92 },
}

local function build()
	frame = CreateFrame("Frame", "ABossMessages", UIParent)
	frame:SetSize(520, 26)
	frame:SetFrameStrata("HIGH")
	UI.Movable(frame, ns.db.text)
	frame.handle = CreateFrame("Button", nil, frame)
	frame.handle:SetAllPoints(frame)
	UI.Fill(frame.handle, { 1, 0.82, 0, 0.25 })
	UI.Border(frame.handle, C.accent)
	frame.handle.label = UI.Text(frame.handle, "GameFontHighlightSmall", "CENTER")
	frame.handle.label:SetPoint("CENTER")
	frame.handle.label:SetText("Warnings")
	frame.handle:RegisterForDrag("LeftButton")
	frame.handle:SetScript("OnDragStart", function() frame:StartMoving() end)
	frame.handle:SetScript("OnDragStop", function() frame:StopDrag() end)
	frame.handle:SetShown(not ns.db.locked)
	for i = 1, 4 do
		local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
		fs:SetPoint("TOP", frame, "TOP", 0, -(i - 1) * 30)
		fs:SetJustifyH("CENTER")
		fs:Hide()
		lines[i] = { fs = fs, shown = 0 }
	end
	frame.big = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	frame.big:SetPoint("BOTTOM", frame, "TOP", 0, 14)
	frame.big:Hide()
	frame.bigAt = 0
	local acc = 0
	frame:SetScript("OnUpdate", function(_, dt)
		acc = acc + (dt or 0)
		if acc < 0.05 then return end
		acc = 0
		Messages.Tick()
	end)
end

function Messages.Tick()
	if not frame then return end
	local now = ns.Now()
	for _, l in ipairs(lines) do
		if l.fs:IsShown() then
			local age = now - l.shown
			if age >= HOLD + FADE then
				l.fs:Hide()
			elseif age > HOLD then
				l.fs:SetAlpha(1 - (age - HOLD) / FADE)
			end
		end
	end
	if frame.big:IsShown() and now - frame.bigAt > 1.1 then frame.big:Hide() end
end

function Messages.Show(text, color, sound)
	if not ns.db then return end
	if not frame then build() end
	for i = #lines, 2, -1 do
		local from, to = lines[i - 1], lines[i]
		if from.fs:IsShown() then
			to.fs:SetText(from.text)
			to.text = from.text
			to.shown = from.shown
			to.fs:SetTextColor(from.r, from.g, from.b)
			to.r, to.g, to.b = from.r, from.g, from.b
			to.fs:SetAlpha(1)
			to.fs:Show()
		else
			to.fs:Hide()
		end
	end
	local c = COLORS[color or 0] or COLORS[0]
	local l = lines[1]
	l.text = text
	l.shown = ns.Now()
	l.r, l.g, l.b = c[1], c[2], c[3]
	l.fs:SetText(text)
	l.fs:SetTextColor(c[1], c[2], c[3])
	l.fs:SetAlpha(1)
	l.fs:Show()
	if sound ~= false then ns.Sound(type(sound) == "string" and sound or nil) end
end

function Messages.Count(n)
	if not frame then build() end
	frame.big:SetText(n)
	frame.big:SetTextColor(1, 0.82, 0)
	frame.big:Show()
	frame.bigAt = ns.Now()
	ns.Sound("IG_QUEST_LIST_OPEN")
end

function Messages.Apply()
	if not ns.db then return end
	if not frame then build() end
	frame:Restore()
	frame.handle:SetShown(not ns.db.locked)
end

local function warning(info)
	if not ns.db.warnings or type(info) ~= "table" then return end
	if ns.Plain(info.shouldShowWarning, "boolean") == false then return end
	local text = info.text
	if type(text) == "nil" then return end
	local caster, target = info.casterName, info.targetName
	if type(caster) == "nil" then caster = "" end
	if type(target) == "nil" then target = "" end
	local ok, formatted = pcall(string.format, text, caster, target)
	if ok and type(formatted) ~= "nil" then text = formatted end
	local severity = ns.Plain(info.severity, "number") or 0
	local play = ns.Plain(info.shouldPlaySound, "boolean") ~= false
	Messages.Show(text, severity, play)
end

ns:On("ENCOUNTER_WARNING", function(info) pcall(warning, info) end)
ns:Listen("LOGIN", Messages.Apply)
