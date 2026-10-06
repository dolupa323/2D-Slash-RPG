-- 파티원 칸 — 늘 보이는 화면의 왼쪽(공방 「기본 · UI」 탭의 화면 배치 2번, data/ui.generated.luau의 hud.party). 파티가 없으면 안 보인다.
--  파티원(나를 뺀 셋까지)마다 비치는 바탕 위에 이름과 체력 띠. 다른 맵에 있는 사람은 이름이 흐리다. 사람 수만큼 아래로 쌓인다.
--  초대를 받으면 화면 위쪽 가운데에 「○○의 파티 초대 — 받기 · 거절」이 뜬다(30초 뒤에 저절로 사라진다).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local UI = require(lune.data["ui.generated"])
local Kit = require(script.Parent.ui.kit)

local C = Kit.COLOR
local ROW = 15 -- 한 사람: 칸(14 — 이름 한 줄과 체력 띠) + 사이 1

local PartyHud = {}
PartyHud.ROW = ROW
PartyHud.MAX_W = 100 -- 이름이 길면 칸이 여기까지 넓어진다(그보다 길면 줄여 적는다)

-- 파티원 칸의 폭: 가장 긴 이름이 들어가게(기본 폭부터 MAX_W까지)
function PartyHud.width(base: number, nameWidths: { number }): number
	local w = base
	for _, n in nameWidths do
		w = math.max(w, n + 6)
	end
	return math.min(w, PartyHud.MAX_W)
end
PartyHud.ASK_TEXT = "파티에 초대했다"
PartyHud.ASK = { x = 114, y = 30, w = 142, h = 52 } -- 초대 알림의 자리(대화 상자와 같은 데 — 둘이 같이 뜨지는 않는다)

function PartyHud.init(root: Frame, send)
	local r = UI.hud.party
	local box = Kit.group(root, r.x, r.y, r.w, 1)
	box.Name = "Party"
	box.Visible = false
	PartyHud.box = box
	PartyHud.rows = {}
	PartyHud.send = send
	PartyHud.root = root
end

-- info = 서버가 보낸 파티의 모습 { leader, members = { { id, name, class, level, hp, maxHp, scene } … } } · myId = 나 · scene = 내가 있는 맵
function PartyHud.set(info, myId: any, scene: string)
	local r = UI.hud.party
	for _, row in PartyHud.rows do
		row.frame:Destroy()
	end
	table.clear(PartyHud.rows)
	local n = 0
	local widths = {}
	for _, m in (info and info.members) or {} do
		if m.id ~= myId then
			table.insert(widths, Kit.measure(m.name))
		end
	end
	local w = PartyHud.width(r.w, widths)
	for _, m in (info and info.members) or {} do
		if m.id ~= myId and n < 3 then
			local frame = Kit.group(PartyHud.box, 0, n * ROW, w, ROW - 1)
			local back = Kit.part(frame, "veil", 0, 0, w, ROW - 1)
			back.ImageTransparency = 0.3
			local here = m.scene == scene
			Kit.text(frame, m.name, 3, 1, w - 6, { color = if here then C.mint else C.dim })
			local bar = Kit.bar(frame, 3, 9, w - 6, 4, "hp")
			bar:set(if here then m.hp / math.max(1, m.maxHp) else 0)
			table.insert(PartyHud.rows, { frame = frame })
			n += 1
		end
	end
	PartyHud.box.Visible = n > 0
	PartyHud.box.Size = UDim2.fromOffset(w, math.max(1, n * ROW))
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
	local panel = Kit.plate(PartyHud.root, "frame", a.x, a.y, a.w, a.h)
	panel.Name = "PartyAsk"
	panel.ZIndex = 30
	Kit.text(panel, ask.name, 6, 5, a.w - 12, { color = C.yellow })
	Kit.text(panel, PartyHud.ASK_TEXT, 6, 17, a.w - 12)
	local bw = math.floor((a.w - 14) / 2)
	Kit.button(panel, "받기", 6, 32, bw, 14, function()
		PartyHud.send("Party", "accept")
		PartyHud.ask(nil)
	end, { kind = "orange" }).frame.Name = "Accept"
	Kit.button(panel, "거절", 8 + bw, 32, bw, 14, function()
		PartyHud.send("Party", "decline")
		PartyHud.ask(nil)
	end).frame.Name = "Decline"
	PartyHud.prompt = panel
	task.delay(30, function()
		if PartyHud.prompt == panel then
			PartyHud.ask(nil)
		end
	end)
end

return PartyHud
