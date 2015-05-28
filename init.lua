--
-- Helper functions
--

local function is_water(pos)
	local nn = minetest.env:get_node(pos).name
	return minetest.get_item_group(nn, "water") ~= 0
end

local function get_sign(i)
	if i == 0 then
		return 0
	else
		return i/math.abs(i)
	end
end

local function get_velocity(v, yaw, y)
	local x = math.cos(yaw)*v
	local z = math.sin(yaw)*v
	return {x=x, y=y, z=z}
end

local function get_v(v)
	return math.sqrt(v.x^2+v.z^2)
end

--
-- Initialization
--

local mana_regen_cost = 1.5

local mod_model, mod_mana
if minetest.get_modpath("default") ~= nil or minetest.get_modpath("playermodel") then
	mod_model = true
else
	mod_model = false
end
if minetest.get_modpath("mana") ~= nil then
	mod_mana = true
else
	mod_mana = false
end


--
-- Carpet entity
--

local carpet = {
	physical = true,
	collide_with_objects = false,
	collisionbox = {-1,-0.02,-1, 1,0.02,1},
	visual = "mesh",
	mesh = "flying_carpet_model.obj",
	textures = {"flying_carpet_surface.png"},

	driver = nil,
	v = 0,
	h = 0,
	falling = false,
	flying = false,
	prefly = true,
	starttimer = 0,

	sound_flight = nil,
}

function carpet:on_rightclick(clicker)
	if not clicker or not clicker:is_player() then
		return
	end
	local name = clicker:get_player_name()
	if self.driver and clicker == self.driver then
		self.driver = nil
		clicker:set_detach()
		if mod_model then
			default.player_attached[name] = false
			default.player_set_animation(clicker, "stand", 30)
		end
		if mod_mana then
			mana.setregen(clicker:get_player_name(), mana.getregen(clicker:get_player_name())+mana_regen_cost)
		end
	elseif not self.driver then
		self.driver = clicker
		clicker:set_look_yaw(self.object:getyaw()-math.pi/2)
		clicker:set_attach(self.object, "", {x=-4,y=10.1,z=0}, {x=0,y=90,z=0})
		if mod_model then
			default.player_attached[name] = true
			minetest.after(0.2, function()
				default.player_set_animation(clicker, "sit", 30)
			end)
		end
		if mod_mana then
			mana.setregen(clicker:get_player_name(), mana.getregen(clicker:get_player_name())-mana_regen_cost)
		end
		if self.prefly then
			self.flying = true
			self.falling = false
			self.prefly = false
			self.object:setvelocity(get_velocity(4, self.object:getyaw(), 0))
		end
	end
end

function carpet:on_activate(staticdata, dtime_s)
	self.object:set_armor_groups({fabric=100})
	if staticdata then
		self.v = tonumber(staticdata)
	end
end

function carpet:get_staticdata()
	return tostring(v)
end

function carpet:on_punch(puncher, time_from_last_punch, tool_capabilities, direction)
	if puncher and puncher:is_player() then
		if self.driver == nil or self.driver == puncher then
			puncher:get_inventory():add_item("main", "flying_carpet:carpet")
			minetest.sound_play("flying_carpet_take", {pos=self.object:getpos(), gain=0.3})
			puncher:set_detach()
			if mod_mana and self.driver == puncher then
				mana.setregen(puncher:get_player_name(), mana.getregen(puncher:get_player_name())+mana_regen_cost)
			end
			if mod_model then
				default.player_attached[puncher:get_player_name()] = false
			end
			if self.sound_flight then
				minetest.sound_stop(self.sound_flight)
				self.sound_flight = nil
			end
			self.object:remove()
		end
	end
end

