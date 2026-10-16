-- 장비의 별(스타포스)을 글로 — 이름 위에 별 그림으로 적는다(2026-10-15).
--  사용자: "강화 표기 방법도 잘못됬는데 아이템 이름 옆에 +1 이렇게 되는게 아니라 아이템 이름 위에 별이 표기되는겁니다. 별 개수에 맞춰서 1강당 별 1개"
--  메이플스토리의 툴팁처럼: 한 줄에 15개(다섯마다 한 칸 띄운다) · 붙은 별은 노랑, 아직 안 붙은 별(최대 22까지)은 흐리게. 게임의 글꼴에 「★」가 있다(공방 tools/import_bdf_font.mjs의 EXTRA).
--  화면 없이 셈하는 부분만 여기에 둔다 — 그리는 것은 client/lune/ui/ui.luau의 Ui.stars, 공방은 js/lune/ui/paint.js의 starRows가 같은 셈을 한다.
local StarText = {}

StarText.PER = 15 -- 한 줄의 별
StarText.GROUP = 5 -- 다섯마다 한 칸 띄운다
StarText.STAR = "★"

-- 줄마다 { on = 붙은 별의 글, off = 안 붙은 별의 글 } — n = 붙은 별 · max = 최대(22). 별이 하나도 없는 장비도 빈 별을 보인다(메이플처럼 — 얼마나 더 붙일 수 있는지 보인다)
function StarText.rows(n: number, max: number): { { on: string, off: string } }
	local out = {}
	local k = 0
	while k < max do
		local on, off = {}, {}
		for i = 1, math.min(StarText.PER, max - k) do
			local idx = k + i
			local piece = StarText.STAR
			if i > 1 and (i - 1) % StarText.GROUP == 0 then
				piece = " " .. piece
			end
			if idx <= n then
				table.insert(on, piece)
			else
				table.insert(off, piece)
			end
		end
		table.insert(out, { on = table.concat(on), off = table.concat(off) })
		k += StarText.PER
	end
	return out
end

return StarText
