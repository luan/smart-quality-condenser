local targets = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
targets.name = "smart-quality-condenser-targets"
targets.minable = { mining_time = 0.1, result = targets.name }
targets.item_slot_count = 1000
targets.hidden = true
local item = table.deepcopy(data.raw.item["constant-combinator"])
item.name = targets.name
item.place_result = targets.name
item.hidden = true
local recipe = {
	type = "recipe",
	name = targets.name,
	enabled = false,
	hidden = true,
	energy_required = 0.5,
	ingredients = {
		{ type = "item", name = "constant-combinator", amount = 1 },
		{ type = "item", name = "requester-chest", amount = 1 },
		{ type = "item", name = "active-provider-chest", amount = 1 },
	},
	results = { { type = "item", name = targets.name, amount = 1 } },
}
data:extend({ targets, item, recipe })
for _, kind in ipairs({ "input", "output" }) do
	local buffer =
		table.deepcopy(data.raw["logistic-container"][kind == "input" and "requester-chest" or "active-provider-chest"])
	buffer.name = "smart-quality-condenser-" .. kind
	buffer.inventory_size = 200
	buffer.quality_affects_inventory_size = false
	buffer.flags =
		{ "not-on-map", "not-blueprintable", "not-deconstructable", "not-flammable", "not-selectable-in-game" }
	buffer.hidden = true
	buffer.minable = nil
	buffer.collision_mask = { layers = {} }
	buffer.selection_box = { { 0, 0 }, { 0, 0 } }
	buffer.picture = nil
	buffer.animation = nil
	buffer.use_exact_mode = true
	data:extend({ buffer })
end
