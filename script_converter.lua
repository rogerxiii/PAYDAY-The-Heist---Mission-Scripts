--
-- Helper functions
--

-- local function print_tabs(indent)
-- 	indent = indent or 1

-- 	_log_newlines_temp = true
-- 	local _, output = string.rep("\t", indent)
-- 	_log(output)
-- end

local function print_tabs(indent)
	indent = indent or 1

	for _ = 1, indent do
		_log_newlines_temp = true
		_log("\t")
	end
end

local function _log_with_indent(indent, ...)
	print_tabs(indent)
	_log(...)
end

local function get_delay(delay)
	if not delay or type(delay) == "number" and delay <= 0 then
		return ""
	end

	return string.format("\t(DELAY %s)", tostring(delay))
end

---@param element table Element object
---@param delay number|boolean? execution delay
---@param indent number?
---@param short boolean?
local function print_element(element, delay, indent, short)
	print_tabs(indent)

	local header = (short and "") or "Execute element "
	local output = string.format(
		"%s'%s' [%s] %d from %s%s",
		header,
		element.name,
		element.group,
		element.id,
		element.event,
		get_delay(delay)
	)
	_log(output)
end

---converts a vector object into a printable string
local function vector_string(vector)
	return string.format("(%s, %s, %s)", tostring(vector.x), tostring(vector.y), tostring(vector.z))
end

---converts a rotation object into a printable string
local function rotation_string(rotation)
	return string.format(
		"(%s, %s, %s)",
		tostring(rotation:roll()),
		tostring(rotation:pitch()),
		tostring(rotation:yaw())
	)
end

---@param values string|table Id or table of elements to execute
---@param indent number?
local function perform_element(values, indent)
	indent = indent or 1

	local execute = type(values) == "table"
	local element = elements[execute and values.id or values]

	local delay = false
	if execute and values.delay > 0 then
		delay = values.delay
	end

	if inline[element.group] then
		inline[element.group](element, delay, indent)
		return
	end

	print_element(element, delay, indent)
end

local function print_execution_list(list, indent)
	if type(list) ~= "table" then
		return
	end

	-- print_tabs(indent)

	for _, values in pairs(list) do
		perform_element(values, indent)
	end
end

local function print_execution_list_no_recursion(list, group, path, indent)
	if type(list) ~= "table" then
		return
	end

	for _, values in pairs(list) do
		if elements[values.id].group == group then
			inline[group](elements[values.id], values.delay > 0 and values.delay or false, indent, path)
		else
			perform_element(values, indent)
		end
	end
end

local print_compact_list = shift()
local module = D and D:module("mission_dumper")
if module then
	local tag = print_compact_list and "compact" or "full"
	local level_id = tablex.get(Global.game_settings, "level_id") or "apartment"
	local current_level = tablex.get({
		hospital = "l4d",
		heat_street = "street",
		diamond_heist = "diamondheist",
		slaughter_house = "slaughterhouse",
	}, level_id) or level_id
	local path = string.format("%slevels [%s]/%s_%s.txt", module:path(), tag, current_level, tag)
	_log_global_handle = io.open(path, "a")
else
	_log_global_handle = io.open("mods/log.txt", "a")
end

local scripts = managers.mission._scripts
elements = {}
unit_ids = {}

-- We keep a stack (FIFO) of (non-inlined) elements to handle
-- We start with the startup script(s)
-- We keep another list to avoid dupes
local elements_to_do = {}
local elements_done = {}

