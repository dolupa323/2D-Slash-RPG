-- 파티원 칸 — 늘 보이는 화면의 왼쪽 위(공방 「기본 · UI」 탭의 화면 배치, data/ui.generated.luau의 hud.party). 파티가 없으면 안 보인다.
--  파티원(나를 뺀 셋까지)마다 이름(판 없이 테두리 두른 글)과 그 아래 가는 체력 줄. 다른 맵에 있는 사람은 이름이 흐리다. 사람 수만큼 아래로 쌓인다.
--  초대를 받으면 화면 위쪽 가운데에 「○○ — 파티에 초대했다 · 받기 · 거절」이 뜬다(30초 뒤에 저절로 사라진다).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local UI = require(lune.data["ui.generated"])
local Layout = require(lune.ui.layout)
local Stage = require(script.Parent.stage)
local Ui = require(script.Parent.ui.ui)

local C = Ui.COLOR
local P = Layout.PARTY -- 치수(자동 검사가 같은 값을 본다)
local ROW = P.row -- 한 사람: 이름 한 줄 + 체력 줄 + 사이

local PartyHud = {}
PartyHud.ROW = ROW
PartyHud.ASK_TEXT = P.askText
PartyHud.ASK = P.ask -- 초대 알림의 자리(위쪽 가운데 — 보스 체력 칸 아래)

function PartyHud.init(root: Frame, send)
	local r = UI.hud.party
	local box = Stage.placeRect(root, "Party", r)
	box.Visible = false
	PartyHud.box = box
	PartyHud.rows = {}
	PartyHud.send = send
	PartyHud.root = root
end

-- info = 서버가 보낸 파티의 모습 { leader, members = { { id, name, class, level, hp, maxHp, scene } … } } · myId = 나 · scene = 내가 있는 맵
function PartyHud.set(info, myId: any, scene: string)
	if not PartyHud.rows then
		return -- 아직 화면을 짓기 전에 서버의 파티 소식이 먼저 왔다(시작할 때) — 장면에 들어갈 때 boot가 다시 부른다
	end
	local r = UI.hud.party
	for _, row in PartyHud.rows do
		row.frame:Destroy()
	end
	table.clear(PartyHud.rows)
	local n = 0
	for _, m in (info and info.members) or {} do
		if m.id ~= myId and n < P.max then
			local frame = Ui.group(PartyHud.box, 0, n * ROW, r.w, ROW, "Member")
			local here = m.scene == scene
			Ui.text(frame, m.name, 0, 0, r.w, { color = if here then C.accent else C.dim, outline = true })
			local bar = Ui.bar(frame, 0, P.barY, P.barW, P.barH, C.hp)
			bar:set(if here then m.hp / math.max(1, m.maxHp) else 0)
			table.insert(PartyHud.rows, { frame = frame })
			n += 1
		end
	end
	PartyHud.box.Visible = n > 0
end

-- 초대 알림. ask = { from, name } — from이 false면 지운다
function PartyHud.ask(ask)
	if PartyHud.prompt then
		PartyHud.prompt:Destroy()
		PartyHud.prompt = nil
	end
	if not ask or not ask.from then
		return
	end
	local a = PartyHud.ASK
	local holder = Stage.place(PartyHud.root, "PartyAsk", a.at, a.x, a.y, a.w, a.h)
	holder.ZIndex = 30
	local panel = Ui.panel(holder, 0, 0, a.w, a.h)
	Ui.text(panel, ask.name, a.pad, 12, a.w - a.pad * 2, { font = "body", color = C.gold })
	Ui.text(panel, PartyHud.ASK_TEXT, a.pad, 32, a.w - a.pad * 2)
	local bw = math.floor((a.w - a.pad * 2 - 8) / 2)
	Ui.button(panel, "받기", a.pad, 52, bw, function()
		PartyHud.send("Party", "accept")
		PartyHud.ask(nil)
	end, { main = true }).frame.Name = "Accept"
	Ui.button(panel, "거절", a.pad + bw + 8, 52, bw, function()
		PartyHud.send("Party", "decline")
		PartyHud.ask(nil)
	end).frame.Name = "Decline"
	PartyHud.prompt = holder
	task.delay(30, function()
		if PartyHud.prompt == holder then
			PartyHud.ask(nil)
		end
	end)
end

return PartyHud
