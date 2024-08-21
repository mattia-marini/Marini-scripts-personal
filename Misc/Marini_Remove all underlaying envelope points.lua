start_time, end_time = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
--reaper.ShowConsoleMsg(tostring(start_time).." ")
--reaper.ShowConsoleMsg(tostring(end_time).." ")
--reaper.ShowConsoleMsg("\n------------\n")
for t = 0, reaper.CountSelectedTracks(0)-1 do
  local track = reaper.GetSelectedTrack(0, t)
 
  for fx=0, reaper.TrackFX_GetCount(track) -1 do
    for fx_param=0, reaper.TrackFX_GetNumParams(track, fx) -1 do
      
      local envelope = reaper.GetFXEnvelope(track, fx, fx_param, false)
      
      --reaper.ShowConsoleMsg(tostring(envelope).."\n")
      
      if envelope then
        --[[
        for point=0, reaper.CountEnvelopePointsEx(envelope, -1) -1 do
          _, time = reaper.GetEnvelopePoint(envelope, point)
          reaper.ShowConsoleMsg(tostring(time).."\n")
          --reaper.DeleteEnvelopePointEx(envelope, -1, point, true)
        end
        --]]
        reaper.DeleteEnvelopePointRangeEx(envelope, -1, start_time, end_time)
        --reaper.Envelope_SortPoints(envelope)
        
      end
    end
  end
end

reaper.TrackList_AdjustWindows(false)
