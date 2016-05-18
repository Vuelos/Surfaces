--[[
	Surfaces (Factorio Mod)
    Copyright (C) 2016  Simon Crawley

    This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License. To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/ or send a letter to Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
]]

require("script.config")
require("script.lib.util")
require("script.lib.pair-util")

function create_surface(surface_type, surface_layer)
	local result = false
	if is_valid_surface(surface_type, surface_layer) then
		local surface_name = surface_mapname(surface_type, surface_layer)
		if game.get_surface(surface_name)==nil then
			game.create_surface(surface_name, get_map_gen_settings(surface_type))
		end
		result = game.get_surface(surface_name)
	end
	return result
end

function surface_mapname(surface_type, surface_layer)
	local result="nauvis"
	if is_valid_surface(surface_type, surface_layer) then
		result=surface_prefix.."_"..surface_type.."_"..surface_layer
	end
	return result
end
	
function is_valid_surface_type(surface_type)
	return (surface_type==surface_type_underground or surface_type==surface_type_sky)
end

function is_surface_from_this_mod(surface)
	return string.find(tostring(get_surface_name(surface)), surface_prefix.."_")~=nil
end

function get_surface_name(surface)
	if surface and surface.valid then return surface.name
	else return surface end
end

function get_surface_layer(surface)
	local surface_name=get_surface_name(surface)
	local surface_layer=nil
	if is_surface_from_this_mod(surface_name) then
		local surface_string=surface_prefix.."_"..get_surface_type(surface_name).."_"
		surface_layer=string.sub(surface_name, string.find(surface_name, surface_string)+string.len(surface_string))
	elseif surface_name=="nauvis" then surface_layer=0 end
	return tonumber(surface_layer)
end

function get_surface_type(surface)
	local surface_name = get_surface_name(surface)
	if is_surface_from_this_mod(surface) then
		if string.find(surface_name, surface_type_underground) then return surface_type_underground
		elseif string.find(surface_name, surface_type_sky) then return surface_type_sky end
	end
	return nil
end	

function is_surface_underground(surface)
	return get_surface_type(get_surface_name(surface)) == surface_type_underground
end

function get_surface_above(surface)
	if surface and surface.valid then
		if is_surface_from_this_mod(surface) or surface.name=="nauvis" then
			local surface_layer = get_surface_layer(surface)
			if is_surface_underground(surface) then
				if surface_layer > 1 then return game.get_surface(surface_mapname(surface_type_underground, surface_layer-1))
				elseif surface.name=="nauvis" then return game.get_surface(surface_mapname(surface_type_sky, 1))
				else return game.get_surface("nauvis") end
			else
				return game.get_surface(surface_mapname(surface_type_sky, surface_layer+1))
			end
		end
	end
end

function create_surface_above(surface)
	local surface_name = get_surface_name(surface)
	if is_surface_from_this_mod(surface) then
		local surface_layer = get_surface_layer(surface)
		if not(is_surface_underground(surface)) then
			return create_surface(surface_type_sky, surface_layer+1)
		end
	elseif surface_name == "nauvis" then
		return create_surface(surface_type_sky, 1)
	end
	return get_surface_above(surface)
end

function get_surface_below(surface)
	if is_surface_from_this_mod(surface) or surface.name=="nauvis" then
		local surface_layer = get_surface_layer(surface)
		if is_surface_underground(surface) then
			return game.get_surface(surface_mapname(surface_type_underground, surface_layer+1))
		else
			if surface_layer > 1 then return game.get_surface(surface_mapname(surface_type_sky, surface_layer-1))
			elseif surface.name=="nauvis" then return game.get_surface(surface_mapname(surface_type_underground, 1))
			else return game.get_surface("nauvis") end
		end
	end
end

function create_surface_below(surface)
	local surface_name = get_surface_name(surface)
	--game.player.print(surface_name)
	if is_surface_from_this_mod(surface) then
		local surface_layer = get_surface_layer(surface)
		if is_surface_underground(surface) then
			return create_surface(surface_type_underground, surface_layer+1)
		end
	elseif surface_name == "nauvis" then
		return create_surface(surface_type_underground, 1)
	end
	return get_surface_below(surface)
end

function is_valid_surface(surface_type, surface_layer)
	return ((surface_layer >=1) and is_valid_surface_type(surface_type))
end

