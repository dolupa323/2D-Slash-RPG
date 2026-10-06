-- 같은 맵에 있는 다른 사람들 — 서버가 알려 준 이름표(Who)와 자리(Heroes · 초당 10번)를 받아 그린다. 자리 사이는 이어서 그린다.
--  동작은 움직임에서 짐작한다: 옆으로 움직이면 달리기, 위아래로 움직이면 뛰기, 아니면 서 있기. 기술은 서버가 알려 준 것(Act)을 그 구간 동안 튼다.
--  발밑에 이름표(메이플처럼 이름만) — 파티원은 민트색이다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local COMBAT = require(ReplicatedStorage.shared.lune.data["combat.generated"])
local Sprite = require(script.Parent.sprite)
local Kit = require(script.Parent.ui.kit)

local WHITE = Kit.COLOR.white
local MINT = Kit.COLOR.mint
local LERP = 0.12 -- 자리 보고 사이를 이만큼에 걸쳐 잇는다(초)
local TAG_DOWN = 3 -- 이름표: 발밑에서 이만큼 아래

local Others = {}
Others.__index = Others
Others.TAG_DOWN = TAG_DOWN

-- 이름표에 적는 글: 이름만(레벨은 파티원 칸 · 파티 창에서 본다)
function Others.tagText(_level: number, name: string): string
	return name
end

function Others.new(heroLayer: Frame, tagLayer: Frame, myId: any)
	local self = setmetatable({}, Others)
	self.heroLayer, self.tagLayer, self.myId = heroLayer, tagLayer, myId
	self.list = {} -- [번호] = 한 사람
	return self
end

local function drop(o)
	o.sprite:destroy()
	o.tag:Destroy()
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
					tag = Kit.tag(self.tagLayer, "", WHITE, 150),
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
				}
				o.sprite.label.Visible = false
				o.tag.Frame.Visible = false
				self.list[w.id] = o
			end
			if o.name ~= w.name or o.level ~= w.level then
				o.name, o.level = w.name, w.level
				o.tag:SetText(Others.tagText(w.level, w.name))
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

-- 그 사람이 기술의 한 구간을 쓴다
function Others:act(id: any, skillId: string, seg: number, x: number, y: number, dir: number, now: number)
	local o = self.list[id]
	local def = COMBAT.skills[skillId]
	if not o or not def or not def.segs[seg] then
		return
	end
	o.act = { def = def, seg = seg, t0 = now }
	o.dir = dir
	if not o.placed then
		o.x, o.y, o.toX, o.toY, o.fromX, o.fromY, o.placed = x, y, x, y, x, y, true
	end
end

-- party = 내 파티원 { [번호] = true }
function Others:update(now: number, party)
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
				clip, frame = segDef.clip, segDef.from + math.min(segDef.to - segDef.from, math.floor(t * segDef.fps)) + 1
			end
		end
		if not o.alive then
			local n = #char.clips.death.frames
			clip, frame = "death", math.min(n, math.floor((now - (o.deadAt or now)) * char.clips.death.fps) + 1)
		elseif not act then
			if now - o.airT < 0.25 then
				clip, frame = "jump", Sprite.frameAt(char, "jump", (now - o.airT) + 0.2, true)
			elseif now - o.moveT < 0.25 then
				clip, frame = "run", Sprite.frameAt(char, "run", now, false)
			end
		end
		o.sprite:set(clip, frame, o.x, o.y, o.dir)
		o.tag.Frame.Visible = true -- 자리는 boot가 정한다(이름표끼리 겹치지 않게 쌓는다 — tags())
		local color = if party and party[id] then MINT else WHITE
		if o.tagColor ~= color then
			o.tagColor = color
			o.tag:SetColor(color)
		end
	end
end

-- 이름표들: { x(왼쪽), y(위), w, frame } — 번호 차례(늘 같은 차례로 쌓이게)
function Others:tags()
	local out = {}
	for id, o in self.list do
		if o.placed then
			table.insert(out, { id = id, x = math.floor(o.x - o.tag.Width / 2 + 0.5), y = math.floor(o.y + 0.5) + TAG_DOWN, w = o.tag.Width, frame = o.tag.Frame })
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
