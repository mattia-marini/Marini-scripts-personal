local track = reaper.GetSelectedTrack(0, 0)

if not track then
    reaper.ShowMessageBox(
        "No track selected.",
        "Unlink FX",
        0
    )
    return
end


------------------------------------------------------------
-- Unlink one FX
------------------------------------------------------------

local unlinked_count = 0

local function unlink_fx(fx_id)
    local num_params =
        reaper.TrackFX_GetNumParams(
            track,
            fx_id
        )

    for param = 0, num_params - 1 do
        local prefix =
            "param." .. param .. ".plink."

        local ok, active =
            reaper.TrackFX_GetNamedConfigParm(
                track,
                fx_id,
                prefix .. "active"
            )

        if ok and tonumber(active) ~= 0 then
            reaper.TrackFX_SetNamedConfigParm(
                track,
                fx_id,
                prefix .. "active",
                "0"
            )

            unlinked_count = unlinked_count + 1
        end
    end
end


------------------------------------------------------------
-- Traverse FX hierarchy
------------------------------------------------------------

local function walk_fx(fx_id)
    local ok, container_count =
        reaper.TrackFX_GetNamedConfigParm(
            track,
            fx_id,
            "container_count"
        )

    if ok then
        container_count = tonumber(container_count) or 0

        for i = 0, container_count - 1 do
            local child_ok, child_fx_id =
                reaper.TrackFX_GetNamedConfigParm(
                    track,
                    fx_id,
                    "container_item." .. i
                )

            if child_ok then
                walk_fx(tonumber(child_fx_id))
            end
        end

        return
    end

    -- Leaf FX.
    unlink_fx(fx_id)
end


------------------------------------------------------------
-- Enumerate top-level FX
------------------------------------------------------------

reaper.Undo_BeginBlock()

local fx_count = reaper.TrackFX_GetCount(track)

for fx_id = 0, fx_count - 1 do
    walk_fx(fx_id)
end

reaper.Undo_EndBlock(
    "Unlink all FX parameters",
    -1
)


------------------------------------------------------------
-- Summary
------------------------------------------------------------

reaper.ShowMessageBox(
    "Removed " .. unlinked_count .. " parameter links.",
    "Unlink FX",
    0
)
