require("shared")
mod_prefix = "quality-condenser-forked--"

local Combinators = require("scripts.combinators")
local Beacons = require("scripts.beacons")
local Smart = require("scripts.smart-logistics")
local TargetsGui = require("scripts.targets-gui")

local function new_struct(table, struct)
  assert(struct.id, serpent.block(struct))
  assert(table[struct.id] == nil)
  table[struct.id] = struct
  return struct
end

function reset_offering_1(struct)
  if struct.inserter_1_offering.valid then return end
  -- game.print(string.format("resetting offering 1 for #%d @ %d", struct.id, game.tick))
  struct.inserter_1.held_stack.clear()
  struct.inserter_1_offering = storage.surface.create_entity{
    name = "item-on-ground",
    force = "neutral",
    position = {0.5 + struct.index, -6.5},
    stack = {name = "wood"},
  }
  storage.deathrattles[script.register_on_object_destroyed(struct.inserter_1_offering)] = {"offering-1", struct.id}
end

function reset_offering_2(struct)
  if struct.inserter_2_offering.valid then return end
  -- game.print(string.format("resetting offering 2 for #%d @ %d", struct.id, game.tick))
  struct.inserter_2.held_stack.clear()
  struct.inserter_2_offering = storage.surface.create_entity{
    name = "item-on-ground",
    force = "neutral",
    position = {0.5 + struct.index, -8.5},
    stack = {name = "wood"},
  }
  storage.deathrattles[script.register_on_object_destroyed(struct.inserter_2_offering)] = {"offering-2", struct.id}
end

local function spill_entity_inventory(entity, defines_inventory)
  local inventory = entity.get_inventory(defines_inventory)

  for slot = 1, #inventory do
    local stack = inventory[slot]
    if stack.valid_for_read then
      entity.surface.spill_item_stack{
        position = entity.position,
        stack = stack,
        force = entity.force,
        allow_belts = false,
      }
    end
  end

  inventory.clear()
end

local technology_changes_quality = {}
for _, technology in pairs(prototypes.technology) do
  local sum = 0
  for _, effect in pairs(technology.effects) do
    if effect.type == "nothing" then
      local effect_description = effect.effect_description[1]
      if effect_description and type(effect_description) == "string" and effect_description == "effect-description.quality-condenser-forked-quality" then
        sum = sum + tonumber(effect.effect_description[3])
      end
    end
  end
  if sum ~= 0 then
    technology_changes_quality[technology.name] = sum
  end
end
log("technology_changes_quality = " .. serpent.block(technology_changes_quality))
log(string.format("[%s] beacon boost mode: %s, power multiplier: %s",
  mod_name,
  settings.startup[mod_prefix .. "beacon-boost"].value,
  settings.startup[mod_prefix .. "beacon-power-multiplier"].value))

local function get_bonus_quality(force)
  if table_size(technology_changes_quality) == 0 then return 0 end

  local sum = 0

  for technology_name, technology in pairs(force.technologies) do
    if technology_changes_quality[technology_name] and technology.researched then
      sum = sum + technology_changes_quality[technology_name]
    end
  end

  return sum * 10 -- technology_changes_quality is in 0-100 decimal format, we need it in 0-1000 format
end

local Handler = {}

