--[[
    MIDI Text Lyrics Web Interface
    ===============================

    Reads MIDI text events from the track named "Lyrics" and exposes
    them to a REAPER Web Interface through ExtState.

    The MIDI data is deliberately NOT stored as a persistent/cached
    text state. The MIDI text events are read from the MIDI take every
    UPDATE_INTERVAL seconds.

    Current position:
        - playing / recording / paused -> REAPER play position
        - stopped                      -> edit cursor

    The current event is the last event whose position is <= current
    position.

    Supported MIDI text event types:
        1-14

    Type 15 (notation events) is ignored.

    ExtState section:
        XR_MIDI_TEXT

    ExtState key:
        data

    Example:

        {
            "current": 3,
            "events": [
                {
                    "pos": 10.123,
                    "text": "Hello"
                },
                {
                    "pos": 12.456,
                    "text": "world"
                }
            ]
        }
]]

------------------------------------------------------------
-- Configuration
------------------------------------------------------------

local TRACK_NAME = "Lyrics"

local EXT_SECTION = "XR_MIDI_TEXT"
local EXT_KEY = "data"

-- 200 ms.
local UPDATE_INTERVAL = 0.200

local MIN_TEXT_TYPE = 1
local MAX_TEXT_TYPE = 14


------------------------------------------------------------
-- JSON helpers
------------------------------------------------------------

local function escape_json_string(str)
    str = tostring(str or "")

    str = str:gsub("\\", "\\\\")
    str = str:gsub('"', '\\"')
    str = str:gsub("\b", "\\b")
    str = str:gsub("\f", "\\f")
    str = str:gsub("\n", "\\n")
    str = str:gsub("\r", "\\r")
    str = str:gsub("\t", "\\t")

    -- Escape remaining control characters.
    str = str:gsub("[%z\1-\31]", function(c)
        return string.format(
            "\\u%04x",
            string.byte(c)
        )
    end)

    return str
end


local function json_string(str)
    return '"' .. escape_json_string(str) .. '"'
end


local function json_number(number)
    return string.format("%.12f", number)
end


------------------------------------------------------------
-- Find Lyrics track
------------------------------------------------------------

local function get_lyrics_track()
    local track_count = reaper.CountTracks(0)

    for i = 0, track_count - 1 do
        local track = reaper.GetTrack(0, i)

        local retval, name =
            reaper.GetSetMediaTrackInfo_String(
                track,
                "P_NAME",
                "",
                false
            )

        if retval and name == TRACK_NAME then
            return track
        end
    end

    return nil
end


------------------------------------------------------------
-- Read MIDI text events
------------------------------------------------------------

local function collect_text_events(track)
    local events = {}

    if not track then
        return events
    end

    local item_count =
        reaper.CountTrackMediaItems(track)

    for item_index = 0, item_count - 1 do

        local item =
            reaper.GetTrackMediaItem(
                track,
                item_index
            )

        local take =
            reaper.GetActiveTake(item)

        if take and reaper.TakeIsMIDI(take) then

            ------------------------------------------------
            -- IMPORTANT:
            --
            -- MIDI_CountEvts returns:
            --
            -- retval
            -- note_count
            -- cc_count
            -- textsysex_count
            ------------------------------------------------

            local _, _, _, text_count =
                reaper.MIDI_CountEvts(take)

            for event_index = 0, text_count - 1 do

                local ok,
                    selected,
                    muted,
                    ppqpos,
                    event_type,
                    msg =
                    reaper.MIDI_GetTextSysexEvt(
                        take,
                        event_index
                    )

                if ok then

                    if
                        event_type >= MIN_TEXT_TYPE
                        and
                        event_type <= MAX_TEXT_TYPE
                    then

                        local position =
                            reaper.MIDI_GetProjTimeFromPPQPos(
                                take,
                                ppqpos
                            )

                        events[#events + 1] = {
                            pos = position,
                            text = msg or "",
                            type = event_type,
                            muted = muted and true or false,
                            source_order = #events + 1
                        }
                    end
                end
            end
        end
    end


    --------------------------------------------------------
    -- Sort by project position.
    --
    -- source_order provides deterministic ordering when
    -- multiple text events occur at exactly the same time.
    --------------------------------------------------------

    table.sort(events, function(a, b)

        if a.pos ~= b.pos then
            return a.pos < b.pos
        end

        return a.source_order < b.source_order
    end)


    --------------------------------------------------------
    -- Remove internal field before publishing.
    --------------------------------------------------------

    for _, event in ipairs(events) do
        event.source_order = nil
    end

    return events
