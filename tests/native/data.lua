-- Transport tests use a guaranteed upgrade, matching the live machine's >100% effect.
local module = table.deepcopy(data.raw.module["quality-module-3"])
module.name = "smart-condenser-qa-module"
module.effect = { quality = 100 }
data:extend({ module })