function Handler.refresh_gui_for_player(player)
  for _, relative_gui in ipairs(player.gui.relative.children) do
    if relative_gui.name == mod_prefix .. "tabbed-pane-modules" or relative_gui.name == mod_prefix .. "tabbed-pane-inventory" then
      relative_gui.destroy()
    end
  end

  do
    local tabbed_pane = player.gui.relative.add{
      name = mod_prefix .. "tabbed-pane-modules",
      type = "tabbed-pane",
      style = "quality_condenser_tabbed_pane",
      anchor = {
        gui = defines.relative_gui_type.assembling_machine_gui,
        position = defines.relative_gui_position.top,
        name = "quality-condenser-forked",
      }
    }
    tabbed_pane.style.horizontally_stretchable = true

    local tab1 = tabbed_pane.add{type="tab", caption="Modules"}
    local tab2 = tabbed_pane.add{type="tab", caption="Inventory"}
    local tab3 = tabbed_pane.add{type="tab", caption={"sqc.targets"}}
    local label1 = tabbed_pane.add{type="empty-widget"}
    local label2 = tabbed_pane.add{type="empty-widget"}
    tabbed_pane.add_tab(tab1, label1)
    tabbed_pane.add_tab(tab2, label2)
    tabbed_pane.add_tab(tab3, tabbed_pane.add{type="empty-widget"})
    tabbed_pane.selected_tab_index = 1
  end

  do
    local tabbed_pane = player.gui.relative.add{
      name = mod_prefix .. "tabbed-pane-inventory",
      type = "tabbed-pane",
      style = "quality_condenser_tabbed_pane",
      anchor = {
        gui = defines.relative_gui_type.container_gui,
        position = defines.relative_gui_position.top,
        name = "quality-condenser-forked--container",
      }
    }
    tabbed_pane.style.horizontally_stretchable = true

    local tab1 = tabbed_pane.add{type="tab", caption="Modules"}
    local tab2 = tabbed_pane.add{type="tab", caption="Inventory"}
    local tab3 = tabbed_pane.add{type="tab", caption={"sqc.targets"}}
    local label1 = tabbed_pane.add{type="empty-widget"}
    local label2 = tabbed_pane.add{type="empty-widget"}
    tabbed_pane.add_tab(tab1, label1)
    tabbed_pane.add_tab(tab2, label2)
    tabbed_pane.add_tab(tab3, tabbed_pane.add{type="empty-widget"})
    tabbed_pane.selected_tab_index = 2
  end
end

function Handler.refresh_gui_for_players()
  for _, player in pairs(game.players) do
    Handler.refresh_gui_for_player(player)
  end
end

script.on_event(defines.events.on_player_created, function(event)
  local player = game.get_player(event.player_index) --[[@as LuaEntity]]
  Handler.refresh_gui_for_player(player)
end)

