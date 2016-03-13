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
--page_inventory.lua:INVENTORY PAGE

--INVENTORY PAGE

local DEPOSITTIME=1 --Time taken for a DEPOSIT.Does not scale with items.
local RETRIEVETIME=1 --Time taken for a RETRIEVE.Does not scale with items.

--Get front inventory
local function vm_getfrontinv(meta,pos)
	--Okay,first:Is there a inventory in front of us with a sub-inventory called "main"?
	--If so,it's either another robot(wow,robot transport!),a chest,or a node breaker :)
	--None are any loss.
	--(Course,I have yet to handle the case of locked chests,or really any inventory permissions stuff.)
	local pos2=vector.add(pos,minetest.facedir_to_dir(minetest.get_node(pos).param2))
	--Permissions check,and does a implict is_air test.(hence it exists)
	if not simple_robots.vm_can_remove(meta:get_string("robot_owner"),pos2) then return nil end
	local tgtmeta=minetest.get_meta(pos2)
	if not tgtmeta then
		return
	end
	local inv=tgtmeta:get_inventory()
	if not inv then return nil end
	if inv:get_size("main")<1 then return nil end
	return inv
end

--"SELECT SLOT"

simple_robots.commands["SELECT SLOT"]=function (pos,arg)
	local meta=minetest.get_meta(pos)
	local p=tonumber(arg)
	if p==nil then simple_robots.shutdownat(pos) return nil end
	if p<1 then simple_robots.shutdownat(pos) return nil end
	if p>16 then simple_robots.shutdownat(pos) return nil end
	meta:set_int("robot_slot",p)
	return simple_robots.vm_advance(pos,0)
end




--PAGE DEFINITION

simple_robots.commandpages["inventory"]={["SELECT SLOT"]="1"}
