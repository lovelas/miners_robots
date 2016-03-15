--Copyright 2016 lovelas
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

--init.lua:miners_robots core.
--This file handles the core of miners_robots.
--It contains the basic programming interface,and functions to define robots.
--It also creates the miners_robots API.

--CONFIG
--NOTE:Configurations(and commands) for specific pages are in different files,1 for each page.
--     For example,TURNTIME is now in "page_scout.lua".
--     The code will be a lot easier to go through this way.

--Do not set CPUTIME to 0,it's there to prevent crashes!
local CPUTIME=1 --Time taken if more than 10 commands execute in a row without waiting. Must be >0.

if CPUTIME<0.05 then error("CPUTIME too low. Please do not disable this safety feature.") end
--Editing notes:
--Please use any editor with tab control!
--Turn off tabs!
--Also,please use LF, instead of CR or CR-LF, for your line endings.
--If you've been editing and have ignored this note,I have some tips for removing tabs:
--Notepad++:EDIT/BLANK OPERATIONS/TAB TO SPACE!
--Programmer's Notepad 2:EDIT/CONVERT TABS TO SPACES
--Gedit:sed init.lua "s/\t/    /"
--This note added because I once made a similar mistake. --gamemanj

--TODO LIST!
--1.Fix inventory commands. Currently they ignore metadata permissions.
--2.Add the ability to select inventories.
--  Rely on formspec.
--  If a slot isn't in the formspec,
--  then chances are it's not supposed to be visible.
--  As nice as support for locked chests is,
--  it's not so nice to be eaten by server owners.
--  Note that we CANNOT USE PIPEWORKS FOR THIS.
--  First,it's rather limited in support.
--  It actually relies on modifying nodes for default support,
--  which should say a lot by itself.
--  Second,AFAIK,Technic's Pipeworks support seems to be broken.
--         Can't get uranium out of a centrifuge? Tough luck, apparently only inserting works.
--  This problem might be usable to this mod's advantage :)

--API for miners_robots.
miners_robots={}

--Command pages. This table should be modified by mods wishing to add more pages.
--Command pages can have up to 7 commands in them.
miners_robots.commandpages={}
--Page sets. This table's values should be modified by mods wishing to add pages to existing tiers.
miners_robots.pagesets={}
--Commands. These are indexed by their name in capitals.
--This table should be modified by any mod wishing to add a command.
--Command functions are given the position of the robot,and the argument.
--They must return a value for the timer,or 0 if this only takes up CPU time,
--or nil if it should avoid doing anything to the node timer.
--Furthermore,the PC will NOT automatically advance.
--Use utility functions miners_robots.vm_advance and miners_robots.vm_lookup.
--They must be passed the timer value you want,
--and they will return either that,or nil(meaning the robot shutdown).
--This should be used somewhat like: return vm_advance(pos,MOVETIME)
--Movement commands should manually set the timer in the place they move to.
miners_robots.commands={}

--Custom metadata.
miners_robots.custommetas={}

--TODO:Make it so that command sets are indexed in a sane way.
--     At the moment,as all functions have some way of
--     getting the "robot which is turned on" block ID for this tier,that's used.
--TODO:Modularize commands.A simple API that relies on knowledge of the metas should work.
--     Things like movement should stay internal,
--     but commands with hardly any function dependencies can be exported.
--     (that is,all mining commands)
--     Probably best the "scout" page stay internal,"miner" "builder" "inventory" can be exported.
--     (Also,move vm_shutdown into the API,plus get rid of vm_p_mine and friends)

--NOTE:DO NOT CHANGE CODELINES!
local CODELINES=64

local license={
"miners_robots:Copyright 2016 lovelas",
"",
"Licensed under the Apache License, Version 2.0 (the \"License\");",
"you may not use this file except in compliance with the License.",
"You may obtain a copy of the License at",
"",
"    http://www.apache.org/licenses/LICENSE-2.0",
"",
"Unless required by applicable law or agreed to in writing, software",
"distributed under the License is distributed on an \"AS IS\" BASIS,",
"WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.",
"See the License for the specific language governing permissions and",
"limitations under the License.",
}
local licenseformspec="size[14,8] button_exit[0,7;2,1;exit;Close] "
for k,v in ipairs(license) do
    licenseformspec=licenseformspec.." label[0,"..(k/2)..";"..minetest.formspec_escape(v).."]"
end
--Send the license to the player. This is for the sake of server owners.
minetest.register_chatcommand("miners_robots_showlicense",
{
    params = "",
    description="Show the license notice for miners_robots.",
    func = function(name)
        minetest.show_formspec(name, "miners_robots:license", licenseformspec)
        return true, "Done."
    end,
})

