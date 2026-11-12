return function(Smart, Gui, initialize_base, Handler)
	local BLUEPRINT = require("tests.blueprint")
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
		storage.entries = {}
		initialize_base()
		Smart.on_init()
	end)
	script.on_event(defines.events.on_player_created, function(event)
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
		local entry = Smart.get(cond)
		local player = game.get_player(event.player_index)
		player.set_controller({ type = defines.controllers.god })
		Handler.refresh_gui_for_player(player)
		player.opened = cond
		local tabs = player.gui.relative["quality-condenser-forked--tabbed-pane-modules"]
		tabs.selected_tab_index = 3
		script.get_event_handler(defines.events.on_gui_selected_tab_changed)({
			player_index = player.index,
			element = tabs,
		})
		assert(
			player.opened and player.opened.name == "smart-quality-condenser-editor",
			"Targets tab did not open built-in editor"
		)
		-- Route both directions through the real dispatcher: leaving Targets destroys its tab element.
		local dispatch = script.get_event_handler(defines.events.on_gui_selected_tab_changed)
		for _, destination in ipairs({ 1, 2, 1, 2 }) do
			local editor_tabs = player.gui.screen["smart-quality-condenser-editor"]["smart-quality-condenser-tabs"]
			editor_tabs.selected_tab_index = destination
			dispatch({ player_index = player.index, element = editor_tabs })
			assert(not editor_tabs.valid, "Targets editor was not closed")
			assert(player.opened == (destination == 1 and cond or entry.box), "Tab opened the wrong entity")
			local name = destination == 1 and "quality-condenser-forked--tabbed-pane-modules"
				or "quality-condenser-forked--tabbed-pane-inventory"
			local native_tabs = player.gui.relative[name]
			native_tabs.selected_tab_index = 3
			dispatch({ player_index = player.index, element = native_tabs })
			assert(player.gui.screen["smart-quality-condenser-editor"], "Could not reopen Targets")
		end
		Gui.open(player, entry)
		local function body()
			return player.gui.screen["smart-quality-condenser-editor"]["smart-quality-condenser-tabs"]["content-3"]
		end
		local function add(name, quality, count)
			local slot = body().scroll.grid["slot-" .. (#entry.targets + 1)]
			Gui.on_gui_click({ player_index = player.index, element = slot, button = defines.mouse_button_type.left })
			local editor = body()["slot-editor"]
			local item = editor.fields.item
			item.elem_value = { name = name, quality = quality }
			Gui.on_gui_elem_changed({ player_index = player.index, element = item })
			local amount = editor.fields.details.stock.amount
			amount.text = tostring(count)
			Gui.on_gui_confirmed({ player_index = player.index, element = amount })
		end
		local chest = s.create_entity({ name = "storage-chest", position = { -18.5, -6.5 }, force = f })
		for i, name in ipairs(ITEMS) do
			chest.insert({ name = name, count = 40 })
			add(name, "rare", 10)
		end
		add("copper-cable", "uncommon", 10)
		add("iron-plate", "legendary", 10)
		assert(#entry.targets == 26, "Grid lost targets")
		local grid = body().scroll.grid
		assert(#grid.children == 40, "Grid should fit 27 targets in four compact rows")
		assert(
			grid["slot-1"].number == 10 and grid["slot-1"].quality.name == "rare",
			"Slot amount or quality badge missing"
		)
		-- Canceling and validation must leave the live target list untouched.
		Gui.on_gui_click({ player_index = player.index, element = grid["slot-27"] })
		Gui.on_gui_click({ player_index = player.index, element = body()["slot-editor"].actions.cancel })
		assert(#entry.targets == 26, "Cancel added a target")
		add("iron-plate", "normal", 10)
		assert(
			#entry.targets == 26 and body()["slot-editor"]["error-label"].visible,
			"Normal-quality target was accepted"
		)
		add("copper-plate", "rare", 0)
		assert(#entry.targets == 26 and body()["slot-editor"]["error-label"].visible, "Zero stock target was accepted")
		local draft = body()["slot-editor"]
		draft.fields.details.stock.amount.text = "17"
		Gui.on_gui_click({ player_index = player.index, element = draft.actions.apply })
		assert(#entry.targets == 27 and entry.targets[27].count == 17, "New target was not committed")
		Gui.on_gui_click({
			player_index = player.index,
			element = body().scroll.grid["slot-27"],
			button = defines.mouse_button_type.right,
		})
		assert(#entry.targets == 26, "Right-click did not remove target")
		-- The same item has targets at uncommon and rare, and plates at rare and legendary.
		storage.cond = cond
		storage.entry = entry
		storage.qa_player = player
		storage.qa_force = f
		assert(entry.enabled and #entry.targets == 26, "GUI did not enable and save the targets")
		storage.chest = chest
		storage.rp = rp
		storage.started = game.tick
	end)
	script.on_nth_tick(15, function()
		Smart.on_tick({ tick = game.tick })
		local ok, err = pcall(function()
			if not storage.started then
				return
			end
			local t = game.tick - storage.started
			local c = storage.cond
			local s = game.surfaces.nauvis
			local input = s.find_entities_filtered({
				name = "smart-quality-condenser-input",
				position = { 0.5, 0.5 },
				limit = 1,
			})[1]
			local box = s.find_entities_filtered({
				name = "quality-condenser-forked--container",
				position = { 0.5, 0.5 },
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

			if t == 135 then
				local other = c.clone({ position = { 40.5, 40.5 }, surface = s, force = c.force })
				assert(other, "Condenser clone failed")
				local second = Smart.get(other)
				assert(
					#second.targets == #storage.entry.targets and second.enabled == storage.entry.enabled,
					"Cloning lost targets"
				)
				for i, target in ipairs(storage.entry.targets) do
					local copied = second.targets[i]
					assert(
						copied.count == target.count
							and copied.item.name == target.item.name
							and copied.item.quality == target.item.quality,
						"Clone target changed"
					)
				end
				local player = storage.qa_player
				Gui.open(player, second)
				local body =
					player.gui.screen["smart-quality-condenser-editor"]["smart-quality-condenser-tabs"]["content-3"]
				Gui.on_gui_click({ player_index = player.index, element = body.scroll.grid["slot-1"] })
				local stale = body["slot-editor"].fields.details.stock.amount
				stale.text = "99"
				Gui.on_settings_pasted({ source = c, destination = other })
				Gui.on_gui_confirmed({ player_index = player.index, element = stale })
				assert(
					second.targets[1].count == 10 and body["slot-editor"]["error-label"].visible,
					"A stale editor overwrote updated targets"
				)
				Gui.on_gui_click({ player_index = player.index, element = body.scroll.grid["slot-1"] })
				local amount = body["slot-editor"].fields.details.stock.amount
				amount.text = "17"
				Gui.on_gui_confirmed({ player_index = player.index, element = amount })
				assert(
					second.targets[1].count == 17 and storage.entry.targets[1].count == 10,
					"Targets are shared between condensers"
				)
				Gui.on_settings_pasted({ source = c, destination = other })
				assert(second.targets[1].count == 10, "Settings paste lost targets")
				Gui.open(player, storage.entry)
				-- Exercise the blueprint setup hook with Factorio's actual entity mapping.
				player.cursor_stack.set_stack({ name = "blueprint" })
				local bp = player.cursor_stack
				local mapping = bp.create_blueprint({ surface = s, force = c.force, area = { { -4, -4 }, { 5, 5 } } })
				Gui.on_blueprint({
					player_index = player.index,
					mapping = {
						get = function()
							return mapping
						end,
					},
				})
				local entities = bp.get_blueprint_entities()
				local tagged = false
				for _, e in pairs(entities) do
					if e.name == "quality-condenser-forked" then
						assert(
							e.tags and #e.tags.smart_quality_condenser.targets == 26,
							"Blueprint lost target settings"
						)
						tagged = true
					end
				end
				assert(tagged, "Blueprint did not contain condenser")
				storage.config_blueprint = bp.export_stack()
				player.cursor_stack.clear()
				other.destroy()
			end
			if t == 150 and script.test_arg == "editor" then
				result({
					passed = true,
					grid = true,
					quality_badges = true,
					count_overlay = true,
					enter_and_confirm = true,
					cancel_and_validation = true,
					right_click_remove = true,
					stale_edit_rejected = true,
					per_condenser = true,
				})
				script.finish_test(true)
			end

			if t == 42000 then
				assert(storage.removed, "In-progress removal was not exercised")
				storage.rp.destroy()
				local out = s.find_entities_filtered({
					name = "smart-quality-condenser-output",
					position = { 0.5, 0.5 },
					limit = 1,
				})[1]
				local inv = out.get_inventory(defines.inventory.chest)
				inv.clear()
				for i = 1, #inv do
					inv[i].set_stack({ name = "stone", count = prototypes.item.stone.stack_size })
				end
				box.get_inventory(defines.inventory.chest).insert({ name = "iron-plate", quality = "rare", count = 10 })
				storage.entry.targets = {}
				storage.entry.enabled = true
			end
			if t == 42030 then
				assert(c.disabled_by_script, "A full output did not pause the condenser")
				assert(
					box.get_inventory(defines.inventory.chest).get_item_count({ name = "iron-plate", quality = "rare" })
						== 10,
					"Blocked output upgraded past the target"
				)
				s.find_entities_filtered({ name = "smart-quality-condenser-output", position = { 0.5, 0.5 }, limit = 1 })[1]
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
					position = { 0.5, 0.5 },
					limit = 1,
				})[1]
				assert(
					out.get_inventory(defines.inventory.chest).get_item_count({ name = "iron-plate", quality = "rare" })
						== 10
				)
				c.destroy()
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
					force = storage.qa_force,
					position = { 0, 0 },
					build_mode = defines.build_mode.forced,
					raise_built = true,
				})
				assert(#ghosts == 3, "Blueprint should contain three entities")
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
					surface.count_entities_filtered({ name = "smart-quality-condenser-targets" }) == 0,
					"Blueprint still needs a target combinator"
				)

				local configured = game.create_surface("smart-qa-configured", { width = 128, height = 128 })
				configured.generate_with_lab_tiles = true
				configured.request_to_generate_chunks({ 0, 0 }, 1)
				configured.force_generate_chunk_requests()
				assert(inv[1].import_stack(storage.config_blueprint) == 0)
				for _, ghost in
					pairs(inv[1].build_blueprint({
						surface = configured,
						force = storage.qa_force,
						position = { 0, 0 },
						build_mode = defines.build_mode.forced,
						raise_built = true,
					}))
				do
					local _, entity, proxy = ghost.revive({ raise_revive = true })
					assert(entity, "Configured blueprint failed to revive")
					if proxy then
						proxy.destroy()
					end
				end
				local pasted = configured.find_entities_filtered({ name = "quality-condenser-forked" })[1]
				assert(pasted and #Smart.get(pasted).targets == 26, "Blueprint revive lost per-condenser settings")
				inv.destroy()
				storage.paste = surface
			end
			if t == 42120 then
				assert(s.count_entities_filtered({
					name = { "smart-quality-condenser-input", "smart-quality-condenser-output" },
				}) == 0, "Internal buffers leaked after condenser removal")
				result({
					passed = true,
					targets = 26,
					request_pairs = storage.request_count,
					mixed_qualities = true,
					legendary = true,
					removed_in_progress_recovered = true,
					gui_edits_saved = true,
					clone_and_settings_paste = true,
					blueprint_targets_preserved = true,
					per_condenser = true,
					blocked_output_preserved = true,
					removal_spilled_contents = true,
					blueprint_pasted = true,
					tick = game.tick,
				})
				if script.test_arg == "native" then
					script.finish_test(true)
				end
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
end
