-- 채널(2026-11-12 사용자: "현재 vip 서버를 매크로로 인해서 닫았는데 그래서 사냥터에 사람이 너무 겹치는 현상이 발생한다 그래서 메이플스토리처럼 한 서버에 채널을 두어서
--  채널변경으로 사냥터를 별개로 쓸수있는개념을 도입할수있나?") — 공방 design/world.js의 CHANNELS(scenes.generated의 channels).
--  한 서버 안에서 사냥 맵만 채널마다 따로 된 방: 방 이름 = <맵>#c<채널>(채널 1은 맵 이름 그대로 — 예전 저장 · 예전 방과 같다).
--  장면의 자료는 SCENES.scenes[방 이름](#c<n>을 떼고 찾는다) · 설계의 이름과 견줄 때는 SCENES.base(방 이름). 셈만 한다 — 옮기는 것은 서버 world.luau(roomKeyFor · onChannel)
local SCENES = require(script.Parent.Parent.data["scenes.generated"])

local Channel = {}
Channel.DATA = SCENES.channels or { count = 1, gap = 10, words = {} }
Channel.COUNT = Channel.DATA.count

-- 방 이름 → 맵 · 채널(채널의 방이 아니면 그 이름 · 1)
function Channel.split(key: string?): (string?, number)
	if typeof(key) ~= "string" then
		return key, 1
	end
	local base, n = string.match(key, "^(.-)#c(%d+)$")
	if base then
		return base, tonumber(n) or 1
	end
	return key, 1
end

-- 채널마다 따로 되는 맵인가: 사냥 맵(몬스터가 서는 곳)만 — 마을(돌아가는 곳) · 쉼터 · 실내 · 따로 들어가는 방(파티마다 · 혼자) · 던전 · 토벌 · 보스 방 · 보상의 방 · 꿈 · 배 · 검정 방은 아니다
function Channel.splits(key: string): boolean
	local sc = rawget(SCENES.scenes, key)
	if not sc or SCENES.homes[key] or sc.inst or sc.rest or sc.rift or sc.dungeon or sc.vault or sc.jail or sc.dojo or sc.ship or sc.tut or sc.story then
		return false
	end
	if sc.bosses and #sc.bosses > 0 then
		return false
	end
	-- 보스의 문 · 던전의 문이 있는 맵은 나누지 않는다(2026-11-12 사용자 "보스갈때는 신경쓸필요없지?" — 문 앞에서 모두 만나 파티를 모으고 초대한다)
	for _, p in sc.portals or {} do
		if p.weekly or p.dungeon then
			return false
		end
	end
	return sc.mobs ~= nil and #sc.mobs > 0
end

-- 그 맵의 그 채널의 방 이름(채널로 나뉘지 않는 맵 · 채널 1이면 맵 이름 그대로)
function Channel.key(base: string, ch: number?): string
	if not ch or ch <= 1 or not Channel.splits(base) then
		return base
	end
	return base .. "#c" .. tostring(math.floor(ch))
end

-- 바른 채널 번호인가
function Channel.valid(n: any): boolean
	return typeof(n) == "number" and n == math.floor(n) and n >= 1 and n <= Channel.COUNT
end

-- 들어올 때의 채널: 채널 1에 fill명이 찰 때까지는 1(사람이 적은 서버에서 친구끼리 갈라지지 않게) · 그 뒤로는 사람이 가장 적은 채널
function Channel.pick(counts: { [number]: number }): number
	if (counts[1] or 0) < (Channel.DATA.fill or 0) then
		return 1
	end
	return Channel.least(counts)
end

-- 사람이 가장 적은 채널(같으면 앞 번호): counts[n] = 그 채널의 사람 수
function Channel.least(counts: { [number]: number }): number
	local best, bestN = 1, math.huge
	for n = 1, Channel.COUNT do
		local c = counts[n] or 0
		if c < bestN then
			best, bestN = n, c
		end
	end
	return best
end

return Channel
