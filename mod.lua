return DMod:new("mission_dumper", {
	name = "Mission Dumper",
	author = "RogerXIII",
	config = {
		{ "menu", "dump_mission", { type = "keybind", text = "Dump Mission" } },
	},
	hooks = {
		{
			"lib/managers/missionmanager", function(module)
				local MissionScript = module:hook_class("MissionScript")

				-- prevent any script data from being manipulated, will softlock missions
				module:hook(MissionScript, "activate", function(self, ...)
					-- managers.mission:add_persistent_debug_output("")
					-- managers.mission:add_persistent_debug_output("Activate mission " .. self._name, Color(1, 0, 1, 0))
					for _, element in pairs(self._elements) do
						element:on_script_activated()
					end
					-- for _, element in pairs(self._elements) do
					-- 	if element:value("execute_on_startup") then
					-- 		element:on_executed(...)
					-- 	end
					-- end
				end)
			end,
		},
		{
			"OnKeyPressed", "dump_mission", function()
				local module = D:module("mission_dumper")
				local path = module:path()

				require(path .. "log.lua")
				local _, data = pcall(loadfile, path .. "script_converter.lua")
				if data then
					data()
				end
			end,
		},
	},
})
