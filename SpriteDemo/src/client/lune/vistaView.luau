-- 경관 — 성의 테라스에 들어서면 화면 가득 잠깐 보이는 그림(2026-10-16 밤 · 공방 design/city.js의 CITYROOMS vista · tools/build_lune_cityrooms.mjs의 vistaPicture).
--  사용자 2026-10-16: "영주 성같은걸 크게 만들고 들어가게하고 바깥 경관 볼수있는 그런것도 만들고 경관 이미지 멋있게 만들어서 잠깐 보여주는등"
--  들어설 때마다 한 번 · 테라스의 가운데(vista.x)에서 ↑ = 다시 본다. 천천히 밝아지고(FADE_IN) → 머물고(HOLD — 아래에 곳의 이름) → 천천히 사라진다(FADE_OUT).
--  화면 부품(HUD)보다 위 · 장면을 바꾸는 막(curtain — DisplayOrder 1000)보다 아래. 보는 동안에도 캐릭터는 움직일 수 있다(그림이 덮을 뿐)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local ASSETS = require(lune.data["assets.generated"])
local Stage = require(script.Parent.stage)
local Ui = require(script.Parent.ui.ui)

local C = Ui.COLOR

local VistaView = {}
VistaView.FADE_IN, VistaView.HOLD, VistaView.FADE_OUT = 0.7, 3.2, 0.9 -- 초(제가 정한 것)
VistaView.t = nil :: number? -- 보이기 시작한 뒤의 시간(안 보이면 nil)

local box: Frame = nil
local image: ImageLabel = nil
local title, sub

function VistaView.init(root: Frame)
	box = Stage.place(root, "Vista", "tl", 0, 0, Stage.REF_W, Stage.REF_H)
	box.ZIndex = 900
	box.Visible = false
	image = Instance.new("ImageLabel")
	image.Name = "Picture"
	image.BackgroundColor3 = Color3.fromRGB(11, 15, 22)
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.ResampleMode = Enum.ResamplerMode.Pixelated
	image.ScaleType = Enum.ScaleType.Crop -- 화면의 꼴(PC · 폰)이 달라도 가득 채운다(넘치는 가장자리는 잘린다)
	image.Size = UDim2.fromScale(1, 1)
	image.ZIndex = 1
	image.Parent = box
	title = Ui.text(box, "", 0, Stage.REF_H - 70, Stage.REF_W, { align = "center", font = "body", color = C.text })
	sub = Ui.text(box, "", 0, Stage.REF_H - 52, Stage.REF_W, { align = "center", color = C.accent })
	for _, d in box:GetDescendants() do
		if d ~= image and d:IsA("GuiObject") then
			d.ZIndex = math.max(d.ZIndex, 2) -- 글은 그림 위
		end
	end
end

-- 그 장면의 경관을 띄운다(vista = { img, title, sub } — 장면의 자료)
function VistaView.show(vista)
	if not box or not vista or not ASSETS[vista.img] then
		return
	end
	image.Image = ASSETS[vista.img]
	title:set(vista.title or "")
	sub:set(vista.sub or "")
	title:show(false)
	sub:show(false)
	VistaView.t = 0
	box.Visible = true
	image.ImageTransparency = 1
	image.BackgroundTransparency = 1
end

function VistaView.stop()
	VistaView.t = nil
	if box then
		box.Visible = false
	end
end

function VistaView.showing(): boolean
	return VistaView.t ~= nil
end

-- 매 장면: 밝아지기 → 머물기(글) → 사라지기
function VistaView.update(dt: number)
	if not VistaView.t then
		return
	end
	VistaView.t += dt
	local t, A, B, Cc = VistaView.t, VistaView.FADE_IN, VistaView.FADE_IN + VistaView.HOLD, VistaView.FADE_IN + VistaView.HOLD + VistaView.FADE_OUT
	local a = if t < A then t / A elseif t < B then 1 elseif t < Cc then 1 - (t - B) / VistaView.FADE_OUT else 0
	image.ImageTransparency = 1 - a
	image.BackgroundTransparency = 1 - a
	local words = t >= A * 0.6 and t < B
	title:show(words)
	sub:show(words)
	if t >= Cc then
		VistaView.stop()
	end
end

return VistaView
