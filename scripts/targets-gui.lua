local Smart = require("scripts.smart-logistics")
local M = {}
local ROOT = "smart-quality-condenser-editor"
local PREFIX = "smart-quality-condenser-"
local function close(player)
	local frame = player.gui.screen[ROOT]
	if frame then
		frame.destroy()
	end
	storage.target_views = storage.target_views or {}
	storage.target_views[player.index] = nil
end
local function entry_for(player)
	local id = storage.target_views and storage.target_views[player.index]
	local entry = id and storage.entries[id]
	if entry and entry.condenser.valid then
		return entry
	end
end
local function body_for(player)
	local frame = player.gui.screen[ROOT]
	return frame and frame[PREFIX .. "tabs"]["content-3"]
end
local function render_grid(body, entry)
	local grid = body.scroll.grid
	grid.clear()
	local slots = math.max(40, math.ceil((#entry.targets + 1) / 10) * 10)
	for i = 1, slots do
		local target = entry.targets[i]
		local item = target and target.item
		local slot = grid.add({
			type = "sprite-button",
			name = "slot-" .. i,
			style = "slot_button",
			tags = { sqc = "slot", row = i },
			mouse_button_filter = { "left", "right" },
		})
		if item then
			slot.sprite = "item/" .. item.name
			slot.quality = item.quality
			slot.number = target.count or 0
			slot.tooltip = {
				"",
				prototypes.item[item.name].localised_name,
				" (",
				prototypes.quality[item.quality].localised_name,
				")\n",
				{ "sqc.stock" },
				": ",
				tostring(target.count or 0),
				"\n",
				{ "sqc.slot-help" },
			}
		else
			slot.tooltip = { "sqc.add" }
			if i == #entry.targets + 1 then
				slot.sprite = "utility/add"
			end
		end
	end
	body["automation-enabled"].state = entry.enabled
end
local function edit_slot(player, entry, index)
	local body = body_for(player)
	local editor = body["slot-editor"]
	editor.clear()
	editor.visible = true
	editor.tags = { row = index, revision = entry.target_revision or 0 }
	local target = entry.targets[index] or { count = 50 }
	editor.add({ type = "label", caption = { target.item and "sqc.edit" or "sqc.add" }, style = "heading_2_label" })
	local fields = editor.add({ type = "flow", name = "fields", direction = "horizontal" })
	local item = fields.add({
		type = "choose-elem-button",
		name = "item",
		elem_type = "item-with-quality",
		tags = {
			sqc = "item",
		},
	})
	item.elem_value = target.item
	local details = fields.add({ type = "flow", name = "details", direction = "vertical" })
	local label = details.add({
		type = "label",
		name = "item-label",
		caption = target.item and prototypes.item[target.item.name].localised_name or { "sqc.choose-item" },
	})
	label.style.width = 290
	local amount_row = details.add({ type = "flow", name = "stock", direction = "horizontal" })
	amount_row.add({ type = "label", caption = { "sqc.stock" } })
	local amount = amount_row.add({
		type = "textfield",
		name = "amount",
		text = tostring(target.count or 0),
		numeric = true,
		allow_decimal = false,
		allow_negative = false,
		tags = { sqc = "amount" },
	})
	amount.style.width = 110
	local error_label = editor.add({ type = "label", name = "error-label", caption = "" })
	error_label.style.font_color = { 1, 0.45, 0.35 }
	error_label.style.single_line = false
	error_label.style.width = 400
	error_label.visible = false
	local actions = editor.add({ type = "flow", name = "actions", direction = "horizontal" })
	actions.add({ type = "button", name = "cancel", caption = { "gui.cancel" }, tags = { sqc = "cancel" } })
	actions.add({
		type = "button",
		name = "apply",
		caption = { "gui.confirm" },
		style = "confirm_button",
		tags = {
			sqc = "apply",
		},
	})
	if target.item then
		amount.focus()
		amount.select_all()
	end
end
function M.open(player, entry)
	close(player)
	storage.target_views[player.index] = entry.condenser.unit_number
	local frame = player.gui.screen.add({ type = "frame", name = ROOT, direction = "vertical" })
	frame.auto_center = true
	local title = frame.add({ type = "flow", direction = "horizontal" })
	title.add({ type = "label", caption = { "entity-name.quality-condenser-forked" }, style = "frame_title" }).drag_target =
		frame
	local space = title.add({ type = "empty-widget", style = "draggable_space_header" })
	space.style.horizontally_stretchable = true
	space.style.height = 24
	space.drag_target = frame
	title.add({
		type = "sprite-button",
		sprite = "utility/close",
		style = "frame_action_button",
		tags = { sqc = "close" },
	})
	local pane = frame.add({ type = "tabbed-pane", name = PREFIX .. "tabs" })
	for i, caption in ipairs({ "Modules", "Inventory", "Targets" }) do
		local tab = pane.add({ type = "tab", caption = { "sqc." .. caption:lower() } })
		local content = pane.add({ type = "flow", direction = "vertical", name = "content-" .. i })
		pane.add_tab(tab, content)
	end
	pane.selected_tab_index = 3
	local body = pane["content-3"]
	local hint = body.add({ type = "label", caption = { "sqc.grid-help" } })
	hint.style.single_line = false
	hint.style.width = 440
	body.add({
		type = "checkbox",
		name = "automation-enabled",
		caption = { "sqc.enabled" },
		tooltip = { "sqc.help" },
		state = entry.enabled,
		tags = {
			sqc = "enabled",
		},
	})
	local status = body.add({ type = "label", name = "status", caption = entry.status or { "sqc.starting" } })
	status.style.single_line = false
	status.style.width = 440
	local hint = body.add({ type = "label", caption = { "sqc.slot-help" } })
	hint.style.font_color = { 0.7, 0.7, 0.7 }
	local scroll =
		body.add({ type = "scroll-pane", name = "scroll", direction = "vertical", horizontal_scroll_policy = "never" })
	scroll.style.maximal_height = 320
	scroll.style.minimal_width = 440
	local grid = scroll.add({ type = "table", name = "grid", column_count = 10 })
	grid.style.horizontal_spacing = 0
	grid.style.vertical_spacing = 0
	local editor =
		body.add({ type = "frame", name = "slot-editor", direction = "vertical", style = "inside_shallow_frame" })
	editor.visible = false
	render_grid(body, entry)
	player.opened = frame
end
local function refresh(entry, except)
	for _, player in pairs(game.players) do
		if player.index ~= except and entry_for(player) == entry then
			local body = body_for(player)
			if body then
				render_grid(body, entry)
			end
		end
	end
end
function M.on_gui_opened(event)
	if event.entity then
		local player = game.get_player(event.player_index)
		close(player)
	end
end
function M.on_gui_closed(event)
	if event.element and event.element.valid and event.element.name == ROOT then
		close(game.get_player(event.player_index))
	end
end
local function changed(entry)
	entry.target_revision = (entry.target_revision or 0) + 1
	refresh(entry)
end
local function commit(player, entry)
	local editor = body_for(player)["slot-editor"]
	if not editor.visible then
		return
	end
	local item = editor.fields.item.elem_value
	local amount = tonumber(editor.fields.details.stock.amount.text)
	local message
	if editor.tags.revision ~= (entry.target_revision or 0) then
		message = { "sqc.changed" }
	elseif not item or item.quality == "normal" or not entry.condenser.force.is_quality_unlocked(item.quality) then
		message = { "sqc.invalid-item" }
	elseif not amount or amount < 1 or amount > 2147483647 then
		message = { "sqc.invalid-count" }
	end
	if message then
		editor["error-label"].caption = message
		editor["error-label"].visible = true
		return
	end
	local index = math.min(editor.tags.row, #entry.targets + 1)
	entry.targets[index] = { item = { name = item.name, quality = item.quality }, count = math.floor(amount) }
	entry.enabled = true
	editor.visible = false
	changed(entry)
end
function M.on_gui_click(event)
	local action = event.element.tags.sqc
	if not action then
		return
	end
	local player = game.get_player(event.player_index)
	local entry = entry_for(player)
	if action == "close" then
		player.opened = nil
		close(player)
		return
	end
	if not entry then
		close(player)
		return
	end
	if action == "slot" then
		local index = event.element.tags.row
		if event.button == defines.mouse_button_type.right then
			if entry.targets[index] then
				table.remove(entry.targets, index)
				body_for(player)["slot-editor"].visible = false
				changed(entry)
			end
		else
			edit_slot(player, entry, math.min(index, #entry.targets + 1))
		end
	elseif action == "apply" then
		commit(player, entry)
	elseif action == "cancel" then
		body_for(player)["slot-editor"].visible = false
	end
end
function M.on_gui_elem_changed(event)
	if event.element.tags.sqc ~= "item" then
		return
	end
	local player = game.get_player(event.player_index)
	local body = body_for(player)
	if not body then
		return
	end
	local item = event.element.elem_value
	body["slot-editor"].fields.details["item-label"].caption = item and prototypes.item[item.name].localised_name
		or { "sqc.choose-item" }
end
function M.on_gui_confirmed(event)
	if event.element.tags.sqc ~= "amount" then
		return
	end
	local player = game.get_player(event.player_index)
	local entry = entry_for(player)
	if entry then
		commit(player, entry)
	end
end
function M.on_gui_checked_state_changed(event)
	if event.element.tags.sqc ~= "enabled" then
		return
	end
	local player = game.get_player(event.player_index)
	local entry = entry_for(player)
	if entry then
		entry.enabled = event.element.state
		changed(entry)
	end
end
function M.on_gui_selected_tab_changed(event)
	if event.element.name ~= PREFIX .. "tabs" then
		return
	end
	local index = event.element.selected_tab_index
	if index == 3 then
		return
	end
	local player = game.get_player(event.player_index)
	local entry = entry_for(player)
	if not entry then
		close(player)
		return
	end
	local entity = index == 1 and entry.condenser or entry.box
	player.opened = entity
	close(player)
end
function M.on_tick()
	for index in pairs(storage.target_views or {}) do
		local player = game.get_player(index)
		local entry = player and entry_for(player)
		local frame = player and player.gui.screen[ROOT]
		if not entry or not frame then
			if player then
				close(player)
			end
		else
			frame[PREFIX .. "tabs"]["content-3"].status.caption = entry.status or { "sqc.starting" }
		end
	end
end
function M.reset()
	for _, player in pairs(game.players) do
		close(player)
	end
end
function M.on_blueprint(event)
	local player = game.get_player(event.player_index)
	local stack = player.blueprint_to_setup
	if not stack.valid_for_read then
		stack = player.cursor_stack
	end
	if not stack or not stack.valid_for_read or not stack.is_blueprint then
		return
	end
	for index, entity in pairs(event.mapping.get()) do
		local entry = Smart.get(entity)
		if entry then
			stack.set_blueprint_entity_tag(index, "smart_quality_condenser", Smart.config(entry))
		end
	end
end
function M.on_settings_pasted(event)
	local source, dest = Smart.get(event.source), Smart.get(event.destination)
	if source and dest then
		Smart.apply(dest, Smart.config(source))
		changed(dest)
	end
end
return M
