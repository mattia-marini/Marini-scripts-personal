--reaper.ShowConsoleMsg(tostring(rv).."\n")

-- stetch marker positions are relative to MEDIA START (D_POSITION)
local rv, division = reaper.GetSetProjectGrid(0, false)
local function ith_division_time(i)
  return reaper.TimeMap2_QNToTime(0,i * division / 0.25).."\n"
end
--reaper.ShowConsoleMsg(tostring(division).."\n")ù
--reaper.ShowConsoleMsg("Cursor pos: ".. reaper.GetCursorPosition().."\n")
--reaper.ShowConsoleMsg(reaper.TimeMap2_timeToQN(0, reaper.GetCursorPosition()))


for selitem_idx = 0, reaper.CountSelectedMediaItems(0)-1 do
  local media_item = reaper.GetSelectedMediaItem(0, selitem_idx)
  for takeidx = 0, reaper.CountTakes(media_item)-1 do
    local take = reaper.GetTake(media_item, takeidx)
    local media_start = reaper.GetMediaItemInfo_Value(media_item, "D_POSITION")
    --reaper.ShowConsoleMsg("Media start: " .. reaper.GetMediaItemInfo_Value(media_item, "D_POSITION") .. "\n")
    --reaper.ShowConsoleMsg("Media loop src: " .. reaper.GetMediaItemInfo_Value(media_item, "B_LOOPSRC") .. "\n")
    --reaper.ShowConsoleMsg("Take start offse: " .. reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS") .. "\n")
    
    local stretchmarker_count = reaper.GetTakeNumStretchMarkers(take)
    
    local start_qn_pos = nil
    if stretchmarker_count > 0 then
      local rv, stretchhmarker_pos = reaper.GetTakeStretchMarker(take, 0)
      stretchhmarker_pos = media_start + stretchhmarker_pos
      --reaper.ShowConsoleMsg("Stretchmarker pos: " .. stretchhmarker_pos .. "\n")
      
      local snapped_pos = reaper.SnapToGrid(0, stretchhmarker_pos)
      
      --reaper.ShowConsoleMsg("Snap pos: " .. snapped_pos .. "\n")
      if snapped_pos < stretchhmarker_pos then
        local qn_pos = reaper.TimeMap_timeToQN(snapped_pos)
        snapped_pos = reaper.TimeMap_QNToTime(qn_pos + division / 0.25) -- Addind a division, converted to quarter note
      end
      start_qn_pos = reaper.TimeMap_timeToQN(snapped_pos)
      reaper.SetTakeStretchMarker(take, 0, snapped_pos - media_start)
    end
    
    
    for stretchmarker_idx = 1, stretchmarker_count -1 do
      local abs_time = reaper.TimeMap_QNToTime(start_qn_pos + stretchmarker_idx * division / 0.25)
      local relative_rime = abs_time - media_start
      reaper.SetTakeStretchMarker(take, stretchmarker_idx, relative_rime)
    end
    
  end
end

reaper.ThemeLayout_RefreshAll()
