local Mini_games = require "expcore.Mini_games"
local Global = require "utils.global" --Used to prevent desynicing.
local Gui = require "expcore.gui._require"
local Belt = Mini_games.new_game("Belt_madness")
local config = require "config.mini_games.belt"
local save = {}
save["tiles"] = {}
save["entity"] = {}
local variables = {}
local centers = {}
local chests = {}
local islands = {}
local chest_pos = {}
local started_players = {}
local items = {}
local won_players = {}
local game_gui
local button
local spectator_gui
local button_for_clear
local update_specatator

Global.register(
    {
        chest_pos = chest_pos,
        items = items,
        chests = chests,
        centers = centers,
        variables = variables,
        save = save,
        islands = islands,
        started_players = started_players,
        won_players = won_players
    },
    function(tbl)
        chest_pos = tbl.chest_pos
        chests = tbl.chests
        centers = tbl.centers
        variables = tbl.variables
        save = tbl.save
        islands = tbl.islands
        started_players = tbl.started_players
        items = tbl.items
        won_players = tbl.won_players
    end
)
local function clean_up(area)
    local left_overs = variables["surface"].find_entities_filtered {area = area}
    for i, ent in ipairs(left_overs) do
        if ent.name ~= "market" and ent.name ~= "steel-chest" then
            ent.destroy()
        end
    end
end
local function fill_chests(player)
    for i, chest in ipairs(chests[player]) do
        local index = chest[2]
        local ent = chest[1]
        local item_name = variables.level.chests[index].item
        local inv = ent.get_inventory(defines.inventory.chest)
        inv.clear()
        if ent.name == "steel-chest" then
            inv.insert({name = item_name, count = "20"})
        else
            inv.insert({name = item_name, count = "1"})
        end
    end
