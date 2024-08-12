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


local lastPos = nil
local lastRegion = nil

local function loop()
  if reaper.GetCursorPosition() ~= lastPos then
    lastPos =  reaper.GetCursorPosition()
    if  getCurrRegionNane() ~= lastRegion then
      lastRegion = getCurrRegionNane()
      reaper.SendMIDIMessageToHardware(id, createSysex(getCurrRegionNane()))
      --reaper.ShowConsoleMsg("Invio\n")
    end
  end
  reaper.defer(loop)
end


setCommandState(1)
reaper.atexit(function() setCommandState(0) end)

loop()