--USELESS ENTITY(Basically abusing the 'player methods return safe values' behavior)
--on_step is there in case a "leak" occurs(object not removed).
--Seeing as leaks should not occur,and in fact should never occur unless something is broken,
--a warning is printed in the server log.
minetest.register_entity("miners_robots:fakeplayer",
{
    initial_properties = {
        hp_max = 1,
        physical = false,
    },
    on_step=function(self, dtime)
        print("WARNING:Fakeplayer object survived more than 1 tick.")
        print("This indicates a problem in the code.")
        print("Report this issue to the maintainer of this branch,")
        print("preferably working out which command caused this, under what conditions.")
        print("Coordinates of this bad robot are:"..(pos.x)..","..(pos.y)..","..(pos.z))
        self.object:remove()
    end,
})

--PROGRAMMER INTERFACE
local function genProgrammer(pages,meta)
    --current page
    local set=miners_robots.commandpages[meta:get_string("command_page")]
    local komendy=meta:get_string("set")
    --messy calculation for size
    local wid=0
    local res="size[17,7]"
    local pc=meta:get_int("robot_pc")
    res=res.."textlist[0,2;10.5,3;lines;"
    for l=1,CODELINES do
        if l~=1 then res=res.."," end
        if l==pc then
            res=res.."> "
        else
            res=res.."_ "
        end
        res=res..meta:get_string("program_"..l.."_op").." "..minetest.formspec_escape(meta:get_string("program_"..l.."_msg"))
    end
    res=res.."]"
    local pos=0
    --Note:Due to the bigger fields of 0.4.11,I've had to shuffle the layout a bit.
    for p,v in ipairs(pages) do
        res=res.."button["..pos..","..(wid-0.5)..";2,1;cmdpage"..p..";"..v.."]"
        pos=pos+2.2
    end
    --For some reason LN liked to equal 0.
    --Doesn't happen anymore,but may as well leave a perfectly good check.
   
    res=res.."label[3,0.5;Command:]"

    if meta:get_string("command_page") == "scout" or meta:get_string("command_page") == "inventory" then
        res=res.."label[7.5,0.5;How much:]"
        res=res.."field[8.5,1.3.1;1,1;value;;1]"
    end

    res=res.."button[9.5,0.9;1,1;confirm;OK]"

    res=res.."dropdown [0,1;8,1;choice;"
		for key, _ in pairs(set) do
			res = res .. key .. ","
		end
		res = string.sub(res, 1, -2)
		res = res .. ";1]"

    res=res.."label[11,-0.25;Player Inventory]"
    res=res.."label[11,4.2;Robot Inventory]"
    res=res.."list[current_player;main;11,0.25;6,4;]"
    res=res.."list[context;main;11,4.7;6,2;]"
    --Reset resets the robot,resume simply resumes it.
    res=res.."button[0,6;3,1;reset;Reset(goto 1)]"
    res=res.."button[3,6;2,1;resume;Resume]"
    res=res.."button[6,6;2,1;file;From File]"
    return res
end

function miners_robots.vm_get_wielded(pos)
    local meta=minetest.get_meta(pos)
    return meta:get_inventory():get_stack("main",meta:get_int("robot_slot"))
end
function miners_robots.vm_set_wielded(pos,is)
    local meta=minetest.get_meta(pos)
    return meta:get_inventory():set_stack("main",meta:get_int("robot_slot"),is)
end
--Fake player code.
--This doesn't have to be perfect,
--it just has to handle EXPECTED behaviors.
--Causing weird errors when a buggy item(that is, a item that crashes minetest if a real player uses it) comes along is fine,
--since that item should be tested by the author anyway(to state it another way:not my fault)
function miners_robots.vm_fakeplayer(name,pos,fp_control,selectedslot)
    local fake_player=minetest.add_entity(pos,"miners_robots:fakeplayer")
    local actual={}
    local actual_meta={}
    actual_meta.__index=function(tab,ind)
        --print("UNIMPLEMENTED ROBOT FUNCTION:"..ind)
        local i=fake_player[ind]
        return function(...) local a={...} a[1]=fake_player return i(unpack(a)) end
    end
    actual.get_player_name=function ()
        return name
    end
    actual.get_inventory=function (_)
        return minetest.get_meta(pos):get_inventory()
    end
    actual.get_wielded_item=function (_)
        return miners_robots.vm_get_wielded(pos)
    end
    actual.set_wielded_item=function (_,is)
        return miners_robots.vm_set_wielded(pos,is)
    end
    actual.get_player_control=function (_)
        return fp_control
    end
    actual.is_player=function (_)
        return true
    end
    setmetatable(actual,actual_meta)
    return actual
