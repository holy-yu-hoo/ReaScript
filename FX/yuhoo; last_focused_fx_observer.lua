-- @description Last focused fx observer
-- @author yuhoo
-- @version 1.0.0
-- @about
--   set last focused fx in project state
-- @provides
--   [main] .
--	 yuhoo; last_focused_fx_observer_settings.lua

local settings

function Main()
	local proj, projfn = reaper.EnumProjects(-1)
	local ret, track, item, take, fx, param = reaper.GetTouchedOrFocusedFX(1)
	if ret then
		local str = track .. ' ' .. item .. ' ' .. take .. " " .. fx .. " " .. param
		if str ~= reaper.GetProjExtState(proj, settings.ext_name_string, settings.key) then
			reaper.SetProjExtState(proj, settings.ext_name_string, settings.key, "")
		end
	end
end

function Exit()
	local _, _, sec_id, cmd_id = reaper.get_action_context()
	reaper.SetToggleCommandState(sec_id, cmd_id, 0)
	reaper.RefreshToolbar2(sec_id, cmd_id)
	local proj, projfn = reaper.EnumProjects(-1)
	reaper.SetProjExtState(proj, settings.ext_name_string, settings.key, "")
end

function Run()
	local _, _, sec_id, cmd_id = reaper.get_action_context()
	reaper.SetToggleCommandState(sec_id, cmd_id, 1)
	reaper.RefreshToolbar2(sec_id, cmd_id)
	reaper.atexit(Exit)
	settings = dofile(debug.getinfo(1, 'S').source:match("^@?(.*[\\/])FX[\\/]") ..
		"FX\\yuhoo; last_focused_fx_observer_settings.lua")
	Main()
end

Run()
