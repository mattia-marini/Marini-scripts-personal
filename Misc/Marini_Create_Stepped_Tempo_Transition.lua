--[[
    Discrete Tempo Ramp
    --------------------

    Converts a linear/smooth tempo change between two tempo markers
    into a series of discrete (instantaneous) tempo changes.

    Usage:
        1. Create a time selection containing exactly two tempo markers.
        2. Run this script.
        3. Enter the number of INTERMEDIATE steps.

    Example:
        120 BPM -> 140 BPM
        4 intermediate steps

        Result:
        120 -> 124 -> 128 -> 132 -> 136 -> 140

    The intermediate markers are evenly distributed in time.
    All tempo changes are instantaneous (lineartempo = false).
--]]

local proj = 0

------------------------------------------------------------
-- Get time selection
------------------------------------------------------------

local sel_start, sel_end = reaper.GetSet_LoopTimeRange2(
    proj,
    false, -- isSet
    false, -- isLoop
    0,
    0,
    false
)

if sel_end <= sel_start then
    reaper.ShowMessageBox(
        "Please create a time selection containing exactly two tempo markers.",
        "Discrete Tempo Ramp",
        0
    )
    return
end

------------------------------------------------------------
-- Find tempo markers inside the time selection
------------------------------------------------------------

local markers = {}
local marker_count = reaper.CountTempoTimeSigMarkers(proj)

-- Small tolerance for floating-point positions
local EPSILON = 0.000001

for i = 0, marker_count - 1 do

    local retval,
          timepos,
          measurepos,
          beatpos,
          bpm,
          timesig_num,
          timesig_denom,
          lineartempo =
        reaper.GetTempoTimeSigMarker(proj, i)

    if retval then

        if timepos >= sel_start - EPSILON
           and timepos <= sel_end + EPSILON then

            table.insert(markers, {
                index = i,
                time = timepos,
                measurepos = measurepos,
                beatpos = beatpos,
                bpm = bpm,
                timesig_num = timesig_num,
                timesig_denom = timesig_denom,
                lineartempo = lineartempo
            })

        end
    end
end

------------------------------------------------------------
-- Validate marker count
------------------------------------------------------------

if #markers ~= 2 then

    reaper.ShowMessageBox(
        string.format(
            "The time selection must contain exactly two tempo markers.\n\nFound: %d",
            #markers
        ),
        "Discrete Tempo Ramp",
        0
    )

    return
end

------------------------------------------------------------
-- Make sure markers are ordered chronologically
------------------------------------------------------------

table.sort(markers, function(a, b)
    return a.time < b.time
end)

local start_marker = markers[1]
local end_marker   = markers[2]

local start_time = start_marker.time
local end_time   = end_marker.time

local start_bpm = start_marker.bpm
local end_bpm   = end_marker.bpm

------------------------------------------------------------
-- Ask user for number of steps
------------------------------------------------------------

local default_steps = "8"

local retval, input = reaper.GetUserInputs(
    "Discrete Tempo Ramp",
    1,
    "Number of intermediate steps:",
    default_steps
)

if not retval then
    return
end

local steps = tonumber(input)

if not steps
   or steps < 1
   or steps ~= math.floor(steps) then

    reaper.ShowMessageBox(
        "Please enter a positive integer number of steps.",
        "Discrete Tempo Ramp",
        0
    )

    return
end

-- Prevent accidentally creating an enormous number of markers.
if steps > 10000 then
    reaper.ShowMessageBox(
        "The maximum number of steps is 10000.",
        "Discrete Tempo Ramp",
        0
    )
    return
end

------------------------------------------------------------
-- Begin undo block
------------------------------------------------------------

reaper.Undo_BeginBlock()

------------------------------------------------------------
-- Disable the smooth ramp on the first marker
--
-- The original first marker may have lineartempo=true,
-- which tells REAPER to gradually transition to the next
-- tempo marker.
--
-- We explicitly change it to false.
------------------------------------------------------------

reaper.SetTempoTimeSigMarker(
    proj,
    start_marker.index,
    start_marker.time,
    -1,
    -1,
    start_marker.bpm,
    start_marker.timesig_num,
    start_marker.timesig_denom,
    false
)

------------------------------------------------------------
-- Insert intermediate tempo markers
--
-- i / (steps + 1) gives positions:
--
-- steps = 1:
--     1/2
--
-- steps = 2:
--     1/3, 2/3
--
-- steps = 4:
--     1/5, 2/5, 3/5, 4/5
--
-- BPM is interpolated linearly between the endpoints.
------------------------------------------------------------

local time_range = end_time - start_time
local bpm_range = end_bpm - start_bpm

for i = 1, steps do

    local fraction = i / (steps + 1)

    local timepos =
        start_time + time_range * fraction

    local bpm =
        start_bpm + bpm_range * fraction

    reaper.SetTempoTimeSigMarker(
        proj,
        -1,                 -- insert new marker
        timepos,
        -1,                 -- calculate measure position
        -1,                 -- calculate beat position
        bpm,
        0,                  -- use previous time signature
        0,
        false               -- NO gradual transition
    )
end

------------------------------------------------------------
-- Explicitly make sure the final marker is NOT a ramp
--
-- Its index may have changed because of inserted markers,
-- so find it again using its original time position.
------------------------------------------------------------

local new_marker_count = reaper.CountTempoTimeSigMarkers(proj)

for i = 0, new_marker_count - 1 do

    local retval,
          timepos,
          measurepos,
          beatpos,
          bpm,
          timesig_num,
          timesig_denom,
          lineartempo =
        reaper.GetTempoTimeSigMarker(proj, i)

    if retval
       and math.abs(timepos - end_time) < EPSILON then

        reaper.SetTempoTimeSigMarker( 
            proj, 
            i,
            timepos,
            -1,
            -1,
            bpm,
            timesig_num,
            timesig_denom,
            false
        )

        break
    end
end

------------------------------------------------------------
-- Finish
------------------------------------------------------------
 
reaper.Undo_EndBlock(
    "Create discrete tempo ramp",
    -1
)

reaper.UpdateArrange()
reaper.UpdateTimeline()
