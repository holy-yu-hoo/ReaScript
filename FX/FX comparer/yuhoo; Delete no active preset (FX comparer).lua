-- @noindex
-- @description Delete no active preset (FX comparer)
-- @author yuhoo
-- @version 1.0.0

local trackidx, itemidx, takeidx, fx, guid, ret, name, fx_name, fx_data
local scripts_path = debug.getinfo(1, 'S').source:match("^@?(.*[\\/])FX[\\/]")
local settings = dofile(scripts_path .. "FX\\FX comparer\\yuhoo; fx_comparer_settings.lua")
local yh = dofile(scripts_path .. "Functions\\yuhoo; functions.lua")

local proj = reaper.EnumProjects(-1)
ret, trackidx, itemidx, takeidx, fx, _ = reaper.GetTouchedOrFocusedFX(1)

if not ret then
  local observer_settings = dofile(scripts_path .. "FX\\yuhoo; last_focused_fx_observer_settings.lua")
  ret, fx_data = reaper.GetProjExtState(proj, observer_settings.ext_name_string, observer_settings.key)
  trackidx, itemidx, takeidx, fx = fx_data:match('(%S+)%s-(%S+)%s-(%S+)%s-(%S+)')
  trackidx, itemidx, takeidx, fx = tonumber(trackidx), tonumber(itemidx), tonumber(takeidx), tonumber(fx)
end
if not (trackidx ~= nil and itemidx ~= nil and takeidx ~= nil and fx ~= nil) then return end

if trackidx == -1 and ((fx % (1 << 25)) >> 24) == 1 then return reaper.defer(function() end) end
local track = (trackidx == -1) and reaper.GetMasterTrack(proj) or reaper.GetTrack(proj, trackidx)
if not track then return end

if itemidx == -1 then
  if reaper.TrackFX_GetOpen(track, fx) or settings.ignore_visibility then
    reaper.Undo_BeginBlock2(proj)
    guid = reaper.TrackFX_GetFXGUID(track, fx)
    reaper.SetProjExtState(proj, settings.ext_name_string, guid, "")

    ret, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    local track_num = math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER"))
    local prefix = (track_num == -1) and "Master" or ("Track " .. track_num)
    name = (name ~= "") and (prefix .. " " .. name) or prefix

    _, fx_name = reaper.TrackFX_GetFXName(track, fx)
    fx_name = yh.GetOnlyFXName(fx_name)
    reaper.Undo_EndBlock2(proj, "FX comparer: Delete preset: " .. name .. ": " .. fx_name, -1)
  end
else
  local item = reaper.GetTrackMediaItem(track, itemidx)
  local take = reaper.GetTake(item, takeidx)
  if reaper.TakeFX_GetOpen(take, fx) or settings.ignore_visibility then
    reaper.Undo_BeginBlock2(proj)
    guid = reaper.TakeFX_GetFXGUID(take, fx)
    reaper.SetProjExtState(proj, settings.ext_name_string, guid, "")

    ret, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    local track_num = math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER"))
    name = (name ~= "") and (track_num .. " " .. name) or tostring(track_num)

    _, fx_name = reaper.TakeFX_GetFXName(take, fx)
    fx_name = yh.GetOnlyFXName(fx_name)
    reaper.Undo_EndBlock2(proj, "FX comparer: Delete preset: Item on track " .. name .. ": " .. fx_name, -1)
  end
end

reaper.defer(function() end)
