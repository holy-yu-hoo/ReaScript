-- @noindex

local yh_plug = {}


function yh_plug.SetTrackChannels(num_channels) --  integer num_channels
	local proj, projfn = reaper.EnumProjects(-1)
	local undo_flag, count_sel_tracks, track = false, nil, nil
	if num_channels % 2 == 0 then
		count_sel_tracks = reaper.CountSelectedTracks2(proj, true)
		if count_sel_tracks > 0 then
			reaper.Undo_BeginBlock2(proj)
			for t = 0, count_sel_tracks - 1 do
				track = reaper.GetSelectedTrack2(proj, t, true)
				if num_channels ~= reaper.GetMediaTrackInfo_Value(track, "I_NCHAN") then
					reaper.SetMediaTrackInfo_Value(track, "I_NCHAN", num_channels)
					undo_flag = true
				end
			end
			if undo_flag then
				reaper.TrackList_AdjustWindows(true)
				reaper.Undo_EndBlock2(proj, "Set tracks to " .. num_channels .. " channels", -1)
			end
		end
	end
end

function yh_plug.TransposeTake(pitch) --  integer pitch
	local proj, projfn = reaper.EnumProjects(-1)
	if pitch == 0 then return end
	local count_sel_items, item, take, count_notes, cur_pitch, undo_str
	count_sel_items = reaper.CountSelectedMediaItems(proj)
	if count_sel_items > 0 and pitch ~= 0 then
		reaper.Undo_BeginBlock2(proj)
		for i = 0, count_sel_items - 1 do
			item = reaper.GetSelectedMediaItem(proj, i)
			take = reaper.GetActiveTake(item)
			if take ~= nil then
				if reaper.TakeIsMIDI(take) then
					_, count_notes = reaper.MIDI_CountEvts(take)
					for j = 0, count_notes - 1 do
						_, _, _, _, _, _, cur_pitch = reaper.MIDI_GetNote(take, j)
						reaper.MIDI_SetNote(take, j, nil, nil, nil, nil, nil, cur_pitch + pitch)
					end
				else
					cur_pitch = reaper.GetMediaItemTakeInfo_Value(take, "D_PITCH")
					reaper.SetMediaItemTakeInfo_Value(take, "D_PITCH", cur_pitch + pitch)
				end
			end
		end
		undo_str = "Transpose takes to " .. (pitch > 0 and "+" or "") .. pitch
		reaper.UpdateArrange()
		reaper.Undo_EndBlock2(proj, undo_str, -1)
	end
end