end

--Load/Save to/from meta
function miners_robots.meta_to_program(meta)
    local ser={}
    for x=1,CODELINES do
        ser[x]={}
        ser[x].op=meta:get_string("program_"..x.."_op")
        ser[x].msg=meta:get_string("program_"..x.."_msg")
    end
    return ser
end

function miners_robots.meta_to_program2(meta)
    local ser={}
    for x=1,CODELINES do
        ser[x]={}
        ser[x].op=meta:get_string("program_"..x.."_op")
        ser[x].msg=meta:get_string("program_"..x.."_msg")
    end
    return ser
end

function miners_robots.program_to_meta2(meta,ser)
local file = io.open(minetest.get_modpath("miners_robots").."/example_task_robot.txt", "r")
io.input(file)
wpis = io.read()
local lines = {}
 for x=1,CODELINES do
        lines[x]={}
        lines[x].op=io.read("*l")
        lines[x].msg=io.read("*n")
  end
    for x=1,CODELINES do
        meta:set_string("program_"..x.."_op",lines[x].op)
        meta:set_string("program_"..x.."_msg","1")
    end

 file:close()
end

function miners_robots.program_to_meta(meta,ser)
    for x=1,CODELINES do
        meta:set_string("program_"..x.."_op",ser[x].op)
        meta:set_string("program_"..x.."_msg",ser[x].msg)
    end
end
function miners_robots.robot_to_table(pos)
    local ser={}
    local meta=minetest.get_meta(pos)
    ser.pc=meta:get_int("robot_pc")
    ser.slot=meta:get_int("robot_slot")
    ser.owner=meta:get_string("robot_owner")
    ser.prog=miners_robots.meta_to_program(meta)
    ser.inv=meta:get_inventory():get_list("main")--All's fair in love,war,and minetest modding.
    ser.custommetas={}

    for k,v in pairs(miners_robots.custommetas) do
        if type(v)=="string" then
            ser.custommetas[k]=meta:get_string(k)
        end
        if type(v)=="number" then
            set.custommetas[k]=meta:get_int(k)
        end
    end
    return ser
end

function miners_robots.robot_to_table2(pos)
    local ser={}
    local meta=minetest.get_meta(pos)
    ser.pc=meta:get_int("robot_pc")
    ser.slot=meta:get_int("robot_slot")
    ser.owner=meta:get_string("robot_owner")
    ser.prog=miners_robots.meta_to_program2(meta)
    ser.inv=meta:get_inventory():get_list("main")--All's fair in love,war,and minetest modding.
    ser.custommetas={}

    for k,v in pairs(miners_robots.custommetas) do
        if type(v)=="string" then
            ser.custommetas[k]=meta:get_string(k)
        end
        if type(v)=="number" then
            set.custommetas[k]=meta:get_int(k)
        end
    end
    return ser
end

function miners_robots.table_to_robot(pos,ser)
    local meta=minetest.get_meta(pos)
    meta:set_int("robot_pc",ser.pc)
    meta:set_int("robot_slot",ser.slot)
    meta:set_string("robot_owner",ser.owner)
    miners_robots.program_to_meta(meta,ser.prog)
    ser.inv=meta:get_inventory():set_list("main",ser.inv)

    for k,v in pairs(ser.custommetas) do
        if type(v)=="string" then
            meta:set_string(k,v)
        end
        if type(v)=="number" then
            meta:set_int(k,v)
        end
    end
end

function miners_robots.table_to_robot2(pos,ser)
    local meta=minetest.get_meta(pos)
    meta:set_int("robot_pc",ser.pc)
    meta:set_int("robot_slot",ser.slot)
    meta:set_string("robot_owner",ser.owner)
    miners_robots.program_to_meta2(meta,ser.prog)
    ser.inv=meta:get_inventory():set_list("main",ser.inv)

    for k,v in pairs(ser.custommetas) do
        if type(v)=="string" then
            meta:set_string(k,v)
        end
        if type(v)=="number" then
            meta:set_int(k,v)
        end
    end
end

--Will shutdown the robot.
function miners_robots.shutdownat(pos)
    local ser=miners_robots.robot_to_table(pos)
    local tp=minetest.get_node(pos).name
    minetest.set_node(pos,{name=tp.."_off",param2=minetest.get_node(pos).param2})
    miners_robots.table_to_robot(pos,ser)
    local meta=minetest.get_meta(pos)
    --NOTE:When the node is created,command_page and such are reset.
    --But the formspec wasn't updated after miners_robots.table_to_robot.Fix that.
    meta:set_string("formspec",genProgrammer(miners_robots.pagesets[tp.."_off"],meta))
