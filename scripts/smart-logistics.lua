local plan = require("scripts.smart-plan")
local copy = require("util").copy
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
local function create_entry(condenser)
	local box =
		condenser.surface.find_entities_filtered({ name = CONTAINER, position = condenser.position, limit = 1 })[1]
	if not box then
		return
	end
	local entry = { condenser = condenser, box = box, targets = {}, enabled = false }
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
	return entry
end
local function legacy_settings(controller)
	local targets = {}
	for _, section in pairs(controller.get_control_behavior().sections) do
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
	return targets, controller.get_control_behavior().enabled
end
local function adopt(controller, entries)
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
	local entry = condenser and entries[condenser.unit_number]
	if not entry then
		return
	end
	local targets, enabled = legacy_settings(controller)
	for _, target in ipairs(targets) do
		entry.targets[#entry.targets + 1] = target
	end
	entry.enabled = entry.enabled or enabled
	-- Refund the retired controller's ingredients through its native provider buffer.
	for _, name in ipairs({ "constant-combinator", "requester-chest", "active-provider-chest" }) do
		local stack = { name = name, quality = controller.quality.name, count = 1 }
		stack.count = stack.count - inventory(entry.output).insert(stack)
		if stack.count > 0 then
			controller.surface.spill_item_stack({
				position = controller.position,
				stack = stack,
				force = controller.force,
				allow_belts = false,
			})
		end
	end
	controller.destroy()
end
local function rescan()
	local entries = storage.entries
	for id, entry in pairs(entries) do
		if not entry.condenser.valid or not entry.box.valid or not entry.input.valid or not entry.output.valid then
			release(entry)
			entries[id] = nil
		end
	end
	for _, surface in pairs(game.surfaces) do
		for _, condenser in pairs(surface.find_entities_filtered({ name = CONDENSER })) do
			if not entries[condenser.unit_number] then
				entries[condenser.unit_number] = create_entry(condenser)
			end
		end
		local controllers = surface.find_entities_filtered({ name = CONTROLLER })
		table.sort(controllers, function(a, b)
			return a.unit_number < b.unit_number
		end)
		for _, controller in ipairs(controllers) do
			adopt(controller, entries)
		end
	end
end
local function settings(entry)
	local qualities, unlocked = {}, {}
	local q = prototypes.quality.normal
	while q do
		if entry.condenser.force.is_quality_unlocked(q.name) then
			qualities[#qualities + 1] = q.name
			unlocked[q.name] = true
		end
		q = q.next
	end
	local targets, ignored = {}, 0
	if entry.enabled then
		for _, target in ipairs(entry.targets) do
			local v = target.item
			local amount = math.floor(target.count or 0)
			if v and amount > 0 then
				if v.quality ~= "normal" and unlocked[v.quality] and prototypes.item[v.name] then
					targets[v.name] = targets[v.name] or {}
					targets[v.name][v.quality] = (targets[v.name][v.quality] or 0) + amount
				else
					ignored = ignored + 1
				end
			end
		end
	end
	return targets, qualities, ignored
end
local function set_status(entry, message, bad)
	entry.status = message
	entry.status_bad = bad
end
local function update(entry)
	local condenser = entry.condenser
	local point = entry.input.get_logistic_point(defines.logistic_member_index.logistic_container)
	local net = point.logistic_network
	if net and not net.valid then
		net = nil
	end
	if not entry.enabled then
		for _, section in pairs(point.sections) do
			section.filters = {}
		end
		if entry.paused and not condenser.custom_status then
			condenser.disabled_by_script = false
		end
		entry.paused = nil
		set_status(entry, "Automatic logistics off", false)
		return
	end
	local targets, qualities, ignored = settings(entry)
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
		set_status(entry, "No logistic network: add roboport coverage", true)
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
	set_status(entry, message, blocked)
end
local M = {}
function M.get(entity)
	if not entity or not entity.valid then
		return
	end
	if entity.name == CONTAINER then
		entity = entity.surface.find_entities_filtered({
			name = CONDENSER,
			position = entity.position,
			force = entity.force,
			limit = 1,
		})[1]
	end
	if not entity or entity.name ~= CONDENSER then
		return
	end
	local entry = storage.entries[entity.unit_number]
	if not entry then
		entry = create_entry(entity)
		storage.entries[entity.unit_number] = entry
	end
	return entry
end
function M.config(entry)
	return { targets = copy(entry.targets), enabled = entry.enabled }
end
function M.apply(entry, config)
	if not entry or type(config) ~= "table" then
		return
	end
	local targets = {}
	for _, target in ipairs(config.targets or {}) do
		local item = target.item
		if item and prototypes.item[item.name] and prototypes.quality[item.quality or "normal"] then
			targets[#targets + 1] = {
				item = { name = item.name, quality = item.quality or "normal" },
				count = math.max(0, math.min(2147483647, math.floor(tonumber(target.count) or 0))),
			}
		end
	end
	entry.targets = targets
	entry.enabled = config.enabled == true
end
function M.on_created_entity(event)
	local entity = event.entity or event.destination
	if entity.name ~= CONDENSER then
		return
	end
	local entry = M.get(entity)
	local config = event.tags and event.tags.smart_quality_condenser
	if event.source then
		local source = M.get(event.source)
		if source then
			config = M.config(source)
		end
	end
	if config then
		M.apply(entry, config)
	end
end
function M.on_init()
	storage.entries = storage.entries or {}
	rescan()
end
function M.on_configuration_changed()
	local entries = {}
	for _, entry in pairs(storage.entries or {}) do
		if entry.condenser.valid then
			if entry.controller and entry.controller.valid then
				entry.targets, entry.enabled = legacy_settings(entry.controller)
				-- rescan retires the controller; its targets have already been copied.
				for _, section in pairs(entry.controller.get_control_behavior().sections) do
					section.filters = {}
				end
			end
			entry.controller = nil
			entry.targets = entry.targets or {}
			entry.enabled = entry.enabled or false
			entries[entry.condenser.unit_number] = entry
		else
			release(entry)
		end
	end
	storage.entries = entries
	rescan()
end
function M.on_tick(event)
	if event.tick % 60 == 0 then
		rescan()
	end
	for _, entry in pairs(storage.entries) do
		if entry.condenser.valid and entry.box.valid and entry.input.valid and entry.output.valid then
			update(entry)
		end
	end
end
return M