function yh_plug.FillEachStepsInTake(take, step, delete, sel, mute, channel, pitch, vel) --  take Take, integer Step, integer Delete, opt boolean Sel, opt boolean Mute, opt integer Chan, opt integer Pitch, opt integer Vel
	--  If Delete=0 - not delete; &1 - delete in Pitch, &2 delete in Chan, &4 delete all in Chan, &8 delete in all channels
	--  If Chan=-1 - all channels
	local note_len = 240
	local note_space = note_len * (step - 1)
	local def_note = {
		sel = (sel or false),
		mute = (mute or false),
		channel = (channel or 0),
		pitch = (pitch or 60),
		vel = (vel or 127)
	}
	local p, c, ap, ac, gt
	if reaper.BR_IsTakeMidi(take) then
		local _, count_notes = reaper.MIDI_CountEvts(take)

		if delete ~= 0 then
			if delete & 1 == 1 then
				p = def_note.pitch
			else
				p = false
			end
			if delete & 2 == 2 then
				c = def_note.channel
			else
				c = false
			end
			ap = (delete & 4) == 4
			ac = (delete & 8) == 8

			local io = 0
			for i = 0, count_notes - 1 do
				_, _, _, _, _, channel, pitch = reaper.MIDI_GetNote(take, i - io)
				if (pitch == p or ap) and (channel == c or ac) then
					reaper.MIDI_DeleteNote(take, i - io)
					io = io + 1
				end
			end
		end

		local item = reaper.GetMediaItemTake_Item(take)
		local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
		local ending = reaper.MIDI_GetPPQPosFromProjTime(take, pos + reaper.GetMediaItemInfo_Value(item, "D_LENGTH"))
		pos = reaper.MIDI_GetPPQPosFromProjTime(take, pos)

		if reaper.MIDIEditor_GetActive() ~= nil then
			for i, j in pairs({ triplet = reaper.NamedCommandLookup("_SWS_AWTOGGLETRIPLET"), dotted = reaper.NamedCommandLookup("_SWS_AWTOGGLEDOTTED"), swing = 42304 }) do
				if reaper.GetToggleCommandStateEx(0, j) == 1 then
					gt = i
				end
			end
		else
			for i, j in pairs({
				triplet = reaper.NamedCommandLookup("_SWS_AWTOGGLETRIPLET"),
				dotted = reaper.NamedCommandLookup("_SWS_AWTOGGLEDOTTED"),
				swing = 42304
			}) do
				if reaper.GetToggleCommandStateEx(0, j) == 1 then
					gt = i
				end
			end
			gt = gt or "straight"
		end

		if gt == "straight" then
			while pos + note_len <= ending do
				if def_note.channel == -1 then
					for j = 0, 15 do
						reaper.MIDI_InsertNote(take, def_note.sel, def_note.mute, pos, pos + note_len, j, def_note.pitch,
							def_note.vel)
					end
				else
					reaper.MIDI_InsertNote(take, def_note.sel, def_note.mute, pos, pos + note_len, def_note.channel,
						def_note.pitch, def_note.vel)
				end
				pos = pos + note_len + note_space
			end
		elseif gt == "triplet" then
			note_len = note_len * 2 / 3
			note_space = note_space * 2 / 3
			while pos + note_len <= ending do
				if def_note.channel == -1 then
					for j = 0, 15 do
						reaper.MIDI_InsertNote(take, def_note.sel, def_note.mute, pos, pos + note_len, j, def_note.pitch,
							def_note.vel)
					end
				else
					reaper.MIDI_InsertNote(take, def_note.sel, def_note.mute, pos, pos + note_len, def_note.channel,
						def_note.pitch, def_note.vel)
				end
				pos = pos + note_len + note_space
			end
		elseif gt == "dotted" then
			note_len = note_len * 1.5
			note_space = note_space * 1.5

			while pos + note_len <= ending do
				if def_note.channel == -1 then
					for j = 0, 15 do
						reaper.MIDI_InsertNote(take, def_note.sel, def_note.mute, pos, pos + note_len, j, def_note.pitch,
							def_note.vel)
					end
				else
					reaper.MIDI_InsertNote(take, def_note.sel, def_note.mute, pos, pos + note_len, def_note.channel,
						def_note.pitch, def_note.vel)
				end
				pos = pos + note_len + note_space
			end
		elseif gt == "swing" then
			c = 1
			while pos + note_len <= ending do
				local ret, swing = reaper.MIDI_GetGrid(take)
				swing = swing / 2
				if def_note.channel == -1 then
					for j = 0, 15 do
						if c % 2 == 1 then
							reaper.MIDI_InsertNote(take, def_note.sel, def_note.mute, pos, pos + note_len * (1 + swing),
								j,
								def_note.pitch, def_note.vel)
							pos = pos + note_len * (1 + swing) + note_space
						else
							reaper.MIDI_InsertNote(take, def_note.sel, def_note.mute, pos, pos + note_len, j,
								def_note.pitch, def_note.vel)
							pos = pos + note_len * (1 - swing) + note_space
						end
					end
				else
					if c % 2 == 1 then
						reaper.MIDI_InsertNote(take, def_note.sel, def_note.mute, pos, pos + note_len * (1 + swing),
							def_note.channel, def_note.pitch, def_note.vel)
						pos = pos + note_len * (1 + swing) + note_space
					else
						reaper.MIDI_InsertNote(take, def_note.sel, def_note.mute, pos, pos + note_len, def_note.channel,
							def_note.pitch, def_note.vel)
						pos = pos + note_len * (1 - swing) + note_space
					end
					c = c + 1
				end
			end
		end
	end
end

