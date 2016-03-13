--Copyright 2014 gamemanj
--
--Licensed under the Apache License, Version 2.0 (the "License");
--you may not use this file except in compliance with the License.
--You may obtain a copy of the License at
--
--	http://www.apache.org/licenses/LICENSE-2.0
--
--Unless required by applicable law or agreed to in writing, software
--distributed under the License is distributed on an "AS IS" BASIS,
--WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--See the License for the specific language governing permissions and
--limitations under the License.
--
--page_miner.lua:MINER PAGE

--MINER PAGE

local MINEPENALTYTIME=0 --Extra time needed to mine a block(a robot penalty if you will)
local PUNCHTIME=0.5 --Time taken to punch.

--"MINE IN FRONT" "MINE UP" "MINE DOWN"

-- gets the dug sound of a node
local function vm_get_node_dug_sound(name)
	local sound = minetest.registered_nodes[name]
	if not sound then
		return
	end
	sound = sound.sounds
	if not sound then
		return
	end
	sound = sound.dug
	if not sound then
		return
	end
	return sound
end

--Gets the nodedef.diggable property(with a sanity check)
local function vm_diggable(nodename)
	local nodedef = minetest.registered_nodes[nodename]
	if not nodedef then
		return
	end
	--I don't believe it is possible to dig a node you can't hit.
	return nodedef.diggable and nodedef.pointable
end

local function vm_mine(pos1, dir, arg)
	local pos2 = vector.add(pos1, dir)
	local node = minetest.get_node(pos2)
	if not vm_diggable(node.name) then
		return miners_robots.vm_lookup(pos1, arg, 0)
	end
	--For some insane reason,
	--this has to try both the current tool and the hand to find which is better.
	--For example,I can use a stone pickaxe to dig dirt.
	--But I can't do so DIRECTLY. I have to use the hand.
	local dp_pool = {}--Pool of "potential" digparams.
	local dp_result--Result.
	--Hand.(For some reason this must be included
	--	  or it becomes inconsistent with players)
	local groups = ItemStack({name=node.name}):get_definition().groups
	dp_pool[1] = minetest.get_dig_params(
		groups,
		ItemStack({name=":"}):get_tool_capabilities()
	)
	--Tool.
	local toolcaps = miners_robots.vm_get_wielded(pos1):get_tool_capabilities()
	dp_pool[2] = minetest.get_dig_params(
		groups,
		toolcaps
	)
	for k,v in ipairs(dp_pool) do
		--get_dig_params is undocumented @ wiki,but it works.
		--time:float,diggable:boolean
		if v.diggable then
			if not dp_result
			or dp_result.time > v.time then --Compare,to find the most time-efficient dig method.
				dp_result = v
			end
		end
	end
	--Check if unable to dig!
	if not dp_result then
		return miners_robots.vm_lookup(pos1, arg, 0)
	end
	local meta = minetest.get_meta(pos1)
	local fp = miners_robots.vm_fakeplayer(meta:get_string("robot_owner"), pos1, {sneak=false}, meta:get_int("robot_slot"))
	if not fp then
		return miners_robots.vm_lookup(pos1, arg, 0)
	end
	minetest.registered_nodes[node.name].on_dig(pos2, node, fp)
	fp:remove()
	--The block not being air is considered "failure".
	--HOWEVER,since the dig itself was a success,it takes time.
	if not miners_robots.vm_is_air(minetest.get_node(pos2)) then
		return miners_robots.vm_lookup(pos1, arg, dp_result.time+MINEPENALTYTIME)
	end

	local sound = vm_get_node_dug_sound(node.name)
	if sound then
		minetest.sound_play(sound.name, {pos=pos2, gain=sound.gain})
	end

	return miners_robots.vm_advance(pos1, dp_result.time+MINEPENALTYTIME)
end

miners_robots.commands["MINE IN FRONT"] = function(pos,arg)
	return vm_mine(pos,minetest.facedir_to_dir(minetest.get_node(pos).param2),arg)
end
miners_robots.commands["MINE UP"] = function(pos,arg)
	return vm_mine(pos,{x=0,y=1,z=0},arg)
end
miners_robots.commands["MINE DOWN"] = function(pos,arg)
	return vm_mine(pos,{x=0,y=-1,z=0},arg)
end


--PAGE DEFINITION

miners_robots.commandpages.miner = {["MINE IN FRONT"]="1",["MINE UP"]="2",["MINE DOWN"]="3"}