end

--vm_is_air:Is a block air?
function miners_robots.vm_is_air(nt)
    return nt.name=="" or nt.name=="air"
end

--vm_can_add:Simple permissions check,and check in case of solid blocks.
function miners_robots.vm_can_add(owner,pos)
    local nt=minetest.get_node(pos)
    if owner=="" then return false end
    local protected=minetest.is_protected(pos, owner)
    return (not protected) and miners_robots.vm_is_air(nt)
end

--vm_can_remove:Simple permissions check,and check in case of air.
function miners_robots.vm_can_remove(owner,pos)
    local nt=minetest.get_node(pos)
    if owner=="" then return false end
    local protected=minetest.is_protected(pos, owner)
    return (not protected) and (not miners_robots.vm_is_air(nt))
end

function miners_robots.vm_advance(pos,rtime)
    local meta=minetest.get_meta(pos)
    local pc=meta:get_int("robot_pc")
    if pc==CODELINES then meta:set_int("robot_pc",0) miners_robots.shutdownat(pos) return nil end
    meta:set_int("robot_pc",pc+1)
    return rtime
end
--This originally supported labels,but I removed them to simplify things.
--There's only 64 lines.
function miners_robots.vm_lookup(pos,label,rtime)
    local x=tonumber(label)
    local meta=minetest.get_meta(pos)
    if x~=nil then
        if (x>0) and (x<=CODELINES) then
            meta:set_int("robot_pc",x)
            return rtime
        end
    end
    meta:set_int("robot_pc",0)
    miners_robots.shutdownat(pos)
    return nil
end

--Main VM function.
--This returns true if the VM should continue running this tick.
local function vm_run(pos)
    local meta=minetest.get_meta(pos)
    local pc=meta:get_int("robot_pc")
    if pc==0 then miners_robots.shutdownat(pos) return nil end
    local command=meta:get_string("program_"..pc.."_op")
    local arg=meta:get_string("program_"..pc.."_msg")
    --print("RAN "..command)
    local cfunc=miners_robots.commands[command]
    if cfunc~=nil then
        return cfunc(pos,arg)
    end
    --Legacy commands
    --If this EVER happens,something is really wrong with the save file.
    print("Corrupted robot program @ "..(pos.x)..","..(pos.y)..","..(pos.z).." (not the fault of the robot's owner,this is save file corruption) missing command:"..tostring(command))
    miners_robots.shutdownat(pos)
    return nil
end

--VM RESET FUNCTION
--Used to avoid crashes should a "accident" happen.
function miners_robots.resetmeta(meta)
    local inv=meta:get_inventory()
    inv:set_size("main", 16)
    meta:set_string("robot_owner", "")
    for p=1,CODELINES do
        meta:set_string("program_"..p.."_op", "NOP")
        meta:set_string("program_"..p.."_msg", "")
    end
    --Runtime variables
    meta:set_int("robot_pc", 1)
    meta:set_int("robot_slot", 1)
    --Custom metadata
    for k,v in pairs(miners_robots.custommetas) do
        if type(v)=="string" then
            meta:set_string(k,v)
        end
        if type(v)=="number" then
            meta:set_int(k,v)
        end
    end
end

