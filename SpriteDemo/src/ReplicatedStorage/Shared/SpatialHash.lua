-- Uniform-grid spatial partitioning. Pure Luau table, no Roblox instance
-- dependency, so the exact same module runs identically on server (for
-- authoritative separation/hit-tests/interest queries) and client (for local
-- culling), with no behavioral drift between the two.
--
-- cellSize should be roughly the largest interaction radius you'll query
-- with, so a query only ever needs to look at a small, bounded number of
-- neighboring cells regardless of how many entities exist elsewhere in the
-- world (this is what makes queries ~O(1) amortized per entity, O(n) total,
-- instead of the O(n^2) all-pairs check a naive "loop every entity" does).

local SpatialHash = {}
SpatialHash.__index = SpatialHash

function SpatialHash.new(cellSize)
	return setmetatable({
		cellSize = cellSize,
		cells = {}, -- "cx,cy" -> { [id] = true }
		positions = {}, -- id -> Vector2 (last known position, for update/remove)
	}, SpatialHash)
end

local function cellKey(cx, cy)
	return cx .. "," .. cy
end

function SpatialHash:_cellOf(position)
	return math.floor(position.X / self.cellSize), math.floor(position.Y / self.cellSize)
end

function SpatialHash:insert(id, position)
	local cx, cy = self:_cellOf(position)
	local key = cellKey(cx, cy)
	local bucket = self.cells[key]
	if not bucket then
		bucket = {}
		self.cells[key] = bucket
	end
	bucket[id] = true
	self.positions[id] = position
end

function SpatialHash:remove(id)
	local oldPos = self.positions[id]
	if not oldPos then
		return
	end
	local cx, cy = self:_cellOf(oldPos)
	local bucket = self.cells[cellKey(cx, cy)]
	if bucket then
		bucket[id] = nil
	end
	self.positions[id] = nil
end

function SpatialHash:update(id, newPosition)
	local oldPos = self.positions[id]
	if not oldPos then
		self:insert(id, newPosition)
		return
	end
	local oldCx, oldCy = self:_cellOf(oldPos)
	local newCx, newCy = self:_cellOf(newPosition)
	if oldCx ~= newCx or oldCy ~= newCy then
		self.cells[cellKey(oldCx, oldCy)][id] = nil
		local key = cellKey(newCx, newCy)
		local bucket = self.cells[key]
		if not bucket then
			bucket = {}
			self.cells[key] = bucket
		end
		bucket[id] = true
	end
	self.positions[id] = newPosition
end

-- Returns a list of ids within `radius` of `position` (circular, exact
-- distance check — the grid only bounds which cells are scanned).
function SpatialHash:queryRadius(position, radius)
	local results = {}
	local minCx, minCy = self:_cellOf(position - Vector2.new(radius, radius))
	local maxCx, maxCy = self:_cellOf(position + Vector2.new(radius, radius))
	local radiusSq = radius * radius

	for cx = minCx, maxCx do
		for cy = minCy, maxCy do
			local bucket = self.cells[cellKey(cx, cy)]
			if bucket then
				for id in pairs(bucket) do
					local pos = self.positions[id]
					if pos and (pos - position).Magnitude ^ 2 <= radiusSq then
						results[#results + 1] = id
					end
				end
			end
		end
	end

	return results
end

function SpatialHash:getPosition(id)
	return self.positions[id]
end

return SpatialHash
