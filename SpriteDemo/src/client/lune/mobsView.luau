-- 졸개 그리기. 서버가 초당 열 번 보내는 모습(자리 · 보는 쪽 · 상태 · 상태가 된 뒤 흐른 시간 · 체력)을 받아, 그 사이를 이어 그린다.
--  졸개가 무엇을 하는지는 서버가 정한다 — 여기서는 보이는 것만 맞춘다.
--  다친 졸개에게만 머리 위에 체력 띠, 발밑에 이름표(「Lv.1 수습 검병」)가 뜬다 — 다 띄우면 화면이 이름표로 덮인다.
--  체력 띠와 이름표는 글씨의 층(화면 틀의 고운 격자 — overlay.luau)에 그리고, 자리만 졸개를 따라간다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local COMBAT = require(lune.data["combat.generated"])
local Sprite = require(script.Parent.sprite)
local Ui = require(script.Parent.ui.ui)
local Overlay = require(script.Parent.overlay)
local Layout = require(lune.ui.layout)

local C = Ui.COLOR
local LERP = 0.1 -- 모습이 오는 간격(초) — 이 시간에 걸쳐 앞 자리에서 새 자리로 옮긴다
local BAR_W, BAR_H = Layout.MOBBAR.w, Layout.MOBBAR.h -- 체력 띠의 크기(화면 틀의 점)
local BAR_UP = Layout.MOBBAR.up -- 체력 띠: 발밑에서 이만큼 위(게임의 도트)
local TAG_DOWN = Layout.TAG.down -- 이름표: 발밑에서 이만큼 아래(화면 틀의 점)

local MobsView = {}
MobsView.__index = MobsView

function MobsView.tagText(lv: number, name: string): string
	return ("Lv.%d %s"):format(lv, name)
end

-- layer = 졸개 그림의 층(게임 세계) · room = 서버가 준 방의 모습 · tagLayer = 이름표와 체력 띠의 층(화면 틀 — overlay)
function MobsView.new(layer: Frame, room, tagLayer: Frame)
	local self = setmetatable({}, MobsView)
	self.layer = layer
	self.mobs = {}
	local top = tagLayer
	for _, info in room.mobs do
		local bar = Ui.bar(top, 0, 0, BAR_W, BAR_H, C.hp)
		bar.frame.Name = "HpBar"
		bar.frame.ZIndex = 5
		bar.frame.Visible = false
		local tag = Ui.tag(top, MobsView.tagText(info.lv or 1, info.name or COMBAT.mobs[info.kind].name), C.text, 260)
		tag.Frame.Visible = false
		self.mobs[info.id] = {
			info = info,
			def = COMBAT.mobs[info.kind],
			sprite = Sprite.new(layer, COMBAT.mobs[info.kind].sprite, 2), -- 그림을 빌려 쓰는 졸개가 있다(수습 검병 = 검병의 그림)
			bar = bar,
			tag = tag,
			x = 0,
			fromX = 0,
			toX = 0,
			at = 0,
			dir = 1,
			state = "gone",
			t = 0,
			hp = info.maxHp,
			shownHp = -1,
			burst = nil :: number?,
		}
	end
	if room.snap then
		self:apply(room.snap, 0)
		for _, m in self.mobs do
			m.fromX = m.toX
		end
	end
	return self
end

-- 서버가 보낸 모습을 받아 적는다. now = 받은 때(클라이언트 시계)
function MobsView:apply(list, now: number)
	for _, row in list do
		local m = self.mobs[row[1]]
		if m then
			m.fromX = if m.state == "gone" then row[2] else m.x
			m.toX, m.dir, m.at = row[2], row[3], now
			if row[4] ~= "dead" then
				m.burst = nil
			end
			m.state, m.t, m.hp = row[4], row[5], row[6]
		end
	end
end

-- 폭탄병이 터졌다: 죽는 동작 대신 터지는 동작을 끝까지 튼다
function MobsView:burst(id: number, now: number)
	local m = self.mobs[id]
	if m then
		m.burst = now
	end
end

function MobsView:get(id: number)
	return self.mobs[id]
end

function MobsView:update(now: number)
	for _, m in self.mobs do
		local k = math.clamp((now - m.at) / LERP, 0, 1)
		m.x = m.fromX + (m.toX - m.fromX) * k
		local t = m.t + (now - m.at)
		local char = m.sprite.char
		local clip, frame = "idle", 1
		local show = true
		if m.state == "gone" then
			show = false
		elseif m.state == "dead" then
			if m.burst then
				-- 터지는 동작의 맞는 장부터 끝까지
				local atk = m.def.atk
				local f = atk.frame + math.floor((now - m.burst) * atk.fps)
				clip, frame = "atk", f + 1
				show = f < #char.clips.atk.frames
			else
				clip = "death"
				frame = math.min(#char.clips.death.frames, math.floor(t * char.clips.death.fps) + 1)
			end
		elseif m.state == "spawn" then
			clip = "spawn"
			frame = math.min(#char.clips.spawn.frames, math.floor(t * char.clips.spawn.fps) + 1)
		elseif m.state == "atk" then
			clip = "atk"
			frame = math.min(#char.clips.atk.frames, math.floor(t * m.def.atk.fps) + 1)
		elseif m.state == "hit" then
			clip = "hit"
			frame = math.min(#char.clips.hit.frames, math.floor(t * char.clips.hit.fps) + 1)
		elseif m.state == "run" then
			clip = "run"
			frame = Sprite.frameAt(char, "run", now, false)
		else
			frame = Sprite.frameAt(char, "idle", now + m.info.id * 0.3, false)
		end
		if show then
			m.sprite:set(clip, frame, m.x, m.info.y, m.dir)
		else
			m.sprite.label.Visible = false
		end
		-- 체력 띠와 이름표: 다친 졸개에게만
		local alive = m.state ~= "gone" and m.state ~= "dead" and m.state ~= "spawn"
		m.hurt = alive and m.hp < m.info.maxHp
		m.bar.frame.Visible = m.hurt
		m.tag.Frame.Visible = m.hurt -- 자리는 boot가 정한다(이름표끼리 겹치지 않게 쌓는다 — tags())
		if m.hurt then
			m.bar.frame.Position = UDim2.fromOffset(Overlay.x(m.x) - BAR_W / 2, Overlay.y(m.info.y - BAR_UP))
			if m.shownHp ~= m.hp then
				m.shownHp = m.hp
				m.bar:set(m.hp / m.info.maxHp)
			end
		end
	end
end

-- 떠 있는 이름표들: { x(왼쪽), y(위), w, frame } — 화면 틀의 점. 번호 차례(늘 같은 차례로 쌓이게)
function MobsView:tags()
	local out = {}
	for id, m in self.mobs do
		if m.hurt then
			table.insert(out, { id = id, x = Overlay.x(m.x) - math.floor(m.tag.Width / 2), y = Overlay.y(m.info.y) + TAG_DOWN, w = m.tag.Width, frame = m.tag.Frame })
		end
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end

function MobsView:destroy()
	for _, m in self.mobs do
		m.sprite:destroy()
		m.bar.frame:Destroy()
		m.tag:Destroy()
	end
	table.clear(self.mobs)
end

return MobsView
