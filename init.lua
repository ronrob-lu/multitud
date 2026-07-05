-- Initialize random seed
-- math.randomseed is not necessary as Minetest seeds math.random already

-- Helper function to generate a random texture
local function get_random_texture()
    return "npc_character_" .. math.random(1, 100) .. ".png"
end

minetest.register_entity("nystreets:npc", {
    initial_properties = {
        hp_max = 20,
        physical = true,
        collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.7, 0.3},
        visual = "mesh",
        mesh = "character.b3d",
        textures = {"character.png"},
        makes_footstep_sound = true,
        stepheight = 1.1,

    },

    on_activate = function(self, staticdata, dtime_s)
        -- Set random texture and nametag
        self.object:set_properties({
            textures = {get_random_texture()},
            nametag = "", -- No nametag
        })

        -- Start walking animation (assuming standard Minetest character animation frames 168-187 for walking)
        self.object:set_animation({x=168, y=187}, 30, 0)

        -- Set initial direction
        local yaw = math.random() * math.pi * 2
        self.object:set_yaw(yaw)

        local dir = minetest.yaw_to_dir(yaw)
        self.object:set_velocity({x=dir.x * 3, y=0, z=dir.z * 3})
        self.object:set_acceleration({x=0, y=-9.81, z=0})

        self.timer = 0
        self.stuck_timer = 0
        self.last_pos = self.object:get_pos()
    end,

    on_step = function(self, dtime)
        self.timer = self.timer + dtime

        -- Every 0.5 seconds, check if stuck
        if self.timer > 0.5 then
            self.timer = 0

            local pos = self.object:get_pos()
            if not pos then return end

            -- Check if despawn is needed (too far from any player)
            local nearest_player = false
            for _, player in ipairs(minetest.get_connected_players()) do
                local player_pos = player:get_pos()
                if vector.distance(pos, player_pos) < 120 then
                    nearest_player = true
                    break
                end
            end

            if not nearest_player then
                self.object:remove()
                return
            end

            -- Check for movement
            if vector.distance(pos, self.last_pos) < 0.1 then
                self.stuck_timer = self.stuck_timer + 1

                if self.stuck_timer > 2 then
                    -- Very stuck, change direction to try to find a way out
                    local yaw = self.object:get_yaw()
                    yaw = yaw + (math.random() * math.pi - math.pi/2)
                    self.object:set_yaw(yaw)

                    local dir = minetest.yaw_to_dir(yaw)
                    -- Jump
                    local vel = self.object:get_velocity()
                    self.object:set_velocity({x=dir.x * 3, y=vel.y + 4.5, z=dir.z * 3})

                    self.stuck_timer = 0
                else
                    -- Slightly stuck, maybe just need to jump
                    local vel = self.object:get_velocity()
                    if vel.y == 0 then
                        self.object:set_velocity({x=vel.x, y=4.5, z=vel.z})
                    end
                end
            else
                self.stuck_timer = 0
            end

            self.last_pos = pos

            -- Re-apply velocity based on yaw to ensure straight lines
            local yaw = self.object:get_yaw()
            local dir = minetest.yaw_to_dir(yaw)
            local vel = self.object:get_velocity()
            self.object:set_velocity({x=dir.x * 3, y=vel.y, z=dir.z * 3})
        end
    end,

    -- When hit, it takes damage (default behavior works fine)
})
-- Global Spawner
local spawn_timer = 0
minetest.register_globalstep(function(dtime)
    spawn_timer = spawn_timer + dtime
    if spawn_timer < 5 then return end
    spawn_timer = 0

    for _, player in ipairs(minetest.get_connected_players()) do
        local pos = player:get_pos()
        if pos then

        -- Count NPCs around player
        local objects = minetest.get_objects_inside_radius(pos, 100)
        local npc_count = 0
        for _, obj in ipairs(objects) do
            local luaentity = obj:get_luaentity()
            if luaentity and luaentity.name == "nystreets:npc" then
                npc_count = npc_count + 1
            end
        end

        -- Spawn if below 100
        if npc_count < 100 then
            -- Spawn up to 10 at a time to reduce lag spikes
            local to_spawn = math.min(10, 100 - npc_count)
            for i = 1, to_spawn do
                -- Spawn 70-80 blocks away
                local dist = math.random(70, 80)
                local angle = math.random() * math.pi * 2

                local spawn_x = pos.x + math.cos(angle) * dist
                local spawn_z = pos.z + math.sin(angle) * dist

                -- Find valid height
                local spawn_y = pos.y + 20 -- start above
                local found_ground = false

                for y = pos.y + 20, pos.y - 20, -1 do
                    local node_pos = {x = spawn_x, y = y, z = spawn_z}
                    local node = minetest.get_node(node_pos)

                    if node.name ~= "air" and minetest.registered_nodes[node.name] and minetest.registered_nodes[node.name].walkable then
                        local above1 = minetest.get_node({x = spawn_x, y = y + 1, z = spawn_z})
                        local above2 = minetest.get_node({x = spawn_x, y = y + 2, z = spawn_z})

                        if above1.name == "air" and above2.name == "air" then
                            spawn_y = y + 1
                            found_ground = true
                            break
                        end
                    end
                end

                if found_ground then
                    local spawn_pos = {x = spawn_x, y = spawn_y, z = spawn_z}
                    local obj = minetest.add_entity(spawn_pos, "nystreets:npc")

                    if obj then
                        -- Face towards the opposite side of the player's viewable area
                        -- Generally just direct them across the area, so angle + pi
                        local opposite_angle = angle + math.pi + (math.random() * 0.5 - 0.25)
                        obj:set_yaw(opposite_angle)
                    end
                end
            end
        end

        end -- close if pos then
    end
end)

-- Clear Multitud Command
minetest.register_chatcommand("clear_multitud", {
    description = "Remove all nystreets NPCs",
    privs = {server = true},
    func = function(name, param)
        local count = 0
        for _, obj in pairs(minetest.luaentities) do
            if obj.name == "nystreets:npc" then
                obj.object:remove()
                count = count + 1
            end
        end
        return true, "Removed " .. count .. " NPCs."
    end,
})

-- Spawn Egg
minetest.register_craftitem("nystreets:egg", {
    description = "NPC Spawn Egg",
    inventory_image = "character.png^[colorize:#FF0000:127",
    on_place = function(itemstack, placer, pointed_thing)
        if pointed_thing.type == "node" then
            local pos = pointed_thing.above
            minetest.add_entity(pos, "nystreets:npc")
            if not minetest.is_creative_enabled(placer:get_player_name()) then
                itemstack:take_item()
            end
        end
        return itemstack
    end,
})
