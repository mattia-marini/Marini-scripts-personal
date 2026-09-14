-- REAPER Lua Script: Merge MIDI Lyrics per Measure
--
-- For every selected MIDI item:
--
--   1. Find all MIDI LYRIC events (type 5)
--   2. Group them by measure
--   3. Keep the first lyric event in each measure
--   4. Append the text of every other lyric event to it
--   5. Delete the other lyric events
--
-- Example:
--
--   Measure 1:
--       "Primo evento "
--       "Secondo"
--       "Terzo"
--
--   becomes:
--
--       "Primo evento  Secondo Terzo"
--
--   with only one lyric event remaining.
--
-- The first event keeps its original PPQ position.

------------------------------------------------------------
-- Configuration
------------------------------------------------------------

local LYRIC_EVENT_TYPE = 5

-- Separator inserted between lyric payloads.
local SEPARATOR = " "


------------------------------------------------------------
-- Merge lyrics
------------------------------------------------------------

local function merge_lyrics_per_measure()

    ------------------------------------------------------------
    -- Collect selected MIDI takes
    ------------------------------------------------------------

    local selected_takes = {}

    local item_count = reaper.CountSelectedMediaItems(0)

    for i = 0, item_count - 1 do

        local item = reaper.GetSelectedMediaItem(0, i)
        local take = reaper.GetActiveTake(item)

        if take and reaper.TakeIsMIDI(take) then
            table.insert(selected_takes, take)
        end
    end


    ------------------------------------------------------------
    -- If nothing is selected, use active MIDI editor take
    ------------------------------------------------------------

    if #selected_takes == 0 then

        local editor = reaper.MIDIEditor_GetActive()

        if editor then

            local take = reaper.MIDIEditor_GetTake(editor)

            if take and reaper.TakeIsMIDI(take) then
                table.insert(selected_takes, take)
            end
        end
    end


    ------------------------------------------------------------
    -- Nothing to process
    ------------------------------------------------------------

    if #selected_takes == 0 then

        reaper.ShowMessageBox(
            "Please select a MIDI item.",
            "Merge MIDI Lyrics",
            0
        )

        return
    end


    ------------------------------------------------------------
    -- Undo / UI block
    ------------------------------------------------------------

    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)


    ------------------------------------------------------------
    -- Process every MIDI take
    ------------------------------------------------------------

    for _, take in ipairs(selected_takes) do

        reaper.MIDI_DisableSort(take)


        --------------------------------------------------------
        -- Get number of text/sysex events
        --------------------------------------------------------

        local _, _, _, text_count =
            reaper.MIDI_CountEvts(take)


        --------------------------------------------------------
        -- Collect lyric events
        --------------------------------------------------------

        local lyric_events = {}

        for i = 0, text_count - 1 do

            local retval,
                  selected,
                  muted,
                  ppqpos,
                  event_type,
                  msg =
                reaper.MIDI_GetTextSysexEvt(
                    take,
                    i
                )

            if retval and event_type == LYRIC_EVENT_TYPE then

                ------------------------------------------------
                -- Find the beginning of this event's measure.
                ------------------------------------------------

                local measure_start =
                    reaper.MIDI_GetPPQPos_StartOfMeasure(
                        take,
                        ppqpos
                    )

                table.insert(
                    lyric_events,
                    {
                        idx = i,
                        ppq = ppqpos,
                        measure = measure_start,
                        text = msg or "",
                        selected = selected,
                        muted = muted
                    }
                )
            end
        end


        --------------------------------------------------------
        -- Group lyrics by measure
        --------------------------------------------------------

        local measures = {}
        local measure_order = {}

        for _, event in ipairs(lyric_events) do

            local measure = event.measure

            if not measures[measure] then

                measures[measure] = {}

                table.insert(
                    measure_order,
                    measure
                )
            end

            table.insert(
                measures[measure],
                event
            )
        end


        --------------------------------------------------------
        -- Process every measure
        --------------------------------------------------------

        local events_to_delete = {}

        for _, measure in ipairs(measure_order) do

            local events = measures[measure]


            ----------------------------------------------------
            -- Make sure events are chronological
            ----------------------------------------------------

            table.sort(
                events,
                function(a, b)
                    return a.ppq < b.ppq
                end
            )


            ----------------------------------------------------
            -- Only do anything if there are multiple lyrics
            ----------------------------------------------------

            if #events > 1 then

                local first_event = events[1]

                local combined_text = first_event.text


                ------------------------------------------------
                -- Merge every subsequent lyric
                ------------------------------------------------

                for i = 2, #events do

                    local event = events[i]

                    combined_text =
                        combined_text
                        .. SEPARATOR
                        .. event.text

                    table.insert(
                        events_to_delete,
                        event.idx
                    )
                end


                ------------------------------------------------
                -- Update the first lyric event.
                --
                -- IMPORTANT:
                -- The message is ONLY the text.
                -- We do NOT prepend \5.
                --
                -- type = 5 tells REAPER this is a lyric.
                ------------------------------------------------

                reaper.MIDI_SetTextSysexEvt(
                    take,
                    first_event.idx,
                    first_event.selected,
                    first_event.muted,
                    first_event.ppq,
                    LYRIC_EVENT_TYPE,
                    combined_text,
                    true
                )
            end
        end


        --------------------------------------------------------
        -- Delete redundant lyric events.
        --
        -- Delete backwards so indices remain valid.
        --------------------------------------------------------

        table.sort(
            events_to_delete,
            function(a, b)
                return a > b
            end
        )

        for _, idx in ipairs(events_to_delete) do

            reaper.MIDI_DeleteTextSysexEvt(
                take,
                idx
            )
        end


        --------------------------------------------------------
        -- Re-sort MIDI
        --------------------------------------------------------

        reaper.MIDI_Sort(take)

    end


    ------------------------------------------------------------
    -- Finish
    ------------------------------------------------------------

    reaper.PreventUIRefresh(-1)

    reaper.UpdateArrange()

    reaper.Undo_EndBlock(
        "Merge MIDI Lyrics per Measure",
        -1
    )
end


------------------------------------------------------------
-- Run
------------------------------------------------------------

merge_lyrics_per_measure()

