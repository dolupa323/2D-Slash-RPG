-- 기간 이벤트의 날아다니는 장식(2026-10-29 — 공방 design/event.js의 fly · 할로윈).
--  사용자: "일반사냥터들에 그냥 마녀나, 무서운 호박들 아무효과없는거 날아다니고 분위기를 그렇게 내는거야 다 할로윈 기간 한정으로"
--  사냥터에서만(보스 방 · 던전 · 토벌 · 꿈 · 마을이 아니다) · 그 이벤트가 켜져 있을 때만. 맞지도 치지도 않는 그림일 뿐이다 — 서버는 모른다(화면마다 따로 난다).
--  화면 위쪽을 가로질러 날아간다: 한꺼번에 cfg.max마리 · cfg.every초마다 하나 · 빠르기 cfg.speed · 카메라 위 cfg.top점 · 위아래 cfg.bob점 출렁.
--  층 = 맵 틀 안의 뒤 소품(Back 10) 위 · 땅(Ground 20) · 주민 · 캐릭터 아래(사용자 2026-10-08 「맵의 것은 캐릭터 앞에 그리지 않는다」).
--  그림: 호박 · 마녀 = tools/build_lune_halloween.mjs(손으로 찍은 점) · 박쥐 = 펫 「아기 호박박쥐」의 그림(펫의 배율로). 공방 시험 탭의 luneTab.js가 같은 셈으로 그린다
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local Event = require(lune.sim.event)
local G = require(lune.config.game)
local Stage = require(script.Parent.stage)
local Sprite = require(script.Parent.sprite)

local EventFly = {}
EventFly.Z = 15 -- 맵 틀 안의 차례(Back 10 위 · Ground 20 아래)

local now = nil -- { view, layer, cfg, flyers, wait, rng }

-- 사냥터인가(공방 · 서버의 Room.huntRoom과 같은 조건)
function EventFly.huntScene(scene): boolean
	return scene ~= nil and scene.mobs ~= nil and #scene.mobs > 0 and not scene.rest and not scene.rift and not scene.dungeon and not scene.dojo and not scene.story and not scene.tut and not (scene.bosses and #scene.bosses > 0)
end

function EventFly.leave()
	if now then
		for _, f in now.flyers do
			f.sprite:destroy()
		end
		if now.layer then
			now.layer:Destroy()
		end
		now = nil
	end
end

-- 장면에 들어섰다(맵 틀 view.world가 새로 지어졌다)
function EventFly.enter(view, scene, at: number?)
	EventFly.leave()
	if not view or not EventFly.huntScene(scene) then
		return
	end
	local cfg = nil
	for _, e in Event.active(at) do
		if e.fly then
			cfg = e.fly
			break
		end
	end
	if not cfg then
		return
	end
	now = { view = view, layer = Stage.group(view.world, "EventFly", EventFly.Z), cfg = cfg, flyers = {}, wait = 1.5, rng = Random.new() }
end

local function pick(rng, kinds)
	local sum = 0
	for _, k in kinds do
		sum += k[2]
	end
	local r = rng:NextNumber(0, sum)
	for _, k in kinds do
		r -= k[2]
		if r <= 0 then
			return k[1]
		end
	end
	return kinds[1][1]
end

local function spawn(n)
	local cfg, view, rng = n.cfg, n.view, n.rng
	local who = pick(rng, cfg.kinds)
	local ok, sprite = pcall(Sprite.new, n.layer, who)
	if not ok then
		return -- (그림이 아직 실리지 않았다)
	end
	local dir = if rng:NextNumber() < 0.5 then 1 else -1
	local camX, camY = view.camX or 0, view.camY or 0
	local margin = 40
	local x = if dir > 0 then camX - margin else camX + G.VIEW_W + margin
	local y = camY + rng:NextNumber(cfg.top[1], cfg.top[2])
	table.insert(n.flyers, { sprite = sprite, who = who, dir = dir, x = x, y = y, vx = dir * rng:NextNumber(cfg.speed[1], cfg.speed[2]), t = rng:NextNumber(0, 3), phase = rng:NextNumber(0, math.pi * 2) })
end

-- 매 화면(BindToRenderStep 안 — 화면의 그림은 그때만 고친다): 날려 보내고 · 움직이고 · 화면 밖으로 나간 것을 거둔다
function EventFly.update(dt: number)
	local n = now
	if not n or not n.layer.Parent then
		return
	end
	n.wait -= dt
	if n.wait <= 0 then
		n.wait = n.rng:NextNumber(n.cfg.every[1], n.cfg.every[2])
		if #n.flyers < n.cfg.max then
			spawn(n)
		end
	end
	local camX = n.view.camX or 0
	for i = #n.flyers, 1, -1 do
		local f = n.flyers[i]
		f.t += dt
		f.x += f.vx * dt
		local c = f.sprite.char.clips.idle
		local count = (c and #c.frames) or 1
		local frame = (math.floor(f.t * ((c and c.fps) or 6)) % count) + 1
		f.sprite:set("idle", frame, f.x, f.y + n.cfg.bob * math.sin(f.t * 1.6 + f.phase), f.dir)
		if (f.dir > 0 and f.x > camX + G.VIEW_W + 60) or (f.dir < 0 and f.x < camX - 60) then
			f.sprite:destroy()
			table.remove(n.flyers, i)
		end
	end
end

-- 지금 날고 있는 것(자동 검사가 본다)
function EventFly.flyers(): { any }
	return if now then now.flyers else {}
end

return EventFly
