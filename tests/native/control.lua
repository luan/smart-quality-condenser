local BLUEPRINT = require("blueprint")
local ITEMS = {
	"iron-plate",
	"copper-plate",
	"steel-plate",
	"iron-gear-wheel",
	"electronic-circuit",
	"advanced-circuit",
	"processing-unit",
	"copper-cable",
	"pipe",
	"pipe-to-ground",
	"engine-unit",
	"electric-engine-unit",
	"battery",
	"electric-furnace",
	"assembling-machine-3",
	"chemical-plant",
	"oil-refinery",
	"beacon",
	"solar-panel",
	"accumulator",
	"speed-module-3",
	"quality-module-3",
	"productivity-module-3",
	"gun-turret",
}
local function result(value)
	log("SMART_CONDENSER_QA " .. helpers.table_to_json(value))
	helpers.write_file("smart-condenser-qa.json", helpers.table_to_json(value), false)
end
script.on_init(function()
	local s, f = game.surfaces.nauvis, game.forces.player
	f.research_all_technologies()
	s.request_to_generate_chunks({ 0, 0 }, 2)
	s.force_generate_chunk_requests()
	for _, e in pairs(s.find_entities_filtered({ area = { { -32, -32 }, { 32, 32 } } })) do
		if e.type ~= "character" then
			e.destroy()
		end
	end
	local tiles = {}
	for x = -32, 32 do
		for y = -32, 32 do
			tiles[#tiles + 1] = { name = "lab-dark-1", position = { x, y } }
		end
	end
	s.set_tiles(tiles)
	local power = s.create_entity({ name = "electric-energy-interface", position = { -2, 8 }, force = f })
	power.power_production = 1e9
	power.electric_buffer_size = 1e10
	s.create_entity({ name = "substation", position = { -7, 1 }, force = f })
	local rp = s.create_entity({ name = "roboport", position = { -10, -8 }, force = f })
	rp.insert({ name = "logistic-robot", count = 100 })
	local cond = s.create_entity({
		name = "quality-condenser-forked",
		position = { 0.5, 0.5 },
		force = f,
		quality = "legendary",
		raise_built = true,
	})
	cond.set_recipe("quality-condenser-forked--recipe")
	cond.get_module_inventory().insert({ name = "smart-condenser-qa-module", quality = "legendary", count = 1 })
	local cc = s.create_entity({
		name = "smart-quality-condenser-targets",
		position = { 6.5, -5.5 },
		force = f,
		raise_built = true,
	})
	local sec = cc.get_control_behavior().get_section(1)
	local chest = s.create_entity({ name = "storage-chest", position = { -18.5, -6.5 }, force = f })
	for i, name in ipairs(ITEMS) do
		chest.insert({ name = name, count = 40 })
		sec.set_slot(i, { value = { type = "item", name = name, quality = "rare" }, min = 10 })
	end
	sec.set_slot(25, { value = { type = "item", name = "copper-cable", quality = "uncommon" }, min = 10 })
	sec.set_slot(26, { value = { type = "item", name = "iron-plate", quality = "legendary" }, min = 10 })
	-- The same item has targets at uncommon and rare, and plates at rare and legendary.
	storage.cond = cond
	storage.cc = cc
	storage.chest = chest
	storage.rp = rp
	storage.started = game.tick
end)
script.on_nth_tick(15, function()
	local ok, err = pcall(function()
		local t = game.tick - storage.started
		local c = storage.cond
		local s = c.surface
		local input =
			s.find_entities_filtered({ name = "smart-quality-condenser-input", position = c.position, limit = 1 })[1]
		local box = s.find_entities_filtered({
			name = "quality-condenser-forked--container",
			position = c.position,
			limit = 1,
		})[1]
		if t == 120 then
			assert(input, "No internal requester")
			local pt = input.get_logistic_point(defines.logistic_member_index.logistic_container)
			assert(#pt.filters > 5, "Requests still capped at five items")
			storage.request_count = #pt.filters
			result({ stage = "requesting", pairs = storage.request_count, tick = game.tick })
		end
		if t == 24000 or t == 42000 then
			local net = storage.rp.logistic_network
			for _, name in ipairs(ITEMS) do
				assert(net.get_item_count({ name = name, quality = "rare" }) >= 10, "Missing rare " .. name)
			end
			assert(
				net.get_item_count({ name = "copper-cable", quality = "uncommon" }) >= 10,
				"Mixed quality cable target missing"
			)
			assert(
				net.get_item_count({ name = "iron-plate", quality = "legendary" }) >= 10,
				"Legendary plate target missing"
			)
			local pt = input.get_logistic_point(defines.logistic_member_index.logistic_container)
			for _, filter in pairs(pt.filters or {}) do
				assert(filter.min == 0, "Requests continued after targets were reached")
			end
			if t == 24000 then
				assert(net.remove_item({ name = "iron-gear-wheel", quality = "rare", count = 10 }) == 10)
				storage.recovery = true
				result({
					stage = "targets-reached",
					targets = 26,
					request_pairs = storage.request_count,
					tick = game.tick,
				})
			else
				result({
					stage = "recovery-passed",
					targets = 26,
					request_pairs = storage.request_count,
					mixed_qualities = true,
					legendary = true,
					removed_in_progress_recovered = storage.removed or false,
					tick = game.tick,
				})
			end
		end
		if t == 10005 then
			storage.duplicate =
				s.create_entity({ name = "smart-quality-condenser-targets", position = { 7.5, -4.5 }, force = c.force })
		end
		if t == 10140 then
			assert(
				storage.duplicate.custom_status.label == "This condenser already has a target combinator",
				"Duplicate controller was allowed"
			)
			storage.duplicate.destroy()
		end
		if t == 42000 then
			assert(storage.removed, "In-progress removal was not exercised")
			storage.rp.destroy()
			local out = s.find_entities_filtered({
				name = "smart-quality-condenser-output",
				position = c.position,
				limit = 1,
			})[1]
			local inv = out.get_inventory(defines.inventory.chest)
			inv.clear()
			for i = 1, #inv do
				inv[i].set_stack({ name = "stone", count = prototypes.item.stone.stack_size })
			end
			box.get_inventory(defines.inventory.chest).insert({ name = "iron-plate", quality = "rare", count = 10 })
			storage.cc.get_control_behavior().enabled = false
		end
		if t == 42030 then
			assert(c.disabled_by_script, "A full output did not pause the condenser")
			assert(
				box.get_inventory(defines.inventory.chest).get_item_count({ name = "iron-plate", quality = "rare" })
					== 10,
				"Blocked output upgraded past the target"
			)
			s.find_entities_filtered({ name = "smart-quality-condenser-output", position = c.position, limit = 1 })[1]
				.get_inventory(defines.inventory.chest)
				.clear()
		end
		if t == 42060 then
			assert(
				box.get_inventory(defines.inventory.chest).is_empty(),
				"Finished items were not extracted without coverage"
			)
			local out = s.find_entities_filtered({
				name = "smart-quality-condenser-output",
				position = c.position,
				limit = 1,
			})[1]
			assert(
				out.get_inventory(defines.inventory.chest).get_item_count({ name = "iron-plate", quality = "rare" })
					== 10
			)
			storage.cc.destroy()
		end
		if t == 42105 then
			local surface = game.create_surface("smart-qa-paste", { width = 128, height = 128 })
			surface.generate_with_lab_tiles = true
			surface.request_to_generate_chunks({ 0, 0 }, 1)
			surface.force_generate_chunk_requests()
			local inv = game.create_inventory(1)
			assert(inv[1].import_stack(BLUEPRINT) == 0, "Blueprint import failed")
			local ghosts = inv[1].build_blueprint({
				surface = surface,
				force = c.force,
				position = { 0, 0 },
				build_mode = defines.build_mode.forced,
				raise_built = true,
			})
			assert(#ghosts == 4, "Blueprint should contain four entities")
			for _, g in pairs(ghosts) do
				if g.valid then
					local _, e, proxy = g.revive({ raise_revive = true })
					assert(e, "Blueprint entity could not be built")
					if proxy then
						proxy.destroy()
					end
				end
			end
			assert(
				surface.count_entities_filtered({ name = "smart-quality-condenser-targets" }) == 1,
				"Target combinator did not survive the blueprint"
			)
			inv.destroy()
			storage.paste = surface
		end
		if t == 42120 then
			assert(s.count_entities_filtered({
				name = { "smart-quality-condenser-input", "smart-quality-condenser-output" },
			}) == 0, "Internal buffers leaked after controller removal")
			result({
				passed = true,
				targets = 26,
				request_pairs = storage.request_count,
				mixed_qualities = true,
				legendary = true,
				removed_in_progress_recovered = true,
				duplicate_rejected = true,
				blocked_output_preserved = true,
				removal_spilled_contents = true,
				blueprint_pasted = true,
				tick = game.tick,
			})
		end
		if storage.recovery and not storage.removed and t > 24000 and box then
			local inv = box.get_inventory(defines.inventory.chest)
			local count = inv.get_item_count({ name = "iron-gear-wheel", quality = "normal" })
			if count > 0 then
				inv.remove({ name = "iron-gear-wheel", quality = "normal", count = count })
				storage.chest.insert({ name = "iron-gear-wheel", count = count })
				storage.removed = true
			end
		end
	end)
	if not ok then
		result({ passed = false, error = tostring(err), tick = game.tick })
		error(err)
	end
end)
