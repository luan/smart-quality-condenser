mod_name = "quality-condenser-forked"
mod_prefix = mod_name .. "--"
mod_directory = "__" .. mod_name .. "__"

function get_base_quality(quality)
  local setting = settings.startup[mod_prefix .. "base-quality"]
  local formula = (setting and setting.value) or "0"
  local number = load("return " .. formula, "get_base_quality", "t", {quality = quality, math = math})()
  return math.floor(number * 10)
end
