-- 「달의 계승자」 — 사람 앞에서 ↑를 누르면 그 사람과 말한다(문 · 간이 포탈에 먼저 잡히지 않는다)
--  사용자 2026-10-23: "외성밖 들판 퀘스트 주는 샛별이랑 오른쪽가는 포탈이랑 겹쳐있잖아 퀘스트를 받을수없어"
--   (r4a1 — 샛별 70도트 · 간이 포탈 「오른쪽 끝으로」 72도트: ↑는 간이 포탈 → 문 → 사람 차례로 본다 — boot.luau)
--  잡히는 거리는 client sceneView.luau와 같다: 문 가로 26 · 세로 4 / 간이 포탈 가로 16 · 세로 24 / 사람 가로 30 · 세로 24.
--  사람이 선 자리에서 문 · 간이 포탈까지 그 거리 + 6도트(서서 누를 틈)는 떨어져야 한다.
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local GAP = 6

local bad, seen = {}, 0
for key, sc in SCENES.scenes do
	for _, n in sc.npcs or {} do
		if not n.stone then
			seen += 1
			for _, p in sc.portals or {} do
				if math.abs(p.x - n.x) < 26 + GAP and math.abs(p.y - n.y) < 4 then
					table.insert(bad, ("%s: %s(%d)가 문 「%s」(%d)에 겹친다"):format(key, tostring(n.id), n.x, tostring(p.label), p.x))
				end
			end
			for _, w in sc.warps or {} do
				if math.abs(w.x - n.x) < 16 + GAP and math.abs(w.y - n.y) < 24 then
					table.insert(bad, ("%s: %s(%d)가 간이 포탈 「%s」(%d)에 겹친다"):format(key, tostring(n.id), n.x, tostring(w.label), w.x))
				end
			end
		end
	end
end
expect(seen > 50, ("맵의 사람을 셌다(%d)"):format(seen))
for _, line in bad do
	expect(false, line)
end
expect(#bad == 0, ("사람 앞에서 ↑가 문 · 간이 포탈에 잡히는 곳 %d곳"):format(#bad))
