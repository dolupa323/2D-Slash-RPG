-- 같은 맵에 있는 다른 사람들 — 서버가 알려 준 이름표(Who)와 자리(Heroes · 초당 10번)를 받아 그린다. 자리 사이는 이어서 그린다.
--  동작은 움직임에서 짐작한다: 옆으로 움직이면 달리기, 위아래로 움직이면 뛰기, 아니면 서 있기. 기술은 서버가 알려 준 것(Act)을 그 구간 동안 튼다.
--  발밑에 이름표(메이플처럼 이름만) — 파티원은 민트색이다. 이름표는 글씨의 층(화면 틀 — overlay.luau)에 그린다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local COMBAT = require(ReplicatedStorage.shared.lune.data["combat.generated"])
local CLASSES = require(ReplicatedStorage.shared.lune.data["classes.generated"])
local Kitset = require(ReplicatedStorage.shared.lune.kitset)
local CHARS = require(ReplicatedStorage.shared.lune.data["chars.generated"])
local Sprite = require(script.Parent.sprite)
local Grave = require(script.Parent.grave)
local Ui = require(script.Parent.ui.ui)
local Overlay = require(script.Parent.overlay)
local RideView = require(script.Parent.rideView) -- 펫 · 탈것(2026-10-20)

local WHITE = Ui.COLOR.text
local MINT = Ui.COLOR.accent
local LERP = 0.12 -- 자리 보고 사이를 이만큼에 걸쳐 잇는다(초)
local TAG_DOWN = 4 -- 이름표: 발밑에서 이만큼 아래(화면 틀의 점)

local Others = {}
Others.__index = Others
Others.TAG_DOWN = TAG_DOWN

-- 이름표: 판 안에는 이름만, 레벨은 판 바깥 왼쪽에 따로(「Lv.12」 — 나 · 다른 사람 모두 · Ui.tag의 lead).
--  2026-10-21 사용자: "닉네임 이름표 왼쪽에 레벨 나오게 하겠습니다. 다른사람에게 레벨 보이게 합니다" → 이어서 "이름테두리 바깥에 레벨표기입니다. 이 박스 안으로 들어오는게 아니라"
function Others.tagText(_level: number, name: string): string
	return name
end
function Others.levelText(level: number): string
	return ("Lv.%d"):format(level)
end

function Others.new(heroLayer: Frame, tagLayer: Frame, myId: any, ladders: any, scene: any)
	local self = setmetatable({}, Others)
	self.ladders = ladders or {} -- 이 장면의 사다리(사다리 위에 있으면 오르기 동작 — 2026-10-16 밤)
	self.scene = scene -- 이 장면의 칸(그 사람의 펫이 걷는 땅 — rideView)
	self.heroLayer, self.tagLayer, self.myId = heroLayer, tagLayer, myId
	self.list = {} -- [번호] = 한 사람
	self.fx = nil :: any -- 효과(effects.luau) — boot가 넣어 준다. 대쉬의 잔상 · 속도선을 여기에 그린다
	self.graveLayer = nil :: any -- 비석을 놓는 층 — boot가 넣어 준다(장면의 Graves 층)
	self.last = 0 -- 지난번 update의 때(잔상의 간격을 잰다)
	return self
end

local function drop(o)
	o.sprite:destroy()
	o.rv:destroy()
	o.tag:Destroy()
	if o.grave then
		o.grave:Destroy()
	end
end

-- 방 사람들의 이름표: 새로 온 사람은 만들고, 나간 사람은 지운다
function Others:setWho(roster)
	local seen = {}
	for _, w in roster do
		if w.id ~= self.myId then
			seen[w.id] = true
			local o = self.list[w.id]
			if o and o.class ~= w.class then
				drop(o)
				o = nil
			end
			if not o then
				o = {
					id = w.id,
					class = w.class,
					sprite = Sprite.new(self.heroLayer, w.class, 4),
					tag = Ui.tag(self.tagLayer, "", WHITE, 220, true, ""), -- 플레이어의 이름표: 민트 테두리를 두른 판 · 판 바깥 왼쪽에 레벨
					x = 0,
					y = 0,
					fromX = 0,
					fromY = 0,
					toX = 0,
					toY = 0,
					at = -1,
					dir = 1,
					alive = true,
					placed = false,
					moveT = -9,
					airT = -9,
					act = nil :: any,
					rv = RideView.new(self.heroLayer, 4, self.scene), -- 그 사람의 펫 · 탈것(영웅의 ZIndex 4 · 펫은 이 맵의 땅 위를 걷는다)
				}
				o.sprite.label.Visible = false
				o.tag.Frame.Visible = false
				self.list[w.id] = o
			end
			o.rv:setPet(w.pet)
			o.rv:setRide(w.ride)
			if o.name ~= w.name or o.level ~= w.level then
				o.name, o.level = w.name, w.level
				o.tag:SetText(Others.tagText(w.level, w.name))
				Ui.tagLead(o.tag, Others.levelText(w.level))
			end
		end
	end
	for id, o in self.list do
		if not seen[id] then
			drop(o)
			self.list[id] = nil
		end
	end