-- Prototype names stay compatible with the previous fork; script-owned helpers are rebuilt.
local function initialize_base()
  storage.version = 3
  storage.surface = game.planets[mod_name].create_surface()
  storage.surface.generate_with_lab_tiles = true
  for _, entity in pairs(storage.surface.find_entities_filtered{force="neutral"}) do
    if entity.name == "proxy-container" or entity.name == "arithmetic-combinator" or entity.name == "inserter" or entity.name == "item-on-ground" or entity.name == "electric-energy-interface" then
      entity.destroy()
    end
  end
  storage.surface.create_global_electric_network()
  storage.surface.create_entity{name="electric-energy-interface",force="neutral",position={-1,-1}}
  storage.invalid = game.create_inventory(0)
  storage.invalid.destroy()
  storage.index, storage.structs, storage.deathrattles = 0, {}, {}
  local machines = {}
  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered{name=mod_name}) do machines[#machines+1]=entity end
  end
  table.sort(machines,function(a,b) return a.unit_number<b.unit_number end)
  for _, entity in ipairs(machines) do
    local box=entity.surface.find_entities_filtered{name=mod_prefix.."container",position=entity.position,limit=1}[1]
    Handler.on_created_entity{entity=entity,existing_container=box}
  end
  Handler.refresh_gui_for_players()
end
script.on_init(function()
  storage.entries = {}
  initialize_base()
  Smart.on_init()
end)

local function update_quality(struct, bonus_quality)
  -- The quality the condenser is configured for: the base quality setting plus technology bonuses.
  -- It used to be handed to the machine by a hidden beacon-interface tile placed on it, but mods
  -- that limit how many beacons may reach a machine (Beacon Rebalance 2's overload rule) counted
  -- that hidden beacon and disabled the machine as soon as one real beacon was built next to it,
  -- so it now goes through LuaEntity::local_effect (scripts/beacons.lua).
  Beacons.set_quality(struct, (get_base_quality(struct.entity.quality) + (bonus_quality or get_bonus_quality(struct.entity.force))) / 1000)
end

script.on_configuration_changed(function(data)
  storage.entries = storage.entries or {}
  if not storage.structs then initialize_base() end
  if 3 > (storage.version or 0) then
    error("not compatible with quality-condenser-forked <= 2.1.0, remove the mod, save your world, then update the mod.")
  end

  for _, struct in pairs(storage.structs) do
    if struct.beacon_interface and struct.beacon_interface.valid then
      -- older versions put a hidden beacon on the machine, remove those leftovers
      struct.beacon_interface.destroy()
    end
    struct.beacon_interface = nil
    update_quality(struct)
  end

  Handler.refresh_gui_for_players()
  Smart.on_configuration_changed()
  TargetsGui.reset()
end)

function Handler.on_created_entity(event)
  local entity = event.entity or event.destination

  -- mods do not get to clone/place the container.
  if entity.name == mod_prefix .. "container" then
    spill_entity_inventory(entity, defines.inventory.chest)
    entity.destroy()
    return
  -- this mod does not use the beacon-interface anymore, only leftovers of old saves exist
  elseif entity.name == mod_prefix .. "beacon-interface" then
    entity.destroy()
    return
  end

  local struct = new_struct(storage.structs, {
    id = entity.unit_number,
    index = storage.index,
    entity = entity,

    beacon_interface = nil,
    quality = nil,
    beacon_speed = nil,
    beacon_consumption = nil,
    beacon_blocked = nil,
    container = nil,
    container_inventory = nil,
    proxy_container_a = nil,
    proxy_container_b = nil,
    arithmetic_1 = nil,
    arithmetic_2 = nil,
    inserter_1 = nil,
    inserter_1_offering = storage.invalid,
    inserter_2 = nil,
    inserter_2_offering = storage.invalid,
  })
  storage.index = storage.index + 1

  update_quality(struct)

  local other_quality_container = entity.surface.find_entities_filtered{
    name = mod_prefix .. "container",
    force = entity.force,
    position = entity.position,
    limit = 1,
  }[1]

  struct.container = event.existing_container or entity.surface.create_entity{
    name = mod_prefix .. "container",
    force = entity.force,
    position = entity.position,
    quality = entity.quality,
  }
  struct.container.destructible = false
  struct.container_inventory = struct.container.get_inventory(defines.inventory.chest)

  if other_quality_container and other_quality_container ~= struct.container then
    local other_quality_container_inventory = other_quality_container.get_inventory(defines.inventory.chest)
    for slot = 1, #other_quality_container_inventory do
      local stack = other_quality_container_inventory[slot]
      if stack.valid_for_read then
        stack.count = stack.count - struct.container_inventory.insert(stack)
      end
    end
  end

  storage.deathrattles[script.register_on_object_destroyed(entity)] = {"crafter", struct.id}
  storage.deathrattles[script.register_on_object_destroyed(struct.container)] = {"container", struct.id}

  Combinators.create_for_struct(struct)
  reset_offering_2(struct)
  Smart.on_created_entity(event)
end

for _, event in ipairs({
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity,
  defines.events.on_space_platform_built_entity,
  defines.events.script_raised_built,
  defines.events.script_raised_revive,
  defines.events.on_entity_cloned,
}) do
  script.on_event(event, Handler.on_created_entity, {
    {filter = "name", name = mod_name},
    {filter = "name", name = mod_prefix .. "container"},
    {filter = "name", name = mod_prefix .. "beacon-interface"},
  })
end

local Condense = require("scripts.condense")

local deathrattles = {
  ["offering-1"] = function (deathrattle)
    local struct = storage.structs[deathrattle[2]]
    if struct and struct.entity.valid then
      if Beacons.is_blocked(struct) then return end
      struct.entity.custom_status = nil
      struct.entity.disabled_by_script = false
    end
  end,
  ["offering-2"] = function (deathrattle)
    local struct = storage.structs[deathrattle[2]]
    if struct and struct.entity.valid then
      Condense.trigger(struct)
      reset_offering_2(struct)
    end
  end,
  ["crafter"] = function (deathrattle)
    local struct = storage.structs[deathrattle[2]]
    if struct then
      storage.structs[struct.id] = nil
      -- struct.entity.destroy()
      if struct.beacon_interface and struct.beacon_interface.valid then
        struct.beacon_interface.destroy()
      end
      if struct.container_inventory.valid then
        spill_entity_inventory(struct.container, defines.inventory.chest)
      end
      struct.container.destroy()
      struct.proxy_container_a.destroy()
      struct.proxy_container_b.destroy()
      struct.arithmetic_1.destroy()
      struct.arithmetic_2.destroy()
      struct.inserter_1.destroy()
      struct.inserter_1_offering.destroy()
      struct.inserter_2.destroy()
      struct.inserter_2_offering.destroy()
    end
  end,
  ["container"] = function (deathrattle)
    local struct = storage.structs[deathrattle[2]]
    if struct then
      storage.structs[struct.id] = nil
      if struct.entity.valid then
        spill_entity_inventory(struct.entity, defines.inventory.crafter_modules)
      end
      struct.entity.destroy()
      if struct.beacon_interface and struct.beacon_interface.valid then
        struct.beacon_interface.destroy()
      end
      -- struct.container.destroy()
      struct.proxy_container_a.destroy()
      struct.proxy_container_b.destroy()
      struct.arithmetic_1.destroy()
      struct.arithmetic_2.destroy()
      struct.inserter_1.destroy()
      struct.inserter_1_offering.destroy()
      struct.inserter_2.destroy()
      struct.inserter_2_offering.destroy()
    end
  end,
}

script.on_event(defines.events.on_object_destroyed, function(event)
  local deathrattle = storage.deathrattles[event.registration_number]
  if deathrattle then storage.deathrattles[event.registration_number] = nil
    deathrattles[deathrattle[1]](deathrattle)
  end
end)

local function on_research_toggled(event)
  if technology_changes_quality[event.research.name] then
    local force = event.research.force
    local bonus_quality = get_bonus_quality(force)
    for _, struct in pairs(storage.structs) do
      if struct.entity.force == force then
        update_quality(struct, bonus_quality)
      end
    end
  end
end

script.on_event(defines.events.on_research_finished, on_research_toggled)
script.on_event(defines.events.on_research_reversed, on_research_toggled)

script.on_event(defines.events.on_gui_selected_tab_changed, function(event)
  if event.element.name == mod_prefix .. "tabbed-pane-modules" or event.element.name == mod_prefix .. "tabbed-pane-inventory" then
    if event.element.selected_tab_index == 3 then
      local player=game.get_player(event.player_index)
      local entry=Smart.get(player.opened)
      if entry then TargetsGui.open(player,entry) end
      event.element.selected_tab_index = event.element.name == mod_prefix .. "tabbed-pane-modules" and 1 or 2
      return
    end
  end
  TargetsGui.on_gui_selected_tab_changed(event)
  if event.element.name == mod_prefix .. "tabbed-pane-modules" then
    if event.element.selected_tab_index == 1 then return end
    event.element.selected_tab_index = 1
    local player = game.get_player(event.player_index) --[[@as LuaPlayer]]
    local entity = player.opened --[[@as LuaEntity]]
    if player.opened_gui_type == defines.gui_type.entity and entity.name == mod_name then
      player.opened = entity.surface.find_entities_filtered{
        name = mod_prefix .. "container",
        force = entity.force,
        position = entity.position,
        limit = 1,
      }[1]
    end
  elseif event.element.name == mod_prefix .. "tabbed-pane-inventory" then
    if event.element.selected_tab_index == 2 then return end
    event.element.selected_tab_index = 2
    local player = game.get_player(event.player_index) --[[@as LuaPlayer]]
    local entity = player.opened --[[@as LuaEntity]]
    if player.opened_gui_type == defines.gui_type.entity and entity.name == mod_prefix .. "container" then
      player.opened = entity.surface.find_entities_filtered{
        name = mod_name,
        force = entity.force,
        position = entity.position,
        limit = 1,
      }[1]
    end
  end
end)

script.on_nth_tick(15, Smart.on_tick)

script.on_event(defines.events.on_gui_opened, TargetsGui.on_gui_opened)
script.on_event(defines.events.on_gui_closed, TargetsGui.on_gui_closed)
script.on_event(defines.events.on_gui_click, TargetsGui.on_gui_click)
script.on_event(defines.events.on_gui_elem_changed, TargetsGui.on_gui_elem_changed)
script.on_event(defines.events.on_gui_text_changed, TargetsGui.on_gui_text_changed)
script.on_event(defines.events.on_gui_checked_state_changed, TargetsGui.on_gui_checked_state_changed)
script.on_event(defines.events.on_player_setup_blueprint, TargetsGui.on_blueprint)
script.on_event(defines.events.on_entity_settings_pasted, TargetsGui.on_settings_pasted)
script.on_nth_tick(60, function(event)
  if event.tick ~= 0 then
    for _, struct in pairs(storage.structs) do Beacons.update(struct) end
  end
  TargetsGui.on_tick()
end)
