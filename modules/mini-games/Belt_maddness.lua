local Mini_games    = require "expcore.Mini_games"
local Global        = require "utils.global" --Used to prevent desynicing.
local tight         = Mini_games.new_game("Belt_madness")
local walls = {}
local save = {}
save["tiles"] = {}
save["entity"] = {}
local variables = {}
local centers = {}
local markets = {}
local entities = {}
local started = {}
local chests = {}
local islands = {}
local left_players = {}
local areas = {}

Global.register({
    centers     = centers,
    markets     = markets,
    entities    = entities,
    started     = started,
    chests      = chests,
    islands     = islands,
    walls       = walls,
    variables   = variables,
    save        = save,
    left_players= left_players,
},function(tbl)
    centers     = tbl.centers
    markets     = tbl.markets
    entities    = tbl.entities
    started     = tbl.started
    chests      = tbl.chests
    islands     = tbl.islands
    walls       = tbl.walls
    variables   = tbl.variables
    save        = tbl.save
    left_players= tbl.left_players
end)





local function player_join_game(player,at_player)
    local level = variables.level
    local playerforce = player.force
    playerforce.manual_mining_speed_modifier = 100

    --island
    local area = {}
    area[1] = {}
    area[2] = {}
    area[1][1] = level.area[1][1]
    area[1][2] = level.area[1][2]
    area[2][1] = level.area[2][1]
    area[2][2] = level.area[2][2]
    area[1][1] = area[1][1] +  at_player * 500
    area[2][1] = area[2][1] +  at_player * 500
    islands[player.name] = area
    areas[player.name] = area
    local left_overs = variables["surface"].find_entities_filtered {area= area}
    for i, ent in ipairs(left_overs) do
        if ent.name ~= "red-chest" and ent.name ~= "steel-chest" then
            ent.destroy()
        end
    end
    local tiles = {}
    for i,tile in ipairs(save["tiles"]) do
        tiles[i] = tile
        tiles[i].position.x = tiles[i].position.x +  at_player * 500
    end
    variables["surface"].set_tiles(tiles)
    for i, entity in ipairs(save["entity"]) do
        local name = entity[1]
        local position = {}
        position.x = entity[2].x
        position.y = entity[2].y
        local force = entity[3]
        local minable = entity[4]
        position.x = position.x + at_player * 500
        local ent = variables["surface"].create_entity{name = name , position = position , force = force }
        if entity.name == "red-chest" or entity.name == "steel-chest"  then
            if not chests[player.name]  then
                chests[player.name] = {}
                chests[player.name][1] = ent
            else
                chests[player.name][#chests[player.name] + 1] = ent
            end
        end
        ent.minable = minable
    end
    centers[player.name] = {}
    centers[player.name].x = level.center.x
    centers[player.name].y = level.center.y
    centers[player.name].x =  centers[player.name].x + at_player * 500
    local center = centers[player.name]
    player.teleport({center.x,center.y},level.surface)
end


local function level_save()
    local level = variables.level
    for x=level.area[1][1],level.area[2][1] do
        for y = level.area[1][2],level.area[2][2] do
            local tile = variables["surface"].get_tile(x,y)
            local table = {
                name = tile.name,
                position = tile.position
            }
            save["tiles"][#save["tiles"]+1] = table
        end
    end

    save["entity"] = variables["surface"].find_entities_filtered {area = level.area}
    for i, entity in ipairs(save["entity"]) do
        local name = entity.name
        if name ~= "character" then
            --[[
            if entity.name == "red-chest" or entity.name == "steel-chest"  then
                if not chests[player.name]  then
                    chests[player.name] = {}
                    chests[player.name][1] = entity
                else
                    chests[player.name][#chests[player.name] + 1] = entity
                end
            end
            ]]
            local position = entity.position
            local force = entity.force
            local minbale =  entity.minable
            local table = {name,position,force,minbale}
            save["entity"][i] = table
        else
            if i == #save["entity"] then
                save["entity"][i] = nil
            else
                name = save["entity"][#save["entity"]].name
                local position = save["entity"][#save["entity"]].position
                local force = save["entity"][i].force
                local minbale =  save["entity"][i].minable
                local table = {name,position,force,minbale}
                --[[
                if entity.name == "red-chest" or entity.name == "steel-chest"  then
                if not chests[player.name]  then
                    chests[player.name] = {}
                    chests[player.name][1] = entity
                    else
                        chests[player.name][#chests[player.name] + 1] = entity
                    end
                end
                ]]
                save["entity"][i] = table
                save["entity"][#save["entity"]] = nil
            end
        end
    end
end

local function start(args)
    variables["level"] = {}
    variables["surface"] = {}
    local level_index = args[1]
    variables.level = config[level_index]
    variables["surface"] = game.surfaces[variables.level["surface"]]
    if not save["tiles"][1] then
        level_save()
    end
    for i, player in ipairs(game.connected_players) do
        player_join_game(player,i-1)
    end
    variables.tick = game.tick
end


local function reset_table(table)
    for i, _ in pairs(table) do
        table[i] = nil
    end
end

local function getSuffix (n)
    local lastTwo, lastOne = n % 100, n % 10
    if lastTwo > 3 and lastTwo < 21 then return "th" end
    if lastOne == 1 then return "st" end
    if lastOne == 2 then return "nd" end
    if lastOne == 3 then return "rd" end
    return "th"
end

local function Nth (n) return n..getSuffix(n) end

local function stop()
    for i,player in ipairs(game.connected_players) do
        player.set_controller {type = defines.controllers.god}
        player.create_character()
    end

    local area = variables.level.area
    area[1][1] = area[1][1]
    area[2][1] = area[2][1]
    local left_overs = variables["surface"].find_entities_filtered {area = area}
    for i, ent in ipairs(left_overs) do
        if ent.name ~= "red-chest" and ent.name ~= "steel-chest"  then
            ent.destroy()
        end
    end

    for i, entity in ipairs(save["entity"]) do
        local name = entity[1]
        local position = entity[2]
        local force = entity[3]
        local minable = entity[4]
        position.x = position.x
        entity[2].x = position.x
        local ent = variables["surface"].create_entity{name = name , position = position , force = force }
        ent.minable = minable
    end

    local colors =  {
        ["1st"] = "[color=#FFD700]",
        ["2nd"] = "[color=#C0C0C0]",
        ["3rd"] = "[color=#cd7f32]"
    }

    reset_table(centers)
    reset_table(markets)
    reset_table(entities)
    reset_table(started)
    reset_table(chests)
    reset_table(variables)
    reset_table(left_players)
end

local function check_chest()
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
    if player.surface.name == variables.level.surface then  --check if the player has not been tped away
        local center = centers[player.name]
        if center then
            local pos = player.position
            local area = islands[player.name]
            if not insideBox(area,pos) then
                player.teleport({center.x,center.y},variables.level.surface)
            end
        end
    end
end



tight:add_event(defines.events.on_player_changed_position, player_move)
tight:add_on_nth_tick(100, check_chest)

tight:add_map("nauvis", 0, 0)
tight:set_start_function(start)
tight:add_option(2)
tight:set_stop_function(stop)

