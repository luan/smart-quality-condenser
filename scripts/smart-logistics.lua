local plan = require("scripts.smart-plan")
local CONTROLLER = "smart-quality-condenser-targets"
local CONDENSER = "quality-condenser-forked"
local CONTAINER = CONDENSER .. "--container"
local function contents(items)
	local result = {}
	for _, item in pairs(items) do
		local k = plan.key(item.name, item.quality or "normal")
		result[k] = (result[k] or 0) + item.count
	end
	return result
end
local function inventory(entity)
	return entity.get_inventory(defines.inventory.chest)
end
local function split(k)
	return k:match("^(.-)%z(.*)$")
end
local function status(entity, message, bad)
	entity.custom_status =
		{ diode = bad and defines.entity_status_diode.red or defines.entity_status_diode.green, label = message }
end
-- Transfer the actual stacks only between the machine and its colocated logistics buffers.
local function move(source, destination, amounts)
	local total = 0
	for slot = 1, #source do
		local stack = source[slot]
		if stack.valid_for_read then
			local k = plan.key(stack.name, stack.quality.name)
			local remaining = math.min(stack.count, amounts[k] or 0)
			if remaining > 0 then
				for target = 1, #destination do
					local dst = destination[target]
					if not dst.valid_for_read or (dst.name == stack.name and dst.quality == stack.quality) then
						local before = stack.count
						dst.transfer_stack(stack, remaining)
						local moved = before - (stack.valid_for_read and stack.count or 0)
						total = total + moved
						amounts[k] = amounts[k] - moved
						remaining = remaining - moved
						if remaining == 0 then
							break
						end
					end
				end
			end
		end
	end
	return total
end
local function spill(entity)
	if not entity or not entity.valid then
		return
	end
	local inv = inventory(entity)
	for i = 1, #inv do
		if inv[i].valid_for_read then
			entity.surface.spill_item_stack({
				position = entity.position,
				stack = inv[i],
				force = entity.force,
				allow_belts = false,
			})
			inv[i].clear()
		end
	end
	entity.destroy()
end
local function release(entry)
	if entry.paused and entry.condenser.valid and not entry.condenser.custom_status then
		entry.condenser.disabled_by_script = false
	end
	spill(entry.input)
	spill(entry.output)
end
local function pair(controller, used)
	local candidates = controller.surface.find_entities_filtered({
		name = CONDENSER,
		position = controller.position,
		radius = 10,
		force = controller.force,
	})
	table.sort(candidates, function(a, b)
		local function distance(e)
			return (e.position.x - controller.position.x) ^ 2 + (e.position.y - controller.position.y) ^ 2
		end
		local da, db = distance(a), distance(b)
		return da < db or (da == db and a.unit_number < b.unit_number)
	end)
	local condenser = candidates[1]
	if not condenser then
		status(controller, "Place within 10 tiles of a quality condenser", true)
		return
	end
	if used[condenser.unit_number] then
		status(controller, "This condenser already has a target combinator", true)
		return
	end
	local box =
		condenser.surface.find_entities_filtered({ name = CONTAINER, position = condenser.position, limit = 1 })[1]
	if not box then
		status(controller, "Waiting for the condenser inventory", true)
		return
	end
	local entry = { controller = controller, condenser = condenser, box = box }
	for _, kind in ipairs({ "input", "output" }) do
		entry[kind] = condenser.surface.create_entity({
			name = "smart-quality-condenser-" .. kind,
			position = condenser.position,
			force = condenser.force,
		})
		entry[kind].destructible = false
	end
	entry.input.request_from_buffers = true
	local point = entry.input.get_logistic_point(defines.logistic_member_index.logistic_container)
	point.trash_not_requested = false
	while point.sections_count > 0 do
		point.remove_section(1)
	end
	point.add_section()
	used[condenser.unit_number] = true
	return entry