function yh_plug.GetTrackFXChunk(track, fx) --  track track, integer fx
	local _, chunk = reaper.GetTrackStateChunk(track, "", false)
	local guid = reaper.TrackFX_GetFXGUID(track, fx)
	local e, _, s, c, char = chunk:find(">[^>]+FXID " .. guid:gsub("-", "%%-"))
	c, s = 1, e - 1
	while c > 0 do
		char = chunk:sub(s, s)
		if char == ">" then c = c + 1 elseif char == "<" then c = c - 1 end
		s = s - 1
	end
	_, s = chunk:find("[^\n]+", s)
	s, e = s + 1, e - 1
	return chunk:sub(s, e)
end

function yh_plug.SetTrackFXChunk(track, fx, fx_data) --  track track, integer fx, string fx_data
	local _, chunk = reaper.GetTrackStateChunk(track, "", false)
	local guid = reaper.TrackFX_GetFXGUID(track, fx)
	local e, _, s, c, char = chunk:find(">[^>]+FXID " .. guid:gsub("-", "%%-"))
	c, s = 1, e - 1
	while c > 0 do
		char = chunk:sub(s, s)
		if char == ">" then c = c + 1 elseif char == "<" then c = c - 1 end
		s = s - 1
	end
	_, s = chunk:find("[^\n]+", s)
	s, e = s + 1, e - 1
	local new_chunk = chunk:sub(1, s - 1) .. fx_data .. chunk:sub(e + 1)
	return reaper.SetTrackStateChunk(track, new_chunk, true)
end

function yh_plug.GetTakeFXChunk(take, fx) --  take take, integer fx
	local item = reaper.GetMediaItemTake_Item(take)
	local _, chunk = reaper.GetItemStateChunk(item, "", false)
	local guid = reaper.TakeFX_GetFXGUID(take, fx)
	local e, _, s, c, char = chunk:find(">[^>]+FXID " .. guid:gsub("-", "%%-"))
	c, s = 1, e - 1
	while c > 0 do
		char = chunk:sub(s, s)
		if char == ">" then c = c + 1 elseif char == "<" then c = c - 1 end
		s = s - 1
	end
	_, s = chunk:find("[^\n]+", s)
	s, e = s + 1, e - 1
	return chunk:sub(s, e)
end

function yh_plug.SetTakeFXChunk(take, fx, fx_data) --  take take,  integer fx, string fx_data
	local item = reaper.GetMediaItemTake_Item(take)
	local _, chunk = reaper.GetItemStateChunk(item, "", false)
	local guid = reaper.TakeFX_GetFXGUID(take, fx)
	local e, _, s, c, char = chunk:find(">[^>]+FXID " .. guid:gsub("-", "%%-"))
	c, s = 1, e - 1
	while c > 0 do
		char = chunk:sub(s, s)
		if char == ">" then c = c + 1 elseif char == "<" then c = c - 1 end
		s = s - 1
	end
	_, s = chunk:find("[^\n]+", s)
	s, e = s + 1, e - 1
	local new_chunk = chunk:sub(1, s - 1) .. fx_data .. chunk:sub(e + 1)
	return reaper.SetItemStateChunk(item, new_chunk, true)
end

function yh_plug.GetOnlyFXName(fx_name) --  string fx_name
	local char, s, e
	for i = #fx_name, 1, -1 do
		char = fx_name:sub(i, i)
		if char == "(" then
			e = i - 1
		elseif char == ":" then
			s = i + 1
		end
	end

	if s == nil then
		s = 1
	end
	if e == nil then
		e = #fx_name
	end

	return fx_name:sub(s, e):match("%s*(.*)%s*")
end

