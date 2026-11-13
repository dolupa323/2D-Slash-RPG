-- 「달의 계승자」 — 모은 단계: 화면이 센 단계와 서버가 센 단계를 맞춘다(2026-11-11 밤 — 사용자: "엑시온 전투호흡 활성화하고 도끼 범위가 오락가락하는데? 위 아래, 범위가 계속 왔다갔다해
--  전투호흡 안쓰면 그냥 원래 사거리 쭉 자연스럽게 이어지는데").
--  sim/kit.luau Kit.chargeClaim · server world.luau(1차의 모아 친 한 방) · sim/caster.luau(2~4차 — info.claim) · client boot.luau(모으기 다음 구간에 화면이 센 단계를 보낸다)
--  보는 것: ① 화면이 낮게 셌으면 화면의 단계 ② 한 단계 높게 셌고 흔들림(0.12초) 안이면 화면의 단계 ③ 흔들림 밖 · 두 단계 위 · 숫자가 아님 · 소수는 서버의 단계
--   ④ 전투 호흡(한 단계 0.15초)으로 끝까지 모은 것이 네트워크가 30ms 흔들려도 끝 단계로 맞는다(전에는 한 단계 낮았다) ⑤ 2~4차(caster:begin)도 info.claim을 쓴다
local Kit = req("ReplicatedStorage/shared/lune/sim/kit")

-- ① ② ③
local per = 0.15
eq(Kit.chargeClaim(3, 2, 0.45, per, 0, 4), 2, "화면이 낮게 셌다 → 화면의 단계(그린 대로)")
eq(Kit.chargeClaim(3, 4, 0.58, per, 0, 4), 4, "한 단계 높게 · 0.58 + 0.12 ≥ 0.60 → 화면의 단계")
eq(Kit.chargeClaim(3, 4, 0.40, per, 0, 4), 3, "한 단계 높지만 0.40 + 0.12 < 0.60 → 서버의 단계")
eq(Kit.chargeClaim(2, 4, 0.59, per, 0, 4), 2, "두 단계 높게 셌다 → 서버의 단계")
eq(Kit.chargeClaim(3, nil, 0.58, per, 0, 4), 3, "화면이 단계를 보내지 않았다 → 서버의 단계")
eq(Kit.chargeClaim(3, true, 0.58, per, 0, 4), 3, "참/거짓(살라맨더의 강화판) → 서버의 단계")
eq(Kit.chargeClaim(3, 3.5, 0.58, per, 0, 4), 3, "소수 → 서버의 단계")
eq(Kit.chargeClaim(3, 9, 9, per, 0, 4), 4, "끝 단계를 넘는 수는 끝 단계(4)로 줄여 본다 — 한 단계 위 · 시간이 충분하다")
eq(Kit.chargeClaim(1, 2, 0.08, per, 1, 4), 2, "넘치는 힘(1단계를 거저) — 남은 한 단계만 재어 본다")

-- ④ 전투 호흡으로 끝까지(4단계 = 0.60초): 화면은 0.60초에 보냈고 서버에는 30ms 일찍 닿았다(0.57초)
local held = 0.57
local serverLv = math.clamp(math.floor(held / per + 1e-6), 0, 4)
eq(serverLv, 3, "(전에는) 서버는 3단계로 셌다")
eq(Kit.chargeClaim(serverLv, 4, held, per, 0, 4), 4, "이제 화면과 같은 4단계")

-- ⑤ caster(2~4차): info.claim
local src = req("ReplicatedStorage/shared/lune/sim/caster")
expect(type(src) == "table", "caster를 읽는다")
