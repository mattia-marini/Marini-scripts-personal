--[[
REAPER Export Validator

Message box:
  - Shows only pass/fail status for each test.
  - YES = View More -> prints full details to console.
  - NO  = Dismiss

The script does not modify the project.

--]]

-- Configuration

local SONG_FOLDER_NAME  = "Song"
local OTHER_FOLDER_NAME = "Other"
local MIDI_TRACK_NAME   = "Midi"
local REGION_NAME       = "Bonds"

-- Allow a small timing discrepancy when comparing the MIDI
-- item length against the Bonds region length.
local MIDI_LENGTH_TOLERANCE = 0.020

local REQUIRED_SONG_TRACKS = {
    "Lead voice",
    "Bass",
    "Drums",
    "Guitar",
    "Base",
    "Unused"
}

local FOLDER_SENDS = {
    ["Lead voice"] = { 1, 2 },
    ["Drums"]      = { 3, 4 },
    ["Bass"]       = { 5, 6 },
    ["Guitar"]     = { 7, 8 },
    ["Base"]       = { 9, 10 },
    ["Unused"]     = { 11, 12 },
}

-- Utility functions

local function getTrackName(track)
    local _, name = reaper.GetSetMediaTrackInfo_String(
        track,
        "P_NAME",
        "",
        false
    )

    return name or ""
end

local function normalizedName(name)
    return string.lower(name or "")
end

local function isFolder(track)
    return reaper.GetMediaTrackInfo_Value(
        track,
        "I_FOLDERDEPTH"
    ) > 0
end

local function getTrackIndex(track)
    return math.floor(
        reaper.GetMediaTrackInfo_Value(
            track,
            "IP_TRACKNUMBER"
        )
    ) - 1
end

local function formatTrackName(track)
    local name = getTrackName(track)

    if name == "" then
        return "<unnamed>"
    end

    return '"' .. name .. '"'
end

-- Find folders