function yh_plug.ClearProjExtState(ext_name, key, func) --  string ext_name, string key, function func
	-- if key=nil check all keys, function must return boolean
	local proj, projfn = reaper.EnumProjects(-1)
	if key == nil then
		local i = 0

		if func ~= nil then
			while true do
				local ret, k, val = reaper.EnumProjExtState(proj, ext_name, i)
				if not (ret and k) then break end

				if func({ key = k, val = val }) then
					reaper.SetProjExtState(proj, ext_name, k, "")
				else
					i = i + 1
				end
			end
		else
			while true do
				local ret, k, val = reaper.EnumProjExtState(proj, ext_name, 0)
				if not (ret and k) then break end
				reaper.SetProjExtState(proj, ext_name, k, "")
			end
		end
	else
		local ret, val = reaper.GetProjExtState(proj, ext_name, key);
		if func ~= nil then
			if func({ key = key, val = val }) then
				reaper.SetProjExtState(proj, ext_name, key, "")
			end
		else
			reaper.SetProjExtState(proj, ext_name, key, "")
		end
	end
end

function yh_plug.GetFXByGUID(proj, guid) --  ReaProject proj, string guid
	local track, item, take

	track = reaper.GetMasterTrack(proj)
	----  Master track input FX
	for i = 0, reaper.TrackFX_GetCount(track) - 1 do
		if guid == reaper.TrackFX_GetFXGUID(track, i) then
			return true, 0, -1, -1, i
		end
	end
	---- Monitoring FX
	for i = 0, reaper.TrackFX_GetRecCount(track) - 1 do
		if guid == reaper.TrackFX_GetFXGUID(track, i + 2 ^ 24) then
			return true, 0, -1, -1, i + 2 ^ 24
		end
	end

	for i = 0, reaper.CountTracks(proj) - 1 do
		track = reaper.GetTrack(proj, i)
		---- Tracks input FX
		for j = 0, reaper.TrackFX_GetCount(track) - 1 do
			if guid == reaper.TrackFX_GetFXGUID(track, j) then
				return true, i + 1, -1, -1, j
			end
		end
		---- Tracks record FX
		for j = 0, reaper.TrackFX_GetRecCount(track) - 1 do
			if guid == reaper.TrackFX_GetFXGUID(track, j + 2 ^ 24) then
				return true, i + 1, -1, -1, j + 2 ^ 24
			end
		end
	end

	for i = 0, reaper.CountMediaItems(proj) - 1 do
		item = reaper.GetMediaItem(proj, i)
		for j = 0, reaper.CountTakes(item) - 1 do
			take = reaper.GetTake(item, j)
			----  Takes FX
			for k = 0, reaper.TakeFX_GetCount(take) - 1 do
				if guid == reaper.TakeFX_GetFXGUID(take, k) then
					return true, -1, i, j, k
				end
			end
		end
	end

	return false, -1, -1, -1, -1
end

function yh_plug.FXInProj(x)
	local guid, val, track, item, take = x.key, x.val, nil, nil, nil

	local proj, projfn = reaper.EnumProjects(-1)
	track = reaper.GetMasterTrack(proj)
	----  Master track input FX
	for i = 0, reaper.TrackFX_GetCount(track) - 1 do
		if guid == reaper.TrackFX_GetFXGUID(track, i) then
			return false
		end
	end
	---- Monitoring FX
	for i = 0, reaper.TrackFX_GetRecCount(track) - 1 do
		if guid == reaper.TrackFX_GetFXGUID(track, i + 2 ^ 24) then
			return false
		end
	end


	for i = 0, reaper.CountTracks(proj) - 1 do
		track = reaper.GetTrack(proj, i)
		---- Tracks input FX
		for i = 0, reaper.TrackFX_GetCount(track) - 1 do
			if guid == reaper.TrackFX_GetFXGUID(track, i) then
				return false
			end
		end
		---- Tracks record FX
		for i = 0, reaper.TrackFX_GetRecCount(track) - 1 do
			if guid == reaper.TrackFX_GetFXGUID(track, i + 2 ^ 24) then
				return false
			end
		end
	end


	for i = 0, reaper.CountMediaItems(proj) - 1 do
		item = reaper.GetMediaItem(proj, i)
		for j = 0, reaper.CountTakes(item) - 1 do
			take = reaper.GetTake(item, j)
			----  Takes FX
			for k = 0, reaper.TakeFX_GetCount(take) - 1 do
				if guid == reaper.TakeFX_GetFXGUID(take, k) then
					return false
				end
			end
		end
	end


	return true
end

return yh_plug
