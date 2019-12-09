--
-- Helper functions
--

function print_tabs(tabs)
	if not tabs then tabs = 1 end
	for i=1, tabs do
		_log_newlines_temp = true
		_log("\t")
	end
end

function _log_tabs(tabs, ...)
	print_tabs(tabs)
	_log(...)
end

function print_element(ele, delay, tabs, short)
	print_tabs(tabs)
	_log((short and "" or "Execute element ").."'"..ele.name.."' ["..ele.group.."] "..ele.id.." from "..ele.event..(delay and " (DELAY "..delay..")" or ""))
end

function vecstr(vec, rot)
	if rot then return "("..vecstr(vec:x())..", "..vecstr(vec:y())..", "..vecstr(vec:z())..")"
	else return "("..vec.x..", "..vec.y..", "..vec.z..")" end
end

function perform_element(vals, tabs)	-- vals = id or vals = {delay, id}
	if not tabs then tabs = 1 end
	local exec = false
	if type(vals) == "table" then exec = true end
	local do_ele = elements[exec and vals.id or vals]

	if inline[do_ele.group] then inline[do_ele.group](do_ele, (exec and vals.delay > 0) and vals.delay or false, tabs)
	else print_element(do_ele, (exec and vals.delay > 0) and vals.delay or false, tabs) end
end




_log_global_handle = io.open("mods/log.txt", "a")
local scripts = managers.mission._scripts
local compact = true
elements = {}
unit_ids = {}

-- We keep a stack (FIFO) of (non-inlined) elements to handle
-- We start with the startup script(s)
-- We keep another list to avoid dupes
local elements_to_do = {}
local elements_done = {}

