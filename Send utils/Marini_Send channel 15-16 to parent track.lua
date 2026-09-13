local function getSelectedTracks()
  local tracks = {}
  for i = 0, reaper.CountSelectedTracks(0) - 1 do
    table.insert(tracks, reaper.GetSelectedTrack(0, i))
  end
  return tracks
end

local trackErrors = {}
for i, track in ipairs(getSelectedTracks()) do
  local parentTrack = reaper.GetParentTrack(track)
  if parentTrack then
    reaper.SetMediaTrackInfo_Value(track, "B_MAINSEND", 1)
    reaper.SetMediaTrackInfo_Value(track, "C_MAINSEND_OFFS", 14)
  else
    table.insert(trackErrors, track)
  end
  
end

