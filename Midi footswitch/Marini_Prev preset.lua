local function getNameItems()

  local sparkfunNamesItems = {}
  local sparkfunNamesTrackID = nil
  
  for i=0, reaper.CountTracks(0)-1 do
    local track = reaper.GetTrack(0,i)
    local _, trackName = reaper.GetTrackName(track)
    --reaper.ShowConsoleMsg(trackName .. "\n")
    if string.upper(trackName):match("SPARKFUN NAMES")then
      sparkfunNamesTrackID = track
    end
  end
  
  if sparkfunNamesTrackID == nil then return {} end
  
  for i=0, reaper.CountMediaItems(0) -1 do
      --reaper.ShowConsoleMsg(tostring(reaper.GetMediaItem_Track(reaper.GetMediaItem(0,i))))
    if reaper.GetMediaItem_Track(reaper.GetMediaItem(0,i)) == sparkfunNamesTrackID then 
      --local _, trackName = reaper.GetTrackName(reaper.GetMediaItem_Track(reaper.GetMediaItem(0,i)))
      --reaper.ShowConsoleMsg( trackName)
      local item = reaper.GetMediaItem(0,i)
      local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      local itemEnd = reaper.GetMediaItemInfo_Value(item, "D_LENGTH") + itemStart
      local _, itemName =  reaper.GetSetMediaItemInfo_String(item ,"P_NOTES", '', false)
      table.insert(sparkfunNamesItems,
      {["start"]= itemStart,
        ["end"]= itemEnd,
        ["name"]= itemName
      })
    end
  end
  return sparkfunNamesItems
end


reaper.OnStopButton()

local sortedNameItems = getNameItems()

table.sort(sortedNameItems ,function(v1, v2) return v1["end"] > v2["end"] end)

for i, val in ipairs(sortedNameItems) do
  if val["end"] <= reaper.GetCursorPosition() then 
    reaper.SetEditCurPos((val.start + val["end"])/2, true, false)
    break
  end
end