-- Elements which can be inlined into usually at most a few lines
inline = {	["ElementPlayerSpawner"] = 
				function(ele, delay, tabs) 
					_log_tabs(tabs, "Create player spawn at position "..vecstr(ele.values.position)..(delay and " \t(DELAY "..delay..")" or "")) 
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementFleePoint"] = 
				function(ele, delay, tabs) 
					_log_tabs(tabs, "Create flee point at position "..vecstr(ele.values.position)..(delay and " \t(DELAY "..delay..")" or "")) 
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
				
			["ElementAIGraph"] =
				function(ele, delay, tabs)
					print_tabs(tabs)
					_log_newlines = false
					if ele.values.operation == "forbid_access" then _log("Forbid AI nav sections ")
					elseif ele.values.operation == "allow_access" then _log("Allow AI nav sections ") end
					for i,id in pairs(ele.values.graph_ids) do _log(id..(i < #ele.values.graph_ids and ", " or "")) end
					_log((delay and " (DELAY "..delay..")" or "").."\n")
					_log_newlines = true
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
				
			["ElementSpawnEnemyDummy"] = 
				function(ele, delay, tabs) 
					_log_tabs(tabs, "Spawn enemy unit {"..ele.values.enemy.."} at position "..vecstr(ele.values.position)..(delay and " \t(DELAY "..delay..")" or ""))
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementSpawnCivilian"] =
				function(ele, delay, tabs) 
					_log_tabs(tabs, "Spawn civilian unit {"..ele.values.enemy.."} at position "..vecstr(ele.values.position)..(delay and " \t(DELAY "..delay..")" or ""))
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
				
			["ElementActivateScript"] = 
				function(ele, delay, tabs) 
					_log_tabs(tabs, "Activate script '"..ele.values.activate_script.."'"..(delay and " \t(DELAY "..delay..")" or "")) 
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
				
			["ElementSpecialObjective"] =
				function(ele, delay, tabs)
					if ele.values.is_navigation_link then 
						_log_tabs(tabs, "Create navigation link for "..(ele.values.use_instigator and "instigator" or ele.values.ai_group).." from position "..vecstr(ele.values.position).." to "..vecstr(ele.values.search_position).." with action "..ele.values.so_action..(delay and " \t(DELAY "..delay..")" or ""))
					else _log_tabs(tabs, "Create objective for "..(ele.values.use_instigator and "instigator" or ele.values.ai_group).." around position "..vecstr(ele.values.search_position)..(ele.values.search_distance > 0 and " with radius "..ele.values.search_distance or "")..(ele.values.so_action == "none" and "" or " with action "..ele.values.so_action)..(delay and " \t(DELAY "..delay..")" or "")) end
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementDebug"] =
				function(ele, delay, tabs, path)
					if not path then path = {} end
					if path[ele.id] then 
						_log_tabs(tabs, "[Loop previous ElementDebug elements]") 
						return
					end
					path[ele.id] = true
					
					_log_tabs(tabs, "Print debug string '"..ele.values.debug_string.."'"..(delay and " \t(DELAY "..delay..")" or ""))
					for _,vals in pairs(ele.values.on_executed) do
						if elements[vals.id].group == "ElementDebug" then
							inline["ElementDebug"](elements[vals.id], vals.delay > 0 and vals.delay or false, tabs, path)
						else perform_element(vals, tabs) end
					end
				end,
			
			["ElementDialogue"] =
				function(ele, delay, tabs, path)
					if not path then path = {} end
					if path[ele.id] then 
						_log_tabs(tabs, "[Loop previous ElementDialogue elements]") 
						return
					end
					path[ele.id] = true
					
					_log_tabs(tabs, "Play dialogue '"..ele.values.dialogue.."'"..(delay and " \t(DELAY "..delay..")" or ""))
					for _,vals in pairs(ele.values.on_executed) do
						if elements[vals.id].group == "ElementDialogue" then
							inline["ElementDialogue"](elements[vals.id], vals.delay > 0 and vals.delay or false, tabs, path)
						else perform_element(vals, tabs) end
					end
				end,
			
			["ElementEnemyPreferedAdd"] =
				function(ele, delay, tabs)
					if delay then _log_tabs(tabs, "Perform '"..ele.name.."':"..(delay and " \t(DELAY "..delay..")" or "")) end
					for _,point in pairs(ele._raw._group_data.spawn_points) do _log_tabs(delay and tabs + 1 or tabs, "Add preferred spawn point for {"..point._values.enemy.."} with action "..point._values.spawn_action.." at "..vecstr(point._values.position)) end
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementEnemyPreferedRemove"] =
				function(ele, delay, tabs)
					for _,id in pairs(ele.values.elements) do _log_tabs(tabs, "Remove all preferred spawn points associated with '"..elements[id].name.."'"..(delay and " \t(DELAY "..delay..")" or "")) end
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementPlaySound"] =
				function(ele, delay, tabs)
					if #ele.values.elements > 0 then
						_log_tabs(tabs, "Play sound '"..ele.values.sound_event.."' from units:"..(delay and " \t(DELAY "..delay..")" or ""))
						for _,id in pairs(ele.values.elements) do
							local do_ele = elements[id]
							_log_tabs(tabs + 1, "- {"..do_ele.values.enemy.."} from element '"..do_ele.name.."'")
						end
					else
						_log_tabs(tabs, "Play sound '"..ele.values.sound_event.."'"..(delay and " \t(DELAY "..delay..")" or ""))
					end
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementFakeAssaultState"] =
				function(ele, delay, tabs) 
					_log_tabs(tabs, (ele.values.state and "Enable " or "Disable ").."fake assault state"..(delay and " \t(DELAY "..delay..")" or ""))
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
				
			["ElementTeammateComment"] =
				function(ele, delay, tabs, path)
					if not path then path = {} end
					if path[ele.id] then 
						_log_tabs(tabs, "[Loop previous ElementTeammateComment elements]") 
						return
					end
					path[ele.id] = true
					
					_log_tabs(tabs, "Make teammates "..(ele.values.use_instigator and "close to instigator " or "").."say '"..ele.values.comment.."'"..(delay and " \t(DELAY "..delay..")" or "")) 
					for _,vals in pairs(ele.values.on_executed) do 
						if elements[vals.id].group == "ElementTeammateComment" then
							inline["ElementTeammateComment"](elements[vals.id], vals.delay > 0 and vals.delay or false, tabs, path)
						else perform_element(vals, tabs) end
					end
				end,
				
			["ElementToggle"] =
				function(ele, delay, tabs)
					for _,id in pairs(ele.values.elements) do
						local do_ele = elements[id]
						if do_ele.group == "ElementWaypoint" then inline["ElementWaypoint"](do_ele, false, delay and tabs + 1 or tabs, ele.values.toggle == "off")
						else _log_tabs(tabs, "Toggle "..(ele.values.toggle == "on" and "ON " or (ele.values.toggle == "off" and "OFF " or " ")).."element '"..do_ele.name.."' ["..do_ele.group.."] "..do_ele.id.." from "..do_ele.event..(delay and " \t(DELAY "..delay..")" or "")) end
					end
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementMoney"] =
				function(ele, delay, tabs)
					local size = tweak_data.experience_manager.actions[ele.values.action]
					local points = tweak_data.experience_manager.values[size]
					_log_tabs(tabs, "Award players money/experience for action '"..ele.values.action.."' which is worth "..points.." points"..(delay and " \t(DELAY "..delay..")" or ""))
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
				
			["ElementAIRemove"] =
				function(ele, delay, tabs)
					if ele.values.use_instigator then _log_tabs(tabs, "Remove/Kill AI instigator from the level"..(delay and " \t(DELAY "..delay..")" or ""))
					else 
						if delay then _log_tabs(tabs, "Perform '"..ele.name.."':"..(delay and " \t(DELAY "..delay..")" or "")) end
						for _,vals in pairs(ele.values.elements) do
							local do_ele = elements[vals]
							_log_tabs(delay and tabs + 1 or tabs, "Remove/Kill unit {"..do_ele.values.enemy.."} from element '"..do_ele.name.."'")
						end
					end
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
				
			["ElementObjective"] =
				function(ele, delay, tabs)
					_log_tabs(tabs, (ele.values.state:gsub("^%l", string.upper)).." objective '"..ele.values.objective.."'"..(ele.values.sub_objective ~= "none" and " with sub-objective '"..ele.values.sub_objective.."'" or "").." at position "..vecstr(ele.values.position)..(delay and " \t(DELAY "..delay..")" or ""))
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
				
			["ElementWaypoint"] =
				function(ele, delay, tabs, rem)
					_log_tabs(tabs, (rem and "Remove " or "Add ").."waypoint with text '"..managers.localization:text(ele.values.text_id).."' and icon "..ele.values.icon..(rem and " from " or " at ")..vecstr(ele.values.position)..(delay and " \t(DELAY "..delay..")" or ""))
					if not rem then for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end end
				end,
				
			["ElementDangerZone"] =
				function(ele, delay, tabs)
					_log_tabs(tabs, "Set danger zone level to "..ele.values.level..(delay and " \t(DELAY "..delay..")" or ""))
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
				
			["ElementDisableUnit"] =
				function(ele, delay, tabs)
					if #ele.values.unit_ids == 1 then
						local unit = unit_ids[ele.values.unit_ids[1]]
						_log_tabs(tabs, "Disable unit {"..unit.name.."} at "..vecstr(unit.position)..(delay and " \t(DELAY "..delay..")" or ""))
						for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
					else
						if delay then _log_tabs(tabs, "Perform '"..ele.name.."':"..(delay and " \t(DELAY "..delay..")" or "")) end
						for _,id in pairs(ele.values.unit_ids) do
							local unit = unit_ids[id]
							_log_tabs(delay and tabs + 1 or tabs, "Disable unit {"..unit.name.."} at "..vecstr(unit.position))
						end
						for _,vals in pairs(ele.values.on_executed) do perform_element(vals, delay and tabs + 1 or tabs) end
					end
				end,
			
			["ElementBlurZone"] =
				function(ele, delay, tabs) 
					_log_tabs(tabs, "Set blurzone to mode "..ele.values.mode.." with height "..ele.values.height.." and radius "..ele.values.radius.." at "..vecstr(ele.values.position)..(delay and " \t(DELAY "..delay..")" or "")) 
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementDifficultyLevelCheck"] =
				function(ele, delay, tabs)
					_log_tabs(tabs, "If difficulty is at least "..(ele.values.difficulty == "overkill_145" and "Overkill 145+" or (ele.values.difficulty:gsub("^%l", string.upper))).." then perform:"..(delay and " \t(DELAY "..delay..")" or ""))
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs + 1) end
				end,
			
			["ElementMaskFilter"] = 
				function(ele, delay, tabs)
					if ele.values.mask == "none" then _log_tabs(tabs, "Remove any applied mask filter"..(delay and " \t(DELAY "..delay..")" or ""))
					else _log_tabs(tabs, "Change mask filter to '"..ele.values.mask.."'"..(delay and " \t(DELAY "..delay..")" or "")) end
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementScenarioEvent"] =
				function(ele, delay, tabs)
					_log_tabs(tabs, ele.values.base_chance * 100 .. "% base chance with "..ele.values.chance_inc * 100 .."% increase to use spawn event with task '"..ele.values.task.."' "..ele.values.amount.." time"..(ele.values.amount > 1 and "s" or "").." at position "..vecstr(ele.values.position)..(delay and " \t(DELAY "..delay..")" or ""))
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementOperator"] = 
				function(ele, delay, tabs)
					if delay then _log_tabs(tabs, "Perform '"..ele.name.."':"..(delay and " \t(DELAY "..delay..")" or "")) end
					for _,id in pairs(ele.values.elements) do
						local do_ele = elements[id]
						if do_ele.group == "ElementWaypoint" then inline["ElementWaypoint"](do_ele, false, delay and tabs + 1 or tabs, ele.values.operation == "remove")
						else _log_tabs(delay and tabs + 1 or tabs, (ele.values.operation:gsub("^%l", string.upper)).." element '"..do_ele.name.."' ["..do_ele.group.."] "..do_ele.id.." from "..do_ele.event) end
					end
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementAiGlobalEvent"] =
				function(ele, delay, tabs)
					_log_tabs(tabs, "Trigger global AI event '"..ele.values.event.."'"..(delay and " \t(DELAY "..delay..")" or ""))
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementLogicChance"] =
				function(ele, delay, tabs)
					-- NOTE: This element should not actually be inlined when compared to the other elements
					-- But, since [ElementLogicChanceOperator] gets used so sparingly, making this inlined greatly improves readability
					_log_tabs(tabs, "Roll the dice with "..ele.values.chance.."% chance to succeed."..(delay and " \t(DELAY "..delay..")" or ""))
					local fails = {}
					local successes = {}
					
					for _,vals in pairs(ele.values.on_executed) do table.insert(successes, vals) end
					for id,vals in pairs(ele._raw._triggers) do 
						if vals.outcome == "success" then table.insert(successes, id)
						elseif vals.outcome == "fail" then table.insert(fails, id) end
					end
					
					if #successes > 0 then 
						_log_tabs(tabs, "On success, perform:")
						for _,vals in pairs(successes) do perform_element(vals, tabs + 1) end
					end
					
					if #fails > 0 then
						_log_tabs(tabs, "On failure, perform:")
						for _,vals in pairs(fails) do perform_element(vals, tabs + 1) end
					end
				end,
			
			["ElementRandom"] =
				function(ele, delay, tabs)
					_log_tabs(tabs, "Execute at random "..ele.values.amount.." of the following elements:"..(delay and " \t(DELAY "..delay..")" or ""))
					for id,vals in pairs(ele.values.on_executed) do 
						local do_ele = elements[vals.id]
						_log_tabs(tabs + 1, id..") '"..do_ele.name.."'"..(vals.delay > 0 and " \t(DELAY "..vals.delay..")" or ""))					
					end
				end,
			
			["ElementUnitSequence"] =
				function(ele, delay, tabs)
					if delay then _log_tabs(tabs, "Perform '"..ele.name.."':"..(delay and " \t(DELAY "..delay..")" or "")) end
					for _,vals in pairs(ele.values.trigger_list) do
						local unit = unit_ids[vals.notify_unit_id]
						if vals.name == "run_sequence" then _log_tabs(delay and tabs + 1 or tabs, "Run sequence '"..vals.notify_unit_sequence.."' on unit {"..unit.name.."} at "..vecstr(unit.position)..(tonumber(vals.time) > 0 and " \t(DELAY "..vals.time..")" or "")) end
					end
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, delay and tabs + 1 or tabs) end
				end,
			
			["ElementFilter"] =
				function(ele, delay, tabs)
					local diffs = ""
					if ele.values.difficulty_easy then diffs = diffs..", Easy" end
					if ele.values.difficulty_normal then diffs = diffs..", Normal" end
					if ele.values.difficulty_hard then diffs = diffs..", Hard" end
					if ele.values.difficulty_overkill then diffs = diffs..", Overkill" end
					if ele.values.difficulty_overkill_145 then diffs = diffs..", Overkill 145+" end
					
					local modes = "{"..(ele.values.mode_assault and (ele.values.mode_control and "assault, control" or "assault") or ele.values.mode_control and "control" or "N/A").."}"
					local player_count = ele.values.player_4 and 4 or (ele.values.player_3 and 3 or (ele.values.player_2 and 2 or (ele.values.player_1 and 1 or "N/A")))
					local platform = ele.values.platform_win32 and "WIN32" or "PS3"
					
					_log_tabs(tabs, "If difficulty is in {"..(diffs:sub(3)).."} and the current mode is in "..modes.." and the player count is "..player_count.." and the platform is '"..platform.."' then perform:"..(delay and " \t(DELAY "..delay..")" or ""))
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs + 1) end
				end,
				
			["ElementSpawnEnemyGroup"] =
				function(ele, delay, tabs)
					_log_tabs(tabs, "Spawn "..ele.values.amount.." enemies in "..(ele.values.random and "randomly picked spawn points from:" or "the following spawn points:"..(delay and " \t(DELAY "..delay..")" or "")))
					for id,point in pairs(ele._raw._group_data.spawn_points) do _log_tabs(tabs + 1, id..") {"..point._values.enemy.."} at "..vecstr(point._values.position)) end
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
				
			["ElementSpawnCivilianGroup"] =
				function(ele, delay, tabs)
					_log_tabs(tabs, "Spawn "..ele.values.amount.." civilians in "..(ele.values.random and "randomly picked spawn points from:" or "the following spawn points:"..(delay and " \t(DELAY "..delay..")" or "")))
					for id,point in pairs(ele._raw._group_data.spawn_points) do _log_tabs(tabs + 1, id..") {"..point._values.enemy.."} at "..vecstr(point._values.position)) end
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
				
			["ElementAwardAchievment"] =
				function(ele, delay, tabs)
					if not managers.challenges._challenges_map[ele.values.achievment] then _log_tabs(tabs, "Award achievement '"..ele.values.achievment.."'\t(achievement doesn't exist anymore, probably removed but forget to edit the map)"..(delay and " \t(DELAY "..delay..")" or ""))
					else
						local title = managers.localization:text(managers.challenges._challenges_map[ele.values.achievment].title_id)
						_log_tabs(tabs, "Award achievement '"..title.."'"..(delay and " \t(DELAY "..delay..")" or ""))
					end
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementCharacterOutline"] =
				function(ele, delay, tabs)
					_log_tabs(tabs, "Enable outline for all civilians that have the property 'outline_on_discover'"..(delay and " \t(DELAY "..delay..")" or ""))
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementCounterReset"] =
				function(ele, delay, tabs)
					if delay then _log_tabs(tabs, "Perform '"..ele.name.."':"..(delay and " \t(DELAY "..delay..")" or "")) end
					for _,vals in pairs(ele.values.elements) do
						_log_tabs(delay and tabs + 1 or tabs, "Reset counter '"..elements[vals].name.."' with counter target "..ele.values.counter_target)
					end
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementDifficulty"] =
				function(ele, delay, tabs)
					_log_tabs(tabs, "Set difficulty to "..ele.values.difficulty..(delay and " \t(DELAY "..delay..")" or ""))
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
				
			["ElementDropinState"] =
				function(ele, delay, tabs)
					_log_tabs(tabs, (ele.values.state and "Enable " or "Disable ").."drop-in for players"..(delay and " \t(DELAY "..delay..")" or ""))
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementEquipment"] =
				function(ele, delay, tabs)
					_log_tabs(tabs, "Give instigator "..ele.values.amount.." of equipment '"..ele.values.equipment.."'"..(delay and " \t(DELAY "..delay..")" or ""))
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementExecuteInOtherMission"] = 
				function(ele, delay, tabs)
					if delay then _log_tabs(tabs, "Perform '"..ele.name.."':"..(delay and " \t(DELAY "..delay..")" or "")) end
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, delay and tabs + 1 or tabs) end
				end,
			
			["ElementFeedback"] =
				function(ele, delay, tabs)
					_log_tabs(tabs, "Cause screen shake with"..(ele.values.use_camera_shake and "" or "out").." camera shake and with"..(ele.values.use_rumble and "" or "out").." rumble"..(delay and " \t(DELAY "..delay..")" or ""))
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementHint"] =
				function(ele, delay, tabs)
					_log_tabs(tabs, "Show hint '"..managers.localization:text(managers.hint:hint(ele.values.hint_id).text_id).."'"..(delay and " \t(DELAY "..delay..")" or ""))
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
				
			["ElementKillZone"] = 
				function(ele, delay, tabs)
					_log_tabs(tabs, "Create killzone for instigator of damage type '"..ele.values.type.."'"..(delay and " \t(DELAY "..delay..")" or ""))
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementLogicChanceOperator"] =
				function(ele, delay, tabs)
					if delay then _log_tabs(tabs, "Perform '"..ele.name.."':"..(delay and " \t(DELAY "..delay..")" or "")) end
					for _,id in pairs(ele.values.elements) do
						if ele.values.operation == "add_chance" then _log_tabs(delay and tabs + 1 or tabs, "Add chance of "..ele.values.chance.."% to the logic chance element '"..elements[id].name.."'")
						elseif ele.values.operation == "subtract_chance" then _log_tabs(delay and tabs + 1 or tabs, "Subtract chance of "..ele.values.chance.."% to the logic chance element '"..elements[id].name.."'")
						elseif ele.values.operation == "reset" then _log_tabs(delay and tabs + 1 or tabs, "Reset chance of the logic chance element '"..elements[id].name.."'")
						elseif ele.values.operation == "set_chance" then _log_tabs(delay and tabs + 1 or tabs, "Set the chance of the logic chance element '"..elements[id].name.."' to "..ele.values.chance.."%") end
					end
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementMissionEnd"] =
				function(ele, delay, tabs)
					_log_tabs(tabs, "End the current level/mission with state '"..ele.values.state.."'"..(delay and " \t(DELAY "..delay..")" or ""))
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementPlayEffect"] =
				function(ele, delay, tabs)
					_log_tabs(tabs, "Play effect {"..ele.values.effect.."} "..(ele.values.screen_space and "on player HUD" or "at position "..ele.values.position)..(delay and " \t(DELAY "..delay..")" or ""))
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementStopEffect"] =
				function(ele, delay, tabs)
					if delay then _log_tabs(tabs, "Perform '"..ele.name.."':"..(delay and " \t(DELAY "..delay..")" or "")) end
					for _,vals in pairs(ele.values.elements) do
						_log_tabs(delay and tabs + 1 or tabs, "Stop effect {"..elements[vals].values.effect.."}"..(ele.values.operation == "fade_kill" and " with fade-out" or ""))
					end
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementPlayerState"] =
				function(ele, delay, tabs)
					_log_tabs(tabs, "Change player state to '"..ele.values.state.."'"..(delay and " \t(DELAY "..delay..")" or ""))
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementPointOfNoReturn"] =
				function(ele, delay, tabs)
					_log_tabs(tabs, "Enable 'Point Of No Return' timer:"..(delay and " \t(DELAY "..delay..")" or ""))
					_log_tabs(tabs + 1, "If difficulty is 'Easy' then set timer to "..ele.values.time_easy.." seconds")
					_log_tabs(tabs + 1, "If difficulty is 'Normal' then set timer to "..ele.values.time_normal.." seconds")
					_log_tabs(tabs + 1, "If difficulty is 'Hard' then set timer to "..ele.values.time_hard.." seconds")
					_log_tabs(tabs + 1, "If difficulty is 'Overkill' then set timer to "..ele.values.time_overkill.." seconds")
					_log_tabs(tabs + 1, "If difficulty is 'Overkill 145+' then set timer to "..ele.values.time_overkill_145.." seconds")
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementSecretAssignment"] =
				function(ele, delay, tabs)
					-- NOTE: This element is deprecated and not used by the game.
					-- This used to be an extra assignment, like killing the bank manager or not having a certain civilian escape.
					-- But, for some reason this never made it into the final game.
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementAreaMinPoliceForce"] =
				function(ele, delay, tabs)
					_log_tabs(tabs, "Enable gathering point for "..ele.values.amount.." enemies at position "..vecstr(ele.values.position)..(delay and " \t(DELAY "..delay..")" or ""))
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementExplosionDamage"] =
				function(ele, delay, tabs)
					_log_tabs(tabs, "Create explosion at "..vecstr(ele.values.position).." with linear damage fall-off starting at "..ele.values.damage.." damage with a maximum range of "..ele.values.range..(delay and " \t(DELAY "..delay..")" or ""))
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementLogicChanceTrigger"] =
				function(ele, delay, tabs)
					-- Can be inlined since all the logic is handled in [ElementLogicChance]
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementSmokeGrenade"] =
				function(ele, delay, tabs)
					_log_tabs(tabs, "Create smoke grenade at "..vecstr(ele.values.position).." for "..ele.values.duration.." seconds"..(delay and " \t(DELAY "..delay..")" or ""))
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementFlashlight"] =
				function(ele, delay, tabs)
					_log_tabs(tabs, "Turn "..(ele.values.state and "on " or "off ").."flashlights "..(ele.values.on_player and "on player" or "in world")..(delay and " \t(DELAY "..delay..")" or ""))
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementWhisperState"] =
				function(ele, delay, tabs)
					_log_tabs(tabs, (ele.values.state and "Enable " or "Disable ").."whisper mode (controls what shouting at any enemy does)"..(delay and " \t(DELAY "..delay..")" or ""))
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementTimerTrigger"] =
				function(ele, delay, tabs)
					-- Can be inlined since all the logic is handled in [ElementTimer]
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementTimerOperator"] =
				function(ele, delay, tabs)
					if delay then _log_tabs(tabs, "Perform '"..ele.name.."':"..(delay and " \t(DELAY "..delay..")" or "")) end
					for _,id in pairs(ele.values.elements) do
						local do_ele = elements[id]
						if ele.values.operation == "pause" then _log_tabs(delay and tabs + 1 or tabs, "Pause timer '"..do_ele.name.."'")
						elseif ele.values.operation == "start" then _log_tabs(delay and tabs + 1 or tabs, "Start timer '"..do_ele.name.."'")
						elseif ele.values.operation == "add_time" then _log_tabs(delay and tabs + 1 or tabs, "Add "..ele.values.time.." seconds to timer '"..do_ele.name.."'")
						elseif ele.values.operation == "subtract_time" then _log_tabs(delay and tabs + 1 or tabs, "Subtract "..ele.values.time.." seconds to timer '"..do_ele.name.."'")
						elseif ele.values.operation == "reset" then _log_tabs(delay and tabs + 1 or tabs, "Reset timer '"..do_ele.name.."'")
						elseif ele.values.operation == "set_time" then _log_tabs(delay and tabs + 1 or tabs, "Set timer '"..do_ele.name.."' to "..ele.values.time.." seconds") end
					end
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementDisableShout"] =
				function(ele, delay, tabs)
					if delay then _log_tabs(tabs, "Perform '"..ele.name.."':"..(delay and " \t(DELAY "..delay..")" or "")) end
					for _,id in pairs(ele.values.elements) do
						local do_ele = elements[id]
						_log_tabs(delay and tabs + 1 or tabs, (ele.values.disable_shout and "Disable " or "Enable ").."shouting against unit {"..do_ele.values.enemy.."} from element '"..do_ele.name.."'")
					end
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementSequenceCharacter"] =
				function(ele, delay, tabs)
					if delay then _log_tabs(tabs, "Perform '"..ele.name.."':"..(delay and " \t(DELAY "..delay..")" or "")) end
					for _,id in pairs(ele.values.elements) do
						local do_ele = elements[id]
						_log_tabs(delay and tabs + 1 or tabs, "Run sequence '"..ele.values.sequence.."' on unit {"..do_ele.values.enemy.."} from element '"..do_ele.name.."'")
					end
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementSetOutline"] =
				function(ele, delay, tabs)
					if delay then _log_tabs(tabs, "Perform '"..ele.name.."':"..(delay and " \t(DELAY "..delay..")" or "")) end
					for _,id in pairs(ele.values.elements) do
						local do_ele = elements[id]
						_log_tabs(delay and tabs + 1 or tabs, (ele.values.set_outline and "Enable " or "Disable ").."outline on unit {"..do_ele.values.enemy.."} from element '"..do_ele.name.."'")
					end
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementBainState"] =
				function(ele, delay, tabs)
					_log_tabs(tabs, "Turn Bain "..(ele.values.state and "on" or "off")..(delay and " \t(DELAY "..delay..")" or ""))
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementBlackscreenVariant"] =
				function(ele, delay, tabs)
					_log_tabs(tabs, "Set blackscreen to variant "..ele.values.variant..(delay and " \t(DELAY "..delay..")" or ""))
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementOverlayEffect"] =
				function(ele, delay, tabs)
					_log_tabs(tabs, "Activate overlay effect '"..ele.values.effect.."'"..(delay and " \t(DELAY "..delay..")" or ""))
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end,
			
			["ElementPlayerStyle"] = 
				function(ele, delay, tabs)
					_log_tabs(tabs, "Change player look to style '"..ele.values.style.."'"..(delay and " \t(DELAY "..delay..")" or ""))
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, tabs) end
				end
		}
				
