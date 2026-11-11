local function snapshot()
	local out = { machines = {}, boxes = {}, controllers = {}, buffers = {} }
	for _, s in pairs(game.surfaces) do
		for _, e in
			pairs(
				s.find_entities_filtered({
					name = {
						"quality-condenser-forked",
						"quality-condenser-forked--container",
						"smart-quality-condenser-targets",
						"smart-quality-condenser-input",
						"smart-quality-condenser-output",
					},
				})
			)
		do
			local row =
				{ unit = e.unit_number, name = e.name, position = e.position, surface = s.name, quality = e.quality.name }
			if e.name == "quality-condenser-forked" then
				row.modules = e.get_module_inventory().get_contents()
				out.machines[tostring(e.unit_number)] = row
			elseif e.name == "smart-quality-condenser-targets" then
				row.sections = {}
				for _, sec in pairs(e.get_control_behavior().sections) do
					row.sections[#row.sections + 1] =
						{ filters = sec.filters, active = sec.active, group = sec.group, multiplier = sec.multiplier }
				end
				out.controllers[tostring(e.unit_number)] = row
			else
				row.items = e.get_inventory(defines.inventory.chest).get_contents()
				if e.name == "quality-condenser-forked--container" then
					out.boxes[tostring(e.unit_number)] = row
				else
					out.buffers[tostring(e.unit_number)] = row
				end
			end
		end
	end
	return out
end
script.on_init(function()
	storage.before = snapshot()
end)
script.on_configuration_changed(function()
	local after = snapshot()
	assert(
		helpers.table_to_json(storage.before) == helpers.table_to_json(after),
		"Machines, original inventories, modules, targets or internal buffers changed during migration"
	)
	local count = table_size(after.machines)
	local s = game.surfaces["quality-condenser-forked"]
	assert(
		s.count_entities_filtered({ name = "proxy-container" }) == 2 * count,
		"Missing or duplicated internal helpers"
	)
	storage.migrated = true
	local result = {
		passed = true,
		machines = count,
		containers = table_size(after.boxes),
		controllers = table_size(after.controllers),
		buffers = table_size(after.buffers),
		original_entity_ids_preserved = true,
		items_and_modules_preserved = true,
		targets_preserved = true,
		helpers_rebuilt = true,
	}
	log("SMART_FORK_MIGRATION_QA " .. helpers.table_to_json(result))
	helpers.write_file("smart-fork-migration-qa.json", helpers.table_to_json(result), false)
end)
