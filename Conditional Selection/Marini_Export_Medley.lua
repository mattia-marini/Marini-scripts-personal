local project = reaper.EnumProjects(-1)

function GetActionCommandIDByFilename(searchfilename)
  for k in io.lines(reaper.GetResourcePath() .. "/reaper-kb.ini") do
    if k:match("SCR") and k:match(searchfilename) then
      return "_" .. k:match("SCR %d+ %d+ (%S*) ")
    end
  end
  return nil
end

local commands = {
 ["Drums"] = reaper.NamedCommandLookup(GetActionCommandIDByFilename("Marini_Select_Drums_Tracks.lua")),
 ["Bass"] = reaper.NamedCommandLookup(GetActionCommandIDByFilename("Marini_Select_Bass_Tracks.lua")),
 ["Guitar"] = reaper.NamedCommandLookup(GetActionCommandIDByFilename("Marini_Select_Guitar_Tracks.lua")),
 ["LeadVoice"] = reaper.NamedCommandLookup(GetActionCommandIDByFilename("Marini_Select_LeadVoice_Tracks.lua")),
 ["Base"] = reaper.NamedCommandLookup(GetActionCommandIDByFilename("Marini_Select_Base_Tracks.lua"))
}

local scripts = {
  render_project = 42230,
  unsolo_all_tracks = 40729,
  solo_selected_tracks = 40728
}



function getHomeDirectory()
    if reaper.GetOS():match("Win") then
        return os.getenv("USERPROFILE") or ""
    else
        return os.getenv("HOME") or ""
    end
end



reaper.GetSetProjectInfo(project, "RENDER_BOUNDSFLAG", 2, true)--time selection
--reaper.GetSetProjectInfo_String(project, "RENDER_FILE", getHomeDirectory() .. "/Desktop/"..reaper.GetProjectName(project):match("(.*)%.RPP").." Stems", true)--directory = desktop

--reaper.GetSetProjectInfo_String(project, "RENDER_FORMAT", "bDNwbYAAAAAAAAAAAgAAAP////8EAAAAgAAAAAAAAAA=", true)--setto mp3-128kb/s
--reaper.GetSetProjectInfo_String(project, "RENDER_FORMAT", "bDNwbcAAAAAAAAAAAgAAAP////8EAAAAwAAAAAAAAAA=", true)--setto mp3-192kb/s
--reaper.GetSetProjectInfo_String(project, "RENDER_FORMAT", "bDNwbUABAAAAAAAAAgAAAP////8EAAAAQAEAAAAAAAA=", true)--setto mp3-320kb/s


for tracks, command in pairs(commands) do

  reaper.GetSetProjectInfo_String(project, "RENDER_PATTERN", tracks, true)
  
  reaper.Main_OnCommand(scripts.unsolo_all_tracks, 0)
  
  reaper.Main_OnCommand(command, 0)
  if reaper.CountSelectedTracks(0) ~= 0 then 
    reaper.Main_OnCommand(scripts.solo_selected_tracks, 0)
    reaper.Main_OnCommand(scripts.render_project, 0)
  end

end
