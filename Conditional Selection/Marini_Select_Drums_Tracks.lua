local project = reaper.EnumProjects(-1)

for i = 0, reaper.CountTracks() -1 do
  local track = reaper.GetTrack(project, i)
  reaper.SetTrackSelected(track, false)
end


for i = 0, reaper.CountTracks() -1 do
  local track = reaper.GetTrack(project, i)
  local _,trackName = reaper.GetTrackName(track)
  
  if trackName:match(".*(Drum).*") ~= nil then 
    reaper.SetTrackSelected(track, true)
  end
end