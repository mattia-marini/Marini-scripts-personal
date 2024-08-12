local project = reaper.EnumProjects(-1)

for i = 0, reaper.CountTracks() -1 do
  local track = reaper.GetTrack(project, i)
  reaper.SetTrackSelected(track, false)
end


for i = 0, reaper.CountTracks() -1 do
  local track = reaper.GetTrack(project, i)
  local _,trackName = reaper.GetTrackName(track)
  
  if trackName:match(".*(Bass_Fede).*") ~= nil then 
    reaper.SetTrackSelected(track, true)
  end
end

local unsolo_all_tracks = 40340
local solo_selected_tracks = 40728
local unselect_all = 40297

reaper.Main_OnCommand(unsolo_all_tracks, 0)
reaper.Main_OnCommand(solo_selected_tracks, 0)
reaper.Main_OnCommand(unselect_all, 0)
