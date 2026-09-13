local track = reaper.GetSelectedTrack(0, 0)

if not track then
    reaper.ShowMessageBox(
        "No track selected.",
        "Sync FX",
        0
    )
    return
end


------------------------------------------------------------
-- FX hierarchy / scopes
------------------------------------------------------------

local next_id = 1
local groups = {}

groups[1] = {}

local function walk_fx(fx_id, group_id)
    local ok, container_count =
        reaper.TrackFX_GetNamedConfigParm(
            track,
            fx_id,
            "container_count"
        )

    if ok then
        container_count = tonumber(container_count) or 0

        next_id = next_id + 1
        local subgroup_id = next_id

        groups[subgroup_id] = {}

        for i = 0, container_count - 1 do
            local child_ok, child_fx_id =
                reaper.TrackFX_GetNamedConfigParm(
                    track,
                    fx_id,
                    "container_item." .. i
                )

            if child_ok then
                walk_fx(
                    tonumber(child_fx_id),
                    subgroup_id
                )
            end
        end

        return
    end

    if not groups[group_id] then
        groups[group_id] = {}
    end

    table.insert(groups[group_id], fx_id)
end


------------------------------------------------------------
-- Enumerate top-level FX
------------------------------------------------------------

local ROOT_SCOPE = 1

local fx_count =
    reaper.TrackFX_GetCount(track)

for fx_id = 0, fx_count - 1 do
    walk_fx(fx_id, ROOT_SCOPE)
end


------------------------------------------------------------
-- Get the FX index used by plink.effect
------------------------------------------------------------

local function get_link_effect_index(fx_id)
    local ok, parent_id =
        reaper.TrackFX_GetNamedConfigParm(
            track,
            fx_id,
            "parent_container"
        )

    -- Top-level FX.
    if not ok or parent_id == "" then
        return fx_id
    end

    parent_id = tonumber(parent_id)

    local ok_count, container_count =
        reaper.TrackFX_GetNamedConfigParm(
            track,
            parent_id,
            "container_count"
        )

    if not ok_count then
        return nil
    end

    container_count = tonumber(container_count) or 0

    -- Find the FX's index inside its immediate parent.
    for i = 0, container_count - 1 do
        local ok_item, item_fx_id =
            reaper.TrackFX_GetNamedConfigParm(
                track,
                parent_id,
                "container_item." .. i
            )

        if ok_item and tonumber(item_fx_id) == fx_id then
            return i
        end
    end

    return nil
end


------------------------------------------------------------
-- Synchronize identical FX
------------------------------------------------------------

local linked_count = 0

local function sync_fx_ids(ids)
    local ids_by_type = {}

    for _, fx_id in ipairs(ids) do
        local _, fx_ident =
            reaper.TrackFX_GetNamedConfigParm(
                track,
                fx_id,
                "fx_ident"
            )

        if not ids_by_type[fx_ident] then
            ids_by_type[fx_ident] = {}
        end

        table.insert(
            ids_by_type[fx_ident],
            fx_id
        )
    end

    for _, same_type_ids in pairs(ids_by_type) do

        if #same_type_ids > 1 then
            local master = same_type_ids[1]

            local master_link_index =
                get_link_effect_index(master)

            if master_link_index ~= nil then

                local num_params =
                    reaper.TrackFX_GetNumParams(
                        track,
                        master
                    )

                for i = 2, #same_type_ids do
                    local slave = same_type_ids[i]

                    local slave_params =
                        reaper.TrackFX_GetNumParams(
                            track,
                            slave
                        )

                    -- Only link FX with matching parameter counts.
                    if slave_params == num_params then

                        for param = 0, num_params - 1 do

                            local prefix =
                                "param." ..
                                param ..
                                ".plink."

                            ------------------------------------------------
                            -- Configure the link
                            ------------------------------------------------

                            reaper.TrackFX_SetNamedConfigParm(
                                track,
                                slave,
                                prefix .. "effect",
                                tostring(master_link_index)
                            )

                            reaper.TrackFX_SetNamedConfigParm(
                                track,
                                slave,
                                prefix .. "param",
                                tostring(param)
                            )

                            reaper.TrackFX_SetNamedConfigParm(
                                track,
                                slave,
                                prefix .. "scale",
                                "1"
                            )

                            reaper.TrackFX_SetNamedConfigParm(
                                track,
                                slave,
                                prefix .. "offset",
                                "0"
                            )

                            ------------------------------------------------
                            -- Enable the link last.
                            ------------------------------------------------

                            reaper.TrackFX_SetNamedConfigParm(
                                track,
                                slave,
                                prefix .. "active",
                                "1"
                            )

                            ------------------------------------------------
                            -- Count only if REAPER reports it as active.
                            ------------------------------------------------

                            local read_ok, active =
                                reaper.TrackFX_GetNamedConfigParm(
                                    track,
                                    slave,
                                    prefix .. "active"
                                )

                            if read_ok and tonumber(active) ~= 0 then
                                linked_count = linked_count + 1
                            end
                        end
                    end
                end
            end
        end
    end
end


------------------------------------------------------------
-- Run
------------------------------------------------------------

reaper.Undo_BeginBlock()

for _, fx_list in pairs(groups) do
    sync_fx_ids(fx_list)
end

reaper.Undo_EndBlock(
    "Sync identical FX",
    -1
)


------------------------------------------------------------
-- Summary
------------------------------------------------------------

reaper.ShowMessageBox(
    "Linked " .. linked_count .. " parameters.",
    "Sync FX",
    0
)

