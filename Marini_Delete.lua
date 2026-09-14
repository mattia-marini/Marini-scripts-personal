--[[
    Test MIDI Lyrics

    Inserts MIDI Lyric events (type 5) into all selected MIDI items,
    then queries them back and prints the results.

    MIDI lyric type = 5
]]

local function msg(text)
    reaper.ShowConsoleMsg(text .. "\n")
end

local selected_items = {}

-- Collect selected MIDI items
local item_count = reaper.CountSelectedMediaItems(0)

for i = 0, item_count - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local take = reaper.GetActiveTake(item)

    if take and reaper.TakeIsMIDI(take) then
        table.insert(selected_items, {
            item = item,
            take = take
        })
    end
end

if #selected_items == 0 then
    reaper.ShowMessageBox(
        "No selected MIDI items.",
        "Test MIDI Lyrics",
        0
    )
    return
end


reaper.ClearConsole()

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

------------------------------------------------------------
-- INSERT TEST LYRICS
------------------------------------------------------------

local test_lyrics = {
    { 0,    "Hello" },
    { 240,  "world" },
    { 480,  "this" },
    { 720,  "is" },
    { 960,  "a" },
    { 1200, "test" },
}

for _, data in ipairs(selected_items) do

    local take = data.take

    -- Remove existing lyric events so the test is clean.
    local _, _, _, text_count = reaper.MIDI_CountEvts(take)

    for i = text_count - 1, 0, -1 do
        local retval, _, _, _, event_type =
            reaper.MIDI_GetTextSysexEvt(take, i)

        if retval and event_type == 5 then
            reaper.MIDI_DeleteTextSysexEvt(take, i)
        end
    end

    -- Insert test lyrics.
    for _, lyric in ipairs(test_lyrics) do
        local ppqpos = lyric[1]
        local text = lyric[2]

        reaper.MIDI_InsertTextSysexEvt(
            take,
            false, -- selected
            false, -- muted
            ppqpos,
            5,     -- MIDI Lyric
            text
        )
    end

    reaper.MIDI_Sort(take)
    --reaper.MIDI_RefreshEditors(take)
end

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Insert test MIDI lyrics", -1)


------------------------------------------------------------
-- QUERY THE LYRIC EVENTS
------------------------------------------------------------

msg("========================================")
msg("       MIDI LYRIC QUERY TEST")
msg("========================================")
msg("")

for item_index, data in ipairs(selected_items) do

    local take = data.take

    local _, _, _, text_count =
        reaper.MIDI_CountEvts(take)

    msg("ITEM " .. item_index)
    msg("----------------------------------------")

    local found = 0

    for i = 0, text_count - 1 do

        local retval
        local selected
        local muted
        local ppqpos
        local event_type
        local text

        retval,
        selected,
        muted,
        ppqpos,
        event_type,
        text =
            reaper.MIDI_GetTextSysexEvt(
                take,
                i
            )

        if retval and event_type == 5 then

            found = found + 1

            local project_time =
                reaper.MIDI_GetProjTimeFromPPQPos(
                    take,
                    ppqpos
                )

            msg(string.format(
                "#%d  PPQ: %.3f  Time: %.3f  Text: %q",
                found,
                ppqpos,
                project_time,
                text
            ))
        end
    end

    msg("Found " .. found .. " lyric events.")
    msg("")
end

msg("========================================")
msg("Done.")
msg("========================================")


------------------------------------------------------------
-- MESSAGE BOX
------------------------------------------------------------

reaper.ShowMessageBox(
    "Inserted and successfully queried test MIDI lyric events.\n\n" ..
    "Open the REAPER console to see the complete results.",
    "Test MIDI Lyrics",
    0
)
