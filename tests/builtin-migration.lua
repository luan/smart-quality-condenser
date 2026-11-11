local M = {}
local function items(entity)
	local result = {}
	for _, stack in pairs(entity.get_inventory(defines.inventory.chest).get_contents()) do
		result[stack.name .. "/" .. stack.quality] = (result[stack.name .. "/" .. stack.quality] or 0) + stack.count
	end
	return result
end
local function equal(a, b, message)
	if type(a) ~= "table" then
		assert(a == b, message)
		return
	end
	assert(type(b) == "table", message)
	for k, v in pairs(a) do
		equal(v, b[k], message)
	end
	for k in pairs(b) do
		assert(a[k] ~= nil, message)
	end
end
function M.before()
	local before = {}
	for _, entry in pairs(storage.entries) do
		local targets = {}
		for _, section in pairs(entry.controller.get_control_behavior().sections) do
			if section.active then
				for _, filter in pairs(section.filters) do
					local v = filter.value
					if v and (v.type or "item") == "item" then
						targets[#targets + 1] = {
							item = { name = v.name, quality = v.quality or "normal" },
							count = math.floor((filter.min or 0) * section.multiplier),
						}
					end
				end
			end
		end
		before[entry.condenser.unit_number] = {
			targets = targets,
			enabled = entry.controller.get_control_behavior().enabled,
			condenser = entry.condenser,
			box = entry.box,
			input = entry.input,
			output = entry.output,
			box_items = items(entry.box),
			input_items = items(entry.input),
			output_items = items(entry.output),
			modules = entry.condenser.get_module_inventory().get_contents(),
			quality = entry.controller.quality.name,
			controller = entry.controller,
		}
	end
	return before
end
function M.after(before, Smart, Gui)
	local target_count = 0
	for id, row in pairs(before) do
		local entry = assert(storage.entries[id], "Condenser missing after migration")
		assert(
			entry.condenser == row.condenser
				and entry.box == row.box
				and entry.input == row.input
				and entry.output == row.output,
			"Original entities or buffers replaced"
		)
		assert(not row.controller.valid, "Legacy controller remains")
		equal(entry.targets, row.targets, "Targets changed during migration")
		assert(entry.enabled == row.enabled, "Automation toggle lost")
		equal(entry.condenser.get_module_inventory().get_contents(), row.modules, "Modules changed")
		equal(items(entry.box), row.box_items, "Machine items changed")
		equal(items(entry.input), row.input_items, "Incoming items changed")
		for _, name in ipairs({ "constant-combinator", "requester-chest", "active-provider-chest" }) do
			local k = name .. "/" .. row.quality
			row.output_items[k] = (row.output_items[k] or 0) + 1
		end
		equal(items(entry.output), row.output_items, "Output items or ingredient refund changed")
		target_count = target_count + #entry.targets
	end
	local out = {
		passed = true,
		machines = table_size(before),
		targets = target_count,
		inventory_ids_preserved = true,
		items_and_modules_preserved = true,
		controller_retired = true,
		ingredients_refunded = true,
	}
	helpers.write_file("builtin-migration.json", helpers.table_to_json(out), false)
	log("BUILTIN_MIGRATION_QA " .. helpers.table_to_json(out))
end
return M