function surfaces_chunk_generated(surface, area)
	global.surface_chunk_generated = global.surface_chunk_generated or {}
	local chunkstring=tostring((area.left_top.x/32)..","..(area.left_top.y/32))
	if global.surface_chunk_generated[surface.name]==nil or global.surface_chunk_generated[surface.name][chunkstring]==nil then
		local data = global.surface_chunk_generated[surface.name] or {}
		data[chunkstring] = false
		global.surface_chunk_generated[surface.name]=data
	end
	if not(global.surface_chunk_generated[surface.name][chunkstring]==true) then
		global.surface_chunk_generated[surface.name][chunkstring] = true
		local replacementTiles = {}
		local tile_name = surface_tile_sky_floor
		local entity_name = nil
		if is_surface_underground(surface) then
			tile_name=surface_tile_underground_floor
			entity_name=surface_entity_underground_wall
		end
		local tilesToReplace=get_tiles_in_area(area)
		for k, v in pairs(tilesToReplace) do
			for key, value in pairs(surface.find_entities({{v.x,v.y},{v.x,v.y}})) do
				if entity_name==nil then
					if not(is_paired_entity(value)) then
						value.destroy()
					end
				elseif value.type=="tree" or value.type=="decorative" or value.type=="fish" or value.type=="noise-layer" or value.type=="simple-entity" then
					value.destroy()
				end
			end
			if not(surface.count_entities_filtered({area={{v.x-1,v.y-1},{v.x+2,v.y+2}}, type="electric-pole"}) == 0) or not(surface.count_entities_filtered({area={{v.x-2,v.y-2},{v.x+3,v.y+3}}, type="unit-spawner"})==0) or not(surface.count_entities_filtered({area={{v.x-2,v.y-2},{v.x+3,v.y+3}}, type="turret"})==0) or not(surface.count_entities_filtered({area={{v.x-1,v.y-1},{v.x+2,v.y+2}}, type="container"})==0) then
				if entity_name then table.insert(replacementTiles, {name = tile_name, position = {math.floor(v.x),math.floor(v.y)}})
				else table.insert(replacementTiles, {name = surface_tile_sky_concrete, position = {math.floor(v.x),math.floor(v.y)}})
				end
			else
				if entity_name then
					table.insert(replacementTiles, {name = tile_name, position = {math.floor(v.x),math.floor(v.y)}})
					if surface.count_entities_filtered({area={{math.floor(v.x)+0.5,math.floor(v.y)+0.5},{math.floor(v.x)+0.5,math.floor(v.y)+0.5}}, name=entity_name})==0 then
						surface.create_entity({name=entity_name, position={math.floor(v.x)+0.5,math.floor(v.y)+0.5}, force=game.forces.player})
					end
				else 
					table.insert(replacementTiles, {name = tile_name, position = {math.floor(v.x),math.floor(v.y)}})
				end
			end
		end
		surface.set_tiles(replacementTiles)
	end
end

function underground_floor_fix(entity, surface)
	if is_surface_from_this_mod(surface) and is_surface_underground(surface) then
		if surface.get_tile(math.floor(entity.position.x),math.floor(entity.position.y)).name~=surface_tile_underground_floor then
			local replacementTiles = {}
			local area={}
			area.left_top={x=math.floor(entity.position.x-1),y=math.floor(entity.position.y-1)}
			area.right_bottom={x=math.floor(entity.position.x+2),y=math.floor(entity.position.y+2)}
			local tilesToReplace=get_tiles_in_area(area)
			for k, v in pairs(tilesToReplace) do
				table.insert(replacementTiles, {name = surface_tile_underground_floor, position = {math.floor(v.x),math.floor(v.y)}})
			end			
			surface.set_tiles(replacementTiles)
		end
	end
end

function clear_floor_for_paired_entity(entity, surface)
	return clear_floor_around_location({x=math.floor(entity.position.x), y=math.floor(entity.position.y)}, surface, 1)
end

function clear_floor_around_location(position, surface, radius)
	if is_surface_from_this_mod(surface) and radius>=0 then
		local replacementTiles = {}
		local area={}
		area.left_top={x=math.floor(position.x-radius),y=math.floor(position.y-radius)}
		area.right_bottom={x=math.floor(position.x+radius),y=math.floor(position.y+radius)}
		local tilesToReplace=get_tiles_in_area(area)
		if is_surface_underground(surface) then
			for k, v in pairs(tilesToReplace) do
				for key,value in pairs(surface.find_entities_filtered({area={v,{x=v.x+1, y=v.y+1}}, name=="underground-wall"})) do
					value.destroy()
				end
				table.insert(replacementTiles, {name = surface_tile_underground_floor, position = {math.floor(v.x),math.floor(v.y)}})
			end			
		else
			for k, v in pairs(tilesToReplace) do
				table.insert(replacementTiles, {name = surface_tile_sky_concrete, position = {math.floor(v.x),math.floor(v.y)}})
			end
		end
		surface.set_tiles(replacementTiles)
	end
end

function sky_floor_fix(position, surface)
	if is_surface_from_this_mod(surface) and not(is_surface_underground(surface)) then
		if surface.get_tile(position.x,position.y).name~=surface_tile_sky_floor then
			local replacementTiles = {}
			local area={}
			area.left_top={x=math.floor(position.x-1),y=math.floor(position.y-1)}
			area.right_bottom={x=math.floor(position.x+2),y=math.floor(position.y+2)}
			local tilesToReplace=get_tiles_in_area(area)
			for k, v in pairs(tilesToReplace) do
				table.insert(replacementTiles, {name = surface_tile_sky_floor, position = {math.floor(v.x),math.floor(v.y)}})
			end
			surface.set_tiles(replacementTiles)
		end
	end
