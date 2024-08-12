local commandID = ({reaper.get_action_context()})[4]
local toggle = reaper.GetToggleCommandState(commandID) == 1

reaper.SetToggleCommandState(0,commandID, 1)
reaper.RefreshToolbar(commandID)

function init()
gfx.ext_retina = 1
gfx.init("Big Cock")
gfx.x = 0
gfx.y = 0
local scale = gfx.ext_retina
end


local topSize = 1/2
local middleSize = 0
local bottomSize = 1/2

function getNextMarker(time)
    

    local _, numMarkers, numRegions = reaper.CountProjectMarkers(0)

    local nextMarker = nil
    for i = 0, (numMarkers + numRegions -1) do
  
        local _, isRegion, markerPos, _, markerName, markerIndex = reaper.EnumProjectMarkers3(0, i)
        --reaper.ConsoleMsg(i)
        --reaper.ShowConsoleMsg(regionName == "" and "No name\n" or regionName .."\n")
        --reaper.ShowConsoleMsg(regionStart.." "..regionEnd.." "..regionName.. "\n")

        if not isRegion and time <= markerPos then
             nextMarker = markerName == "" and tostring("Marker "..rgnid) or markerName
             return nextMarker, markerPos 
        end
        
    end

    
    return "No next marker", nil
end

function getCursorPosition()

  if (reaper.GetPlayState() & 1) == 1 then 
    return reaper.GetPlayPosition()
  else
    return reaper.GetCursorPosition()
  end
  
end

function computeFontSize(text, width, height)
    gfx.setfont(1, "Calibri", height)
    
    local font_size = height
    
    repeat
        gfx.setfont(1, "Calibri", font_size)
        font_size = font_size - 10
        local text_width = gfx.measurestr(text)
    until text_width <= width or font_size == 1
    
end


function drawBottom(currPos, nextDivPos)

  reaper.ClearConsole()
  if not nextDivPos then return end
  
  local _, currPosMeasures, _, currPosBeats =  reaper.TimeMap2_timeToBeats(0,currPos)
  local _, nextDivPosMeasures, _, nextDivPosBeats =  reaper.TimeMap2_timeToBeats(0,nextDivPos)
  local leftMeasures = nextDivPosMeasures - currPosMeasures
  
  gfx.set(1,1,1,1)
  gfx.x = 20
  gfx.y = (topSize + middleSize) * gfx.h
  
  local mesIndicatorWidth =  gfx.w * 2/7
  computeFontSize(next_region, mesIndicatorWidth, gfx.h* bottomSize)
  gfx.drawstr("Misure: "..leftMeasures, 4, 20 + mesIndicatorWidth , gfx.h)
  
  local numberSpace = (gfx.w - 40 - mesIndicatorWidth) / 6
  
  local countdownNumbers = {"3","2","3","2","1","0"}
  local countdownPoint = 0
  if leftMeasures <=2 then
    local beatsDiff = nextDivPosBeats - currPosBeats 
    if beatsDiff <= 8 and beatsDiff >6 then 
      countdownPoint = 1
    elseif  beatsDiff <= 6 and beatsDiff >4 then 
        countdownPoint = 2
    elseif  beatsDiff <= 4 and beatsDiff >3 then 
        countdownPoint = 3
    elseif  beatsDiff <= 3 and beatsDiff >2 then 
        countdownPoint = 4
    elseif  beatsDiff <= 2 and beatsDiff >1 then 
        countdownPoint = 5
    elseif  beatsDiff <= 1 and beatsDiff >0 then 
        countdownPoint = 6
    end
  end 
  
  gfx.set(0,1,0,1)
  for i=0, countdownPoint -1 do 
    local x =  mesIndicatorWidth + numberSpace * i
    gfx.x = x
    gfx.y = (topSize + middleSize) * gfx.h
    computeFontSize(countdownNumbers[i+1], numberSpace, gfx.h * bottomSize)
    gfx.drawstr(countdownNumbers[i+1], 5, x + numberSpace , gfx.h)
  end
  
  gfx.set(1,1,1,1)
  for i=countdownPoint, 5 do 
    local x =  mesIndicatorWidth + numberSpace * i
    gfx.x = x
    gfx.y = (topSize + middleSize) * gfx.h
    computeFontSize(countdownNumbers[i+1], numberSpace, gfx.h * bottomSize)
    gfx.drawstr(countdownNumbers[i+1], 5, x + numberSpace , gfx.h)
  end

end


function drawTop(curr_region)
  gfx.set(0,0,1,1)
  
  gfx.x = 0
  gfx.y = 0
  
  
  computeFontSize(curr_region, gfx.w, gfx.h * topSize)
  gfx.drawstr(curr_region,5, gfx.w, gfx.h * topSize)
end

function drawMiddle(next_region)
  gfx.set(1,1,1,1)
  
  gfx.x = 0
  gfx.y = topSize * gfx.h
  computeFontSize(next_region, gfx.w, gfx.h* topSize)
  gfx.drawstr(next_region,5, gfx.w, (topSize + middleSize)*gfx.h)
end

gfx.clear = 0x171717

function main()

local cursorPos = getCursorPosition()
local currMarker, currMarkerPos = getNextMarker(cursorPos)

drawTop(currMarker)


drawBottom(cursorPos, currMarkerPos)

gfx.update()
  if gfx.getchar() == -1 then 
    quit()
    return
  end
reaper.defer(main)
end

function quit()
  gfx.quit()
  reaper.SetToggleCommandState(0,commandID, 0)
  reaper.RefreshToolbar(commandID)
end

reaper.atexit(quit)
init()
main()
