local ok, newLocation = reaper.GetUserInputs("Relocate audio files",1,"extrawidth=300 Inserisci URL dei file audio", "")
if not ok then return end

function commonCharsAtEnd(str1, str2)
    local len1 = #str1
    local len2 = #str2
    local count = 0

    -- Start comparing characters from the end of the strings
    while len1 > 0 and len2 > 0 and str1:sub(len1, len1) == str2:sub(len2, len2) do
        count = count + 1
        len1 = len1 - 1
        len2 = len2 - 1
    end

    return count
end

--[[
for i = 0, reaper.CountMediaItems(0)-1 do
  local item = reaper.GetMediaItemTake(reaper.GetMediaItem(0,i),0)
  reaper.ShowConsoleMsg(reaper.GetMediaSourceFileName(reaper.GetMediaItemTake_Source(item)).."\n")
end
]]--

--reaper.ShowConsoleMsg(commonCharsAtEnd("abaaba","aaaab"))



local function concat(v1, v2)
  for _, v in ipairs(v2) do
      table.insert(v1, v)
  end
end

local function printArray(v)
  for _, v in ipairs(v) do
      reaper.ShowConsoleMsg(v.."\n")
  end
end


local function getFilesRec(dir)

  local files = {}

  local file = reaper.EnumerateFiles(dir, 0)
  local fileIndex = 1
  
  
  
  while file do
    table.insert(files, dir.."/"..file)
    file = reaper.EnumerateFiles(dir, fileIndex)
    fileIndex = fileIndex + 1
  end
  
  
  local subDir = reaper.EnumerateSubdirectories(dir, 0)
  local subDirIndex = 1
  
  while subDir do
    concat(files, getFilesRec(dir.."/"..subDir))
    
    subDir = reaper.EnumerateSubdirectories(dir, subDirIndex)
    subDirIndex = subDirIndex + 1
  end
  
  return files
end

function fileName(path)
    local filename = path:match("^.+/(.+)$") -- Match everything after the last '/'
    if not filename then
        filename = path -- If no '/' found, the path is the filename
    end
    return filename
end


local files = getFilesRec(newLocation)
local fileNameHash = {}
--printArray(files)

for _, path in ipairs(files)do
  if not fileNameHash[fileName(path)] then 
    fileNameHash[fileName(path)]={}
  end
  
  table.insert(fileNameHash[fileName(path)], path)
end

local audioClips =  reaper.CountSelectedMediaItems(0)
local notFound = {}

for i = 0, reaper.CountSelectedMediaItems(0)-1 do

  local item = reaper.GetMediaItemTake(reaper.GetSelectedMediaItem(0,i),0)
  local sourcePath = reaper.GetMediaSourceFileName(reaper.GetMediaItemTake_Source(item))
  
  if sourcePath ~= "" then 
    local longestMatchingPath = ""
    local maxLen = 0
    --[[
    reaper.ShowConsoleMsg("----------------------------------\n")
    printArray(fileNameHash[fileName(sourcePath)])
    reaper.ShowConsoleMsg("----------------------------------\n")
    --]]
    
    local candidates = fileNameHash[fileName(sourcePath)]
    if candidates then
      for _, val in ipairs(candidates) do 
  
        local commonChars = commonCharsAtEnd(val, sourcePath)
        if commonChars > maxLen then
          longestMatchingPath = val
          maxLen = commonChars
        end
      end
      --reaper.ShowConsoleMsg(longestMatchingPath .. ".\n")
      reaper.SetMediaItemTake_Source(item,reaper.PCM_Source_CreateFromFile(longestMatchingPath))
    else
      table.insert(notFound, sourcePath)
    end
  else
    audioClips=audioClips-1
  end
 
end


reaper.ShowMessageBox("Effettuato ".. audioClips - #notFound .. "/" .. audioClips .. " sostituzioni", "Relocation complete", 0)

if #notFound ~= 0 then 
  reaper.ShowConsoleMsg("Item non trovati: \n")
  for _, val in ipairs(notFound)do reaper.ShowConsoleMsg(val.."\n")end
end
