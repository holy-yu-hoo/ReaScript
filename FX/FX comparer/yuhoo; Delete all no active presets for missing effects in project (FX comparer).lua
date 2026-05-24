-- @noindex
-- @description Delete all no active presets for missing effects in project (FX comparer)
-- @author yuhoo
-- @version 1.0.0

local scripts_path = debug.getinfo(1, 'S').source:match("^@?(.*[\\/])FX[\\/]")
local settings = dofile(scripts_path .. "FX\\FX comparer\\yuhoo; fx_comparer_settings.lua")
local yh = dofile(scripts_path .. "Functions\\yuhoo; functions.lua")
local proj, projfn = reaper.EnumProjects(-1)
reaper.Undo_BeginBlock2(proj)
yh.ClearProjExtState(settings.ext_name_string, nil, yh.FXInProj)
reaper.Undo_EndBlock2(proj, "FX comparer: Delete all no active presets for missing effects in project", -1)
if settings.save_proj_after_clear then
  reaper.Main_OnCommand(40026, 0) --  File: Save project
end

reaper.defer(function() end)
