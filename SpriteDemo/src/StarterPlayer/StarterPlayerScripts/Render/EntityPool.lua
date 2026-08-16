-- Generic GUI-instance pool: reuses {sprite, animator, healthFill} bundles
-- across enter/leave cycles instead of Instance.new()/Destroy() churn every
-- time an enemy spawns/dies or an entity enters/leaves interest range.
--
-- `createFn` builds one fresh bundle (called only when the pool is empty and
-- a new one is actually needed); a released bundle is hidden and its
-- animator reset to idle (cheap) rather than destroyed, then handed back out
-- on the next acquire() instead of allocating again.

local EntityPool = {}
EntityPool.__index = EntityPool

function EntityPool.new(createFn)
	return setmetatable({
		createFn = createFn,
		free = {}, -- array of unused bundles
		active = {}, -- id -> bundle
	}, EntityPool)
end

function EntityPool:acquire(id)
	local existing = self.active[id]
	if existing then
		return existing
	end

	local bundle = table.remove(self.free)
	if bundle then
		bundle.sprite.Visible = true
	else
		bundle = self.createFn()
	end

	self.active[id] = bundle
	return bundle
end

function EntityPool:release(id)
	local bundle = self.active[id]
	if not bundle then
		return
	end
	self.active[id] = nil
	bundle.sprite.Visible = false
	bundle.animator:setLoopState("idle")
	table.insert(self.free, bundle)
end

-- Releases every active id NOT present in `seenIds` ({id = true, ...}).
function EntityPool:releaseUnseen(seenIds)
	for id in pairs(self.active) do
		if not seenIds[id] then
			self:release(id)
		end
	end
end

function EntityPool:count()
	local activeCount, freeCount = 0, #self.free
	for _ in pairs(self.active) do
		activeCount += 1
	end
	return activeCount, freeCount
end

return EntityPool
