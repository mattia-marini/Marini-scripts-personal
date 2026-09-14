
--[[
    Set All Receives Channel Mapping

    Input formats:

        MONO:
            number-number
            Example: 1-3

        STEREO:
            number/number-number/number
            Example: 1/2-3/4

    The first part specifies the source channels.
    The second part specifies the destination channels.

    The mapping is applied to every receive on the selected track.
]]

local track = reaper.GetSelectedTrack(0, 0)

if not track then
    reaper.ShowMessageBox(
        "No track selected.",
        "Set Receive Channels",
        0
    )
    return
end


------------------------------------------------------------
-- INPUT
------------------------------------------------------------

local retval, input = reaper.GetUserInputs(
    "Set Receive Channels",
    1,
    "Channel mapping:",
    ""
)

if not retval then
    return
end

input = input:gsub("%s+", "")


------------------------------------------------------------
-- PARSE
------------------------------------------------------------

-- Mono: 1-3
local src_mono, dst_mono =
    input:match("^(%d+)%-(%d+)$")

-- Stereo: 1/2-3/4
local src1, src2, dst1, dst2 =
    input:match("^(%d+)/(%d+)%-(%d+)/(%d+)$")


------------------------------------------------------------
-- VALIDATE
------------------------------------------------------------

local is_mono = src_mono ~= nil
local is_stereo = src1 ~= nil

if not is_mono and not is_stereo then

    reaper.ShowMessageBox(
        "Invalid format.\n\n" ..
        "Mono:\n" ..
        "1-3\n\n" ..
        "Stereo:\n" ..
        "1/2-3/4",
        "Set Receive Channels",
        0
    )

    return
end


------------------------------------------------------------
-- CONVERT TO REAPER'S CHANNEL ENCODING
------------------------------------------------------------

local src_chan
local dst_chan

if is_mono then

    src_mono = tonumber(src_mono)
    dst_mono = tonumber(dst_mono)

    if src_mono < 1 or dst_mono < 1 then
        reaper.ShowMessageBox(
            "Channel numbers must be >= 1.",
            "Set Receive Channels",
            0
        )
        return
    end

    --------------------------------------------------------
    -- I_SRCCHAN:
    --
    -- low 10 bits = channel offset
    -- bit 10 = mono
    --
    -- mono channel 1 = 1024
    -- mono channel 2 = 1025
    -- mono channel 3 = 1026
    --------------------------------------------------------

    src_chan = 1024 + (src_mono - 1)

    --------------------------------------------------------
    -- I_DSTCHAN:
    --
    -- low 10 bits = destination channel
    -- bit 10 = mix to mono
    --
    -- mono channel 1 = 1024
    -- mono channel 2 = 1025
    -- mono channel 3 = 1026
    --------------------------------------------------------

    dst_chan = 1024 + (dst_mono - 1)

else

    src1 = tonumber(src1)
    src2 = tonumber(src2)
    dst1 = tonumber(dst1)
    dst2 = tonumber(dst2)

    --------------------------------------------------------
    -- Stereo channels must be consecutive
    --------------------------------------------------------

    if src2 ~= src1 + 1 or dst2 ~= dst1 + 1 then

        reaper.ShowMessageBox(
            "Stereo channels must be consecutive.\n\n" ..
            "Examples:\n" ..
            "1/2-3/4\n" ..
            "3/4-1/2",
            "Set Receive Channels",
            0
        )

        return
    end

    if src1 < 1 or dst1 < 1 then

        reaper.ShowMessageBox(
            "Channel numbers must be >= 1.",
            "Set Receive Channels",
            0
        )

        return
    end

    --------------------------------------------------------
    -- I_SRCCHAN:
    --
    -- Stereo is represented by the channel offset.
    --
    -- 1/2 -> 0
    -- 3/4 -> 2
    -- 5/6 -> 4
    --------------------------------------------------------

    src_chan = src1 - 1

    --------------------------------------------------------
    -- I_DSTCHAN:
    --
    -- Stereo is ALSO represented by the channel offset,
    -- but WITHOUT the 1024 mono flag.
    --
    -- 1/2 -> 0
    -- 3/4 -> 2
    -- 5/6 -> 4
    --------------------------------------------------------

    dst_chan = dst1 - 1

end


------------------------------------------------------------
-- GET RECEIVES
------------------------------------------------------------

local receive_count = reaper.GetTrackNumSends(track, -1)

if receive_count == 0 then

    reaper.ShowMessageBox(
        "The selected track has no receives.",
        "Set Receive Channels",
        0
    )

    return
end


------------------------------------------------------------
-- APPLY
------------------------------------------------------------

reaper.Undo_BeginBlock()

for i = 0, receive_count - 1 do

    reaper.SetTrackSendInfo_Value(
        track,
        -1,
        i,
        "I_SRCCHAN",
        src_chan
    )

    reaper.SetTrackSendInfo_Value(
        track,
        -1,
        i,
        "I_DSTCHAN",
        dst_chan
    )

end

reaper.Undo_EndBlock(
    "Set all receives channel mapping",
    -1
)

reaper.UpdateArrange()


------------------------------------------------------------
-- CONFIRMATION
------------------------------------------------------------

local mapping

if is_mono then

    mapping = string.format(
        "%d-%d",
        src_mono,
        dst_mono
    )

else

    mapping = string.format(
        "%d/%d-%d/%d",
        src1,
        src2,
        dst1,
        dst2
    )

end

reaper.ShowMessageBox(
    string.format(
        "Set %d receive(s) to %s.",
        receive_count,
        mapping
    ),
    "Set Receive Channels",
    0
)

