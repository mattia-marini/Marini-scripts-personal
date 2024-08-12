
function p(string)
  if string == "" then return end
  reaper.ShowConsoleMsg(tostring(string) .. "\n")
end

function get_presets()
for i = 0, reaper.CountMediaItems(0) -1 do 
  local item = reaper.GetMediaItem(0, i)
  local retval, item_notes = reaper.GetSetMediaItemInfo_String(item ,"P_NOTES", '', false)
  --reaper.ShowConsoleMsg(tostring(retval))
  --p(item_notes)
end
end


function copyAutomationItemAtPos(env, item1,pos)

  local insertPos = pos
  
  local item1Start = reaper.GetSetAutomationItemInfo(env, item1, 'D_POSITION', 0, false) 
  local item1End =  item1Start + reaper.GetSetAutomationItemInfo(env, item1, 'D_LENGTH', 0, false) 
  
  
  local item2 = reaper.InsertAutomationItem(env, -1, insertPos, item1End- item1Start)
  local item2Start = reaper.GetSetAutomationItemInfo(env, item2, 'D_POSITION', 0, false) 
  local item2End = item2Start + reaper.GetSetAutomationItemInfo(env, item2, 'D_LENGTH', 0, false)
  
  reaper.DeleteEnvelopePointRangeEx(env, -1, item2Start, item2End)
  
  
  reaper.DeleteEnvelopePointRangeEx(env, item2, item2Start,item2End)
  
  if insertPos < item1Start then item1 = item1 + 1 end
  
  
  --reaper.InsertAutomationItem(env, -1, 0, 4)
  --clearing points
 
  --p("i1 start: ".. item1Start)
  --p("i2 start: ".. item2Start)
  --p(reaper.CountEnvelopePointsEx(env, item1)-1)
  for i=0, reaper.CountEnvelopePointsEx(env, item1)-1 do
    local _,  time,  value,  shape,  tension, selected = reaper.GetEnvelopePointEx( env, item1, i)
    --p( time - item1Start)
    --p("value: " .. time - item1Start + item2Start)
    reaper.InsertEnvelopePointEx( env, item2, item2Start + math.max(time - item1Start, 0) + 0.01 ,  value,  shape,  tension, selected)
  end
  
end


function getPresetsTimeInterval()
  for i = 0, reaper.CountProjectMarkers(0)-1 do
    local _, isRgn, rgStart, rgEnd, name = reaper.EnumProjectMarkers(i)
    if isRgn and name == "Presets" then 
      --p("trovata sezione presets")
      return rgStart, rgEnd
    end
  end
end


function copyAllAutomationInRangeToPos(track, startPos, endPos, position)
  local sensitivity = 0.001
  for i=0, reaper.CountTrackEnvelopes(track) -1 do
    local env = reaper.GetTrackEnvelope(track, i)
    local lCorrection = 0
 
    for j = 0, reaper.CountAutomationItems(env) -1 do
      local itemStart = reaper.GetSetAutomationItemInfo(env, j + lCorrection, 'D_POSITION', 0, false)
      local itemEnd = itemStart + reaper.GetSetAutomationItemInfo(env, j + lCorrection, 'D_LENGTH', 0, false)
      
      --local n_points = reaper.CountEnvelopePointsEx(env, j)
      if itemStart >= startPos - sensitivity and itemEnd <= endPos + sensitivity then 
        copyAutomationItemAtPos(env, j, position)
        if position < startPos then
          lCorrection = lCorrection + 1
        end
        --p("copio " .. j)
        --p(n_points)
      end
    end
    --p(reaper.CountTrackEnvelopes(reaper.GetSelectedTrack(0, 0)))
    --GetTrackMediaItem(selectedTrack, i)
  end
end


function getPresetUnderCursor()
 local cursorPos = reaper.GetCursorPosition()
 local selectedTrack = reaper.GetSelectedTrack(0,0)
 for i = 0, reaper.CountTrackMediaItems(selectedTrack)-1 do 
   local item = reaper.GetTrackMediaItem(selectedTrack, i)
   local itemStart = reaper.GetMediaItemInfo_Value(item ,"D_POSITION")
   local itemEnd = itemStart + reaper.GetMediaItemInfo_Value(item ,"D_LENGTH")
   
   if cursorPos <= itemEnd and cursorPos >= itemStart then
    local _, item_notes = reaper.GetSetMediaItemInfo_String(item ,"P_NOTES", '', false)
    return item_notes, i, itemStart, itemEnd
   end
  end
end

