-- 쓰러졌을 때 묻는 상자 — 「쓰러졌다 · 마을로 돌아갈까요?」와 단추 하나(공방 js/lune/design/ui.js의 UILAYOUT.death → Layout.DEATH).
--  사용자 2026-10-08: "죽으면 비석 세우고, 모달띄워서 마을로 갈거냐고 물어보는 딜레이를 넣읍시다."
--  쓰러지고 조금 뒤(싸움의 규칙 reviveWait)에 화면 위쪽 가운데에 뜬다. 단추를 누를 때까지 떠 있고(저절로 마을로 가지 않는다), 파티원이 소생으로 일으켜 주면 사라진다.
--  파티 초대 알림(partyHud.luau)과 같은 부품으로 짓는다 — PC는 마우스로, 스마트폰은 손가락으로 누른다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Layout = require(ReplicatedStorage.shared.lune.ui.layout)
local Stage = require(script.Parent.Parent.stage)
local Ui = require(script.Parent.ui)

local C = Ui.COLOR
local D = Layout.DEATH

local DeathBox = {}
DeathBox.holder = nil :: Frame?

function DeathBox.shown(): boolean
	return DeathBox.holder ~= nil
end

function DeathBox.hide()
	if DeathBox.holder then
		DeathBox.holder:Destroy()
		DeathBox.holder = nil
	end
end

-- root = 늘 보이는 화면의 틀 · onReturn = 「마을로 돌아간다」를 눌렀을 때 · weakMin = 되살아난 뒤 약해짐이 남는 분(0이면 그 줄을 비운다 — Lv.10 아래는 벌칙이 없다)
function DeathBox.show(root: Instance, onReturn: () -> (), weakMin: number?)
	DeathBox.hide()
	local holder = Stage.place(root, "DeathBox", D.at, D.x, D.y, D.w, D.h)
	holder.ZIndex = 40
	local panel = Ui.panel(holder, 0, 0, D.w, D.h)
	local inner = D.w - D.pad * 2
	Ui.text(panel, D.title, D.pad, D.titleY, inner, { font = "body", color = C.gold })
	Ui.text(panel, D.text, D.pad, D.textY, inner)
	if weakMin and weakMin > 0 then -- 쓰러진 벌칙(2026-10-18 — 전에는 화면 어디에도 보이지 않았다)
		Ui.text(panel, (string.gsub(D.weak, "{m}", tostring(weakMin))), D.pad, D.weakY, inner, { color = C.red })
	end
	Ui.text(panel, D.hint, D.pad, D.hintY, inner, { color = C.dim })
	local sent = false
	Ui.button(panel, D.yes, D.pad, D.buttonY, inner, function()
		if not sent then
			sent = true -- 한 번만 보낸다(서버가 마을로 옮기면 이 상자는 사라진다)
			onReturn()
			task.delay(1.5, function()
				sent = false -- 받아들여지지 않았으면(너무 일렀다) 다시 누를 수 있다
			end)
		end
	end, { main = true }).frame.Name = "Return"
	DeathBox.holder = holder
end

return DeathBox
