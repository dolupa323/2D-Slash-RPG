-- 배의 갑판에서 화면 위 가운데의 판: 「은달 항구까지 42초」(2026-10-16 — sim/voyage.luau · 서버가 Voyage로 알린다).
--  사용자 2026-10-16: "왜 대도시로 넘어갈때 배타는건 구현을 안합니까 왜 그냥 포탈이에요" — 선장에게 말을 걸어 배에 오르면 갑판에서 바다를 건넌다(배가 닿으면 서버가 내려 준다).
--  자리 · 크기는 토벌의 위의 판(UILAYOUT.riftHud)과 같다. 시계만 받은 뒤로 흐르게 한다(닿는 때는 서버가 정한다)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local Voyage = require(lune.sim.voyage)
local Layout = require(lune.ui.layout)
local Stage = require(script.Parent.stage)
local Ui = require(script.Parent.ui.ui)

local C = Ui.COLOR

local VoyageView = {}
VoyageView.left = nil :: number? -- 닿기까지 남은 초(배 위에 있을 때만)
VoyageView.dest = ""

function VoyageView.init(root: Frame)
	local H = Layout.RIFT_HUD
	local box = Stage.place(root, "Voyage", "tc", math.floor((Stage.REF_W - H.w) / 2), H.y, H.w, 24)
	box.Visible = false
	Ui.panel(box, 0, 0, H.w, 24)
	VoyageView.box = box
	VoyageView.text = Ui.text(box, "", 10, 7, H.w - 20, { align = "center", color = C.text })
end

function VoyageView.draw()
	if not VoyageView.left then
		return
	end
	VoyageView.text:set(Voyage.leftText({ dest = VoyageView.dest }, VoyageView.left))
end

function VoyageView.start(left: number, dest: string)
	VoyageView.left, VoyageView.dest = left, dest
	VoyageView.box.Visible = true
	VoyageView.draw()
end

function VoyageView.stop()
	VoyageView.left = nil
	if VoyageView.box then
		VoyageView.box.Visible = false
	end
end

-- 매 장면: 초가 바뀔 때만 다시 그린다
function VoyageView.update(dt: number)
	if not VoyageView.left then
		return
	end
	local before = math.ceil(VoyageView.left)
	VoyageView.left = math.max(0, VoyageView.left - dt)
	if math.ceil(VoyageView.left) ~= before then
		VoyageView.draw()
	end
end

return VoyageView