end
local function rescan()
	local entries, used = storage.entries, {}
	for id, entry in pairs(entries) do
		if
			not entry.controller.valid
			or not entry.condenser.valid
			or not entry.box.valid
			or not entry.input.valid
			or not entry.output.valid
		then
			release(entry)
			entries[id] = nil
		else
			used[entry.condenser.unit_number] = true
		end
	end
	local controllers = {}
	for _, surface in pairs(game.surfaces) do
		for _, controller in pairs(surface.find_entities_filtered({ name = CONTROLLER })) do
			controllers[#controllers + 1] = controller
		end
	end
	table.sort(controllers, function(a, b)
		return a.unit_number < b.unit_number
	end)
	for _, controller in ipairs(controllers) do
		if not entries[controller.unit_number] then
			entries[controller.unit_number] = pair(controller, used)
		end
	end
end
local function settings(controller)
	local qualities, unlocked = {}, {}
	local q = prototypes.quality.normal
	while q do
		if controller.force.is_quality_unlocked(q.name) then
			qualities[#qualities + 1] = q.name
			unlocked[q.name] = true
		end
		q = q.next
	end
	local targets, ignored = {}, 0
	local cb = controller.get_control_behavior()
	if cb.enabled then
		for _, section in pairs(cb.sections) do
			if section.active then
				for _, filter in pairs(section.filters) do
					local v = filter.value
					local amount = math.floor((filter.min or 0) * section.multiplier)
					if v and amount > 0 then
						if
							(v.type or "item") == "item"
							and v.quality ~= "normal"
							and unlocked[v.quality or "normal"]
							and prototypes.item[v.name]
						then
							targets[v.name] = targets[v.name] or {}
							targets[v.name][v.quality] = (targets[v.name][v.quality] or 0) + amount
						else
							ignored = ignored + 1
						end
					end
				end
			end
		end
	end
	return targets, qualities, ignored
end
local function update(entry)
	local controller, condenser = entry.controller, entry.condenser
	local point = entry.input.get_logistic_point(defines.logistic_member_index.logistic_container)
	local net = point.logistic_network
	if net and not net.valid then
		net = nil
	end
	local targets, qualities, ignored = settings(controller)
	local inside, input, output = inventory(entry.box), inventory(entry.input), inventory(entry.output)
	local function compute()
		return plan.make(
			targets,
			qualities,
			contents(net and net.get_contents() or {}),
			contents(inside.get_contents()),
			contents(input.get_contents()),
			contents(point.targeted_items_deliver)
		)
	end
	local p = compute()
	move(inside, output, p.output)
	move(input, output, p.output)
	local blocked = false
	for _, n in pairs(p.output) do
		if n > 0 then
			blocked = true
			break
		end
	end
	if not blocked then
		local fed = move(input, inside, p.feed)
		local custom = condenser.custom_status

		if fed > 0 and custom and type(custom.label) == "table" and custom.label[1] == "entity-status.sleeping" then
			condenser.custom_status = nil
			condenser.disabled_by_script = false
		end
	end
	if blocked then
		if not condenser.disabled_by_script then
			entry.paused = true
		end
		condenser.disabled_by_script = true
	elseif entry.paused then
		if not condenser.custom_status then
			condenser.disabled_by_script = false
		end
		entry.paused = nil
	end
	-- Recalculate after transfers, so moving a delivered batch inside cannot request it twice.
	p = compute()
	local filters, keys = {}, {}
	for k, n in pairs(p.requests) do
		if n > 0 then
			keys[#keys + 1] = k
		end
	end
	table.sort(keys)
	for _, k in ipairs(keys) do
		local name, quality = split(k)
		filters[#filters + 1] =
			{ value = { type = "item", name = name, quality = quality, comparator = "=" }, min = p.requests[k] }
	end
	if not net then
		filters = {}
	end
	-- Native logistic sections have 1000 slots; use additional sections for larger configurations.
	local count = math.max(1, math.ceil(#filters / 1000))
	while point.sections_count < count do
		point.add_section()
	end
	for i, section in ipairs(point.sections) do
		local chunk = {}
		for j = (i - 1) * 1000 + 1, math.min(i * 1000, #filters) do
			chunk[#chunk + 1] = filters[j]
		end
		section.filters = chunk
	end
	if not net then
		status(controller, "No logistic network: add roboport coverage", true)
		return
	end
	local message = blocked and "Output full: make room in logistic storage"
		or (
			#keys > 0 and ("Requesting " .. #keys .. " item/quality pairs")
			or (p.waiting > 0 and "Waiting for lower-quality stock" or "Targets covered or batches in progress")
		)
	if ignored > 0 then
		message = message .. " · " .. ignored .. " invalid or locked targets ignored"
	end
	status(controller, message, blocked)
end
local M = {}
function M.on_init()
	storage.entries = {}
	rescan()
end
function M.on_configuration_changed()
	storage.entries = storage.entries or {}
	rescan()
end
function M.on_tick(event)
	if event.tick % 60 == 0 then
		rescan()
	end
	for _, entry in pairs(storage.entries) do
		if
			entry.controller.valid
			and entry.condenser.valid
			and entry.box.valid
			and entry.input.valid
			and entry.output.valid
		then
			update(entry)
		end
	end
end

return M