function carpet:on_step(dtime)
	if not self.prefly then
	self.v = get_v(self.object:getvelocity())*get_sign(self.v)
	self.h = self.object:getvelocity().y

	if self.flying then
		if self.driver then
			local ctrl = self.driver:get_player_control()
			if ctrl.up then
				self.v = self.v+0.1
			end
			if ctrl.down then
				self.v = self.v-0.08
			end
			if ctrl.left then
				self.object:setyaw(self.object:getyaw()+math.pi/600+dtime*math.pi/600)
			end
			if ctrl.right then
				self.object:setyaw(self.object:getyaw()-math.pi/600-dtime*math.pi/600)
			end
			if ctrl.jump then
				if self.v >= 6 then
					self.h = self.h+0.02
				end
			end
			if ctrl.sneak then
				if self.v >= 6 then
					self.h = self.h-0.03
				end
			end

			if mod_mana then
				if mana.getregen(self.driver:get_player_name()) < 0 and mana.get(self.driver:get_player_name()) == 0 then
					minetest.sound_play("flying_carpet_out_of_energy", {pos = self.object:getpos(), gain=0.7})
					self.falling = true
					self.flying = false
					if self.sound_flight then
						minetest.sound_stop(self.sound_flight)
						self.sound_flight = nil
					end
				end
			end
	
			if self.v > 15 then
				self.v = 15
				self.v = self.v - 0.02
			elseif self.v > 12 then
				self.v = self.v - 0.02
			elseif self.v < 6 then
				self.v = self.v + 0.06
			elseif self.v < 9 then
				self.v = self.v + 0.04
			elseif self.v < 12 then
				self.v = self.v + 0.02
			end

		else
			self.v = self.v - 0.025
		end
		if self.v > 3 and self.flying then
			if not self.sound_flight then
				self.sound_flight = minetest.sound_play("flying_carpet_flight", {object = self.object, gain = 0.6, max_hear_distance = 16, loop = true })
			end
		elseif self.sound_flight then
			minetest.sound_stop(self.sound_flight)
			self.sound_flight = nil
		end
	end

	local sh = get_sign(self.h)

	self.starttimer = self.starttimer + dtime

	if self.v < 6 then
		if self.starttimer >= 5 then
			if self.falling == false then
				minetest.sound_play("flying_carpet_out_of_energy", {pos = self.object:getpos(), gain=0.7})
				self.falling = true
				self.flying = false
				if self.sound_flight then
					self.sound_flight = minetest.sound_stop(self.sound_flight)
				end
			end
			self.v = self.v - 0.04
		end
	else
		if self.h > 0.01 then
			self.h = self.h - 0.005
		elseif self.h < 0.01 then
			self.h = self.h + 0.005
		end
		if math.abs(self.h) > 1 then
			self.h = 1*sh
		end
		if math.abs(self.h) < 0.01 then
			self.h = 0
		end
	end

	if self.v < 0 then
		self.v = 0
	end

	local y
	if self.falling then
		y = self.object:getvelocity().y
		self.object:setacceleration({x=0,y=-9.81,z=0})
	else
		y = self.h
		self.object:setacceleration({x=0,y=0,z=0})
	end
	self.object:setvelocity(get_velocity(self.v, self.object:getyaw(), y))

	end
end

minetest.register_entity("flying_carpet:carpet", carpet)


minetest.register_craftitem("flying_carpet:carpet", {
	description = "flying carpet",
	inventory_image = "flying_carpet_inventory.png",
	wield_image = "flying_carpet_wield.png",
	wield_scale = {x=1.374, y=2, z=0.2},
	
	on_place = function(itemstack, placer, pointed_thing)
		if pointed_thing.type ~= "node" then
			return
		end
		local place_pos = pointed_thing.under
		place_pos.y = place_pos.y+1.5
		-- check if there is enough free space for the carpet
		local check_pos = vector.round(place_pos)
		for x=-1,1 do
			for y=-1,0 do
				for z=-1,1 do
					local node = minetest.get_node({x=check_pos.x+x, y=check_pos.y+y, z=check_pos.z+z})
					local nodedef = minetest.registered_nodes[node.name]
					if not (not nodedef.walkable and nodedef.liquidtype == "none") then
						return
					end
				end
			end
		end

		-- check if carpet wouldn't collide with any nearby carpet
		local conflict_objects = minetest.get_objects_inside_radius(place_pos, math.sqrt(2)*1.5)
		for i=1, #conflict_objects do
			local le = conflict_objects[i]:get_luaentity()
			if le ~= nil and le.name == "flying_carpet:carpet" then
				return
			end
		end

		local ent = minetest.add_entity(place_pos, "flying_carpet:carpet")
		ent:setyaw(placer:get_look_yaw())
		itemstack:take_item()
		minetest.sound_play("flying_carpet_place", {pos = place_pos, gain = 1})
		return itemstack
	end,
})
