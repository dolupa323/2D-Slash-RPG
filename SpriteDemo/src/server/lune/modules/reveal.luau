-- 보스의 출현(2026-11-05 — shared/lune/sim/reveal.luau · 공방 design/weekboss.js의 reveal). 사용자: "내가 퍼블리시를 하면 보스가 바로 열리는게 아니라 … 1시간정도로 해줘".
--  ① 출현 시각: 이 판으로 처음 켜진 서버가 세계 기록 reveal_<보스>에 「지금 + wait초」를 적는다(store.luau revealClaim — UpdateAsync: 이미 있으면 그것을 쓴다) → 모든 서버가 같은 시각.
--     못 적으면(저장소 탈) RETRY초마다 다시 — 그동안은 닫혀 있다(모르는 시각으로 열지 않는다). Studio = 저장소에 적지 않고 그 서버가 켜진 때부터 센다(시험).
--  ② 1초마다(world.luau의 World.revealTick): 남은 초가 marks의 때를 지나면 이 서버의 모두에게 알림(「용암 거인 출현까지 30:00」 + 말 한 줄) · 0이 되면 「용암 거인 출현!」.
--     모든 서버가 같은 시각 · 같은 차례의 말을 쓰니 MessagingService 없이도 모든 서버에 같은 때 같은 알림이 뜬다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Reveal = require(ReplicatedStorage.shared.lune.sim.reveal)
local CITY = require(ReplicatedStorage.shared.lune.data["city.generated"])
local Store = require(script.Parent.store)

local RS = {}
RS.RETRY = 30 -- 출현 시각을 적지 못했을 때 다시 해 보기까지(초)

local busy, failAt = {}, {}
local prevLeft = {} -- [보스] = 지난번의 남은 초(알림의 때를 지났는지 본다)
local test = false

local function bosses(): { any }
	local out = {}
	for _, b in CITY.weekly.bosses do
		if b.reveal then
			table.insert(out, b)
		end
	end
	return out
end
RS.bosses = bosses

local function claim(b, now: number)
	if busy[b.id] or now - (failAt[b.id] or -math.huge) < RS.RETRY then
		return
	end
	busy[b.id] = true
	task.spawn(function()
		local ok, at = pcall(Store.revealClaim, b.id, now + b.reveal.wait)
		busy[b.id] = nil
		if ok and typeof(at) == "number" then
			Reveal.at[b.id] = at
		else
			failAt[b.id] = now
		end
	end)
end

-- 서버가 켜질 때 한 번. studio = 시험(저장소에 적지 않는다)
function RS.start(studio: boolean, now: number)
	test = studio == true
	for _, b in bosses() do
		if test then
			Reveal.at[b.id] = Reveal.at[b.id] or (now + b.reveal.wait)
		else
			claim(b, now)
		end
	end
end

-- 1초마다: 알릴 것들 { { kind = "tease" | "open", boss, name, left, line, lv } … }(이 서버의 모두에게 — world.luau가 보낸다)
function RS.tick(now: number): { any }
	local out = {}
	for _, b in bosses() do
		local at = Reveal.at[b.id]
		if at == nil then
			if not test then
				claim(b, now) -- 아직 모른다: 다시 적어 본다(이미 있으면 그 시각이 온다)
			end
		else
			local left = math.max(0, at - now)
			local prev = prevLeft[b.id]
			if prev ~= nil and prev > 0 then
				if left <= 0 then
					table.insert(out, { kind = "open", boss = b.id, name = b.name, lv = (b.normal and b.normal.need) or 1 })
				else
					local i = Reveal.markCrossed(b.reveal, prev, left)
					if i then
						table.insert(out, { kind = "tease", boss = b.id, name = b.name, left = left, line = Reveal.line(b.reveal, b.id, i) })
					end
				end
			elseif prev == nil and left > 0 and left >= b.reveal.wait - 2 then
				-- 막 정해졌다(이 판의 첫 서버 · 첫 초): 첫 알림(한 시간 전)을 바로
				table.insert(out, { kind = "tease", boss = b.id, name = b.name, left = left, line = Reveal.line(b.reveal, b.id, 1) })
			end
			prevLeft[b.id] = left
		end
	end
	return out
end

-- 화면에 보내는 것: { at = { [보스] = 출현 시각 }, now = 서버의 지금 }(화면이 남은 시간을 그린다 — 시계가 어긋나도 서버의 지금으로 맞춘다)
function RS.view(now: number)
	local at = {}
	for _, b in bosses() do
		if Reveal.at[b.id] then
			at[b.id] = Reveal.at[b.id]
		end
	end
	return { at = at, now = now }
end

-- (자동 검사: 비운다)
function RS.reset()
	busy, failAt, prevLeft, test = {}, {}, {}, false
	Reveal.at = {}
end

return RS