-- Elements which (can) stand on their own
noinline = {["MissionScriptElement"] =
				function(ele)
					-- NOTE: This is the element that does most of the game logic, nothing specifically special though.
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals) end
				end,

			["ElementCounter"] =
				function(ele)
					_log("\tWhen counter target "..ele.values.counter_target.." is reached, perform:")
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, 2) end
				end,
			
			["ElementAreaTrigger"] =
				function(ele)
					_log("\tTrigger shape (HxWxD): "..ele.values.height.." x "..ele.values.width.." x "..ele.values.depth.." at position "..vecstr(ele.values.position))
					_log("\tTrigger instigator: "..ele.values.instigator)
					_log("\tWhen trigger condition '"..ele.values.trigger_on.."' is met, perform:")
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, 2) end
				end,
			
			["ElementUnitSequenceTrigger"] =
				function(ele)
					_log("\tIf any of the following sequences get triggered:")
					for id, vals in pairs(ele.values.sequence_list) do
						if vals.unit_id == 0 then _log("\t\t"..id..") no unit runs '"..vals.sequence.."'\t\t(probably deprecated or for debugging only)")
						elseif not unit_ids[vals.unit_id] then _log("\t\t#TODO unit_id "..vals.unit_id.." cannot be resolved to a unit!")
						else _log("\t\t"..id..") {"..unit_ids[vals.unit_id].name.."} runs '"..vals.sequence.."'") end
					end
					_log("\tThen perform:")
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, 2) end
				end,
				
			["ElementEnemyDummyTrigger"] =
				function(ele)
					_log("\tIf event '"..ele.values.event.."' gets executed by any of:")
					for i,id in pairs(ele.values.elements) do 
						local enemy = elements[id].values.enemy or (elements[id]._raw._spawn_points and elements[id]._raw._spawn_points[1]._values.enemy or ((elements[id]._raw._group_data and #elements[id]._raw._group_data.spawn_points > 0) and elements[id]._raw._group_data.spawn_points[1]._values.enemy or "#TODO unknown"))--)
						_log("\t\t"..i..") {"..enemy.."} from element '"..elements[id].name.."'") 
					end
					_log("\tThen perform:")
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, 2) end
				end,
				
			["ElementSpecialObjectiveTrigger"] =
				function(ele)
					for i,id in pairs(ele.values.elements) do
						local do_ele = elements[id]
						_log("\tWhen one of AI "..do_ele.values.ai_group.." that are following special objective '"..do_ele.values.so_action.."' from element '"..do_ele.name.."' performs event '"..ele.values.event.."' "..(i == #ele.values.elements and "then perform:" or "OR"))
					end
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, 2) end
				end,
			
			["ElementGlobalEventTrigger"] =
				function(ele)
					_log("\tUpon global event '"..ele.values.global_event.."', perform:")
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, 2) end
				end,
			
			["ElementLookAtTrigger"] =
				function(ele)
					_log("\t[position = "..vecstr(ele.values.position).."]")
					_log("\t[rotation = "..vecstr(ele.values.rotation, true).."]")
					_log("\t[distance = "..ele.values.distance.."]")
					_log("\t[sensitivity = "..ele.values.sensitivity.."]")
					_log("\t[in_front = "..(ele.values.in_front and "true" or "false").."]")
					_log("\tAccording to the above values, wait for player to move to 'position' with (camera) 'rotation'.")
					_log("\t'distance' is the max distance between player location and 'position'.")
					_log("\tDot product must exceed 'sensitivity'.")
					_log("\tWhen these conditions are met, perform:")
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, 2) end
				end,
			
			["ElementPlayerStateTrigger"] =
				function(ele)
					_log("\tWhen player state is changed to '"..ele.values.state.."' perform:")
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, 2) end
				end,
			
			["ElementAlertTrigger"] =
				function(ele)
					_log("\tCreate an alert listener at "..vecstr(ele.values.position))
					_log("\tWhen the alert gets triggered by sound of a bullet shot, perform:")
					for _,vals in pairs(ele.values.on_executed) do perform_element(vals, 2) end
				end,
			
			["ElementTimer"] =
				function(ele)
					_log("\tCreate timer with an initial time of "..ele.values.timer.." seconds")
					local done_exec = false
					for id, vals in pairs(ele._raw._triggers) do
						_log("\tWhen the timer has "..vals.time.." seconds left, perform:")
						for _,v in pairs(elements[id].values.on_executed) do perform_element(v, 2) end
						if vals.time == 0 then
							done_exec = true
							for _,v in pairs(ele.values.on_executed) do perform_element(v, 2) end
						end
					end
					if not done_exec then
						_log("\tWhen the timer has 0 seconds left, perform:")
						for _,vals in pairs(ele.values.on_executed) do perform_element(vals, 2) end
					end
				end,
		}




