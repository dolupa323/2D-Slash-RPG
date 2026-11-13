-- 하루 사냥 시간(2026-11-12 사용자: "6시간 이상 사냥하면 경험치, 달돈,달가루 이런거 사냥파밍 다 불가능하게 해줘 자원이 안뜨게 사냥가능 시간이 모두 소진되었습니다 이렇게").
--  서버 world.luau World.huntCapStep이 보내는 「HuntTime」 { left, cap, over, hunt, crossed }을 화면에:
--   ① 남은 분이 warn(60 · 10분)으로 내려갈 때 화면 위 알림 「사냥 가능 시간이 n분 남았습니다」
--   ② 다 쓴 순간 화면 위 큰 알림 「사냥 가능 시간이 모두 소진되었습니다」 + 채팅 알림 글
--   ③ 다 쓴 채 사냥 맵에 있는 동안 화면 위 가운데 띠 「사냥 가능 시간 소진 / 0시(한국 시간)에 다시 채워집니다」(매크로의 띠들 아래)
--  글 · 숫자 = 공방 design/world.js의 HUNT_CAP(scenes.generated의 huntCap)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local SCENES = require(lune.data["scenes.generated"])
local Format = require(lune.ui.format)
local Stage = require(script.Parent.stage)
local Ui = require(script.Parent.ui.ui)

local HC = SCENES.huntCap or { minutes = 360, warn = {}, words = {} }
local W = HC.words
local C = Ui.COLOR
local BAND = { w = 240, h = 34, y = 92 } -- (매크로의 띠 y 54 아래 — 제가 정한 자리)

local HuntCapView = {}
HuntCapView.banner = nil :: ((head: string, line: string, seconds: number) -> ())? -- boot가 단다(Guide.banner)
HuntCapView.note = nil :: ((text: string) -> ())? -- boot가 단다(채팅 알림 글)
HuntCapView.left = nil :: number? -- 마지막으로 받은 남은 분(없으면 아직 모른다)

local band: Frame? = nil

local function showBand(on: boolean)
	if on and not band then
		local holder = Stage.place(Stage.ui, "HuntCap", "tc", math.floor((Stage.REF_W - BAND.w) / 2), BAND.y, BAND.w, BAND.h)
		holder.ZIndex = 940
		Ui.panel(holder, 0, 0, BAND.w, BAND.h)
		Ui.text(holder, W.band or "", 0, 4, BAND.w, { align = "center", color = C.red })
		Ui.text(holder, W.bandHint or "", 0, 4 + Ui.M.smallLine, BAND.w, { align = "center", color = C.dim })
		band = holder
	end
	if band then
		band.Visible = on
	end
end

function HuntCapView.update(v)
	if typeof(v) ~= "table" or typeof(v.left) ~= "number" then
		return
	end
	local was = HuntCapView.left
	HuntCapView.left = v.left
	if v.crossed then
		if HuntCapView.banner then
			HuntCapView.banner(W.done or "", W.doneHint or "", 10)
		end
		if HuntCapView.note then
			HuntCapView.note(W.done or "")
		end
	elseif was ~= nil and v.left > 0 then
		for _, w in HC.warn or {} do
			if was > w and v.left <= w and HuntCapView.banner then
				HuntCapView.banner(Format.fill(W.left or "", { m = v.left }), W.leftHint or "", 6)
				break
			end
		end
	end
	showBand(v.over == true and v.hunt == true)
end

return HuntCapView
