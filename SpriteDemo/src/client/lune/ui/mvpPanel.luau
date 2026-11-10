-- 주간 보스 격파의 MVP 판(2026-11-07 사용자: "보스 종료시 로스트아크 mvp 처럼 딜량이나 팀기여 이런거 따라서 mvp 출력되어야해") — 서버 sim/weekly.luau의 Weekly.mvp가 셈을 한다.
--  화면 위 가운데(기준 격자 y 96): 「격파 결과」 · 사람마다 한 줄(점수 차례) — 이름(MVP는 금빛 + 「MVP」 딱지) · 피해 %(막대) · 기믹 %(막대) · 쓰러짐 수 · 분야마다 가장 높은 사람 「최고」
--  내 줄은 민트 테두리 · 혼자면 MVP 없이 「혼자 격파 — MVP는 두 사람 이상일 때」 · show초 뒤 저절로 닫힌다(「닫기」로도). 공방 시험 탭 paint.js의 paintMvp와 같은 짜임
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local CITY = require(lune.data["city.generated"])
local Stage = require(script.Parent.Parent.stage)
local Ui = require(script.Parent.ui)

local C = Ui.COLOR
local M = CITY.weekly.mvp
local Wd = M.words

local MvpPanel = {}
local layer: Frame? = nil
local token = 0

MvpPanel.W, MvpPanel.ROW, MvpPanel.HEAD, MvpPanel.FOOT = 360, 34, 34, 34

function MvpPanel.close()
	if layer then
		layer:Destroy()
		layer = nil
	end
end

local function bar(parent: Instance, x: number, y: number, w: number, k: number, color: Color3)
	Ui.box(parent, x, y, w, 3, C.ink)
	Ui.box(parent, x, y, math.max(0, math.floor(w * math.clamp(k, 0, 1) + 0.5)), 3, color)
end

-- v = { rows = { { id, name, dmg, gim, deaths, mvp, best } … }, mvp, me }
function MvpPanel.show(v)
	if typeof(v) ~= "table" or typeof(v.rows) ~= "table" then
		return
	end
	MvpPanel.close()
	token += 1
	local mine = token
	local rows = v.rows
	local w, rh = MvpPanel.W, MvpPanel.ROW
	local h = MvpPanel.HEAD + #rows * rh + MvpPanel.FOOT
	layer = Stage.group(Stage.ui, "Mvp", 880) -- (룬 해방 판 900 · 매크로 확인 950 아래 · 창 · 메뉴 위)
	local holder = Stage.place(layer :: Frame, "MvpPanel", "tc", math.floor((Stage.REF_W - w) / 2), 96, w, h)
	Ui.panel(holder, 0, 0, w, h)
	Ui.text(holder, Wd.title, 0, 10, w, { font = "body", align = "center", color = C.gold })
	for i, r in rows do
		local y = MvpPanel.HEAD + (i - 1) * rh
		local row = Ui.group(holder, 10, y, w - 20, rh - 4, "Row" .. i)
		if r.id == v.me then
			Ui.box(row, 0, 0, w - 20, rh - 4, C.accent, 0.82)
		end
		local nameColor = if r.mvp then C.gold else C.text
		local name = Ui.text(row, tostring(r.name or ""), 6, 4, 120, { font = "body", color = nameColor })
		if r.mvp then
			local nw = select(1, name:size())
			local tag = Ui.box(row, 6 + nw + 4, 5, 28, 12, C.gold)
			Ui.text(tag, Wd.mvp, 0, 0, 28, { align = "center", color = C.ink })
		end
		-- 피해 · 기믹 · 쓰러짐(분야의 「최고」는 그 글을 민트로)
		local best = r.best or {}
		Ui.text(row, ("%s %d%%"):format(Wd.dmg, math.floor((r.dmg or 0) * 100 + 0.5)), 140, 3, 80, { color = if best.dmg then C.accent else C.dim })
		bar(row, 140, 19, 72, r.dmg or 0, C.red)
		Ui.text(row, ("%s %d%%"):format(Wd.gim, math.floor((r.gim or 0) * 100 + 0.5)), 228, 3, 64, { color = if best.gim then C.accent else C.dim })
		bar(row, 228, 19, 52, r.gim or 0, C.gold)
		Ui.text(row, ("%s %d"):format(Wd.life, r.deaths or 0), 290, 3, 50, { color = if best.life then C.accent else C.dim })
	end
	local foot = MvpPanel.HEAD + #rows * rh
	if not v.mvp then
		Ui.text(holder, Wd.solo, 0, foot + 2, w, { align = "center", color = C.dim })
	end
	Ui.button(holder, Wd.close, math.floor((w - 64) / 2), foot + (if v.mvp then 4 else 14), 64, function()
		MvpPanel.close()
	end, { h = 18 })
	task.delay(M.show, function()
		if token == mine then
			MvpPanel.close()
		end
	end)
end

return MvpPanel
