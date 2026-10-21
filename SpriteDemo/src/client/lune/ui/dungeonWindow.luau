-- 던전 창 — 그 던전의 문 앞에서 ↑(2026-10-21 — 공방 design/dungeon.js · 수정 거울숲). 문은 그 퀘스트(「수정 틈의 문」)를 끝내야 열린다.
--  사용자: "수정틈안에 들어가면 던전 입장 멋지게 있고, 파티로 들어갈수도있고 개인으로 들어갈수도있는 문이 하나 있고, 거기에 포탈타는것처럼 상호작용하면, 던전 ui 가 나오는거지"
--  위부터: 이름(본문 · 금색) · 오른쪽 「오늘 0/1」 / 「Lv.30 ~ 40 · 제한 시간 10분」 / 던전의 글 / 줄 / 「완료 보상」 「경험치 8,932」(지금 내 레벨로) /
--   「몬스터는 경험치 · 아이템을 주지 않는다 — …」 / 「한국 시간 자정에 다시 열린다」 / [혼자 입장] [파티 입장] / 들어가지 못한 까닭(빨강) · 안내 한 줄.
--  들어가기는 서버가 정한다(ctx.riftDo("enter", 던전, 파티인가) → world.luau의 onRift · dungeonEnter). 모양은 공방 시험 탭의 js/lune/ui/paint.js(paintDungeon)와 같다.
--  화면 오른쪽의 옆 판(ui/windows.luau). 문에서 멀어지면 닫힌다(boot.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local Rift = require(lune.sim.rift)
local Format = require(lune.ui.format)
local Layout = require(lune.ui.layout)
local Ui = require(script.Parent.ui)

local C = Ui.COLOR
local S = Layout.DUNGEON
local DG = Rift.DUNGEON
local W = DG.words

local DungeonWindow = {}
DungeonWindow.TITLE = W.title

function DungeonWindow.size(): (number, number)
	return S.w, S.h
end

-- 그 던전(arg = 단계의 이름표 — 없으면 첫 던전)
local function tierOf(arg: any)
	local t = Rift.tier(arg)
	return if Rift.isDungeon(t) then t else DG.tiers[1]
end
DungeonWindow.tierOf = tierOf

function DungeonWindow.build(body: Frame, ctx, w: number, _h: number, arg: any)
	local t = tierOf(arg)
	local view = {}
	Ui.text(body, t.name, 0, 2, w - 80, { font = "body", color = C.gold })
	local today = Ui.text(body, "", 0, 4, w, { align = "right", color = C.accent })
	Ui.text(body, Format.fill(W.range, { a = t.lv, b = t.lvMax }) .. " · " .. Format.fill(W.time, { m = math.floor(DG.time / 60) }), 0, S.infoY, w, { color = C.dim })
	Ui.text(body, t.text, 0, S.textY, w, { lines = S.textLines, color = C.text })
	Ui.line(body, 0, S.lineY, w)
	Ui.text(body, W.pay, 0, S.payY, S.payLabelW, { color = C.dim })
	local xp = Ui.text(body, "", S.payLabelW, S.payY, w - S.payLabelW, { color = C.gold })
	Ui.text(body, W.note, 0, S.noteY, w, { lines = S.noteLines, color = C.dim })
	Ui.text(body, W.reset, 0, S.resetY, w, { color = C.dim })
	local half = math.floor((w - S.btnGap) / 2)
	local entering = false
	local function enter(party: boolean)
		if entering then
			return -- 답을 기다리는 중(두 번 눌러 방에 든 뒤 「문 앞에서 …」가 뜨지 않게)
		end
		entering = true
		ctx.riftDo("enter", t.id, party)
		entering = false
	end
	local solo = Ui.button(body, W.solo, 0, S.btnY, half, function()
		enter(false)
	end, { main = true })
	solo.frame.Name = "Solo"
	local party = Ui.button(body, W.party, half + S.btnGap, S.btnY, w - half - S.btnGap, function()
		enter(true)
	end)
	party.frame.Name = "Party"
	local note = Ui.text(body, "", 0, S.footY, w, { color = C.dim })

	function view.refresh()
		local me = ctx.me()
		local level = if me then me.level else 1
		local got = ctx.rift()
		local done = got and got.dungeonDone and got.dungeonDone[t.id] == true
		today:set(Format.fill(W.today, { n = if done then 1 else 0, max = DG.perDay }))
		today:color(if done then C.dim else C.accent)
		xp:set(Format.fill(W.xp, { n = Format.comma(Rift.dungeonXp(level)) }))
		local open = not done and level >= t.lv and level <= t.lvMax
		solo:setEnabled(open)
		party:setEnabled(open and ctx.partyHere ~= nil and ctx.partyHere())
		local why = got and got.why
		if not why and done then
			why = W.done
		elseif not why and level < t.lv then
			why = Format.fill(W.low, { a = t.lv })
		elseif not why and level > t.lvMax then
			why = Format.fill(W.high, { b = t.lvMax })
		end
		note:set(why or W.partyHint)
		note:color(if why then C.red else C.dim)
	end
	view.refresh()
	return view
end

return DungeonWindow
