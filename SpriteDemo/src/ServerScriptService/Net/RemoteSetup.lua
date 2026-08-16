-- Creates every Remote(Event) the game uses, once, under
-- ReplicatedStorage.Shared.Remotes. Server-only (only the server creates
-- instances); clients just WaitForChild the folder/events by name.
--
-- Reliable vs Unreliable: position/snapshot streams are Unreliable because a
-- dropped frame is superseded by the next one moments later — resending a
-- stale position is wasted bandwidth. Damage/spawn/despawn/stat events are
-- Reliable because losing one is a correctness bug (e.g. an enemy that never
-- gets removed client-side).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteSetup = {}

local REMOTES = {
	-- name -> className
	ClientReady = "RemoteEvent", -- C->S: {} — fired once NetworkClient has connected OnClientEvent; the server never fires WorldSnapshot at a player before this arrives (see Main.server.lua), which is what keeps "discarded event" engine warnings from ever appearing in Output — anything printed there post-launch is a real bug, never this race.
	PlayerInput = "UnreliableRemoteEvent", -- C->S: {moveX, jumpPressed}
	WorldSnapshot = "UnreliableRemoteEvent", -- S->C: {players = {...}}
	RequestAttack = "RemoteEvent", -- C->S: {} (Phase 5)
	RequestWave = "RemoteEvent", -- C->S: {} (Phase 5)
	PlayerStatsChanged = "RemoteEvent", -- S->C(one): {hp,maxHp,level,xp,xpToNext} (Phase 5)
	CombatEvent = "RemoteEvent", -- S->C: {kind,...} (Phase 5)
	EntityEnter = "RemoteEvent", -- S->C: {kind,id,spawnState} (Phase 6)
	EntityLeave = "RemoteEvent", -- S->C: {kind,id} (Phase 6)
}

function RemoteSetup.init()
	local folder = ReplicatedStorage.Shared:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage.Shared
	end

	local remotes = {}
	for name, className in pairs(REMOTES) do
		local existing = folder:FindFirstChild(name)
		if not existing then
			existing = Instance.new(className)
			existing.Name = name
			existing.Parent = folder
		end
		remotes[name] = existing
	end

	return remotes
end

return RemoteSetup
