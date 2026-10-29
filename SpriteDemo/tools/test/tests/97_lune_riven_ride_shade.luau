-- 「달의 계승자」 — 리븐의 그림자 분신이 탈것을 탄 동안 따로 걷는다(2026-10-26 사용자 "리븐 캐릭터가 탈것을 탔을때 그림자 분신이 엄청나게 이상하게 나온다
--  그림자 분신은 그대로인상태에서 캐릭터만 탈것에 올라가버려 … 리븐 그림자를 완전 별도 캐릭터처럼 따로 움직이게").
--  보는 것: 탄 동안 분신은 땅(내 발 높이)에서 탈것 뒤를 늦게 따라 달리고(run) · 멈추면 선다(idle) · 장 번호가 그 동작 안이다 · 쌍영이면 둘 · 내리면 다시 내 모습(pose)을 따른다
local riven = req("ReplicatedStorage/shared/lune/kits/riven")
local drawn = {}
local FRAMES = { run = 6, idle = 7 }
local g = {
	s = { venom = 0, n = 0 },
	clock = 0,
	x = 100,
	y = 176,
	dir = 1,
	riding = true,
	pose = { clip = "idle", f = 0 },
	skill = { rv_clone = 10, rv_clone2 = 0 },
}
function g.has(id)
	return id == "rv_clone"
end
function g.sk(id)
	return g.skill[id] or 0
end
function g.frames(clip)
	return FRAMES[clip] or 1
end
function g.sprite(clip, f, x, y, dir, o)
	table.insert(drawn, { clip = clip, f = f, x = x, y = y, dir = dir, o = o })
end
local function frame(dt)
	g.clock += dt
	table.clear(drawn)
	riven.drawBack(nil, g)
end

-- 탄 채로 오른쪽으로 달린다(1초에 120도트)
for _ = 1, 30 do
	g.x += 120 / 30
	frame(1 / 30)
end
eq(#drawn, 1, "분신 하나(쌍영 없음)")
local d = drawn[1]
expect(d.clip == "run", "탄 채로 달리면 분신도 제 발로 달린다 — " .. tostring(d.clip))
eq(d.y, g.y, "분신은 땅(내 발 높이)에 있다 — 안장 위의 모습을 따라 그리지 않는다")
expect(d.x < g.x - 20, ("분신은 탈것 뒤에 있다(분신 %d · 나 %d)"):format(d.x, g.x))
expect(d.f >= 0 and d.f < FRAMES.run, "장 번호가 달리기 동작 안이다")
eq(d.dir, 1, "달리는 쪽을 본다")
-- 멈춘다: 분신이 따라붙어 선다
for _ = 1, 60 do
	frame(1 / 30)
end
d = drawn[1]
eq(d.clip, "idle", "멈추면 분신도 선다")
expect(math.abs(d.x - (g.x - 26)) < 2, ("멈춘 뒤 분신은 탈것 바로 뒤에 선다(%d)"):format(d.x))
expect(d.f >= 0 and d.f < FRAMES.idle, "장 번호가 서기 동작 안이다")
-- 쌍영: 둘 · 둘째가 더 뒤
g.skill.rv_clone2 = 10
g.x += 80
for _ = 1, 10 do
	frame(1 / 30)
end
eq(#drawn, 2, "쌍영이면 분신 둘")
expect(drawn[2].x < drawn[1].x, "둘째 분신이 더 뒤에서 따라온다")
-- 내린다: 다시 내 모습(pose)을 그대로
g.riding = false
g.pose = { clip = "slash", f = 3 }
frame(1 / 30)
expect(#drawn >= 1 and drawn[1].clip == "slash" and drawn[1].f == 3, "내리면 다시 내 동작을 그대로 따라 그린다")
eq(g.s.shadeX, nil, "따로 걷던 자리는 지운다(다시 타면 탈것 뒤에서 시작)")
-- 분신 버프가 없으면 아무것도
g.has = function() return false end
g.riding = true
frame(1 / 30)
eq(#drawn, 0, "분신 버프가 없으면 그리지 않는다")
