if reaper.CountSelectedTracks(0) < 2 then 
  reaper.ShowMessageBox("Please select at least 2 tracks", "Error", 0)
  return
end

local firstTrack = reaper.GetSelectedTrack(0, 0)


reaper.ShowConsoleMsg(tostring(firstTrack).."\n")

for i=1, reaper.CountSelectedTracks(0) -1 do
  local recievingTrack = reaper.GetSelectedTrack(0, i)
  
  local sendId = reaper.CreateTrackSend(firstTrack, recievingTrack)
  
  
  --reaper.GetSetTrackSendInfo_String(firstTrack, , integer sendidx, string parmname, string stringNeedBig, boolean setNewValue)
  
  --reaper.GetTrackSendInfo_Value(firstTrack, 0, sendId, "I_SRCCHAN")
  
  reaper.SetTrackSendInfo_Value(firstTrack, 0 , sendId,  "I_SRCCHAN", tostring(2*(i-1)))
  

  reaper.ShowConsoleMsg(select(2,reaper.GetTrackName(recievingTrack)).."\n")
  
end



