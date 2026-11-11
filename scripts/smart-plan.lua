local M = {}
function M.key(name, quality)
	return name .. "\0" .. quality
end
local function copy(source)
	local result = {}
	for k, v in pairs(source) do
		result[k] = math.max(0, v)
	end
	return result
end
-- Inventories and robot reservations are the only in-progress state.
function M.make(targets, qualities, stock, inside, input, incoming)
	local held, buffered, flying, available = copy(inside), copy(input), copy(incoming), copy(stock)
	local output, feed, requests, keep = {}, {}, {}, {}
	local waiting = 0
	local function add(map, k, count)
		map[k] = (map[k] or 0) + count
	end
	local function take(map, k, count)
		local n = math.min(map[k] or 0, count)
		map[k] = (map[k] or 0) - n
		return n
	end
	local names = {}
	for name in pairs(targets) do
		names[#names + 1] = name
	end
	table.sort(names)
	for _, name in ipairs(names) do
		for tier = 2, #qualities do
			local q = qualities[tier]
			local k = M.key(name, q)
			local missing = math.max(0, (targets[name][q] or 0) - (stock[k] or 0))
			local n = take(held, k, missing)
			add(output, k, n)
			missing = missing - n
			n = take(buffered, k, missing)
			add(output, k, n)
			missing = missing - n
			for lower = tier - 1, 1, -1 do
				local lk = M.key(name, qualities[lower])
				n = take(held, lk, missing)
				add(keep, lk, n)
				missing = missing - n
				n = take(buffered, lk, missing)
				add(feed, lk, n)
				missing = missing - n
				n = take(flying, lk, missing)
				add(requests, lk, n)
				missing = missing - n
			end
			for lower = tier - 1, 1, -1 do
				local lk = M.key(name, qualities[lower])
				n = take(available, lk, missing)
				add(requests, lk, n)
				missing = missing - n
			end
			if missing > 0 then
				add(requests, M.key(name, qualities[1]), missing)
				waiting = waiting + 1
			end
		end
	end
	-- Return surplus and removed targets at their current quality, without upgrading them.
	for k, n in pairs(held) do
		add(output, k, n)
	end
	for k, n in pairs(buffered) do
		add(output, k, n)
	end
	return { output = output, feed = feed, requests = requests, keep = keep, waiting = waiting }
end
return M