-- First we get a table of all the element ids and their respective editor name and their element group
for event_name, event in pairs(scripts) do
	for id, element in pairs(event._elements) do 
		elements[id] = { id = id, 
						 name = element._editor_name, 
						 event = event_name,
						 values = element._values,
						 _raw = element }
		if --[[event._activate_on_parsed and--]] element._values.execute_on_startup then table.insert(elements_to_do, id) end
	end
	for group_name, group in pairs(event._element_groups) do
		for _, group_element in pairs(group) do elements[group_element._id].group = group_name end
	end
end

-- Then we add to the remaining element list those who are not inlined
for _,ele in pairs(elements) do
	if not inline[ele.group] then table.insert(elements_to_do, ele.id) end
end

-- We also need a conversion between unit_id <--> unit
for id, unit in pairs(managers.worlddefinition._all_units) do
	if unit and not tostring(unit):find("NULL") then
		unit_ids[id] = {name = Idstring:reverse(unit:name()), position = unit:position()}
	end
end

-- And finally we handle all the elements
while #elements_to_do > 0 do	
	local ele = elements[table.remove(elements_to_do, 1)]
	if not elements_done[ele.id] then
		elements_done[ele.id] = true
		
		-- First we print some basic information about the element
		print_element(ele, nil, 0, true)
		if not ele.values.enabled then _log("\t[INITIALLY DISABLED]") end
		if ele.values.execute_on_startup then _log("\t[EXECUTE ON STARTUP]") end
		if ele.values.trigger_times > 0 then _log("\t[INITIAL TRIGGER TIMES: "..ele.values.trigger_times.."]") end
		
		-- If it's a not-inlined element, it might have extra information to show
		if noinline[ele.group] then noinline[ele.group](ele)
		
		-- If it is inlined, then this must be an "execute on startup" element, just print the inlined version
		else inline[ele.group](ele, false, 1) end
		
		_log(" ") -- Newline
	end
end

-- Now we also want separate headers for all the inlined elements, in case they get referenced somewhere
-- We put these elements at the bottom with a separator dividing them from the "main" elements
if not compact then
	_log("/SEP")
	_log("/SEP")
	_log("\t\t\t\t\t[ALL REMAINING ELEMENTS]")
	_log("/SEP")
	_log("/SEP")
	_log(" ")
	for _,ele in pairs(elements) do
		if not elements_done[ele.id] then
			elements_done[ele.id] = true
			print_element(ele, nil, 0, true)
			if not ele.values.enabled then _log("\t[INITIALLY DISABLED]") end
			if ele.values.execute_on_startup then _log("\t[EXECUTE ON STARTUP]") end
			if ele.values.trigger_times > 0 then _log("\t[INITIAL TRIGGER TIMES: "..ele.values.trigger_times.."]") end
			inline[ele.group](ele, false, 1)
			_log(" ")
		end
	end
end

_log_global_handle:close()
_log_global_handle = nil