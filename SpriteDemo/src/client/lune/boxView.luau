-- 보상의 방의 보상 상자(2026-10-28 — sim/weekly.luau의 boxView · 공방 시험 탭 luneTab.js의 drawChest와 같은 모습).
--  사용자: "보스를 처치하면 자동으로 모두 보스 보상방으로 이동하고 보스 보상방에는 보상상자가 멋지게 잇고 상자를 열면 보상이 파티보상으로 흩부려지는 방식으로 …"
--  하는 일: 상자 그림(그림판 bosschest — idle 닫힘 · open 여는 다섯 장 · done 열림)을 장면의 상자 자리(scene.chest — 바닥 가운데)에 그린다.
--   닫혀 있는 동안 보석 둘레에 작은 반짝임 · 머리 위에 「↑ 보상 상자」(곁에 서면 밝게) · 열리면 여는 동작 → 빛기둥 · 고리 · 파편(Cast의 fx)
--   · 흩어진 보상은 Effects가 상자에서 튀어나오게 그린다(떨어진 것의 fromX · delay). 머리 위의 줄 = 보스의 문 앞으로 가기까지 남은 초
--  상자를 여는 것은 boot의 ↑(곁에 있으면 BoxView.near) → Week "open"(서버가 받을 사람 · 거리를 본다)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local Weekly = require(lune.sim.weekly)
local Format = require(lune.ui.format)
local Sprite = require(script.Parent.sprite)
local Ui = require(script.Parent.ui.ui)
local Overlay = require(script.Parent.overlay)
local Cast = require(script.Parent.cast)

local W = Weekly.DATA.words
local BOX = Weekly.BOX
local CHAR = "bosschest"
local C = Ui.COLOR

local BoxView = {}
local cur = nil :: any -- { sprite, label, view, openAt, fx(Cast의 fx — 빛기둥 · 파편), sparkT }

-- 장면에 들어섰다: 보상의 방이면 상자를 세운다(view = 방의 상자 — 없으면 치운다)
function BoxView.enter(layer: Instance, over: Instance, view: any, cast: any)
	BoxView.leave()
	if not view then
		return
	end
	local sprite = Sprite.new(layer, CHAR, 1)
	local label = Ui.text(over, "", 0, 0, 160, { align = "center", outline = true, color = C.text })
	cur = { sprite = sprite, label = label, view = view, openAt = if view.opened then -99 else nil, cast = cast, sparkT = 0 }
end

function BoxView.leave()
	if cur then
		cur.sprite:destroy()
		cur.label.destroy()
		cur = nil
	end
end

function BoxView.active(): boolean
	return cur ~= nil
end
function BoxView.opened(): boolean
	return cur ~= nil and cur.view.opened == true
end

-- 서버가 상자의 모습을 보냈다(BoxView): 처음 열렸으면 여는 동작 · 빛을 튼다
function BoxView.set(view: any, now: number)
	if not cur or not view then
		return
	end
	local was = cur.view.opened
	cur.view = view
	if view.opened and not was then
		cur.openAt = now
		local fx = cur.cast and cur.cast.fx
		if fx then
			local mint, pink = Cast.tone("mint"), Cast.tone("pink")
			local x, y = view.x, view.y
			fx.beam(x, y - 20, 34, 90, mint, { life = 1.1, delay = 0.35 })
			fx.ring(x, y - 2, 6, 70, mint, { squash = 0.3, life = 0.8, delay = 0.35 })
			fx.ring(x, y - 2, 4, 46, pink, { squash = 0.3, life = 0.6, delay = 0.45 })
			fx.shards(x, y - 34, 18, mint, { speed = 80, up = 120, kind = "mix", life = 0.9, delay = 0.38 })
			fx.shards(x, y - 34, 10, pink, { speed = 70, up = 110, kind = "dot", life = 0.8, delay = 0.42 })
			fx.rise(x, y - 6, 14, mint, { w = 40, speed = 40, life = 1.4, delay = 0.4 })
		end
	end
end

-- 상자 곁인가(↑로 열 수 있는 거리 — 서버의 Weekly.canOpen과 같은 셈 · 닫혀 있을 때만)
function BoxView.near(x: number, y: number): boolean
	return cur ~= nil and not cur.view.opened and math.abs(x - cur.view.x) <= BOX.reach and math.abs(y - cur.view.y) <= 40
end

-- 열어 달라고 한다(서버가 받을 사람 · 거리를 본다 — 안 되면 까닭을 띄운다)
function BoxView.open(ask: (string) -> any, float: (string) -> ())
	if not cur or cur.asking then
		return
	end
	cur.asking = true
	task.spawn(function()
		local ok, res = pcall(ask, "open")
		if cur then
			cur.asking = false
		end
		if ok and res and not res.ok and res.why then
			float(res.why)
		end
	end)
end

-- 장마다: 상자의 그림 · 머리 위의 줄 · 닫힌 동안의 반짝임. body = 내 몸(곁에 섰는가)
function BoxView.update(now: number, dt: number, body: any)
	if not cur then
		return
	end
	local v = cur.view
	local char = cur.sprite.char
	local clip, frame = "idle", 1
	if cur.openAt then
		local t = now - cur.openAt
		local n = #char.clips.open.frames
		if t < n / char.clips.open.fps then
			clip, frame = "open", Sprite.frameAt(char, "open", t, true)
		else
			clip, frame = "done", 1
		end
	end
	cur.sprite:set(clip, frame, v.x, v.y, 1)
	-- 닫혀 있는 동안: 자물쇠의 분홍 보석 둘레에 작은 반짝임(1.2초마다)
	if not v.opened and cur.cast and cur.cast.fx then
		cur.sparkT -= dt
		if cur.sparkT <= 0 then
			cur.sparkT = 1.2
			cur.cast.fx.pop(v.x - 2 + math.random(-6, 6), v.y - 22 + math.random(-4, 4), Cast.tone("pink"), { r = 3, life = 0.3 })
		end
	end
	-- 머리 위의 줄: 닫힘 = 「↑ 보상 상자」(곁이면 밝게) · 열림 = 남은 초(서버가 보낸 남은 초에서 센다)
	cur.left = math.max(0, (cur.left or v.left) - dt)
	if cur.lastLeft ~= v.left then
		cur.lastLeft, cur.left = v.left, v.left
	end
	local text, color
	if v.opened then
		text, color = Format.fill(W.boxLeft, { t = math.ceil(cur.left) }), C.dim
	else
		local near = body and BoxView.near(body.x, body.y)
		text, color = W.boxOpen, if near then C.accent else C.text
	end
	if cur.text ~= text then
		cur.text = text
		cur.label:set(text)
	end
	cur.label:color(color)
	cur.label:move(Overlay.x(v.x) - 80, Overlay.y(v.y - char.oy - 10))
end

return BoxView
