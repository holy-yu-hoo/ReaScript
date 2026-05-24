-- @description FX AB comparer
-- @author yuhoo
-- @version 1.0.0
-- @about
--   using track and take chunk for save fx state
--   for setting see "yuhoo; fx_comparer_settings.lua" in this directory
--   also see actions:
--   Script: yuhoo; Copy active FX preset to no active (FX comparer).lua
--   Script: yuhoo; Delete all no active presets (FX comparer).lua
--   Script: yuhoo; Delete all no active presets for missing effects in project (FX comparer).lua
--   Script: yuhoo; Delete no active preset (FX comparer).lua
-- @provides
--   [main] .
--   [main] yuhoo; Copy active FX preset to no active (FX comparer).lua
--   [main] yuhoo; Delete all no active presets (FX comparer).lua
--   [main] yuhoo; Delete all no active presets for missing effects in project (FX comparer).lua
--   [main] yuhoo; Delete no active preset (FX comparer).lua
--   yuhoo; fx_comparer_settings.lua
--   ../yuhoo; last_focused_fx_observer_settings.lua
--   ../../Functions/yuhoo; functions.lua

local track, trackidx, item, itemidx, take, takeidx, fx, guid, fx_chunk, ret, fx_data, name, fx_name, param, state
local scripts_path = debug.getinfo(1, 'S').source:match("^@?(.*[\\/])FX[\\/]")
local settings = dofile(scripts_path .. "FX\\FX comparer\\yuhoo; fx_comparer_settings.lua")

local proj, projfn = reaper.EnumProjects(-1)
ret, trackidx, itemidx, takeidx, fx, param = reaper.GetTouchedOrFocusedFX(1)

if not ret then
  local observer_settings = dofile(scripts_path ..
    "FX\\yuhoo; last_focused_fx_observer_settings.lua")
  ret, state = reaper.GetProjExtState(proj, observer_settings.ext_name_string, observer_settings.key)
  trackidx, itemidx, takeidx, fx, param = state:match('(%S+)%s-(%S+)%s-(%S+)%s-(%S+)%s-(%S+)')
  trackidx, itemidx, takeidx, fx, param = tonumber(trackidx), tonumber(itemidx), tonumber(takeidx), tonumber(fx),
      tonumber(param)
end
if not (trackidx ~= nil and itemidx ~= nil and takeidx ~= nil and fx ~= nil and param ~= nil) then return end

if trackidx == -1 and ((fx % (1 << 25)) >> 24) == 1 then return reaper.defer(function() end) end
if trackidx == -1 then track = reaper.GetMasterTrack(proj) else track = reaper.GetTrack(proj, trackidx) end

local yh = dofile(scripts_path .. "Functions\\yuhoo; functions.lua")

if itemidx == -1 then
  if reaper.TrackFX_GetOpen(track, fx) or settings.ignore_visibility then
    reaper.Undo_BeginBlock2(proj)
    guid = reaper.TrackFX_GetFXGUID(track, fx)
    fx_chunk = yh.GetTrackFXChunk(track, fx)
    ret, fx_data = reaper.GetProjExtState(proj, settings.ext_name_string, guid)
    if fx_data ~= "" then
      yh.SetTrackFXChunk(track, fx, fx_data)
      reaper.SetProjExtState(proj, settings.ext_name_string, guid, fx_chunk)
    else
      reaper.SetProjExtState(proj, settings.ext_name_string, guid, fx_chunk)
      if settings.set_to_default then
        if not reaper.TrackFX_SetPresetByIndex(track, fx, -1) then
          reaper.TrackFX_SetPresetByIndex(track, fx, -2)
        end
      end
    end

    ret, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    local track_num = math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER"))
    local prefix = (track_num == -1) and "Master" or ("Track " .. track_num)
    name = (name ~= "") and (prefix .. " " .. name) or prefix

    _, fx_name = reaper.TrackFX_GetFXName(track, fx)
    fx_name = yh.GetOnlyFXName(fx_name)
    reaper.Undo_EndBlock2(proj, "FX comparer A/B: " .. name .. ": " .. fx_name, -1)
  end
else
  item = reaper.GetTrackMediaItem(track, itemidx)
  take = reaper.GetTake(item, takeidx)
  if reaper.TakeFX_GetOpen(take, fx) or settings.ignore_visibility then
    reaper.Undo_BeginBlock2(proj)
    guid = reaper.TakeFX_GetFXGUID(take, fx)
    fx_chunk = yh.GetTakeFXChunk(take, fx)
    if not fx_chunk then return end
    ret, fx_data = reaper.GetProjExtState(proj, settings.ext_name_string, guid)
    if fx_data ~= "" then
      yh.SetTakeFXChunk(take, fx, fx_data)
      reaper.SetProjExtState(proj, settings.ext_name_string, guid, fx_chunk)
    else
      reaper.SetProjExtState(proj, settings.ext_name_string, guid, fx_chunk)
      if settings.set_to_default then
        if not reaper.TakeFX_SetPresetByIndex(take, fx, -1) then
          reaper.TakeFX_SetPresetByIndex(take, fx, -2)
        end
      end
    end

    ret, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    local track_num = math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER"))
    name = (name ~= "") and (track_num .. " " .. name) or tostring(track_num)

    _, fx_name = reaper.TakeFX_GetFXName(take, fx)
    fx_name = yh.GetOnlyFXName(fx_name)
    reaper.Undo_EndBlock2(proj, "FX comparer A/B: item on track " .. name .. ": " .. fx_name, -1)
  end
end

reaper.defer(function() end)