--ROBOT BLOCK
--Confusingly enough,commandpages as a argument means "the set of pages as strings this robot can use".
--miners_robots.commandpages is a table containing said pages.
function miners_robots.register_robot_type(nodeid,description,nodebox,tex_on,tex_off,pageset)
    --This is on purpose,as the _off variant can't be directly into a normal variant.
    --(Hence the only mechanism for turning a robot on is here.)
    miners_robots.pagesets[nodeid.."_off"]=pageset
    minetest.register_node(nodeid, {
        description = description.." (please don't place,won't set owner)",
        tiles = tex_on,
        --DON'T NODEBOX SOMETHING THAT WILL BE TELEPORTING ITSELF ONCE EVERY SECOND
        --drawtype = "nodebox",
        --node_box = nodebox,
        paramtype = "light",
        paramtype2 = "facedir",
        drop=nodeid.."_off",
        legacy_facedir_simple = true,
        is_ground_content = false,
        groups = {dig_immediate=2,not_in_creative_inventory=1},
        sounds = default.node_sound_defaults(),
        on_construct = function(pos)
            miners_robots.resetmeta(minetest.get_meta(pos))
            local tmr = minetest.get_node_timer(pos)
            tmr:start(1)
        end,
        on_timer = function (pos,elapsed)
            local i=0
            local running=false
            while (i<10) do
                local a=vm_run(pos)
                if a==nil then return false end --Nil means "quit VM now and do not do anything".
                i=i+1
                if a~=0 then
                    local tmr = minetest.get_node_timer(pos)
                    tmr:start(a)
                    return false
                end
            end
            --Either the robot 'crashed' or we're now animating. In this function,the difference is purely academic.
            local tmr = minetest.get_node_timer(pos)
            tmr:start(CPUTIME)
            return false
        end,
        on_rightclick = function (pos, node, clicker, itemstack)
            local meta=minetest.get_meta(pos)
            local own=meta:get_string("robot_owner")
            if (clicker:get_player_name()~=own) and own~="" then
                return
            end
            miners_robots.shutdownat(pos)
        end,
    })
    minetest.register_node(nodeid.."_off", {
        description = description,
        tiles = tex_off,
        drawtype = "nodebox",
        node_box = nodebox,
        paramtype = "light",
        paramtype2 = "facedir",
        legacy_facedir_simple = true,
        is_ground_content = false,
        groups = {dig_immediate=2},
        sounds = default.node_sound_defaults(),
        on_construct = function(pos)
            local meta = minetest.get_meta(pos)
            miners_robots.resetmeta(meta)
            meta:set_int("lineno",1)
            meta:set_string("command_page","scout")
            meta:set_string("formspec",genProgrammer(miners_robots.pagesets[nodeid.."_off"],meta))
        end,
        after_place_node = function (pos,placer,itemstack,pointed_thing)
            minetest.get_meta(pos):set_string("robot_owner",placer:get_player_name())
        end,
        on_receive_fields = function(pos, formname, fields, sender)
            local meta=minetest.get_meta(pos)
            local own=meta:get_string("robot_owner")
            if (sender:get_player_name()~=own) and own~="" then
                return
            end
            --CLAIMING OWNERSHIP OF A ROBOT WITH MISSING OWNER-TAG
            --(how can this happen,you may ask? naive worldeditors,that's how!)
            if (own=="") and fields.claim then
                meta:set_string("robot_owner",sender:get_player_name())
            end
            if fields.lines then
                if fields.lines:sub(1,4)=="CHG:" then
                    meta:set_int("lineno",tonumber(fields.lines:sub(5)))
                end
            end
            if fields.reset or fields.resume then
                local ser=miners_robots.robot_to_table(pos)
                if fields.reset then ser.pc=1 ser.slot=1 end
                minetest.set_node(pos,{name=nodeid,param2=minetest.get_node(pos).param2})
                --Timer is enabled by default (intentional!)
                miners_robots.table_to_robot(pos,ser)
                return --don't set formspec!!!
            end

              if fields.confirm  then
           
                            
                            local ln=meta:get_int("lineno")
                            if (ln~=nil) and (ln~=0) then
                                meta:set_string("program_"..ln.."_op",fields.choice)
                               meta:set_string("program_"..ln.."_msg",fields.value)
                            end
            end

              if fields.file  then
                 local ser=miners_robots.robot_to_table2(pos)
                 if fields.zpliku then ser.pc=1 ser.slot=1 end
                 minetest.set_node(pos,{name=nodeid,param2=minetest.get_node(pos).param2})
                 --Timer is enabled by default (intentional!)
                 miners_robots.table_to_robot2(pos,ser)
                 return --don't set formspec!!!
            end

            for k,v in ipairs(miners_robots.pagesets[nodeid.."_off"]) do
                if fields["cmdpage"..k] then
                    meta:set_string("command_page",v)
                end
                if meta:get_string("command_page")==v then
                    for k2,v2 in ipairs(miners_robots.commandpages[v]) do
                        if fields["cmd"..k2] then
                            local ln=meta:get_int("lineno")
                            if (ln~=nil) and (ln~=0) then
                                meta:set_string("program_"..ln.."_op",v2)
                                meta:set_string("program_"..ln.."_msg",fields["msg"..k2])
                            end
                        end
                    end
                end
            end

            meta:set_string("formspec",genProgrammer(miners_robots.pagesets[nodeid.."_off"],meta))
        end
    })
end

--The built-in command pages.
dofile(minetest.get_modpath(minetest.get_current_modname()).."/page_scout.lua")
dofile(minetest.get_modpath(minetest.get_current_modname()).."/page_miner.lua")
dofile(minetest.get_modpath(minetest.get_current_modname()).."/page_builder.lua")
dofile(minetest.get_modpath(minetest.get_current_modname()).."/page_inventory.lua")
--Tier definitions.
dofile(minetest.get_modpath(minetest.get_current_modname()).."/tiers.lua")

