local _, ns = ...

local Timeline = {}
ns.Timeline = Timeline

local T = C_EncounterTimeline
local STATE = Enum and Enum.EncounterTimelineEventState or {}
local ACTIVE, PAUSED = STATE.Active or 0, STATE.Paused or 1
local FINISHED, CANCELED = STATE.Finished or 2, STATE.Canceled or 3

function Timeline.Available()
	return T ~= nil and T.GetEventState ~= nil
end

local function key(id)
	return "tl" .. tostring(id)
end

local function state(id)
	if not T or not T.GetEventState then return nil end
	local ok, s = pcall(T.GetEventState, id)
	if ok and not ns.IsSecret(s) then return s end
end

local function color(info)
	local severity = ns.Plain(info.severity, "number")
	local icons = ns.Plain(info.icons, "number")
	local set = Enum and Enum.EncounterTimelineIconSet
	if icons and set and bit and bit.band then
		if set.Deadly and bit.band(icons, set.Deadly) ~= 0 then return 2 end
		if set.Enrage and bit.band(icons, set.Enrage) ~= 0 then return 2 end
	end
	if severity and severity >= 0 and severity <= 2 then return severity end
	return 0
end

local function add(info, left)
	if type(info) ~= "table" then return end
	local id = ns.Plain(info.id)
	if id == nil then return end
	local source = ns.Plain(info.source, "number")
	if source == 1 or source == 2 then return end
	local opts = { color = color(info), remaining = left }
	if ns.Plain(info.duration, "number") == nil and T and T.GetEventTimer then
		local ok, timer = pcall(T.GetEventTimer, id)
		if ok then opts.timer = timer end
	end
	local text = info.spellName
	if text == nil then text = "Ability" end
	local bar = ns.Bars.Start(key(id), text, info.duration, info.iconFileID, opts)
	if bar and state(id) == PAUSED then ns.Bars.Pause(key(id)) end
end

function Timeline.Sync()
	if not T or not T.GetEventList or not T.GetEventInfo then return end
	local ok, list = pcall(T.GetEventList)
	if not ok or type(list) ~= "table" then return end
	for _, id in ipairs(list) do
		local s = state(id)
		if (s == ACTIVE or s == PAUSED) and not ns.Bars.Has(key(id)) then
			local ok2, info = pcall(T.GetEventInfo, id)
			if ok2 and info then
				local left
				if T.GetEventTimeRemaining then
					local ok3, r = pcall(T.GetEventTimeRemaining, id)
					if ok3 then left = ns.Plain(r, "number") end
				end
				add(info, left)
			end
		end
	end
end

ns:On("ENCOUNTER_TIMELINE_EVENT_ADDED", function(info) pcall(add, info) end)

ns:On("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED", function(id)
	if id == nil or ns.IsSecret(id) then return end
	local s = state(id)
	if s == ACTIVE then
		ns.Bars.Resume(key(id))
	elseif s == PAUSED then
		ns.Bars.Pause(key(id))
	elseif s == CANCELED or s == FINISHED then
		ns.Bars.Stop(key(id))
	end
end)

ns:On("ENCOUNTER_TIMELINE_EVENT_REMOVED", function(id)
	if id == nil or ns.IsSecret(id) then return end
	ns.Bars.Stop(key(id))
end)

ns:Listen("LOGIN", function() pcall(Timeline.Sync) end)
ns:Listen("ENCOUNTER_BEGIN", function() pcall(Timeline.Sync) end)
ns:Listen("ENCOUNTER_OVER", function() ns.Bars.StopAll("tl") end)