end
local function player_join_game(player, at_player)
    local level = variables.level
    local playerforce = player.force

    player.set_controller {type = defines.controllers.god}
    playerforce.manual_mining_speed_modifier = 100
    player.force.disable_all_prototypes()
    player.cheat_mode = true
    local recipeList = player.force.recipes
    for index, item in pairs(variables.level.recipes) do
        recipeList[item].enabled = true
        player.insert(item)
        player.set_quick_bar_slot(index, item)
    end

    --island
    local player_offset = at_player * 500
    local level_area = level.area
    local area = {
        {level_area[1][1] + player_offset, level_area[1][2]},
        {level_area[2][1] + player_offset, level_area[2][2]}
    }
    islands[player.name] = area
    clean_up(area)
    local tiles = {}
    for i, tile in ipairs(save["tiles"]) do
        tiles[i] = {
            name = tile.name,
            position = {
              x = tile.position.x + player_offset,
              y = tile.position.y
            }
        }
    end
    variables["surface"].set_tiles(tiles)
    for i, entity in ipairs(save.entities) do
        local name = entity[1]
        local position = {}
        position.x = entity[2].x
        position.y = entity[2].y
        local force = entity[3]
        local minable = entity[4]
        position.x = position.x + player_offset
        local ent
        if entity[5] then
            ent =
                variables["surface"].create_entity {
                name = name,
                position = position,
                force = force,
                direction = entity[5]
            }
        else
            ent = variables["surface"].create_entity {name = name, position = position, force = force}
        end
        if ent.name == "red-chest" or ent.name == "steel-chest" then
            ent.operable = false
            local p = entity[2]
            if not chests[player.name] then
                chests[player.name] = {}
                chests[player.name][1] = {ent, chest_pos[p.x .. "," .. p.y]}
            else
                chests[player.name][#chests[player.name] + 1] = {ent, chest_pos[p.x .. "," .. p.y]}
            end
        elseif ent.name == "inserter" or ent.name == "fast-inserter" then
            ent.operable = false
            ent.minable = false
            ent.rotatable = false
            ent.active = false
        end
        ent.minable = minable
    end

    centers[player.name] = {
        x = level.center.x + player_offset,
        y = level.center.y
    }

    local center = centers[player.name]
    player.teleport({center.x, center.y}, level.surface)
    fill_chests(player.name)
end

local function level_save()
    local level = variables.level
    for x = level.area[1][1], level.area[2][1] do
        for y = level.area[1][2], level.area[2][2] do
            local tile = variables["surface"].get_tile(x, y)
            local table = {
                name = tile.name,
                position = tile.position
            }
            save["tiles"][#save["tiles"] + 1] = table
        end
    end
    save.entities = variables["surface"].find_entities_filtered {area = level.area}
    for i, entity in ipairs(save.entities) do
        local name = entity.name
        if name ~= "character" then
            local table
            if entity.supports_direction then
                table = {name, entity.position, entity.force, entity.minable, entity.direction}
            else
                table = {name, entity.position, entity.force, entity.minable}
            end
            save.entities[i] = table
        else
            if i == #save.entities then
                save.entities[i] = nil
            else
                local ent = save.entities[#save.entities]
                name = ent.name
                local table = {name, ent.position, ent.force, ent.minable}
                save.entities[i] = table
                save.entities[#save.entities] = nil
            end
        end
    end
end

local function create_level()
    local level = variables.level
    local _chests = level.chests
    local chest_count = #_chests
    local level_width = level.level_width
    local chest_starting_position = {x = -math.ceil(level_width / 2), y = -math.ceil(chest_count / 2)}
    local chest_ending_position = {x = math.ceil(level_width / 2), y = -math.ceil(chest_count / 2)}
    for index, item in pairs(_chests) do
        local chest_input_position
        if item.input_position == nil then
            chest_input_position = {chest_starting_position.x, chest_starting_position.y + item.input}
        else
            chest_input_position = item.input_position[1]
        end
        local input_chest =
            variables.surface.create_entity {
            name = "steel-chest",
            position = chest_input_position,
            force = game.forces.player
        }
        input_chest.operable = false
        input_chest.minable = false
        local p = input_chest.position
        chest_pos[p.x .. "," .. p.y] = index

        local inserter_input_direction
        local inserter_input_position
        if item.input_position == nil then
            inserter_input_position = {chest_starting_position.x + 1, chest_starting_position.y + item.input}
            inserter_input_direction = defines.direction.east
        else
            inserter_input_position = util.moveposition(item.input_position[1], item.input_position[2], 1)
            inserter_input_direction = item.input_position[2]
        end

        local input_inserter =
            variables.surface.create_entity {
            name = "inserter",
            position = inserter_input_position,
            direction = util.oppositedirection(inserter_input_direction),
            force = game.forces.player
        }
        input_inserter.operable = false
        input_inserter.minable = false
        input_inserter.rotatable = false
        input_inserter.active = false

        local chest_output_position
        if item.output_position == nil then
            chest_output_position = {chest_ending_position.x, chest_starting_position.y + item.output}
        else
            chest_output_position = item.output_position[1]
        end
        local output_chest =
            variables.surface.create_entity {
            name = "red-chest",
            position = chest_output_position,
            force = game.forces.player
        }
        output_chest.operable = false
        output_chest.minable = false
        p = output_chest.position
        chest_pos[p.x .. "," .. p.y] = index

        local inserter_output_direction
        local inserter_output_position
        if item.output_position == nil then
            inserter_output_position = {chest_output_position[1] - 1, chest_output_position[2]}
            inserter_output_direction = defines.direction.west
        else
            inserter_output_position = util.moveposition(chest_output_position, item.output_position[2], 1)
            inserter_output_direction = item.output_position[2]
        end

        local output_inserter =
            variables.surface.create_entity {
            name = "fast-inserter",
            position = inserter_output_position,
            direction = inserter_output_direction,
            force = game.players[1].force
        }
        output_inserter.operable = false
        output_inserter.minable = false
        output_inserter.rotatable = false
        output_inserter.active = false
    end
end

local function start(args)
    variables.joined_player = 0
    variables["level"] = {}
    variables["surface"] = {}
    local level_index = args[1]
    variables.level = config[level_index]
    variables["surface"] = game.surfaces[variables.level["surface"]]
    create_level()
    save["tiles"] = {}
    save["entity"] = {}
    level_save()
    for i, player in ipairs(game.connected_players) do
        player_join_game(player, i - 1)
    end
    variables.tick = game.tick
    for i, chest in ipairs(variables.level.chests) do
        items[#items + 1] = chest.item
    end
end

local function reset_table(table)
    for i, _ in pairs(table) do
        table[i] = nil
    end
end

local function getSuffix(n)
    local lastTwo, lastOne = n % 100, n % 10
    if lastTwo > 3 and lastTwo < 21 then
        return "th"
    end
    if lastOne == 1 then
        return "st"
    end
    if lastOne == 2 then
        return "nd"
    end
    if lastOne == 3 then
        return "rd"
    end
    return "th"
end

local function Nth(n)
    return n .. getSuffix(n)
end
local str_format = string.format
local function stop()
    for i, player in ipairs(game.connected_players) do
        player.set_controller {type = defines.controllers.god}
        player.create_character()
    end

    local area = variables.level.area
    area[1][1] = area[1][1]
    area[2][1] = area[2][1]
    clean_up(area)

    for i, entity in ipairs(save["entity"]) do
        local name = entity[1]
        local position = entity[2]
        local force = entity[3]
        local minable = entity[4]
        position.x = position.x
        entity[2].x = position.x
        local ent = variables["surface"].create_entity {name = name, position = position, force = force}
        ent.minable = minable
    end
    local scores = {}
    for name,time in pairs(won_players) do
        scores[#scores + 1] = {name, time}
    end
    local colors = {
        ["1st"] = "[color=#FFD700]",
        ["2nd"] = "[color=#C0C0C0]",
        ["3rd"] = "[color=#cd7f32]"
    }
    table.sort(scores,function(a, b)return a[2] < b[2]end)
    for i, score in ipairs(scores) do
        local player_name = score[1]
        local time = score[2]
        local place = Nth(i)
        if colors[place] then
            game.print(str_format("%s%s: %s with %d seconds time[/color]",colors[place],place,player_name,time))
        else
            game.print(str_format("[color=#808080]%s: %s with %d seconds points[/color]",place,player_name,time))
        end
    end
    reset_table(chest_pos)
    reset_table(items)
    reset_table(chests)
    reset_table(centers)
    reset_table(variables)
    reset_table(save)
    reset_table(islands)
    reset_table(started_players)
    reset_table(won_players)
end
local function  get_table_lenght (table)
    local count = 0
    for _ in pairs(table) do count = count + 1 end
    return count
end
local function check_player_chests(name)
    local won = 0
    for _, chest in ipairs(chests[name]) do
        local index = chest[2]
        local ent = chest[1]
        if ent.name == "red-chest" then
            local item_name = variables.level.chests[index].item
            local inv = ent.get_inventory(defines.inventory.chest)
            for _, item in ipairs(items) do
                if item == item_name then
                    local sucses = inv.get_item_count(item)
                    if sucses == 21 then
                        won = won + 1
                        if won == #variables.level.chests then
                            local player = game.players[name]
                            local time = game.tick - variables.tick
                            time = time/60
                            won_players[name] = time
                            started_players[name] = nil
                            game.print(name.." has finshished with a time of "..time.." seconds placing him "..Nth(get_table_lenght(won_players)))
                            player.set_controller {type = defines.controllers.spectator}
                            --gui
                            Gui.update_top_flow(player)
                            Gui.toggle_left_element(player,game_gui,false)
                            update_specatator(player)
                            if get_table_lenght(won_players) >= #game.connected_players - variables.joined_player then
                                Mini_games.stop_game()
                            end
                        end
                    end
                else
                    local failed = inv.get_item_count(item)
                    if failed > 0 then
                        variables.surface.create_entity {
                            name = "flying-text",
                            position = ent.position,
                            text = "Failed: this chest shood not contain any "..item..".",
                            color = {r = 1}
                        }
                        local area = islands[name]
                        local ents = variables.surface.find_entities_filtered {area = area, name = {"fast-inserter", "inserter"}}
                        for _, inserter in ipairs(ents) do
                            local dir = inserter.direction
                            local pos = inserter.position
                            local force = inserter.force
                            local ent_name = inserter.name
                            inserter.destroy()
                            local ent_new =
                                variables.surface.create_entity {
                                name = ent_name,
                                position = pos,
                                direction = dir,
                                force = force
                            }
                            ent_new.operable = false
                            ent_new.minable = false
                            ent_new.rotatable = false
                            ent_new.active = false
                        end
                        ents = variables.surface.find_entities_filtered {area = area, name = "item-on-ground"}
                        for _, ground_item in ipairs(ents) do
                            ground_item.destroy()
                        end
                        for _, belt in pairs(variables.surface.find_entities_filtered {type = {"underground-belt", "transport-belt"}}) do
                            for i = 1, 2 do
                                belt.get_transport_line(i).clear()
                            end
                        end
                        fill_chests(name)
                        started_players[name] = nil
                        --gui
                        local Main_gui = Gui.get_left_element(game.players[name], game_gui)
                        local table = Main_gui.container["buttons"].table
                        table[button.name].caption = "start"
                        return "done"
                    end
                end
            end
        end
    end
end

local function check_chest()
    for name, _ in pairs(started_players) do
        check_player_chests(name)
    end
end

local function insideBox(box, pos)
    local x1 = box[1][1]
    local y1 = box[1][2]
    local x2 = box[2][1]
    local y2 = box[2][2]

    local px = pos.x
    local py = pos.y
    return px >= x1 and px <= x2 and py >= y1 and py <= y2
end

local function player_move(event)
    local player = game.players[event.player_index]
    if won_players[player.name] then return end
    if player.surface.name == variables.level.surface then --check if the player has not been tped away
        local center = centers[player.name]
        if center then
            local pos = player.position
            local area = islands[player.name]
            if not insideBox(area, pos) then
                player.teleport({center.x, center.y}, variables.level.surface)
            end
        end
    end
end
local function player_join(event)
    local player = game.players[event.player_index]
    if centers[player.name] then
        local center = centers[player.name]
        player.teleport({center.x, center.y}, variables.level.surface)
    else
        player.teleport({0, 0}, variables.level.surface)
        Gui.toggle_left_element(player,spectator_gui,true)
    end
    variables.joined_player = variables.joined_player +1
end
local function player_leave(event)
    local player = game.players[event.player_index]
    player.teleport({-35, 55}, "nauvis")
    if  not centers[player.name] then
        variables.joined_player =  variables.joined_player - 1
    end
    Gui.toggle_left_element(player,game_gui,false)
    Gui.toggle_left_element(player,spectator_gui,false)
end
--gui
local dorpdown_for_level =
    Gui.element {
    type = "drop-down",
    items = {"level-1", "level-2"},
    selected_index = 1
}:style {
    width = 87
}

local maingui =
    Gui.element(
    function(_, parent)
        local main_flow = parent.add {type = "flow", name = "Tight_flow"}
        dorpdown_for_level(main_flow)
    end
)

local function gui_callback(parent)
    local args = {}
    local flow = parent["Tight_flow"]

    local level_dropwdown = flow[dorpdown_for_level.name]
    local level_config = level_dropwdown.selected_index
    args[1] = level_config

    return args
end
local function start_level(player, element, _)
    if element.caption == "start" then
        local area = islands[player.name]
        local ents = variables.surface.find_entities_filtered {area = area, name = {"fast-inserter", "inserter"}}
        for i, ent in ipairs(ents) do
            ent.active = true
        end
        started_players[player.name] = true
        element.caption = "stop"
    else
        local area = islands[player.name]
        local ents = variables.surface.find_entities_filtered {area = area, name = {"fast-inserter", "inserter"}}
        for i, ent in ipairs(ents) do
            local dir = ent.direction
            local pos = ent.position
            local force = ent.force
            local name = ent.name
            ent.destroy()
            local ent_new =
                variables.surface.create_entity {
                name = name,
                position = pos,
                direction = dir,
                force = force
            }
            ent_new.operable = false
            ent_new.minable = false
            ent_new.rotatable = false
            ent_new.active = false
        end
        ents = variables.surface.find_entities_filtered {area = area, name = "item-on-ground"}
        for i, ent in ipairs(ents) do
            ent.destroy()
        end
        for _, belt in pairs(variables.surface.find_entities_filtered {name = {"underground-belt", "transport-belt"}}) do
            for i = 1, 2 do
                belt.get_transport_line(i).clear()
            end
        end
        fill_chests(player.name)
        started_players[player.name] = nil
        element.caption = "start"
    end
end
local function clear_level(player, _, _)
    local area = islands[player.name]
    local ents = variables.surface.find_entities_filtered {area = area, name = variables.level.recipes}
    for i, ent in ipairs(ents) do
        ent.destroy()
    end
end

local function tp(player, element, _)
    player.teleport(game.players[element.caption].position)
end
--game gui
button_for_clear =
    Gui.element {
    type = "button",
    caption = "clear_level"
}:on_click(clear_level)

button =
    Gui.element {
    type = "button",
    caption = "start"
}:on_click(start_level)

game_gui =
    Gui.element(
    function(event_trigger, parent)
        local container = Gui.container(parent, event_trigger, 200)
        Gui.header(container, "Belt_maddness", "For starting stoping the level.", true)
        local scroll_table_buttons = Gui.scroll_table(container, 250, 2, "buttons")
        button(scroll_table_buttons)
        button_for_clear(scroll_table_buttons)
        return container.parent
    end
):add_to_left_flow(false)
Gui.left_toolbar_button(
    "item/coin",
    "money",
    game_gui,
    function(player)
        return Mini_games.get_running_game() == "Belt_madness" and not won_players[player.name]
    end
)
local tp_button =
    Gui.element {
    type = "button",
    caption = "start"
}:on_click(tp)

spectator_gui =
Gui.element(
    function(event_trigger, parent)
        local container = Gui.container(parent, event_trigger, 200)
        Gui.header(container, "Spectator menu", "You can use this to tp to other players.", true)
        local scroll_table_buttons = Gui.scroll_table(container, 250, 1, "tp_buttons")
        for i,_ in pairs(centers) do
            local button_for_tp = tp_button(scroll_table_buttons)
            button_for_tp.caption = i
        end
        return container.parent
    end
):add_to_left_flow(false)
Gui.left_toolbar_button(
    "utility/search_icon",
    "spectator Menu",
    spectator_gui,
    function(player)
        return Mini_games.get_running_game() == "Belt_madness" and won_players[player.name]
    end
)
update_specatator = function (player)
    local gui = Gui.get_left_element(player, spectator_gui)
    local gui_table = gui.container["tp_buttons"].table
    for player_name in pairs(centers) do
        if player_name ~= player.name  then
            local flow = Gui.alignment(gui_table,player_name,'center','top')
            flow.style.width = 200
            local button_for_tp = tp_button(flow)
            button_for_tp.caption = player_name
        end
    end
end



Belt:add_event(defines.events.on_player_changed_position, player_move)
Belt:add_on_nth_tick(100, check_chest)
Belt:add_event(defines.events.on_player_joined_game,player_join)
Belt:add_event(defines.events.on_player_left_game,player_leave)
Belt:add_map("Belt_Madness", 0, 0)
Belt:set_start_function(start)
Belt:add_option(1)
Belt:set_gui_callback(gui_callback)
Belt:set_gui_element(maingui)
Belt:set_stop_function(stop)
