local function getSelectedTracks()
  local tracks = {}
  for i = 0, reaper.CountSelectedTracks(0) - 1 do
    table.insert(tracks, reaper.GetSelectedTrack(0, i))
  end
  return tracks
end




local trackTree = { none ={}}

local function initTrackTree()
  for i = 0, reaper.CountTracks(0) - 1 do
    trackTree[reaper.GetTrack(0, i)] = {}
  end

  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local parentTrack = reaper.GetParentTrack(track)
    if parentTrack then
      table.insert(trackTree[parentTrack], track)
    else
      table.insert(trackTree["none"], track)
    end
  end
end 


initTrackTree()

local function printTrackTree()
for k, v in pairs(trackTree) do 
  local trackName
  if k == "none" then 
    trackName = "none"
  else
   local _, rv =  reaper.GetTrackName(k)
   trackName = rv
  end
  
  reaper.ShowConsoleMsg(tostring(#v).. " ")
  reaper.ShowConsoleMsg(trackName.. "\n")
end
end



local function getTrackChildrens(track)
  return trackTree[track] or {}
end



--[[


local selectedTracks = getSelectedTracks()

if #selectedTracks == 0 then
  reaper.ShowMessageBox("Please select only 1 track", "Error", 0)
  return
end

local selectedTrack = selectedTracks[1]

local sendsCount = reaper.GetTrackNumSends(selectedTrack, -1) -- Number of normal recieves
 
for sendIndex=0, sendsCount -1 do
  local destTrack = reaper.GetTrackSendInfo_Value(selectedTrack, -1, sendIndex, "P_SRCTRACK")


  
  local _, trackName = reaper.GetTrackName(destTrack)
  reaper.ShowConsoleMsg(trackName.. "\n")
  
  local childrenTracks = getTrackChildrend(destTrack)
  
  
  for _,  t in ipairs(childrenTracks) do
    reaper.ShowConsoleMsg("\t" .. select(2,reaper.GetTrackName(t)) .."\n")
  end
end

--]]



-- Returns (bool sendsAudio, int srcChannelOffset, int srcChannelCount)
local function decodeSrcChannel(channel)
    if channel==-1 then  return false, -1, -1 end -- It does not send audio
    
    local srcChannelOffset = (channel & 0X3FF)  -- Low 10 bits
    local srcChannelCount = (channel >> 10)    -- High bits bits 
    
    local srcChannelCountDecoded
    if srcChannelCount == 0 then 
      srcChannelCountDecoded = 2
    elseif srcChannelCount == 1 then
      srcChannelCountDecoded = 1
    else
      srcChannelCountDecoded = srcChannelCount * 2
    end
    
    return true, srcChannelOffset, srcChannelCountDecoded
end

-- Returns (bool destMixesToMono, int destChannelOffset)
local function decodeDstChannel(channel)
    local destMixesToMono = (channel & 1024) ~= 0    -- Mixes all sending channels into mono
    local destChannelNumber = (channel & (~1024))
    return destMixesToMono, destChannelNumber
end

local function set(t)
  local rv = {}

  for _, x in ipairs(t) do
    rv[tostring(x)] = true
  end

  rv.contains = function(element)
    return rv[tostring(element)] == true
  end

  rv.insert = function(element)
    rv[tostring(element)] = true
  end

  rv.print = function()
    reaper.ShowConsoleMsg("[ ")
    for x, _ in pairs(rv) do
      if type(rv[x]) ~= "function" then
        reaper.ShowConsoleMsg(x .. " ")
      end
    end
    reaper.ShowConsoleMsg("]\n")
  end

  rv.count = function()
    local n = 0
    for k, v in pairs(rv) do
      if type(v) ~= "function" then
        n = n + 1
      end
    end
    return n
  end

  return rv
end


local function printSenderTracksOnChannel(t)
  for track, set in pairs(t) do
    reaper.ShowConsoleMsg(select(2, reaper.GetTrackName(track)) .. ":\t")
    set.print()
  end
end


-- Ritorna ogni traccia che manda audio sul canale specificato di track
-- Se channels == -1 ritorna ogni traccia che manda audio su un qualsiasi canale di track
local function getSenderTracksOnChannel(track, channels)

  local tracks = {} -- Contiene un dizionario {track: {set of sending channels} }
  
  -- Handling normal recieves
  local recieveCount = reaper.GetTrackNumSends(track, -1) -- Number of normal recieves
  for recieveIndex=0, recieveCount -1 do
  
    
    local dst = reaper.GetTrackSendInfo_Value(track, -1, recieveIndex, "I_DSTCHAN")
    local dstMixesToMono, dstChannelOffset = decodeDstChannel(dst)
    
    local src = reaper.GetTrackSendInfo_Value(track, -1, recieveIndex, "I_SRCCHAN")
    local sendsAudio, srcChannelOffset, srcChannelCount = decodeSrcChannel(src)
    
    
    local sendingTrack = reaper.GetTrackSendInfo_Value(track, -1, recieveIndex, "P_SRCTRACK")
    
    local sendingChannels = tracks[sendingTrack] or set({})

    -- Contiene tutti i canali della sending track che mandano audio 
    -- su uno dei canali di interesse della traccia ricevente
    
    --reaper.ShowConsoleMsg(tostring(dstMixesToMono).. " ")
    --reaper.ShowConsoleMsg(dstChannelOffset.. "\n")
        
    --reaper.ShowConsoleMsg(tostring(sendsAudio).. " ")
    --reaper.ShowConsoleMsg(srcChannelOffset.. " ")
    --reaper.ShowConsoleMsg(srcChannelCount.. "\n")
    
    if destMixesToMono then -- Mixa a mono
      if channels.contains(destChannelOffset) then 
        for i=0, srcChannelCount -1 do
          sendingChannels.insert(srcChannelOffset + i)
        end
      end
    else
      for i=0, srcChannelCount -1 do
        if channels.contains(dstChannelOffset + i) then
          sendingChannels.insert(srcChannelOffset + i)
        end
      end
    end
    
    tracks[sendingTrack] = sendingChannels
    -- reaper.ShowConsoleMsg("\nSSSSSSSSSS: "..#sendingChannels .. "\n")
    -- sendingChannels.print()
    -- I_DSTCHAN : int * : low 10 bits are destination index
  
  end
  
  -- B_MAINSEND : bool * : track sends audio to parent
  -- C_MAINSEND_OFFS : char * : channel offset of track send to parent
  -- C_MAINSEND_NCH
  -- Handling folder recieves
  --for _, x in ipairs(getTrackChildrens(track))do
  --  reaper.ShowConsoleMsg(tostring(x))
  --end
  
  for i, child in ipairs(getTrackChildrens(track)) do
    local sendsAudioToParent = reaper.GetMediaTrackInfo_Value(child, "B_MAINSEND")
    local childDstChannelOffset = math.floor(reaper.GetMediaTrackInfo_Value(child, "C_MAINSEND_OFFS"))
    local childChannelSentCount = math.floor(reaper.GetMediaTrackInfo_Value(child, "C_MAINSEND_NCH"))
    
    if sendsAudioToParent > 0.5 then
      
      local sendingChannels = tracks[child] or set({})
      
      local decodedChildChannelSentCount
      if childChannelSentCount == 0 then      -- send all channels
        decodedChildChannelSentCount = math.floor(reaper.GetMediaTrackInfo_Value(child, "I_NCHAN")) 
      elseif childChannelSentCount == 1 then  -- send channel 1 only
        decodedChildChannelSentCount = 1
      else
        decodedChildChannelSentCount = childChannelCount
      end
      --reaper.ShowConsoleMsg(childDstChannelOffset.."\n")
      for i=0, decodedChildChannelSentCount -1 do
        if channels.contains(childDstChannelOffset + i) then
          sendingChannels.insert(i) -- Child sends start always from 1 (0)
          --reaper.ShowConsoleMsg(select(2, reaper.GetTrackName(child)).." \n")
        end
      end
      
      tracks[child] = sendingChannels
    end
  end
  
  return tracks
end


local senderTracks = getSenderTracksOnChannel(getSelectedTracks()[1], set({0,1,2,3,4,5,6,7,8}) )
--printSenderTracksOnChannel(senderTracks)




