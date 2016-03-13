--Copyright 2014 gamemanj
--
--Licensed under the Apache License, Version 2.0 (the "License");
--you may not use this file except in compliance with the License.
--You may obtain a copy of the License at
--
--    http://www.apache.org/licenses/LICENSE-2.0
--
--Unless required by applicable law or agreed to in writing, software
--distributed under the License is distributed on an "AS IS" BASIS,
--WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--See the License for the specific language governing permissions and
--limitations under the License.
--
--tiers.lua: Robot types and recipes.

miners_robots.register_robot_type(
    --node name
    "miners_robots:robot_simple",
    --description
    "Miners Robot",
    --nodebox when off
    {"miners_robots_robot_off_top.png",
        "miners_robots_robot_bottom.png",
        "miners_robots_robot_side.png",
        "miners_robots_robot_side.png",
        "miners_robots_robot_back.png",
        "miners_robots_off_front.png"
   },
    --tex_on
    {"miners_robots_robot_on_top.png",
        "miners_robots_robot_on_bottom.png",
        "miners_robots_robot_on_side.png",
        "miners_robots_robot_on_side.png",
        "miners_robots_robot_on_back.png",
        "miners_robots_simple_front.png"
    },
    --tex_off
    {"miners_robots_robot_off_top.png",
        "miners_robots_robot_bottom.png",
        "miners_robots_robot_side.png",
        "miners_robots_robot_side.png",
        "miners_robots_robot_back.png",
        "miners_robots_off_front.png"},
    {"scout","miner","builder","inventory"}
)

minetest.register_craft({
	output = 'miners_robots:robot_simple_off',
	recipe = {
		{'default:steel_ingot', 'default:steel_ingot', 'default:steel_ingot'},
		{'default:glass', 'default:mese_crystal', 'group:stick'},
		{'default:steel_ingot', 'default:steel_ingot', 'default:steel_ingot'},
	}
})