-- Elements which can be inlined into usually at most a few lines
inline = {
	["ElementPlayerSpawner"] = function(element, delay, indent)
		local values = element.values
		local output = string.format(
			"Create player spawn at position %s with rotation %s%s",
			vector_string(values.position),
			rotation_string(values.rotation),
			get_delay(delay)
		)
		_log_with_indent(indent, output)
		print_execution_list(values.on_executed, indent)
	end,
	["ElementFleePoint"] = function(element, delay, indent)
		local values = element.values
		local output =
			string.format("Create flee point at position %s%s", vector_string(values.position), get_delay(delay))
		_log_with_indent(indent, output)
		print_execution_list(values.on_executed, indent)
	end,
	["ElementAIGraph"] = function(element, delay, indent)
		local values = element.values
		print_tabs(indent)

		local operation = values.operation == "allow_access" and "Allow" or "Forbid"
		local output =
			string.format("%s AI nav sections %s%s", operation, table.concat(values.graph_ids, ", "), get_delay(delay))
		_log_with_indent(indent, output)
		print_execution_list(values.on_executed, indent)
	end,
	["ElementSpawnEnemyDummy"] = function(element, delay, indent)
		local values = element.values
		local output = string.format(
			"Spawn enemy unit {%s} at position %s with rotation %s%s",
			values.enemy,
			vector_string(values.position),
			rotation_string(values.rotation),
			get_delay(delay)
		)
		_log_with_indent(indent, output)
		print_execution_list(values.on_executed, indent)
	end,
	["ElementSpawnCivilian"] = function(element, delay, indent)
		local values = element.values
		local output = string.format(
			"Spawn civilian unit {%s} at position %s with rotation %s%s",
			values.enemy,
			vector_string(values.position),
			rotation_string(values.rotation),
			get_delay(delay)
		)
		_log_with_indent(indent, output)
		print_execution_list(values.on_executed, indent)
	end,
	["ElementActivateScript"] = function(element, delay, indent)
		local values = element.values
		local output = string.format("Activate script '%s'%s", values.activate_script, get_delay(delay))
		_log_with_indent(indent, output)
		print_execution_list(values.on_executed, indent)
	end,
	["ElementSpecialObjective"] = function(element, delay, indent)
		local values = element.values
		local target = values.use_instigator and "instigator" or values.ai_group
		local delay_str = delay and ("\t(DELAY " .. delay .. ")") or ""
		local action_str = (values.so_action ~= "none") and (" with action " .. values.so_action) or ""

		local output = ""
		if values.is_navigation_link then
			output = string.format(
				"Create navigation link for %s from position %s to %s%s%s",
				target,
				vector_string(values.position),
				vector_string(values.search_position),
				action_str,
				delay_str
			)
		else
			local radius_str = (values.search_distance > 0) and (" with radius " .. values.search_distance) or ""
			output = string.format(
				"Create objective for %s around position %s%s%s%s",
				target,
				vector_string(values.search_position),
				radius_str,
				action_str,
				delay_str
			)
		end

		_log_with_indent(indent, output)
		print_execution_list(values.on_executed, indent)
	end,
	["ElementDebug"] = function(element, delay, indent, path)
		path = path or {}
		if path[element.id] then
			_log_with_indent(indent, "[Loop previous ElementDebug elements]")
			return
		end

		path[element.id] = true

		local delay_str = get_delay(delay)
		local output = string.format("Print debug string '%s'%s", element.values.debug_string, delay_str)

		_log_with_indent(indent, output)
		for _, values in pairs(element.values.on_executed) do
			if elements[values.id].group == "ElementDebug" then
				inline["ElementDebug"](elements[values.id], values.delay > 0 and values.delay, indent, path)
			else
				perform_element(values, indent)
			end
		end
	end,
	["ElementDialogue"] = function(element, delay, indent, path)
		path = path or {}
		if path[element.id] then
			_log_with_indent(indent, "[Loop previous ElementDialogue elements]")
			return
		end
		path[element.id] = true

		local values = element.values

		local output = string.format("Play dialogue '%s'%s", values.dialogue, get_delay(delay))
		_log_with_indent(indent, output)
		for _, data in pairs(values.on_executed) do
			if elements[data.id].group == "ElementDialogue" then
				inline["ElementDialogue"](elements[data.id], data.delay > 0 and data.delay, indent, path)
			else
				perform_element(data, indent)
			end
		end
	end,
	["ElementEnemyPreferedAdd"] = function(element, delay, indent)
		local delay_str = delay and ("\t(DELAY " .. delay .. ")") or ""
		if delay then
			_log_with_indent(indent, string.format("Perform '%s': %s", element.name, delay_str))
		end

		local sub_indent = delay and (indent + 1) or indent

		for _, point in pairs(element._raw._group_data.spawn_points or {}) do
			local enemy = point._values.enemy
			local action = point._values.spawn_action
			local position = vector_string(point._values.position)

			_log_with_indent(
				sub_indent,
				string.format("Add preferred spawn point for {%s} with action %s at %s", enemy, action, position)
			)
		end

		print_execution_list(element.values.on_executed, indent)
	end,
	["ElementEnemyPreferedRemove"] = function(element, delay, indent)
		local values = element.values

		for _, id in pairs(values.elements or {}) do
			local name = elements[id] and elements[id].name or ("<unknown id: " .. tostring(id) .. ">")
			local output =
				string.format("Remove all preferred spawn points associated with '%s' %s", name, get_delay(delay))
			_log_with_indent(indent, output)
		end

		print_execution_list(values.on_executed, indent)
	end,
	["ElementPlaySound"] = function(element, delay, indent)
		local values = element.values
		local delay_str = get_delay(delay)

		if #values.elements > 0 then
			_log_with_indent(indent, string.format("Play sound '%s' from units: %s", values.sound_event, delay_str))

			for _, id in pairs(values.elements or {}) do
				local do_ele = elements[id]
				local enemy = do_ele and do_ele.values and do_ele.values.enemy or "<unknown>"
				local name = do_ele and do_ele.name or ("<unknown id: " .. tostring(id) .. ">")

				_log_with_indent(indent + 1, string.format("- {%s} from element '%s'", enemy, name))
			end
		else
			_log_with_indent(indent, string.format("Play sound '%s'%s", values.sound_event, delay_str))
		end

		print_execution_list(values.on_executed or {}, indent)
	end,
	["ElementFakeAssaultState"] = function(element, delay, indent)
		local values = element.values
		local state = values.state and "Enable" or "Disable"
		local output = string.format("%s fake assault state%s", state, get_delay(delay))
		_log_with_indent(indent, output)
		print_execution_list(values.on_executed, indent)
	end,
	["ElementTeammateComment"] = function(element, delay, indent, path)
		path = path or {}
		if path[element.id] then
			_log_with_indent(indent, "[Loop previous ElementTeammateComment elements]")
			return
		end
		path[element.id] = true

		local values = element.values
		local output = string.format(
			"Make teammates%s say '%s'%s",
			values.use_instigator and " close to instigator" or "",
			values.comment,
			get_delay(delay)
		)
		_log_with_indent(indent, output)
		print_execution_list_no_recursion(values.on_executed, element.group, path, indent)
	end,
	["ElementToggle"] = function(element, delay, indent)
		local values = element.values
		for _, id in pairs(values.elements) do
			local do_ele = elements[id]
			if do_ele.group == "ElementWaypoint" then
				inline["ElementWaypoint"](do_ele, false, delay and indent + 1 or indent, element.values.toggle == "off")
			else
				local output = string.format(
					"Toggle %s element '%s' [%s] %s from %s%s",
					values.toggle:upper(),
					do_ele.name,
					do_ele.group,
					do_ele.id,
					do_ele.event,
					get_delay(delay)
				)
				_log_with_indent(indent, output)
			end
		end

		print_execution_list(values.on_executed, indent)
	end,
	["ElementMoney"] = function(element, delay, indent)
		local values = element.values
		local size = tweak_data.experience_manager.actions[element.values.action]
		local points = tweak_data.experience_manager.values[size]
		local output = string.format(
			"Award players money/experience for action '%s' which is worth %d points",
			values.action,
			points,
			get_delay(delay)
		)
		_log_with_indent(indent, output)
		print_execution_list(values.on_executed, indent)
	end,
	["ElementAIRemove"] = function(element, delay, indent)
		local values = element.values
		local delay_str = get_delay(delay)

		if values.use_instigator then
			_log_with_indent(indent, "Remove/Kill AI instigator from the level" .. delay_str)
		else
			if delay then
				_log_with_indent(indent, string.format("Perform '%s':%s", element.name, delay_str))
			end

			local sub_indent = delay and (indent + 1) or indent
			for _, id in pairs(values.elements or {}) do
				local do_ele = elements[id]
				local enemy = do_ele and do_ele.values and do_ele.values.enemy or "<unknown>"
				local name = do_ele and do_ele.name or ("<unknown id: " .. tostring(id) .. ">")

				_log_with_indent(sub_indent, string.format("Remove/Kill unit {%s} from element '%s'", enemy, name))
			end
		end

		print_execution_list(values.on_executed, indent)
	end,
	["ElementObjective"] = function(element, delay, indent)
		local values = element.values
		local delay_str = delay and ("\t(DELAY " .. delay .. ")") or ""
		local state = values.state:gsub("^%l", string.upper)
		local sub_obj = (values.sub_objective ~= "none") and (" with sub-objective '" .. values.sub_objective .. "'")
			or ""
		local position = vector_string(values.position)

		local output = string.format(
			"%s objective '%s'%s at position %s %s",
			state,
			values.objective,
			sub_obj,
			position,
			delay_str
		)
		_log_with_indent(indent, output)

		print_execution_list(values.on_executed, indent)
	end,
	["ElementWaypoint"] = function(element, delay, indent, remove)
		local values = element.values
		local delay_str = get_delay(delay)
		local action = remove and "Remove" or "Add"
		local location_phrase = remove and "from" or "at"
		local text = managers.localization:text(values.text_id)
		local position = vector_string(values.position)

		_log_with_indent(
			indent,
			string.format(
				"%s waypoint with text '%s' and icon %s %s %s %s",
				action,
				text,
				values.icon,
				location_phrase,
				position,
				delay_str
			)
		)

		if remove then
			return
		end

		print_execution_list(values.on_executed, indent)
	end,
	["ElementDangerZone"] = function(element, delay, indent)
		local values = element.values
		_log_with_indent(indent, string.format("Set danger zone level to %d%s", values.level, get_delay(delay)))
		print_execution_list(values.on_executed, indent)
	end,
	["ElementDisableUnit"] = function(element, delay, indent)
		local values = element.values
		local delay_str = get_delay(delay)

		if #values.unit_ids == 1 then
			local id = values.unit_ids[1]
			local unit = unit_ids[id]
			local name = unit and unit.name or "<unknown>"
			local pos = unit and vector_string(unit.position) or "<no position>"

			_log_with_indent(indent, string.format("Disable unit %s {%s} at %s %s", tostring(id), name, pos, delay_str))
			print_execution_list(values.on_executed, indent)
		else
			if delay then
				_log_with_indent(indent, string.format("Perform '%s': %s", element.name, delay_str))
			end

			local sub_tabs = delay and (indent + 1) or indent
			for _, id in pairs(values.unit_ids or {}) do
				local unit = unit_ids[id]
				local name = unit and unit.name or "<unknown>"
				local pos = unit and vector_string(unit.position) or "<no position>"

				_log_with_indent(sub_tabs, string.format("Disable unit %s {%s} at %s", tostring(id), name, pos))
			end

			print_execution_list(values.on_executed, sub_tabs)
		end
	end,
	["ElementBlurZone"] = function(element, delay, indent)
		local values = element.values
		local output = string.format(
			"Set blurzone to mode %s with height %s and radius %s at %s%s",
			values.mode,
			tostring(values.height),
			tostring(values.radius),
			vector_string(values.position),
			get_delay(delay)
		)
		_log_with_indent(indent, output)

		print_execution_list(values.on_executed, indent)
	end,
	["ElementDifficultyLevelCheck"] = function(element, delay, indent)
		local values = element.values
		local difficulty_map = {
			easy = "Easy",
			normal = "Normal",
			hard = "Hard",
			overkill = "Overkill",
			overkill_145 = "Overkill 145+",
			overkill_193 = "Overkill 193+",
		}

		local label = difficulty_map[values.difficulty] or values.difficulty
		if values.difficulty == "overkill" then
			local overkill_or_above = {
				difficulty_map["overkill"],
				difficulty_map["overkill_145"],
				difficulty_map["overkill_193"],
			}
			label = string.format("{%s}", table.concat(overkill_or_above, ", "))
		end
		_log_with_indent(indent, "If difficulty is " .. label .. " then perform:" .. get_delay(delay))

		print_execution_list(values.on_executed, indent + 1)
	end,
	["ElementMaskFilter"] = function(element, delay, indent)
		local values = element.values
		local output

		if values.mask == "none" then
			output = "Remove any applied mask filter" .. get_delay(delay)
		else
			output = string.format("Change mask filter to '%s'%s", values.mask, get_delay(delay))
		end

		_log_with_indent(indent, output)
		print_execution_list(values.on_executed, indent)
	end,
	["ElementScenarioEvent"] = function(element, delay, indent)
		local values = element.values
		local delay_str = get_delay(delay)
		local plural = values.amount == 1 and "" or "s"

		local msg = string.format(
			"%.0f%% base chance with %.0f%% increase to use spawn event with task '%s' %d time%s at position %s%s",
			values.base_chance * 100,
			values.chance_inc * 100,
			values.task,
			values.amount,
			plural,
			vector_string(values.position),
			delay_str
		)

		_log_with_indent(indent, msg)

		print_execution_list(values.on_executed, indent)
	end,
	["ElementOperator"] = function(ele, delay, tabs)
		if delay then
			_log_with_indent(tabs, "Perform '" .. ele.name .. "':" .. (delay and " \t(DELAY " .. delay .. ")" or ""))
		end
		for _, id in pairs(ele.values.elements) do
			local do_ele = elements[id]
			if do_ele.group == "ElementWaypoint" then
				inline["ElementWaypoint"](do_ele, false, delay and tabs + 1 or tabs, ele.values.operation == "remove")
			else
				_log_with_indent(
					delay and tabs + 1 or tabs,
					(ele.values.operation:gsub("^%l", string.upper))
						.. " element '"
						.. do_ele.name
						.. "' ["
						.. do_ele.group
						.. "] "
						.. do_ele.id
						.. " from "
						.. do_ele.event
				)
			end
		end
		for _, vals in pairs(ele.values.on_executed) do
			perform_element(vals, tabs)
		end
	end,
	["ElementAiGlobalEvent"] = function(ele, delay, tabs)
		local output = string.format("Trigger global AI event '%s'%s", ele.values.event, get_delay(delay))
		_log_with_indent(tabs, output)

		print_execution_list(ele.values.on_executed, tabs)
	end,
	["ElementLogicChance"] = function(element, delay, indent)
		-- NOTE: This element should not actually be inlined when compared to the other elements
		-- But, since [ElementLogicChanceOperator] gets used so sparingly, making this inlined greatly improves readability

		local output =
			string.format("Roll the dice with %d%% chance to succeed.%s", element.values.chance, get_delay(delay))
		_log_with_indent(indent, output)

		local fails = {}
		local successes = {}

		-- Add on_executed vals as successes by default
		for _, vals in pairs(element.values.on_executed or {}) do
			table.insert(successes, vals)
		end

		-- Process raw triggers
		for id, vals in pairs(element._raw._triggers or {}) do
			if vals.outcome == "success" then
				table.insert(successes, id)
			elseif vals.outcome == "fail" then
				table.insert(fails, id)
			end
		end

		if #successes > 0 then
			_log_with_indent(indent, "On success, perform:")
			print_execution_list(successes, indent + 1)
		end

		if #fails > 0 then
			_log_with_indent(indent, "On failure, perform:")
			print_execution_list(fails, indent + 1)
		end
	end,
	["ElementRandom"] = function(element, delay, indent)
		local values = element.values
		local output =
			string.format("Execute at random %d of the following elements:%s", values.amount, get_delay(delay))
		_log_with_indent(indent, output)

		for i, data in ipairs(values.on_executed or {}) do
			local do_ele = elements[data.id]
			local delay_str = get_delay(data.delay)
			_log_with_indent(
				indent + 1,
				string.format(
					"%d) '%s' [%s] %d from %s%s",
					i,
					do_ele.name,
					do_ele.group,
					do_ele.id,
					do_ele.event,
					delay_str
				)
			)
		end
	end,
	["ElementUnitSequence"] = function(element, delay, indent)
		if delay then
			_log_with_indent(indent, string.format("Perform '%s': %s", element.name, get_delay(delay)))
		end

		for _, vals in pairs(element.values.trigger_list) do
			local id = vals.notify_unit_id
			local unit = unit_ids[id]

			if vals.name == "run_sequence" then
				local delay_str = tonumber(vals.time) > 0 and get_delay(vals.time) or ""
				_log_with_indent(
					delay and indent + 1 or indent,
					string.format(
						"Run sequence '%s' on unit %s {%s} at %s %s",
						vals.notify_unit_sequence,
						id,
						unit.name,
						vector_string(unit.position),
						delay_str
					)
					-- string.format("Run sequence '%s' on unit {%s} at %s%s", vals.notify_unit_sequence, unit.name, vector_string(unit.position), delay_str)
				)
			end
		end

		print_execution_list(element.values.on_executed, delay and indent + 1 or indent)
	end,
	["ElementFilter"] = function(element, delay, indent)
		local values = element.values
		local output = {}

		local difficulties = {}
		if values.difficulty_easy then
			table.insert(difficulties, "Easy")
		end
		if values.difficulty_normal then
			table.insert(difficulties, "Normal")
		end
		if values.difficulty_hard then
			table.insert(difficulties, "Hard")
		end
		if values.difficulty_overkill then
			table.insert(difficulties, "Overkill")
		end
		if values.difficulty_overkill_145 then
			table.insert(difficulties, "Overkill 145+")
		end
		if values.difficulty_overkill_193 then
			table.insert(difficulties, "Overkill 193+")
		end -- custom difficulty
		if #difficulties > 0 then
			table.insert(output, string.format("the difficulty is {%s}", table.concat(difficulties, ", ")))
		end

		local players = {}
		if values.player_1 then
			table.insert(players, "1")
		end
		if values.player_2 then
			table.insert(players, "2")
		end
		if values.player_3 then
			table.insert(players, "3")
		end
		if values.player_4 then
			table.insert(players, "4")
		end
		if #players > 0 then
			table.insert(output, string.format("the player count is {%s}", table.concat(players, ", ")))
		end

		local platforms = {}
		if values.platform_win32 then
			table.insert(platforms, "WIN32")
		end
		if values.platform_ps3 then
			table.insert(platforms, "PS3")
		end
		if #platforms > 0 then
			table.insert(output, string.format("the platform is {%s}", table.concat(platforms, ", ")))
		end

		local modes = {}
		-- mode is only checked if both are not nil
		if values.mode_assault ~= nil and values.mode_control ~= nil then
			if values.mode_assault then
				table.insert(modes, "assault")
			end
			if values.mode_control then
				table.insert(modes, "control")
			end
			if #modes > 0 then
				table.insert(output, string.format("mode is {%s}", table.concat(modes, ", ")))
			end
		end

		-- Final output
		if #output == 0 then
			_log_with_indent(indent, "Filter is active, but no conditions are set." .. get_delay(delay))
		else
			_log_with_indent(indent, "If " .. table.concat(output, " and ") .. " then perform:" .. get_delay(delay))
		end

		print_execution_list(values.on_executed, indent + 1)
	end,
	["ElementSpawnEnemyGroup"] = function(element, delay, indent)
		_log_with_indent(
			indent,
			string.format(
				"Spawn %d enemies in %s %s",
				element.values.amount,
				element.values.random and "randomly picked spawn points from:" or "the following spawn points:",
				get_delay(delay)
			)
		)

		for id, point in pairs(element._raw._group_data.spawn_points) do
			_log_with_indent(
				indent + 1,
				string.format("%s) {%s} at %s", id, point._values.enemy, vector_string(point._values.position))
			)
		end

		print_execution_list(element.values.on_executed, indent)
	end,
	["ElementSpawnCivilianGroup"] = function(element, delay, indent)
		_log_with_indent(
			indent,
			string.format(
				"Spawn %d civilians in %s %s",
				element.values.amount,
				element.values.random and "randomly picked spawn points from:" or "the following spawn points:",
				get_delay(delay)
			)
		)

		for id, point in pairs(element._raw._group_data.spawn_points) do
			_log_with_indent(
				indent + 1,
				string.format("%s) {%s} at %s", id, point._values.enemy, vector_string(point._values.position))
			)
		end

		print_execution_list(element.values.on_executed, indent)
	end,
	["ElementAwardAchievment"] = function(element, delay, indent)
		local achiev = element.values.achievment
		local name = managers.challenges._challenges_map[achiev]
		local display = name and string.format("Award achievement '%s'", managers.localization:text(name.title_id))
			or string.format(
				"Award achievement '%s'\t(achievement doesn't exist anymore, probably removed but forgot to edit the map)",
				achiev
			)

		_log_with_indent(indent, string.format("%s %s", display, get_delay(delay)))

		print_execution_list(element.values.on_executed, indent)
	end,
	["ElementCharacterOutline"] = function(element, delay, indent)
		_log_with_indent(
			indent,
			string.format(
				"Enable outline for all civilians that have the property 'outline_on_discover' %s",
				get_delay(delay)
			)
		)

		print_execution_list(element.values.on_executed, indent)
	end,
	["ElementCounterReset"] = function(element, delay, indent)
		if delay then
			_log_with_indent(indent, string.format("Perform '%s': %s", element.name, get_delay(delay)))
		end

		for _, id in pairs(element.values.elements) do
			local name = elements[id] and elements[id].name or ("ID " .. tostring(id))
			_log_with_indent(
				delay and indent + 1 or indent,
				string.format("Reset counter '%s' with counter target %s", name, element.values.counter_target)
			)
		end

		print_execution_list(element.values.on_executed, indent)
	end,
	["ElementDifficulty"] = function(element, delay, indent)
		_log_with_indent(indent, string.format("Set difficulty to %s %s", element.values.difficulty, get_delay(delay)))

		print_execution_list(element.values.on_executed, indent)
	end,
	["ElementDropinState"] = function(element, delay, indent)
		_log_with_indent(
			indent,
			string.format("%s drop-in for players %s", element.values.state and "Enable" or "Disable", get_delay(delay))
		)

		print_execution_list(element.values.on_executed, indent)
	end,
	["ElementEquipment"] = function(element, delay, indent)
		_log_with_indent(
			indent,
			string.format(
				"Give instigator %d of equipment '%s' %s",
				element.values.amount,
				element.values.equipment,
				get_delay(delay)
			)
		)

		print_execution_list(element.values.on_executed, indent)
	end,
	["ElementExecuteInOtherMission"] = function(element, delay, indent)
		if delay then
			_log_with_indent(indent, string.format("Perform '%s': %s", element.name, get_delay(delay)))
		end

		print_execution_list(element.values.on_executed, delay and indent + 1 or indent)
	end,
	["ElementFeedback"] = function(element, delay, indent)
		_log_with_indent(
			indent,
			string.format(
				"Cause screen shake with%s camera shake and with%s rumble %s",
				element.values.use_camera_shake and "" or "out",
				element.values.use_rumble and "" or "out",
				get_delay(delay)
			)
		)

		print_execution_list(element.values.on_executed, indent)
	end,
	["ElementHint"] = function(element, delay, indent)
		local hint = managers.localization:text(managers.hint:hint(element.values.hint_id).text_id)
		_log_with_indent(indent, string.format("Show hint '%s'%s", hint, get_delay(delay)))
		print_execution_list(element.values.on_executed, indent)
	end,
	["ElementKillZone"] = function(element, delay, indent)
		_log_with_indent(
			indent,
			string.format("Create killzone for instigator of damage type '%s'%s", element.values.type, get_delay(delay))
		)
		print_execution_list(element.values.on_executed, indent)
	end,
	["ElementLogicChanceOperator"] = function(element, delay, indent)
		if delay then
			_log_with_indent(indent, string.format("Perform '%s':%s", element.name, get_delay(delay)))
		end

		local sub_indent = delay and indent + 1 or indent
		for _, id in pairs(element.values.elements) do
			local target = elements[id].name
			local op = element.values.operation
			local chance = element.values.chance
			if op == "add_chance" then
				_log_with_indent(
					sub_indent,
					string.format("Add chance of %s%% to the logic chance element '%s'", chance, target)
				)
			elseif op == "subtract_chance" then
				_log_with_indent(
					sub_indent,
					string.format("Subtract chance of %s%% to the logic chance element '%s'", chance, target)
				)
			elseif op == "reset" then
				_log_with_indent(sub_indent, string.format("Reset chance of the logic chance element '%s'", target))
			elseif op == "set_chance" then
				_log_with_indent(
					sub_indent,
					string.format("Set the chance of the logic chance element '%s' to %s%%", target, chance)
				)
			end
		end

		print_execution_list(element.values.on_executed, indent)
	end,
	["ElementMissionEnd"] = function(element, delay, indent)
		_log_with_indent(
			indent,
			string.format("End the current level/mission with state '%s'%s", element.values.state, get_delay(delay))
		)
		print_execution_list(element.values.on_executed, indent)
	end,
	["ElementPlayEffect"] = function(element, delay, indent)
		local position = element.values.screen_space and "on player HUD" or "at position " .. element.values.position
		_log_with_indent(
			indent,
			string.format("Play effect {%s} %s%s", element.values.effect, position, get_delay(delay))
		)
		print_execution_list(element.values.on_executed, indent)
	end,
	["ElementStopEffect"] = function(element, delay, indent)
		if delay then
			_log_with_indent(indent, string.format("Perform '%s':%s", element.name, get_delay(delay)))
		end

		local sub_indent = delay and indent + 1 or indent
		for _, id in pairs(element.values.elements) do
			local effect = elements[id].values.effect
			local fade = element.values.operation == "fade_kill" and " with fade-out" or ""
			_log_with_indent(sub_indent, string.format("Stop effect {%s}%s", effect, fade))
		end

		print_execution_list(element.values.on_executed, indent)
	end,
	["ElementPlayerState"] = function(element, delay, indent)
		_log_with_indent(indent, string.format("Change player state to '%s'%s", element.values.state, get_delay(delay)))
		print_execution_list(element.values.on_executed, indent)
	end,
	["ElementPointOfNoReturn"] = function(element, delay, indent)
		_log_with_indent(indent, string.format("Enable 'Point Of No Return' timer:%s", get_delay(delay)))
		_log_with_indent(
			indent + 1,
			string.format("If difficulty is 'Easy' then set timer to %s seconds", element.values.time_easy)
		)
		_log_with_indent(
			indent + 1,
			string.format("If difficulty is 'Normal' then set timer to %s seconds", element.values.time_normal)
		)
		_log_with_indent(
			indent + 1,
			string.format("If difficulty is 'Hard' then set timer to %s seconds", element.values.time_hard)
		)
		_log_with_indent(
			indent + 1,
			string.format("If difficulty is 'Overkill' then set timer to %s seconds", element.values.time_overkill)
		)
		_log_with_indent(
			indent + 1,
			string.format(
				"If difficulty is 'Overkill 145+' then set timer to %s seconds",
				element.values.time_overkill_145
			)
		)
		print_execution_list(element.values.on_executed, indent)
	end,
	["ElementSecretAssignment"] = function(element, delay, indent)
		print_execution_list(element.values.on_executed, indent)
	end,
	["ElementAreaMinPoliceForce"] = function(element, delay, indent)
		_log_with_indent(
			indent,
			string.format(
				"Enable gathering point for %s enemies at position %s%s",
				element.values.amount,
				vector_string(element.values.position),
				get_delay(delay)
			)
		)
		print_execution_list(element.values.on_executed, indent)
	end,
	["ElementExplosionDamage"] = function(element, delay, indent)
		_log_with_indent(
			indent,
			string.format(
				"Create explosion at %s with linear damage fall-off starting at %s damage with a maximum range of %s%s",
				vector_string(element.values.position),
				element.values.damage,
				element.values.range,
				get_delay(delay)
			)
		)
		print_execution_list(element.values.on_executed, indent)
	end,
	["ElementLogicChanceTrigger"] = function(element, delay, indent)
		print_execution_list(element.values.on_executed, indent)
	end,
	["ElementSmokeGrenade"] = function(element, delay, indent)
		_log_with_indent(
			indent,
			string.format(
				"Create smoke grenade at %s for %s seconds%s",
				vector_string(element.values.position),
				element.values.duration,
				get_delay(delay)
			)
		)
		print_execution_list(element.values.on_executed, indent)
	end,
	["ElementFlashlight"] = function(element, delay, indent)
		local state = element.values.state and "on " or "off "
		local target = element.values.on_player and "on player" or "in world"
		_log_with_indent(indent, string.format("Turn %sflashlights %s%s", state, target, get_delay(delay)))
		print_execution_list(element.values.on_executed, indent)
	end,
	["ElementWhisperState"] = function(element, delay, indent)
		local state = element.values.state and "Enable" or "Disable"
		_log_with_indent(
			indent,
			string.format("%s whisper mode (controls what shouting at any enemy does)%s", state, get_delay(delay))
		)
		print_execution_list(element.values.on_executed, indent)
	end,
	["ElementTimerTrigger"] = function(element, delay, indent)
		print_execution_list(element.values.on_executed, indent)
	end,
	["ElementTimerOperator"] = function(element, delay, indent)
		if delay then
			_log_with_indent(indent, string.format("Perform '%s':%s", element.name, get_delay(delay)))
		end

		local sub_indent = delay and indent + 1 or indent
		for _, id in pairs(element.values.elements) do
			local do_ele = elements[id]
			local op = element.values.operation
			local time = element.values.time
			local timer_name = do_ele.name
			if op == "pause" then
				_log_with_indent(sub_indent, string.format("Pause timer '%s'", timer_name))
			elseif op == "start" then
				_log_with_indent(sub_indent, string.format("Start timer '%s'", timer_name))
			elseif op == "add_time" then
				_log_with_indent(sub_indent, string.format("Add %s seconds to timer '%s'", time, timer_name))
			elseif op == "subtract_time" then
				_log_with_indent(sub_indent, string.format("Subtract %s seconds to timer '%s'", time, timer_name))
			elseif op == "reset" then
				_log_with_indent(sub_indent, string.format("Reset timer '%s'", timer_name))
			elseif op == "set_time" then
				_log_with_indent(sub_indent, string.format("Set timer '%s' to %s seconds", timer_name, time))
			end
		end

		print_execution_list(element.values.on_executed, indent)
	end,
	["ElementDisableShout"] = function(element, delay, indent)
		if delay then
			_log_with_indent(indent, string.format("Perform '%s':%s", element.name, get_delay(delay)))
		end

		local sub_indent = delay and indent + 1 or indent
		for _, id in pairs(element.values.elements) do
			local do_ele = elements[id]
			local action = element.values.disable_shout and "Disable" or "Enable"
			_log_with_indent(
				sub_indent,
				string.format(
					"%s shouting against unit {%s} from element '%s'",
					action,
					do_ele.values.enemy,
					do_ele.name
				)
			)
		end

		print_execution_list(element.values.on_executed, indent)
	end,
	["ElementSequenceCharacter"] = function(element, delay, indent)
		if delay then
			_log_with_indent(indent, string.format("Perform '%s':%s", element.name, get_delay(delay)))
		end

		local sub_indent = delay and indent + 1 or indent
		for _, id in pairs(element.values.elements) do
			local do_ele = elements[id]
			_log_with_indent(
				sub_indent,
				string.format(
					"Run sequence '%s' on unit {%s} from element '%s'",
					element.values.sequence,
					do_ele.values.enemy,
					do_ele.name
				)
			)
		end

		print_execution_list(element.values.on_executed, indent)
	end,
	["ElementSetOutline"] = function(element, delay, indent)
		if delay then
			_log_with_indent(indent, string.format("Perform '%s':%s", element.name, get_delay(delay)))
		end

		local values = element.values
		local sub_indent = delay and indent + 1 or indent
		for _, id in pairs(values.elements) do
			local do_ele = elements[id]
			local action = element.values.set_outline and "Enable" or "Disable"
			_log_with_indent(
				sub_indent,
				string.format("%s outline on unit {%s} from element '%s'", action, do_ele.values.enemy, do_ele.name)
			)
		end

		print_execution_list(values.on_executed, indent)
	end,
	["ElementBainState"] = function(element, delay, indent)
		local values = element.values
		_log_with_indent(indent, string.format("Turn Bain %s%s", values.state and "on" or "off", get_delay(delay)))
		print_execution_list(values.on_executed, indent)
	end,
	["ElementBlackscreenVariant"] = function(element, delay, indent)
		local values = element.values
		_log_with_indent(indent, string.format("Set blackscreen to variant %s%s", values.variant, get_delay(delay)))
		print_execution_list(values.on_executed, indent)
	end,
	["ElementOverlayEffect"] = function(element, delay, indent)
		local values = element.values
		_log_with_indent(indent, string.format("Activate overlay effect '%s'%s", values.effect, get_delay(delay)))
		print_execution_list(values.on_executed, indent)
	end,
	["ElementPlayerStyle"] = function(element, delay, indent)
		local values = element.values
		_log_with_indent(indent, string.format("Change player look to style '%s'%s", values.style, get_delay(delay)))
		print_execution_list(values.on_executed, indent)
	end,
	-----
	--- DAHM custom element classes (from scriman/ovk_193)
	---
	["ElementDeleteUnit"] = function(element, delay, indent)
		local unit_ids = element.values.unit_ids
		local delay_str = get_delay(delay)

		if #unit_ids == 0 then
			_log_with_indent(indent, string.format("Delete Unit element with no assigned unit IDs%s", delay_str))
		else
			local suffix = #unit_ids == 1 and "" or "s"
			_log_with_indent(indent, string.format("Delete %d unit%s by ID%s", #unit_ids, suffix, delay_str))
			for i, id in ipairs(unit_ids) do
				_log_with_indent(indent + 1, string.format("%d) Unit ID: %s", i, tostring(id)))
			end
		end

		print_execution_list(element.values.on_executed, indent)
	end,
	["ElementSpawnSyncableUnit"] = function(element, delay, indent)
		local values = element.values
		local delay_str = get_delay(delay)
		local unit_path = values.unit or "units/dummy_unit_1/dummy_unit_1"

		local output = string.format(
			"Spawn syncable unit '%s' at position %s and rotation %s%s",
			unit_path,
			vector_string(values.position),
			vector_string(values.rotation),
			delay_str
		)

		_log_with_indent(indent, output)

		if values.sequence then
			_log_with_indent(indent + 1, string.format("Run sequence '%s' after spawn", values.sequence))
		end

		if values.interactable then
			_log_with_indent(indent + 1, "Enable interaction on unit")
		end

		print_execution_list(values.on_executed, indent)
	end,
	["ElementUnitProperty"] = function(element, delay, indent)
		local values = element.values
		local delay_str = get_delay(delay)

		local value_str
		if type(values.value) == "boolean" then
			value_str = tostring(values.value)
		elseif values.value == nil then
			value_str = "null"
		else
			value_str = string.format("'%s'", tostring(values.value))
		end

		local output = string.format("Set property '%s' to %s on instigator%s", values.property, value_str, delay_str)

		_log_with_indent(indent, output)
		print_execution_list(values.on_executed, indent)
	end,
}

-- Elements which (can) stand on their own
noinline = {
	["MissionScriptElement"] = function(element)
		-- NOTE: This is the element that does most of the game logic, nothing specifically special though.
		print_execution_list(element.values.on_executed)
	end,
	["ElementCounter"] = function(element)
		_log(string.format("\tWhen counter target %s is reached, perform:", element.values.counter_target))
		print_execution_list(element.values.on_executed, 2)
	end,
	["ElementAreaTrigger"] = function(element)
		_log(
			string.format(
				"\tTrigger shape (WxHxD): %s x %s x %s at position %s",
				element.values.width,
				element.values.height,
				element.values.depth,
				vector_string(element.values.position)
			)
		)
		_log(string.format("\tTrigger instigator: %s", element.values.instigator))
		_log(string.format("\tWhen trigger condition '%s' is met, perform:", element.values.trigger_on))
		print_execution_list(element.values.on_executed, 2)
	end,
	["ElementUnitSequenceTrigger"] = function(element)
		_log("\tIf any of the following sequences get triggered:")
		for id, vals in pairs(element.values.sequence_list) do
			if vals.unit_id == 0 then
				_log(
					string.format(
						"\t\t%s) no unit runs '%s'\t\t(probably deprecated or for debugging only)",
						id,
						vals.sequence
					)
				)
			elseif not unit_ids[vals.unit_id] then
				_log(string.format("\t\t#TODO unit_id %s cannot be resolved to a unit!", vals.unit_id))
			else
				_log(string.format("\t\t%s) {%s} runs '%s'", id, unit_ids[vals.unit_id].name, vals.sequence))
			end
		end
		_log("\tThen perform:")
		print_execution_list(element.values.on_executed, 2)
	end,
	["ElementEnemyDummyTrigger"] = function(element)
		_log(string.format("\tIf event '%s' gets executed by any of:", element.values.event))
		for i, id in pairs(element.values.elements) do
			local enemy = elements[id].values.enemy
				or (elements[id]._raw._spawn_points and elements[id]._raw._spawn_points[1]._values.enemy)
				or ((elements[id]._raw._group_data and #elements[id]._raw._group_data.spawn_points > 0) and elements[id]._raw._group_data.spawn_points[1]._values.enemy)
				or "#TODO unknown"
			_log(string.format("\t\t%s) {%s} from element '%s'", i, enemy, elements[id].name))
		end
		_log("\tThen perform:")
		print_execution_list(element.values.on_executed, 2)
	end,
	["ElementSpecialObjectiveTrigger"] = function(element)
		for i, id in pairs(element.values.elements) do
			local do_ele = elements[id]
			local suffix = (i == #element.values.elements) and "then perform:" or "OR"
			_log(
				string.format(
					"\tWhen one of AI %s that are following special objective '%s' from element '%s' performs event '%s' %s",
					do_ele.values.ai_group,
					do_ele.values.so_action,
					do_ele.name,
					element.values.event,
					suffix
				)
			)
		end
		print_execution_list(element.values.on_executed, 2)
	end,
	["ElementGlobalEventTrigger"] = function(element)
		_log(string.format("\tUpon global event '%s', perform:", element.values.global_event))
		print_execution_list(element.values.on_executed, 2)
	end,
	["ElementLookAtTrigger"] = function(element)
		_log(string.format("\t[position = %s]", vector_string(element.values.position)))
		_log(string.format("\t[rotation = %s]", rotation_string(element.values.rotation)))
		_log(string.format("\t[distance = %s]", element.values.distance))
		_log(string.format("\t[sensitivity = %s]", element.values.sensitivity))
		_log(string.format("\t[in_front = %s]", element.values.in_front and "true" or "false"))
		_log("\tAccording to the above values, wait for player to move to 'position' with (camera) 'rotation'.")
		_log("\t'distance' is the max distance between player location and 'position'.")
		_log("\tDot product must exceed 'sensitivity'.")
		_log("\tWhen these conditions are met, perform:")
		print_execution_list(element.values.on_executed, 2)
	end,
	["ElementPlayerStateTrigger"] = function(element)
		_log(string.format("\tWhen player state is changed to '%s' perform:", element.values.state))
		print_execution_list(element.values.on_executed, 2)
	end,
	["ElementAlertTrigger"] = function(element)
		_log(string.format("\tCreate an alert listener at %s", vector_string(element.values.position)))
		_log("\tWhen the alert gets triggered by sound of a bullet shot, perform:")
		print_execution_list(element.values.on_executed, 2)
	end,
	["ElementTimer"] = function(element)
		_log(string.format("\tCreate timer with an initial time of %s seconds", element.values.timer))
		local done_exec = false
		for id, vals in pairs(element._raw._triggers) do
			_log(string.format("\tWhen the timer has %s seconds left, perform:", vals.time))
			print_execution_list(elements[id].values.on_executed, 2)
			if vals.time == 0 then
				done_exec = true
				print_execution_list(element.values.on_executed, 2)
			end
		end
		if not done_exec then
			_log("\tWhen the timer has 0 seconds left, perform:")
			print_execution_list(element.values.on_executed, 2)
		end
	end,
}

-- First we get a table of all the element ids and their respective editor name and their element group
for event_name, event in pairs(scripts) do
	for id, element in pairs(event._elements) do
		elements[id] = {
			id = id,
			name = element._editor_name,
			event = event_name,
			values = element._values,
			_raw = element,
		}
		if element._values.execute_on_startup then
			table.insert(elements_to_do, id)
		end
	end

	for group_name, group in pairs(event._element_groups) do
		for _, group_element in pairs(group) do
			elements[group_element._id].group = group_name
		end
	end
end

-- Then we add to the remaining element list those who are not inlined
for _, element in pairs(elements) do
	if not inline[element.group] then
		table.insert(elements_to_do, element.id)
	end
end

-- We also need a conversion between unit_id <--> unit
for id, unit in pairs(managers.worlddefinition._all_units) do
	if unit and not tostring(unit):find("NULL") then
		unit_ids[id] = {
			name = Idstring:reverse(unit:name()),
			position = unit:position(),
		}
	end
end

-- And finally we handle all the elements
while #elements_to_do > 0 do
	local ele = elements[table.remove(elements_to_do, 1)]

	if not elements_done[ele.id] then
		elements_done[ele.id] = true

		-- Print basic element info
		print_element(ele, nil, 0, true)
		if not ele.values.enabled then
			_log("\t[INITIALLY DISABLED]")
		end
		if ele.values.execute_on_startup then
			_log("\t[EXECUTE ON STARTUP]")
		end
		if ele.values.trigger_times > 0 then
			_log(string.format("\t[INITIAL TRIGGER TIMES: %d]", ele.values.trigger_times))
		end

		-- Print detailed info based on element group
		if noinline[ele.group] then
			noinline[ele.group](ele)
		elseif inline[ele.group] then
			inline[ele.group](ele, false, 1)
		else
			dlog(string.format("unfiltered group %s", tostring(ele.group)))
		end

		_log(" ") -- Newline
	end
end

-- Now we also want separate headers for all the inlined elements, in case they get referenced somewhere
-- We put these elements at the bottom with a separator dividing them from the "main" elements
if not print_compact_list then
	_log("/SEP")
	_log("/SEP")
	_log("\t\t\t\t\t[ALL REMAINING ELEMENTS]")
	_log("/SEP")
	_log("/SEP")
	_log(" ")

	for _, ele in pairs(elements) do
		if not elements_done[ele.id] then
			elements_done[ele.id] = true

			print_element(ele, nil, 0, true)
			if not ele.values.enabled then
				_log("\t[INITIALLY DISABLED]")
			end
			if ele.values.execute_on_startup then
				_log("\t[EXECUTE ON STARTUP]")
			end
			if ele.values.trigger_times > 0 then
				_log(string.format("\t[INITIAL TRIGGER TIMES: %d]", ele.values.trigger_times))
			end

			inline[ele.group](ele, false, 1)
			_log(" ")
		end
	end
end

_log_global_handle:close()
_log_global_handle = nil
