
local header = [[


-- >>>> ReaLink
-- This code is generated by ReaLink. It should NOT be modified by the user
-- It starts the background synching task on startup automatically
-- If you don't want it, you can delete this block or run the "Marini_ReaLink_Autostart_Toggle" script
]]

local body = [[


function GetActionCommandIDByFilename(searchfilename)
  for k in io.lines(reaper.GetResourcePath() .. "/reaper-kb.ini") do
    if k:match("SCR") and k:match(searchfilename) then
      return "_" .. k:match("SCR %d+ %d+ (%S*) ")
    end
  end
  return nil
end

local commands = { GetActionCommandIDByFilename("Marini_ReaLink_Background.lua")
}

for _, command in ipairs(commands) do
  reaper.Main_OnCommand(reaper.NamedCommandLookup(command), -1)
end

]]

local trailer = [[
-- <<<< ReaLink]]

local startupFile = reaper.GetResourcePath().."/Scripts/__startup.lua"
local read = io.open(startupFile, "r")
local content = ""
if read then
  content = read:read("*all")
  read:close()
end

local pattern = "%-%- >>>> ReaLink.*%-%- <<<< ReaLink"

function removeTrailingNewlines(inputString)
    local cleanedString = inputString:gsub("[\r\n]+$", "")
    return cleanedString
end

local function addAutoStartup()
  local write = io.open(startupFile, "w")
  if not write then return end
  if content:match(pattern) then
    print("c'è già autostart")
    write:write(content)
    return
  end
  write:write(removeTrailingNewlines(content) .. header .. body .. trailer)
  write:close()
end

local function removeAutoStartup()
  local write = io.open(startupFile, "w")
  if not write then return end
  local newContent = content:gsub(pattern, "")
  write:write(removeTrailingNewlines(newContent))
  write:close()
end

local commandID = ({reaper.get_action_context()})[4]
local toggle = reaper.GetToggleCommandState(commandID) == 1

if toggle then removeAutoStartup() 
else addAutoStartup() end

reaper.SetToggleCommandState(0,commandID, toggle and 0 or 1)
reaper.RefreshToolbar(commandID)