function getAllPresetBounds(name)
 local selectedTrack = reaper.GetSelectedTrack(0,0)
 local presetsStart, presetsEnd = getPresetsTimeInterval()
 local presetsBounds = {}
 local currPres = nil
 local itemsBeforePresets = 0
 local count = 0
 
 for i = 0, reaper.CountTrackMediaItems(selectedTrack)-1 do 
   local item = reaper.GetTrackMediaItem(selectedTrack, i)
   local itemStart = reaper.GetMediaItemInfo_Value(item ,"D_POSITION")
   local itemEnd = itemStart + reaper.GetMediaItemInfo_Value(item ,"D_LENGTH")
   local _, item_notes = reaper.GetSetMediaItemInfo_String(item ,"P_NOTES", '', false)
    
    
   if itemEnd <= presetsEnd and itemStart >= presetsStart then
   
   --p(item_notes)
   count = count + 1
    table.insert(presetsBounds, {item_notes, itemStart, itemEnd})
    
    if item_notes == name then
      absolutePresItemNumber = i
      currPres = count
    end
    
    --return itemStart, itemEnd
  elseif  itemEnd <= presetsStart then
      itemsBeforePresets = itemsBeforePresets + 1
  end
  
  end
  
  
  return currPres,itemsBeforePresets, presetsBounds
end

function unselectAllItems()
  for trackNumber = 0, reaper.CountTracks(0) -1 do
    local track = reaper.GetTrack(0,trackNumber)
    for envNumber =0, reaper.CountTrackEnvelopes(track) -1 do
      local env = reaper.GetTrackEnvelope(track, envNumber)
      for itemNumber=0, reaper.CountAutomationItems(env) -1 do
        reaper.GetSetAutomationItemInfo(env, itemNumber, 'D_UISEL', 0, true)
      end
    end
  end
end

function clearAllAutomationDataInRange(l, r)
  local track = reaper.GetSelectedTrack(0,0)
  unselectAllItems()
  for i=0, reaper.CountTrackEnvelopes(track) -1 do
    local env = reaper.GetTrackEnvelope(track, i)
    for j=0, reaper.CountAutomationItems(env) -1 do
      local itemStart = reaper.GetSetAutomationItemInfo(env, j, 'D_POSITION', 0, false)
      local itemEnd = itemStart + reaper.GetSetAutomationItemInfo(env, j, 'D_LENGTH', 0, false)

      if not( itemStart >= r or itemEnd <= l )then 
        reaper.GetSetAutomationItemInfo(env, j, 'D_UISEL', 1, true)
      end
    end
    reaper.DeleteEnvelopePointRangeEx(env, -1, l,r)
    --p(reaper.CountTrackEnvelopes(reaper.GetSelectedTrack(0, 0)))
    --GetTrackMediaItem(selectedTrack, i)
  end
  reaper.Main_OnCommand(42086,0)
end

function script()
  local n_selectedTracks = reaper.CountSelectedTracks(0)  

  if n_selectedTracks ~= 1 then 
    reaper.ShowMessageBox("Select 1 track", "Error", 0)
    return
  end
  

  local selectedTrack = reaper.GetSelectedTrack(0, 0)
  local presetsStart, presetsEnd = getPresetsTimeInterval()
  local cursorPosition = reaper.GetCursorPosition()
  if cursorPosition >= presetsStart and cursorPosition <= presetsEnd then 
    reaper.ShowMessageBox("You are hovering the \"preset zone\". Please hover a preset", "Error", 0)
    return
  end
  
  
  
  
  
  --copyAllAutomationInRangeToCursorPos(selectedTrack, presetsStart, presetsEnd)
  local name, itemNumber, presCursorStart, presCursorEnd = getPresetUnderCursor()
  if not name then reaper.ShowMessageBox("Edit cursor is not hovering any preset", "Error", 0) return end

  local currPresNumber, itemsBeforePresets, presetsBounds  = getAllPresetBounds(name)
  
  
  if not currPresNumber then reaper.ShowMessageBox("Preset \"" .. name .. "\" doesen't exist", "Error", 0) return end
  
  clearAllAutomationDataInRange(presCursorStart, presCursorEnd)
  
  local nextPres = currPresNumber + 1
  if nextPres > #presetsBounds then nextPres = 1 end
  copyAllAutomationInRangeToPos(selectedTrack, presetsBounds[nextPres][2], presetsBounds[nextPres][3], presCursorStart)
  
 
  --p( presetsBounds[nextPres][2])
  --p( presetsBounds[nextPres][3])
  local itemUnderCursor = reaper.GetTrackMediaItem(selectedTrack, itemNumber)
  local itemPreset = reaper.GetTrackMediaItem(selectedTrack, itemsBeforePresets + nextPres -1 )
  
    reaper.GetSetMediaItemInfo_String(itemUnderCursor,"P_NOTES", presetsBounds[nextPres][1], true)

  local nextColor = reaper.GetMediaItemInfo_Value(itemPreset, "I_CUSTOMCOLOR")
  reaper.SetMediaItemInfo_Value(itemUnderCursor, "I_CUSTOMCOLOR", nextColor)
  
  
  --p(presetsBounds[nextPres][1])

end

--p(reaper.GetCursorPosition())
script()

--unselectAllItems()
--script()
--copyAutomationItemAtCursorPos(reaper.GetSelectedEnvelope(0),0 )

--local env = reaper.GetSelectedEnvelope(0)
--for i=0, reaper.CountAutomationItems(env)-1 do
--  p(reaper.CountEnvelopePointsEx(env, i))
--end

--getPresetsTimeSelection()
--reaper.GetTrackMediaItem()
