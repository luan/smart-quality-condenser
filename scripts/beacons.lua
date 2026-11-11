-- What foreign (player built) beacons are allowed to do to a condenser is configurable:
--
--   allow   - the beacon may speed the machine up, the extra speed is paid for in electricity
--   ignore  - beacons cannot reach the machine at all (handled in the data stage, no script work)
--   disable - the machine is paused (disabled by script) while a beacon boosts it
--
-- This module also owns the two entries this mod puts into LuaEntity::local_effect:
--
--   * quality     - the quality the condenser is configured for (base quality + technology bonuses)
--   * consumption - the extra power that pays for the speed a foreign beacon provides
--
-- The condenser deliberately does NOT place a beacon on itself anymore: Beacon Rebalance 2 (and
-- similar mods) disable a machine that is reached by more than one beacon, and that hidden beacon
-- made one single player beacon count as two.
--
-- LuaEntity::effects is the sum of the machine's own modules, every beacon in range and our own
-- local_effect, so the foreign part is whatever is left after subtracting the other two.

local Beacons = {}

local config = nil

local function get_config()
  if config == nil then
    config = {
      mode = settings.startup[mod_prefix .. "beacon-boost"].value,
      power_multiplier = settings.startup[mod_prefix .. "beacon-power-multiplier"].value,
    }
  end
  return config
end

-- Effects of the modules the player placed inside the machine itself, at their own quality.
function Beacons.get_local_module_effects(entity)
  local sum = {speed = 0, consumption = 0}

  local module_inventory = entity.get_module_inventory()
  if module_inventory then
    for slot = 1, #module_inventory do
      local stack = module_inventory[slot]
      if stack.valid_for_read then
        local module = prototypes.item[stack.name]
        if module and module.module_effects then
          local module_effects = module.get_module_effects(stack.quality)
          for effect in pairs(sum) do
            sum[effect] = sum[effect] + (module_effects[effect] or 0) * stack.count
          end
        end
      end
    end
  end

  return sum
end

function Beacons.is_blocked(struct)
  return struct.beacon_blocked == true
end

-- Set the quality the condenser is configured for, as a fraction (0.1 = 10%).
function Beacons.set_quality(struct, quality)
  struct.quality = math.max(0, math.min(1, quality)) -- beyond 100% there is no bonus
  Beacons.update(struct)
end

-- Only compares the entries this mod owns, so another mod using local_effect is left alone.
local function changes_owned_entries(wanted, applied)
  return 0.0001 >= math.abs((wanted.quality or 0) - (applied.quality or 0))
    and 0.0001 >= math.abs((wanted.consumption or 0) - (applied.consumption or 0))
end

local function clamp(value)
  return math.max(-1000, math.min(1000, value))
end

function Beacons.update(struct)
  local entity = struct.entity
  if not (entity and entity.valid) then return end

  local wanted = {}
  if 0 < (struct.quality or 0) then
    wanted.quality = clamp(struct.quality)
  end

  local mode = get_config().mode

  if mode ~= "ignore" then -- in "ignore" mode the prototype keeps beacons from reaching the machine
    local engine = entity.effects or {}
    local local_effect = entity.local_effect or {}
    local own = Beacons.get_local_module_effects(entity)

    local foreign_speed = (engine.speed or 0) - own.speed - (local_effect.speed or 0)
    local foreign_consumption = (engine.consumption or 0) - own.consumption - (local_effect.consumption or 0)

    if mode == "disable" then
      if 0 < foreign_speed then
        struct.beacon_blocked = true
        entity.disabled_by_script = true
        entity.custom_status = {
          diode = defines.entity_status_diode.red,
          label = {"entity-status." .. mod_prefix .. "beacon-blocked"},
        }
      elseif struct.beacon_blocked then
        struct.beacon_blocked = nil
        entity.custom_status = nil
        entity.disabled_by_script = false
      end
    elseif 0 < foreign_speed and 0 < get_config().power_multiplier then
      -- the machine draws (1 + speed bonus) times its usual power, so a boost is not free
      wanted.consumption = clamp((1 + foreign_consumption) * foreign_speed * get_config().power_multiplier)
    end
  end

  local applied = entity.local_effect or {}
  if changes_owned_entries(wanted, applied) then return end

  -- keep the entries we do not own (another mod may be using local_effect as well)
  local write = {}
  for effect, value in pairs(applied) do
    if effect ~= "quality" and effect ~= "consumption" then
      write[effect] = value
    end
  end
  if wanted.quality then write.quality = wanted.quality end
  if wanted.consumption then write.consumption = wanted.consumption end

  entity.local_effect = next(write) and write or nil
end

return Beacons