local function findFoldersByName(name)
    local result = {}
    local wanted = normalizedName(name)

    local trackCount = reaper.CountTracks(0)

    for i = 0, trackCount - 1 do
        local track = reaper.GetTrack(0, i)

        if isFolder(track)
            and normalizedName(getTrackName(track)) == wanted
        then
            result[#result + 1] = track
        end
    end

    return result
end

-- Get direct children of a folder

local function getDirectChildren(folder)
    local children = {}

    local folderIndex = getTrackIndex(folder)
    local depth = 1

    local trackCount = reaper.CountTracks(0)

    for i = folderIndex + 1, trackCount - 1 do
        if depth <= 0 then
            break
        end

        local track = reaper.GetTrack(0, i)

        local trackDepth =
            reaper.GetMediaTrackInfo_Value(
                track,
                "I_FOLDERDEPTH"
            )

        if depth == 1 then
            children[#children + 1] = track
        end

        depth = depth + trackDepth
    end

    return children
end

-- Explicit send utilities

-- These are ONLY used for:
--
--     folder -> Song track
--
-- They are NOT used for child -> parent routing.

local function findSend(track, destination)
    local sendCount =
        reaper.GetTrackNumSends(track, 0)

    for sendIndex = 0, sendCount - 1 do
        local dest =
            reaper.GetTrackSendInfo_Value(
                track,
                0,
                sendIndex,
                "P_DESTTRACK"
            )

        if dest == destination then
            return sendIndex
        end
    end

    return nil
end

-- Check 1: Song folder

local function checkSongFolder(details)
    local songs =
        findFoldersByName(SONG_FOLDER_NAME)

    if #songs == 0 then
        details[#details + 1] =
            '[FAIL] "Song" folder does not exist.'

        return false, nil, nil
    end

    local passed = true

    if #songs > 1 then
        passed = false

        details[#details + 1] =
            string.format(
                '[FAIL] Multiple "Song" folders found (%d).',
                #songs
            )
    end

    local song = songs[1]
    local children = getDirectChildren(song)

    if #children ~= 6 then
        passed = false

        details[#details + 1] =
            string.format(
                '[FAIL] "Song" must contain exactly 6 direct child tracks; found %d.',
                #children
            )
    end

    local childrenByName = {}

    for _, child in ipairs(children) do
        local name = getTrackName(child)
        local normalized = normalizedName(name)

        if childrenByName[normalized] then
            passed = false

            details[#details + 1] =
                string.format(
                    '[FAIL] Duplicate "Song" child track "%s".',
                    name
                )
        end

        childrenByName[normalized] = child
    end

    for _, requiredName in ipairs(REQUIRED_SONG_TRACKS) do
        local child =
            childrenByName[normalizedName(requiredName)]

        if not child then
            passed = false

            details[#details + 1] =
                string.format(
                    '[FAIL] "Song" is missing child track "%s".',
                    requiredName
                )
        end
    end

    local expected = {}

    for _, name in ipairs(REQUIRED_SONG_TRACKS) do
        expected[normalizedName(name)] = true
    end

    for _, child in ipairs(children) do
        local name = getTrackName(child)

        if not expected[normalizedName(name)] then
            passed = false

            details[#details + 1] =
                string.format(
                    '[FAIL] Unexpected child track "%s" inside "Song".',
                    name
                )
        end
    end

    return passed, song, childrenByName
end

-- Check 2: Other folder

local function checkOtherFolder(details)
    local others =
        findFoldersByName(OTHER_FOLDER_NAME)

    if #others == 0 then
        details[#details + 1] =
            '[FAIL] "Other" folder does not exist.'

        return false, nil
    end

    local passed = true

    if #others > 1 then
        passed = false

        details[#details + 1] =
            string.format(
                '[FAIL] Multiple "Other" folders found (%d).',
                #others
            )
    end

    return passed, others[1]
end

-- Find Midi track

local function findMidiTrack(other, details)
    if not other then
        return nil
    end

    local children =
        getDirectChildren(other)

    local found = nil

    for _, child in ipairs(children) do
        if normalizedName(getTrackName(child))
            == normalizedName(MIDI_TRACK_NAME)
        then
            if found then
                details[#details + 1] =
                    '[FAIL] Multiple "Midi" tracks found directly inside "Other".'
            end

            found = child
        end
    end

    if not found then
        details[#details + 1] =
            '[FAIL] No "Midi" track found directly inside "Other".'
    end

    return found
end

-- Find region

local function findRegionByName(name)
    local markerCount =
        reaper.CountProjectMarkers(0)

    for i = 0, markerCount - 1 do
        local retval,
              isRegion,
              startPos,
              endPos,
              regionName,
              regionIndex =
            reaper.EnumProjectMarkers(i)

        if retval > 0
            and isRegion
            and normalizedName(regionName)
                == normalizedName(name)
        then
            return {
                start_pos = startPos,
                end_pos = endPos,
                name = regionName,
                index = regionIndex
            }
        end
    end

    return nil
end

-- Check 3: Midi / Bonds

local function checkMidiAndBonds(details, midiTrack)
    local passed = true

    local bondsRegion =
        findRegionByName(REGION_NAME)

    if not bondsRegion then
        passed = false

        details[#details + 1] =
            '[FAIL] No region named "Bonds" exists.'

        return passed, nil
    end

    if bondsRegion.end_pos <= bondsRegion.start_pos then
        passed = false

        details[#details + 1] =
            '[FAIL] "Bonds" region has invalid length.'
    end

    if not midiTrack then
        passed = false
        return passed, bondsRegion
    end

    local itemCount =
        reaper.CountTrackMediaItems(midiTrack)

    if itemCount == 0 then
        passed = false

        details[#details + 1] =
            '[FAIL] "Midi" contains no media items.'

        return passed, bondsRegion
    end

    local requiredLength =
        bondsRegion.end_pos - bondsRegion.start_pos

    local foundLongEnough = false
    local foundStartNote = false
    local foundEndNote = false

    for i = 0, itemCount - 1 do
        local item =
            reaper.GetTrackMediaItem(
                midiTrack,
                i
            )

        local itemStart =
            reaper.GetMediaItemInfo_Value(
                item,
                "D_POSITION"
            )

        local itemLength =
            reaper.GetMediaItemInfo_Value(
                item,
                "D_LENGTH"
            )

        local itemEnd =
            itemStart + itemLength

        ----------------------------------------------------
        -- Item length check
        ----------------------------------------------------

        if itemLength + MIDI_LENGTH_TOLERANCE
            >= requiredLength
        then
            foundLongEnough = true
        end

        if itemStart <= bondsRegion.start_pos
                + MIDI_LENGTH_TOLERANCE
            and itemEnd >= bondsRegion.end_pos
                - MIDI_LENGTH_TOLERANCE
        then
            foundLongEnough = true
        end

        ----------------------------------------------------
        -- MIDI note boundary checks
        ----------------------------------------------------

        local take =
            reaper.GetActiveTake(item)

        if take
            and reaper.TakeIsMIDI(take)
        then
            local _, noteCount =
                reaper.MIDI_CountEvts(
                    take
                )

            for noteIndex = 0, noteCount - 1 do
                local retval,
                      selected,
                      muted,
                      startPPQ,
                      endPPQ,
                      channel,
                      pitch,
                      velocity =
                    reaper.MIDI_GetNote(
                        take,
                        noteIndex
                    )

                if retval then
                    local noteStart =
                        reaper.MIDI_GetProjTimeFromPPQPos(
                            take,
                            startPPQ
                        )

                    local noteEnd =
                        reaper.MIDI_GetProjTimeFromPPQPos(
                            take,
                            endPPQ
                        )

                    ------------------------------------------------
                    -- A note must start at the beginning of the item.
                    ------------------------------------------------

                    if math.abs(
                        noteStart - itemStart
                    ) <= MIDI_LENGTH_TOLERANCE
                    then
                        foundStartNote = true
                    end

                    ------------------------------------------------
                    -- A note must end at the end of the item.
                    ------------------------------------------------

                    if math.abs(
                        noteEnd - itemEnd
                    ) <= MIDI_LENGTH_TOLERANCE
                    then
                        foundEndNote = true
                    end
                end

                if foundStartNote
                    and foundEndNote
                then
                    break
                end
            end
        end
    end

    --------------------------------------------------------
    -- Report MIDI item length failure
    --------------------------------------------------------

    if not foundLongEnough then
        passed = false

        details[#details + 1] =
            string.format(
                '[FAIL] "Midi" has no MIDI item at least as long as the "Bonds" region (%.3f seconds, tolerance %.3f seconds).',
                requiredLength,
                MIDI_LENGTH_TOLERANCE
            )
    end

    --------------------------------------------------------
    -- Report missing note at item start
    --------------------------------------------------------

    if not foundStartNote then
        passed = false

        details[#details + 1] =
            string.format(
                '[FAIL] "Midi" has no MIDI note starting at the beginning of a MIDI item within the tolerance of %.3f seconds.',
                MIDI_LENGTH_TOLERANCE
            )
    end

    --------------------------------------------------------
    -- Report missing note at item end
    --------------------------------------------------------

    if not foundEndNote then
        passed = false

        details[#details + 1] =
            string.format(
                '[FAIL] "Midi" has no MIDI note ending at the end of a MIDI item within the tolerance of %.3f seconds.',
                MIDI_LENGTH_TOLERANCE
            )
    end

    return passed, bondsRegion
end

-- Get parent folder

local function getParentFolder(track)
    if reaper.GetParentTrack then
        return reaper.GetParentTrack(track)
    end

    local trackIndex =
        getTrackIndex(track)

    local depth = 0

    for i = trackIndex - 1, 0, -1 do
        local candidate =
            reaper.GetTrack(0, i)

        local candidateDepth =
            reaper.GetMediaTrackInfo_Value(
                candidate,
                "I_FOLDERDEPTH"
            )

        depth = depth - candidateDepth

        if isFolder(candidate) then
            depth = depth + 1

            if depth == 1 then
                return candidate
            end
        end
    end

    return nil
end

local function isExcludedFolder(
    folder,
    song,
    other
)
    return folder == song
        or folder == other
end

-- Get top-level folders

local function getTopLevelFolders(
    song,
    other
)
    local result = {}

    local trackCount =
        reaper.CountTracks(0)

    for i = 0, trackCount - 1 do
        local track =
            reaper.GetTrack(0, i)

        if isFolder(track)
            and not isExcludedFolder(
                track,
                song,
                other
            )
        then
            local parent =
                getParentFolder(track)

            if not parent then
                result[#result + 1] = track
            end
        end
    end

    return result
end

-- Check 4a: Top-level folder channel count
--
-- Song and Other are excluded.
-- Nested folders are NOT checked.

local function checkFolderChannels(
    details,
    song,
    other
)
    local passed = true

    local topLevelFolders =
        getTopLevelFolders(
            song,
            other
        )

    for _, folder in ipairs(topLevelFolders) do
        local channels =
            math.floor(
                reaper.GetMediaTrackInfo_Value(
                    folder,
                    "I_NCHAN"
                )
            )

        if channels ~= 12 then
            passed = false

            details[#details + 1] =
                string.format(
                    '[FAIL] Folder %s has %d channels; expected 12.',
                    formatTrackName(folder),
                    channels
                )
        end
    end

    return passed
end

-- Parent-send utilities

local function getParentSendInfo(track)
    local enabled =
        reaper.GetMediaTrackInfo_Value(
            track,
            "B_MAINSEND"
        )

    if enabled <= 0 then
        return false, nil
    end

    local _, chunk =
        reaper.GetTrackStateChunk(
            track,
            "",
            false
        )

    if not chunk then
        return true, 0
    end

    local offset =
        chunk:match(
            "MAINSEND%s+1%s+(%-?%d+)"
        )

    offset = tonumber(offset) or 0

    return true, offset
end

-- Format parent-send channels

local function formatParentChannels(offset)
    local firstChannel = offset + 1
    local secondChannel = offset + 2

    return string.format(
        "%d,%d",
        firstChannel,
        secondChannel
    )
end

-- Check 4b: Child -> parent routing

-- Song and Other are intentionally excluded.

local function checkFolderChildrenParentSend(
    details,
    song,
    other
)
    local passed = true

    local trackCount =
        reaper.CountTracks(0)

    for i = 0, trackCount - 1 do
        local folder =
            reaper.GetTrack(0, i)

        if isFolder(folder)
            and folder ~= song
            and folder ~= other
        then
            local children =
                getDirectChildren(folder)

            for _, child in ipairs(children) do
                local enabled =
                    getParentSendInfo(child)

                if not enabled then
                    passed = false

                    details[#details + 1] =
                        string.format(
                            '[FAIL] Child %s has its natural parent send disabled; expected routing to %s.',
                            formatTrackName(child),
                            formatTrackName(folder)
                        )
                end
            end
        end
    end

    return passed
end

-- Build folder routing tree

local function buildFolderRoutingTree(
    folder,
    lines,
    prefix
)
    lines[#lines + 1] =
        prefix .. getTrackName(folder)

    local children =
        getDirectChildren(folder)

    for _, child in ipairs(children) do
        local enabled, offset =
            getParentSendInfo(child)

        local channelText

        if enabled then
            channelText =
                formatParentChannels(offset)
        else
            channelText =
                "OFF"
        end

        local displayName =
            getTrackName(child)

        if displayName == "" then
            displayName = "<unnamed>"
        end

        local channelField =
            string.format(
                "[%-5s]",
                channelText
            )

        lines[#lines + 1] =
            prefix
            .. "|- "
            .. channelField
            .. " "
            .. displayName

        if isFolder(child) then
            buildFolderRoutingTree(
                child,
                lines,
                prefix .. "    "
            )
        end
    end
end

-- Add routing trees to full report

-- Song and Other are excluded.

local function addFolderRoutingTrees(
    details,
    song,
    other
)
    details[#details + 1] = ""
    details[#details + 1] = "FOLDER PARENT ROUTING"
    details[#details + 1] = "---------------------"

    local trackCount =
        reaper.CountTracks(0)

    local foundFolder = false

    for i = 0, trackCount - 1 do
        local folder =
            reaper.GetTrack(0, i)

        if isFolder(folder)
            and folder ~= song
            and folder ~= other
        then
            foundFolder = true

            local tree = {}

            buildFolderRoutingTree(
                folder,
                tree,
                ""
            )

            for _, line in ipairs(tree) do
                details[#details + 1] = line
            end

            details[#details + 1] = ""
        end
    end

    if not foundFolder then
        details[#details + 1] =
            "No eligible folders found."
    end
end

-- Check 4c: Top-level folder -> Song sends
--
-- Song and Other are excluded.
-- Nested folders are NOT checked.

local function checkFolderSongSends(
    details,
    song,
    other,
    songTracks
)
    if not song or not songTracks then
        return false
    end

    local passed = true

    local topLevelFolders =
        getTopLevelFolders(
            song,
            other
        )

    for _, folder in ipairs(topLevelFolders) do
        for destinationName, channels
            in pairs(FOLDER_SENDS)
        do
            local destination =
                songTracks[
                    normalizedName(destinationName)
                ]

            if destination then
                local sendIndex =
                    findSend(
                        folder,
                        destination
                    )

                if not sendIndex then
                    passed = false

                    details[#details + 1] =
                        string.format(
                            '[FAIL] Folder %s has no send to Song track "%s".',
                            formatTrackName(folder),
                            destinationName
                        )
                else
                    local sourceChannel =
                        reaper.GetTrackSendInfo_Value(
                            folder,
                            0,
                            sendIndex,
                            "I_SRCCHAN"
                        )

                    local expectedSource =
                        channels[1] - 1

                    if sourceChannel ~= expectedSource then
                        passed = false

                        details[#details + 1] =
                            string.format(
                                '[FAIL] Send from %s to "%s" starts at channel %d; expected channels %d-%d.',
                                formatTrackName(folder),
                                destinationName,
                                sourceChannel + 1,
                                channels[1],
                                channels[2]
                            )
                    end

                    local destinationChannel =
                        reaper.GetTrackSendInfo_Value(
                            folder,
                            0,
                            sendIndex,
                            "I_DSTCHAN"
                        )

                    if destinationChannel ~= 0 then
                        passed = false

                        details[#details + 1] =
                            string.format(
                                '[FAIL] Send from %s to "%s" is routed to destination channels %d+; expected 1-2.',
                                formatTrackName(folder),
                                destinationName,
                                destinationChannel + 1
                            )
                    end
                end
            end
        end
    end

    return passed
end

-- Check 4: Complete folder routing

local function checkFolderRouting(
    details,
    song,
    other,
    songTracks
)
    local channelsPassed =
        checkFolderChannels(
            details,
            song,
            other
        )

    local childrenPassed =
        checkFolderChildrenParentSend(
            details,
            song,
            other
        )

    local songSendsPassed =
        checkFolderSongSends(
            details,
            song,
            other,
            songTracks
        )

    return
        channelsPassed
        and childrenPassed
        and songSendsPassed
end

-- Check 5: Bonds region

local function checkBondsRegion(details)
    local region =
        findRegionByName(REGION_NAME)

    if not region then
        details[#details + 1] =
            '[FAIL] No region named "Bonds" exists.'

        return false
    end

    if region.end_pos <= region.start_pos then
        details[#details + 1] =
            '[FAIL] "Bonds" region has invalid length.'

        return false
    end

    return true
end

-- Get project markers only
--
-- Regions are ignored.

local function getProjectMarkers()
    local markers = {}

    local markerCount =
        reaper.CountProjectMarkers(0)

    for i = 0, markerCount - 1 do
        local retval,
              isRegion,
              position,
              endPosition,
              name,
              index =
            reaper.EnumProjectMarkers(i)

        if retval > 0 and not isRegion then
            markers[#markers + 1] = {
                position = position,
                name = name or "",
                index = index
            }
        end
    end

    table.sort(
        markers,
        function(a, b)
            return a.position < b.position
        end
    )

    return markers
end

-- Check 6: Top-level folder names vs markers

local function checkTopLevelFolderNames(
    details,
    song,
    other
)
    local folders =
        getTopLevelFolders(
            song,
            other
        )

    local markers =
        getProjectMarkers()

    local passed = true
    local folderCount = #folders
    local markerCount = #markers

    if markerCount < folderCount then
        passed = false

        details[#details + 1] =
            string.format(
                '[FAIL] There are %d top-level folders but only %d project markers.',
                folderCount,
                markerCount
            )
    end

    local count =
        math.min(
            folderCount,
            markerCount
        )

    for i = 1, count do
        local folderName =
            getTrackName(folders[i])

        local markerName =
            markers[i].name

        if normalizedName(folderName)
            ~= normalizedName(markerName)
        then
            passed = false

            details[#details + 1] =
                string.format(
                    '[FAIL] Top-level folder %d is "%s", but marker %d is "%s".',
                    i,
                    folderName,
                    i,
                    markerName
                )
        end
    end

    return passed
end

-- Main

local function main()
    local details = {}

    --------------------------------------------------------
    -- Run tests
    --------------------------------------------------------

    local songPassed,
          song,
          songTracks =
        checkSongFolder(details)

    local otherPassed,
          other =
        checkOtherFolder(details)

    local midiTrack =
        findMidiTrack(
            other,
            details
        )

    local midiPassed =
        checkMidiAndBonds(
            details,
            midiTrack
        )

    local routingPassed =
        checkFolderRouting(
            details,
            song,
            other,
            songTracks
        )

    local bondsPassed =
        checkBondsRegion(details)

    local folderNamesPassed =
        checkTopLevelFolderNames(
            details,
            song,
            other
        )

    --------------------------------------------------------
    -- Build routing tree for detailed console report.
    --------------------------------------------------------

    addFolderRoutingTrees(
        details,
        song,
        other
    )

    --------------------------------------------------------
    -- Build summary
    --------------------------------------------------------

    local tests = {
        {
            name = "Song folder structure",
            passed = songPassed
        },
        {
            name = "Other folder",
            passed = otherPassed
        },
        {
            name = "Midi / Bonds",
            passed = midiPassed
        },
        {
            name = "Folder routing",
            passed = routingPassed
        },
        {
            name = "Bonds region",
            passed = bondsPassed
        },
        {
            name = "Folder / marker names",
            passed = folderNamesPassed
        }
    }

    local allPassed = true

    local summary = {
        "REAPER EXPORT CHECK",
        "===================",
        ""
    }

    for _, test in ipairs(tests) do
        if test.passed then
            summary[#summary + 1] =
                "✓ " .. test.name .. ": PASS"
        else
            summary[#summary + 1] =
                "✗ " .. test.name .. ": FAIL"

            allPassed = false
        end
    end

    --------------------------------------------------------
    -- Full console report
    --------------------------------------------------------

    local consoleReport = {
        "",
        "========== EXPORT CHECK ==========",
        ""
    }

    for _, line in ipairs(summary) do
        consoleReport[#consoleReport + 1] = line
    end

    consoleReport[#consoleReport + 1] = ""

    if #details == 0 then
        consoleReport[#consoleReport + 1] =
            "No errors found."
    else
        consoleReport[#consoleReport + 1] =
            "DETAILS"

        consoleReport[#consoleReport + 1] =
            "-------"

        for _, detail in ipairs(details) do
            consoleReport[#consoleReport + 1] =
                detail
        end
    end

    consoleReport[#consoleReport + 1] = ""

    consoleReport[#consoleReport + 1] =
        "=================================="

    local fullReport =
        table.concat(
            consoleReport,
            "\n"
        )

    --------------------------------------------------------
    -- Message box
    --
    -- 3 = Yes / No / Cancel
    -- Yes = View More
    -- No  = Dismiss
    --------------------------------------------------------

    local message =
        table.concat(
            summary,
            "\n"
        )

    if allPassed then
        message =
            message
            .. "\n\n"
            .. "All checks passed."
            .. "\n\n"
            .. "Want to see the details?"
    else
        message =
            message
            .. "\n\n"
            .. "Some checks failed."
            .. "\n\n"
            .. "Want to see the details?"
    end

    local result =
        reaper.ShowMessageBox(
            message,
            "REAPER Export Check",
            3
        )

    if result == 6 then
        reaper.ShowConsoleMsg(
            fullReport .. "\n"
        )
    end
end

main()
