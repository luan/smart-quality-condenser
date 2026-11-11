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
local function row(table_gui, target, index)
	local item = table_gui.add({
		type = "choose-elem-button",
		elem_type = "item-with-quality",
		name = "item-" .. index,
		tags = { sqc = "item", row = index },
	})
	item.elem_value = target.item
	local label = table_gui.add({
		type = "label",
		name = "label-" .. index,
		caption = target.item and prototypes.item[target.item.name].localised_name or { "sqc.choose-item" },
	})
	label.style.width = 210
	local amount = table_gui.add({
		type = "textfield",
		name = "amount-" .. index,
		text = tostring(target.count or 0),
		numeric = true,
		allow_decimal = false,
		allow_negative = false,
		tags = { sqc = "amount", row = index },
	})
	amount.style.width = 100
	table_gui.add({
		type = "sprite-button",
		sprite = "utility/trash",
		style = "tool_button",
		tooltip = { "sqc.remove" },
		tags = { sqc = "remove", row = index },
	})
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
	local hint = body.add({ type = "label", caption = { "sqc.help" } })
	hint.style.single_line = false
	hint.style.width = 480
	body.add({
		type = "checkbox",
		name = "automation-enabled",
		caption = { "sqc.enabled" },
		state = entry.enabled,
		tags = {
			sqc = "enabled",
		},
	})
	local status = body.add({ type = "label", name = "status", caption = entry.status or { "sqc.starting" } })
	status.style.single_line = false
	status.style.width = 480
	local headers = body.add({ type = "flow", direction = "horizontal" })
	headers.add({ type = "label", caption = { "sqc.item-quality" } }).style.width = 254
	headers.add({ type = "label", caption = { "sqc.stock" } })
	local scroll =
		body.add({ type = "scroll-pane", name = "scroll", direction = "vertical", horizontal_scroll_policy = "never" })
	scroll.style.maximal_height = 420
	scroll.style.minimal_width = 480
	local rows = scroll.add({ type = "table", name = "rows", column_count = 4, vertical_centering = true })
	for i, target in ipairs(entry.targets) do
		row(rows, target, i)
	end
	body.add({ type = "button", caption = { "sqc.add" }, tags = { sqc = "add" } })
	player.opened = frame
end
local function refresh(entry, except)
	for _, player in pairs(game.players) do
		if player.index ~= except and entry_for(player) == entry then
			M.open(player, entry)
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
	if action == "add" then
		entry.targets[#entry.targets + 1] = { count = 50 }
		M.open(player, entry)
		refresh(entry, player.index)
	elseif action == "remove" then
		table.remove(entry.targets, event.element.tags.row)
		M.open(player, entry)
		refresh(entry, player.index)
	end
end
function M.on_gui_elem_changed(event)
	if event.element.tags.sqc ~= "item" then
		return
	end
	local player = game.get_player(event.player_index)
	local entry = entry_for(player)
	if not entry then
		return
	end
	local target = entry.targets[event.element.tags.row]
	if not target then
		return
	end
	target.item = event.element.elem_value
	if target.item and target.item.quality ~= "normal" then
		entry.enabled = true
		player.gui.screen[ROOT][PREFIX .. "tabs"]["content-3"]["automation-enabled"].state = true
	end
	local label = event.element.parent["label-" .. event.element.tags.row]
	label.caption = target.item and prototypes.item[target.item.name].localised_name or { "sqc.choose-item" }
	refresh(entry, player.index)
end
function M.on_gui_text_changed(event)
	if event.element.tags.sqc ~= "amount" then
		return
	end
	local player = game.get_player(event.player_index)
	local entry = entry_for(player)
	local target = entry and entry.targets[event.element.tags.row]
	if not target then
		return
	end
	target.count = math.min(2147483647, tonumber(event.element.text) or 0)
	refresh(entry, player.index)
end
function M.on_gui_checked_state_changed(event)
	if event.element.tags.sqc ~= "enabled" then
		return
	end
	local player = game.get_player(event.player_index)
	local entry = entry_for(player)
	if entry then
		entry.enabled = event.element.state
		refresh(entry, player.index)
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
		refresh(dest)
	end
end
return M
