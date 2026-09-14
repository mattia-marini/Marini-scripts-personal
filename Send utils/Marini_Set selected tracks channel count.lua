local retval, input = reaper.GetUserInputs(
    "Set Track Channel Count",
    1,
    "Number of channels:",
    ""
)

if not retval then
    return
end

local channels = tonumber(input)

if not channels or channels < 2 or channels > 128 or channels % 2 ~= 0 then
    reaper.ShowMessageBox(
        "Please enter an even number between 2 and 128.",
        "Invalid channel count",
        0
    )
    return
end

local count = reaper.CountSelectedTracks(0)

if count == 0 then
    reaper.ShowMessageBox(
        "No tracks selected.",
        "Set Track Channel Count",
        0
    )
    return
end

reaper.Undo_BeginBlock()

for i = 0, count - 1 do
    local track = reaper.GetSelectedTrack(0, i)
    reaper.SetMediaTrackInfo_Value(track, "I_NCHAN", channels)
end

reaper.Undo_EndBlock(
    "Set channel count for selected tracks",
    -1
)

reaper.UpdateArrange()
