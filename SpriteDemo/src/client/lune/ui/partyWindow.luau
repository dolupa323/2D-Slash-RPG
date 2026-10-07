-- 파티 창(O · Lv.10부터) — 위에 파티원(넷까지: 이름 · 레벨 · 파티장 표시)과 「나가기」, 아래에 같은 맵에 있는 사람들과 「초대」.
--  초대 · 나가기는 서버에 부탁한다(Party). 파티 찾기(멀리 있는 사람과 맺기)는 아직 없다. 화면 오른쪽의 옆 판(ui/windows.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local Party = require(lune.sim.party)
local Ui = require(script.Parent.ui)

local C = Ui.COLOR
local W = 300
local LINE = 18 -- 파티원 한 줄
local ROW = Ui.M.button + 4 -- 같은 맵의 사람 한 줄(초대 단추)

local PartyWindow = {}
PartyWindow.NAME_W = W - 80 -- 「Lv.150 이름(열두 자)」가 들어가는 폭 — 넘으면 줄여 적는다
PartyWindow.NEAR = 4 -- 같은 맵의 사람을 몇 줄까지 보이나

function PartyWindow.size(): (number, number)
	return W, 20 + Party.MAX * LINE + 8 + Ui.M.button + 12 + 22 + PartyWindow.NEAR * ROW
end

function PartyWindow.line(level: number, name: string): string
	return ("Lv.%d %s"):format(level, name)
end

function PartyWindow.build(body: Frame, ctx, w: number, _h: number)
	local view = {}
	Ui.text(body, "파티원", 0, 0, 120, { color = C.gold })
	local count = Ui.text(body, "", w - 60, 0, 60, { align = "right", color = C.dim })
	local members = {}
	for i = 1, Party.MAX do
		local y = 20 + (i - 1) * LINE
		members[i] = { name = Ui.text(body, "", 0, y, PartyWindow.NAME_W, { font = "body" }), mark = Ui.text(body, "", w - 70, y + 1, 70, { align = "right", color = C.accent }) }
	end
	local y = 20 + Party.MAX * LINE + 8
	local leave = Ui.button(body, "파티 나가기", 0, y, w, function()
		ctx.send("Party", "leave")
	end)
	y += Ui.M.button + 10
	Ui.line(body, 0, y, w)
	Ui.text(body, "같은 맵의 사람", 0, y + 8, 160, { color = C.gold })
	y += 26
	local near = {}
	for i = 1, PartyWindow.NEAR do
		local ry = y + (i - 1) * ROW
		local row = { name = Ui.text(body, "", 0, ry + 7, PartyWindow.NAME_W, { font = "body" }), id = nil :: any }
		row.button = Ui.button(body, "초대", w - 64, ry, 64, function()
			if row.id then
				ctx.send("Party", "invite", row.id)
			end
		end)
		near[i] = row
	end

	function view.refresh()
		local me, party, myId = ctx.me(), ctx.party(), ctx.myId()
		if not me then
			return
		end
		local list = (party and party.members) or {}
		local inParty = {}
		for i, row in members do
			local m = list[i]
			if m then
				inParty[m.id] = true
				row.name:set(PartyWindow.line(m.level, m.name))
				row.name:color(if m.id == myId then C.text else C.accent)
				row.mark:set(if m.id == party.leader then "파티장" else "")
			else
				row.name:set(if i == 1 and #list == 0 then "파티가 없다" else "")
				row.name:color(C.dim)
				row.mark:set("")
			end
		end
		count:set(("%d / %d"):format(#list, Party.MAX))
		leave:setEnabled(#list > 0)
		-- 초대할 수 있는 사람: 내가 파티장이거나 파티가 없을 때, 자리가 남았을 때
		local canInvite = (#list == 0 or party.leader == myId) and #list < Party.MAX
		local others = {}
		for _, o in ctx.others() do
			if not inParty[o.id] then
				table.insert(others, o)
			end
		end
		for i, row in near do
			local o = others[i]
			row.id = if o then o.id else nil
			row.name:set(if o then PartyWindow.line(o.level, o.name) elseif i == 1 then "아무도 없다" else "")
			row.name:color(if o then C.text else C.dim)
			row.button.frame.Visible = o ~= nil
			row.button:setEnabled(canInvite)
		end
	end
	return view
end

return PartyWindow