end

function get_map_gen_settings(surface_type)
	math.randomseed(game.tick)
	local map_gen_settings = {
		terrain_segmentation=game.get_surface("nauvis").map_gen_settings.terrain_segmentation,
		water="none",
		autoplace_controls = game.get_surface("nauvis").map_gen_settings.autoplace_controls,
		width = game.get_surface("nauvis").map_gen_settings.width,
		height = game.get_surface("nauvis").map_gen_settings.height,
		seed = math.floor(math.random()*4294967295),
		peaceful_mode = game.get_surface("nauvis").map_gen_settings.peaceful_mode}
	if surface_type==surface_type_sky then
		for k, v in pairs(map_gen_settings.autoplace_controls) do v.size="none" end
	end
	return map_gen_settings
end

function transport_player_to_access_shaft(player, destination_access_shaft)
	local new_position = destination_access_shaft.surface.find_non_colliding_position(player.character.prototype.name, destination_access_shaft.position, 2, 1)
	if not(new_position) then
		new_position = player.position
	end
	player.teleport(new_position, destination_access_shaft.surface)
end

function find_nearby_access_shaft(entity, radius, surface)
	for k, v in pairs(surface.find_entities_filtered({area={{entity.position.x-radius,entity.position.y-radius},{entity.position.x+radius,entity.position.y+radius}},type="electric-pole"})) do
		if v.name == "sky-exit" or v.name == "sky-entrance" or v.name == "underground-exit" or v.name == "underground-entrance" then
			return v
		end
	end
	return nil
end

function find_paired_entity(entity)
	local pair_data = get_paired_entity_data(entity)
	if pair_data then
		if pair_data.location==surface_location_above then return find_nearby_entity_by_name(entity, 0.5, get_surface_above(entity.surface), pair_data.name)
		else return find_nearby_entity_by_name(entity, 0.5, get_surface_below(entity.surface), pair_data.name) end
	end
	return nil
end

function trigger_create_paired_entity(entity)
	--game.player.print("trigger create entity")
	local pair_data = get_paired_entity_data(entity)
	local paired_entity, paired_surface = nil
	if is_surface_underground(entity.surface) then
		if pair_data.realm==surface_type_sky then 
			entity.destroy()
		end
	elseif entity.surface.name=="nauvis" then
		if pair_data.nauvis~=true then
			entity.destroy()
		end
	elseif is_surface_from_this_mod(entity.surface) then
		if pair_data.realm==surface_type_underground then
			entity.destroy()
		end
	end
	table.insert(global.task_queue, {task=surface_task_triggercreatesurface, data={entity=entity, pair_location=pair_data.location}})
end

function trigger_create_paired_surface(entity, pair_location)
	--game.player.print("trigger create surface")
	local paired_surface = nil
	if entity and entity.valid then
		if pair_location==surface_location_above then
			paired_surface=get_surface_above(entity)
			if not(paired_surface) or not(paired_surface.valid) then
				paired_surface=create_surface_above(entity.surface)
			end
		elseif pair_location==surface_location_below then
			paired_surface=get_surface_below(entity)
			if not(paired_surface) or not(paired_surface.valid) then
				paired_surface=create_surface_below(entity.surface)
			end
		end
	else
		paired_surface=false
	end
	return paired_surface
end

function create_paired_entity(entity, paired_surface)
	--game.player.print("create entity")
	local pair_data = get_paired_entity_data(entity)
	local paired_entity = nil
	clear_floor_for_paired_entity(entity, paired_surface)
	paired_entity=paired_surface.create_entity({name=pair_data.name, position=entity.position, force=entity.force})
	if not(paired_entity and paired_entity.valid) then
		return false
	end
	return paired_entity
end

function finalize_paired_entity(entity, paired_entity)
	--game.player.print("finalize entity")
	local pair_data = get_paired_entity_data(entity)
	if pair_data.class==surface_pairclass_access_shaft then
		entity.connect_neighbour(paired_entity)
		entity.connect_neighbour{wire = defines.circuitconnector.red, target_entity = paired_entity}
		entity.connect_neighbour{wire = defines.circuitconnector.green, target_entity = paired_entity}
	elseif pair_data.class==surface_pairclass_transport_chest then
		global.transport_chests = global.transport_chests or {}
		table.insert(global.transport_chests, {input=entity,output=paired_entity})
	end
end

function destroy_paired_entity(entity)
	local paired_entity = find_paired_entity(entity)
	if paired_entity then
		paired_entity.destroy()
	end
end