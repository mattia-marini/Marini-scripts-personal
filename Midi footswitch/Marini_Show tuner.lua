  local tunerTrack = nil
  
  for i=0, reaper.CountTracks(0)-1 do
    local track = reaper.GetTrack(0,i)
    local _, trackName = reaper.GetTrackName(track)
    --reaper.ShowConsoleMsg(trackName .. "\n")
    if string.upper(trackName):match("TUNER")then
      tunerTrack = track
    end
  end
  
if tunerTrack == nil then return end

local fxen = reaper.GetMediaTrackInfo_Value(tunerTrack, "I_FXEN")
reaper.SetMediaTrackInfo_Value(tunerTrack, "I_FXEN", fxen == 1 and 0 or 1)
reaper.TrackFX_SetOpen(tunerTrack, 0, fxen == 1 and 0 or 1) 
