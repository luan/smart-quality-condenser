package.path = "scripts/?.lua;" .. package.path
local p = require("smart-plan")
local q = { "normal", "uncommon", "rare", "epic", "legendary" }
local function k(name, quality)
	return p.key(name, quality)
end
local targets, stock = {}, {}
for i = 1, 24 do
	local name = "item-" .. i
	targets[name] = { rare = 50 }
	stock[k(name, "normal")] = 100
end
local result = p.make(targets, q, stock, {}, {}, {})
for name in pairs(targets) do
	assert(result.requests[k(name, "normal")] == 50, "Every target must request")
end
-- Contents removed by a player immediately become missing again; there is no saved counter.
result = p.make(
	{ beacon = { rare = 50 } },
	q,
	{ [k("beacon", "normal")] = 100 },
	{ [k("beacon", "normal")] = 50 },
	{},
	{}
)
assert((result.requests[k("beacon", "normal")] or 0) == 0)
result = p.make({ beacon = { rare = 50 } }, q, { [k("beacon", "normal")] = 100 }, {}, {}, {})
assert(result.requests[k("beacon", "normal")] == 50)
-- Prefer the highest available lower quality, without requesting the same deficit twice.
result = p.make(
	{ beacon = { rare = 50 } },
	q,
	{ [k("beacon", "normal")] = 100, [k("beacon", "uncommon")] = 30 },
	{},
	{},
	{}
)
assert(result.requests[k("beacon", "uncommon")] == 30 and result.requests[k("beacon", "normal")] == 20)
-- The same item can have two target qualities; the lower target is extracted first.
result = p.make({ beacon = { uncommon = 10, rare = 20 } }, q, {}, { [k("beacon", "uncommon")] = 30 }, {}, {})
assert(result.output[k("beacon", "uncommon")] == 10 and result.keep[k("beacon", "uncommon")] == 20)
-- A delivered or flying batch covers demand until it moves inside.
result = p.make(
	{ beacon = { rare = 50 } },
	q,
	{ [k("beacon", "normal")] = 100 },
	{},
	{ [k("beacon", "normal")] = 20 },
	{ [k("beacon", "normal")] = 30 }
)
assert(result.feed[k("beacon", "normal")] == 20 and result.requests[k("beacon", "normal")] == 30)
-- Fulfilled or removed targets return leftovers at their current quality.
result = p.make(
	{ beacon = { rare = 50 } },
	q,
	{ [k("beacon", "rare")] = 50 },
	{ [k("beacon", "normal")] = 17 },
	{ [k("beacon", "uncommon")] = 3 },
	{}
)
assert(result.output[k("beacon", "normal")] == 17 and result.output[k("beacon", "uncommon")] == 3)
for _, n in pairs(result.requests) do
	assert(n == 0)
end
print("PASS: 24 targets, actual inventory recovery, quality allocation, robot reservations and surplus return")

result = p.make({ beacon = { rare = 50 } }, q, {}, {}, {}, {})
assert(result.requests[k("beacon", "normal")] == 50, "Missing stock must keep a visible request")