end


------------------------------------------------------------
-- Find current event
------------------------------------------------------------

local function find_current_index(events, position)

    local current_index = -1

    for i = 1, #events do

        if events[i].pos <= position then
            current_index = i
        else
            break
        end
    end

    return current_index
end


------------------------------------------------------------
-- Serialize complete state
------------------------------------------------------------

local function build_json(events, current_index)

    local parts = {}

    parts[#parts + 1] = "{"

    parts[#parts + 1] = '"current":'
    parts[#parts + 1] = tostring(current_index)

    parts[#parts + 1] = ","

    parts[#parts + 1] = '"events":['

    for i, event in ipairs(events) do

        if i > 1 then
            parts[#parts + 1] = ","
        end

        parts[#parts + 1] = "{"

        parts[#parts + 1] = '"pos":'
        parts[#parts + 1] =
            json_number(event.pos)

        parts[#parts + 1] = ","

        parts[#parts + 1] = '"text":'
        parts[#parts + 1] =
            json_string(event.text)

        parts[#parts + 1] = ","

        parts[#parts + 1] = '"type":'
        parts[#parts + 1] =
            tostring(event.type)

        parts[#parts + 1] = ","

        parts[#parts + 1] = '"muted":'
        parts[#parts + 1] =
            event.muted and "true" or "false"

        parts[#parts + 1] = "}"
    end

    parts[#parts + 1] = "]"

    parts[#parts + 1] = "}"

    return table.concat(parts)
end


------------------------------------------------------------
-- State
------------------------------------------------------------

local next_update_time = 0


------------------------------------------------------------
-- Main update
------------------------------------------------------------

local function update()

    local now = reaper.time_precise()

    --------------------------------------------------------
    -- Rate limit.
    --------------------------------------------------------

    if now < next_update_time then
        reaper.defer(update)
        return
    end

    next_update_time =
        now + UPDATE_INTERVAL


    --------------------------------------------------------
    -- Find track.
    --------------------------------------------------------

    local track =
        get_lyrics_track()


    --------------------------------------------------------
    -- Read MIDI text events.
    --
    -- This happens every UPDATE_INTERVAL.
    --
    -- Nothing from the previous MIDI scan is used as the
    -- source of truth.
    --------------------------------------------------------

    local events =
        collect_text_events(track)


    --------------------------------------------------------
    -- Determine current REAPER position.
    --------------------------------------------------------

    local play_state =
        reaper.GetPlayState()

    local position

    if play_state ~= 0 then
        position =
            reaper.GetPlayPosition()
    else
        position =
            reaper.GetCursorPosition()
    end


    --------------------------------------------------------
    -- Determine current event.
    --------------------------------------------------------

    local current_index =
        find_current_index(
            events,
            position
        )


    --------------------------------------------------------
    -- Publish everything as one atomic ExtState value.
    --------------------------------------------------------

    local json =
        build_json(
            events,
            current_index
        )

    reaper.SetExtState(
        EXT_SECTION,
        EXT_KEY,
        json,
        false
    )


    --------------------------------------------------------
    -- Continue.
    --------------------------------------------------------

    reaper.defer(update)
end


------------------------------------------------------------
-- Cleanup
------------------------------------------------------------

local function cleanup()

    reaper.SetExtState(
        EXT_SECTION,
        EXT_KEY,
        "",
        false
    )
end


reaper.atexit(cleanup)

update()
