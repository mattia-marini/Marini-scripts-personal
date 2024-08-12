local function setCommandState(state)
  local is_new_value,filename,sectionID,cmdID,mode,resolution,val,contextstr = reaper.get_action_context()

  reaper.SetToggleCommandState(sectionID,cmdID, state)
  reaper.RefreshToolbar2(sectionID, cmdID)
end

local function stringToHex(s)
  local hexStr = ""
  for i = 1, #s do
    local byte = string.byte(s, i)
    hexStr = hexStr .. string.format("%02X ", byte)
  end
  return hexStr:sub(1, -2) -- Remove the trailing space
end


local function findSparkFun()
  for i=0, reaper.GetNumMIDIOutputs()  do
    local rv, name = reaper.GetMIDIOutputName(i,"")
    --reaper.ShowConsoleMsg("Device: " ..i .. " ".. name .. "\n")

    if rv and name ~= "" and name and string.upper(name):match("SPARKFUN") then
        return i, name
    end
    i = i+1
  end

  reaper.ShowConsoleMsg("Non trovo sparkfun")
  return nil
end



local signatureBytes = {0x11, 0x12}
local function createSysex(str)

  local sysExT = {0xF0, table.unpack(signatureBytes)} -- SysEx start byte
  for i = 1, #str do
    table.insert(sysExT, string.byte(str, i))
  end
  table.insert(sysExT, 0xF7) -- SysEx end byte

  local msg = ""
  for i=1, #sysExT do msg = msg .. string.char(sysExT[i]) end
  
  return msg
end


local id, name = findSparkFun()

--[[
sysex = { 0xF0, 0x00, 0xF7 }
msg = ""
for i=1, #sysex do msg = msg .. string.char(sysex[i]) end

reaper.ShowConsoleMsg(stringToHex(createSysex("prova di un messaggio sysex")))
--]]



local function getCurrRegionNane()
  local markerIndex, rgnIndex = reaper.GetLastMarkerAndCurRegion(0, reaper.GetCursorPosition())
  if rgnIndex ~= -1 then
    local _,_,_,_, name  = reaper.EnumProjectMarkers(rgnIndex)
    return name == "" and "Region " .. tostring(rgnIndex + 1) or name
  end
  return "No region"
  
end


--local msg = getCurrRegionNane()

--reaper.ShowConsoleMsg(stringToHex(createSysex(msg)))
--reaper.SendMIDIMessageToHardware(id, createSysex(msg))
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


local lastPos = nil
local lastName = nil

local function loop()

    
    lastPos =  reaper.GetCursorPosition()
    local currName = "No preset"
  
    for i, val in ipairs( getNameItems()) do
      if (lastPos >= val["start"] and lastPos <= val["end"]) then
        --reaper.ShowConsoleMsg(val.name)
        currName = val.name
      end
    end
    
    if currName ~= lastName then
      reaper.SendMIDIMessageToHardware(id, createSysex(currName))
      lastName = currName
    end
    --[[
    if  getCurrRegionNane() ~= lastName then
      lastRegion = getCurrRegionNane()
      reaper.SendMIDIMessageToHardware(id, createSysex(getCurrRegionNane()))
      --reaper.ShowConsoleMsg("Invio\n")
    end
    --]]
  reaper.defer(loop)
end


setCommandState(1)
reaper.atexit(function() 
setCommandState(0)
reaper.SendMIDIMessageToHardware(id, createSysex("Not synchronized"))
end)

loop()