end

-- 자리: { { id, x, y, dir, 살아 있는가 } … }
function Others:apply(list, now: number)
	for _, row in list do
		local o = self.list[row[1]]
		if o then
			if not o.placed then
				o.x, o.y = row[2], row[3]
				o.placed = true
			end
			o.fromX, o.fromY = o.x, o.y
			o.toX, o.toY, o.dir, o.at = row[2], row[3], row[4], now
			if math.abs(o.toX - o.fromX) > 0.5 then
				o.moveT = now
			end
			if math.abs(o.toY - o.fromY) > 1.5 then
				o.airT = now
			end
			if row[5] and not o.alive then
				o.act = nil
			end
			if not row[5] and o.alive then
				o.deadAt = now
			end
			o.alive = row[5]
		end
	end
end

-- 2~4차의 쓰는 스킬(직업 묶음의 그 스킬)의 동작: 구간마다 서버가 알려 준다(next) — 되풀이 구간(누르고 있는 것 · 모으는 것 · 조건을 기다리는 것)은 끝 장을 넘으면 loopFrom으로 돌아간다
local KITDEF = {}
local function kitDef(skillId: string)
	local def = KITDEF[skillId]
	if def == nil then
		local skill, kit = Kitset.skill(skillId)
		def = false
		if skill and kit and skill.segs and COMBAT.cast[skillId] then
			local segs = {}
			for i, s in skill.segs do
				local clip = CHARS.chars[kit.who].clips[s.clip]
				local from, to = s.from or 0, s.to or (if clip then #clip.frames - 1 else 0)
				local fps = s.fps or 14
				local loops = s.loop or s.hold or s.charge or s.till
				local time = if s.loop then s.dur elseif s.hold then s.max or 3 elseif s.charge then (to - from + 1) / fps + 1 elseif s.till then s.max or 1.5 else (to - from + 1) / fps
				segs[i] = { clip = s.clip, from = from, to = to, fps = fps, time = time, next = true, loops = loops == true, loopFrom = s.loopFrom or from }
			end
			def = { type = "cast", segs = segs }
		end
		KITDEF[skillId] = def
	end
	return def or nil
end

-- 그 사람이 기술의 한 구간을 쓴다
function Others:act(id: any, skillId: string, seg: number, x: number, y: number, dir: number, now: number)
	local o = self.list[id]
	local def = COMBAT.skills[skillId] or kitDef(skillId)
	if not o or not def or not def.segs[seg] then
		return
	end
	o.act = { def = def, seg = seg, t0 = now }
	o.dir = dir
	if not o.placed then
		o.x, o.y, o.toX, o.toY, o.fromX, o.fromY, o.placed = x, y, x, y, x, y, true
	end
	-- 대쉬를 시작했다: 속도선(잔상은 update가 가는 동안 남긴다)
	if def.type == "move" and seg == 1 and self.fx then
		self.fx:streaks(x, y, def.speed, dir, CLASSES.classes[o.class].tone)
	end
end

-- party = 내 파티원 { [번호] = true }
function Others:update(now: number, party)
	local dt = math.clamp(now - self.last, 0, 0.1)
	self.last = now
	for id, o in self.list do
		if not o.placed then
			continue
		end
		local k = math.clamp((now - o.at) / LERP, 0, 1)
		o.x = o.fromX + (o.toX - o.fromX) * k
		o.y = o.fromY + (o.toY - o.fromY) * k
		local char = o.sprite.char
		local clip, frame = "idle", Sprite.frameAt(char, "idle", now + (id % 7) * 0.3, false)
		local act = o.act
		if act then
			local segDef = act.def.segs[act.seg]
			local t = now - act.t0
			if t >= segDef.time then
				-- 저절로 이어지는 다음 구간(한 번 더 눌러 잇는 구간은 서버가 따로 알려 준다)
				local nextDef = act.def.segs[act.seg + 1]
				if nextDef and not nextDef.next then
					act.seg += 1
					act.t0 += segDef.time
					segDef, t = nextDef, now - act.t0
				else
					o.act, act = nil, nil
				end
			end
			if act then
				local f = segDef.from + math.floor(t * segDef.fps)
				if f > segDef.to then
					f = if segDef.loops then segDef.loopFrom + ((f - segDef.to - 1) % (segDef.to - segDef.loopFrom + 1)) else segDef.to
				end
				clip, frame = segDef.clip, f + 1
				-- 대쉬로 가는 동안: 잔상
				if act.def.type == "move" and t < act.def.dist / act.def.speed and self.fx and o.alive then
					self.fx:trail(o, dt, o.class, clip, frame, o.x, o.y, o.dir, CLASSES.classes[o.class].tone)
				end
			end
		end
		if not o.alive then
			local n = #char.clips.death.frames
			clip, frame = "death", math.min(n, math.floor((now - (o.deadAt or now)) * char.clips.death.fps) + 1)
		elseif not act then
			local onLadder = false
			for _, l in self.ladders do
				onLadder = onLadder or (math.abs(o.x - l.x) <= 1 and o.y > l.top + 0.5 and o.y < l.bottom - 0.5)
			end
			if onLadder then
				-- 사다리 위: 오르내리는 중이면 장이 넘어가고, 멈춰 있으면 첫 장
				clip, frame = "climb", if now - o.airT < 0.25 then Sprite.frameAt(char, "climb", now, false) else 1
			elseif now - o.airT < 0.25 then
				clip, frame = "jump", Sprite.frameAt(char, "jump", (now - o.airT) + 0.2, true)
			elseif now - o.moveT < 0.25 then
				clip, frame = "run", Sprite.frameAt(char, "run", now, false)
			end
		end
		-- 탈것: 탄 동안 서기 모습으로 앉는 자리에(사다리 위 · 기술 중 · 쓰러짐에는 감춘다)
		local hx, hy = o.x, o.y
		local onRung = false
		for _, l in self.ladders do
			onRung = onRung or (math.abs(o.x - l.x) <= 1 and o.y > l.top + 0.5 and o.y < l.bottom - 0.5)
		end
		local rx, ry, rs = o.rv:update(now, dt, o.x, o.y, o.dir, now - o.moveT < 0.25, now - o.airT < 0.25, onRung or act ~= nil or not o.alive)
		if rx then
			hx, hy = rx, ry
			clip, frame = "idle", Sprite.frameAt(char, "idle", now + (id % 7) * 0.3, false)
		end
		o.rideSize = rs -- 탄 동안 작게(boot가 버프의 모습을 입힐 때도 — cast.luau의 look)
		o.hx, o.hy = hx, hy -- 몸을 그린 자리(탄 동안은 안장 위 — boot가 버프의 모습을 이 자리에 입힌다)
		o.sprite:set(clip, frame, hx, hy, o.dir, rs)
		o.clip, o.frame = clip, frame -- 지금의 동작과 장(boot가 버프의 모습을 그 위에 입힌다 — cast.luau의 look)
		-- 쓰러진 사람: 쓰러지는 동작이 끝나면 몸 대신 비석이 선다(마을로 돌아가거나 소생을 받을 때까지)
		local downFor = if o.alive then -1 else now - (o.deadAt or now) - #char.clips.death.frames / char.clips.death.fps
		o.fallen = downFor >= 0
		if o.fallen and self.graveLayer then
			o.grave = o.grave or Grave.new(self.graveLayer)
			Grave.put(o.grave, o.x, o.y, downFor)
			o.sprite.label.Visible = false
		elseif o.grave then
			o.grave.Visible = false
		end
		o.tag.Frame.Visible = true -- 자리는 boot가 정한다(이름표끼리 겹치지 않게 쌓는다 — tags())
		local color = if party and party[id] then MINT else WHITE
		if o.tagColor ~= color then
			o.tagColor = color
			o.tag:SetColor(color)
		end
	end
end

-- 이름표들: { x(왼쪽), y(위), w, frame } — 화면 틀의 점. 번호 차례(늘 같은 차례로 쌓이게)
function Others:tags()
	local out = {}
	for id, o in self.list do
		if o.placed then
			table.insert(out, { id = id, x = Overlay.x(o.x) - math.floor(o.tag.Width / 2), y = Overlay.y(o.y) + TAG_DOWN, w = o.tag.Width, frame = o.tag.Frame })
		end
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end

-- 지금 방에 있는 다른 사람들(파티 창의 초대 목록이 쓴다)
function Others:roster()
	local out = {}
	for id, o in self.list do
		table.insert(out, { id = id, name = o.name, level = o.level, class = o.class })
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end

function Others:destroy()
	for _, o in self.list do
		drop(o)
	end
	table.clear(self.list)
end

return Others
