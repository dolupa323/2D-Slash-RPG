-- 비석 — 쓰러진 사람의 자리에 선다(사용자 2026-10-08: "죽으면 비석 세우고, 모달띄워서 마을로 갈거냐고 물어보는 딜레이를 넣읍시다").
--  그림은 사냥터의 놓는 것 가운데 묘비(공방 assetpack/lune의 props — rects.grave)를 그대로 쓴다(새 그림이 아니다).
--  쓰러지는 동작이 끝나면 몸 대신 비석이 위에서 톡 내려와 선다. 캐릭터 · 졸개의 층보다 뒤에 놓는다(놓인 것이 캐릭터를 가리지 않는다 — 장면의 Graves 층).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local data = ReplicatedStorage.shared.lune.data
local SCENES = require(data["scenes.generated"])
local ASSETS = require(data["assets.generated"])
local Stage = require(script.Parent.stage)

local SOURCE = SCENES.scenes.hunt -- 묘비 그림이 든 판
local RECT = SOURCE.rects.grave
local DROP, FROM = 0.18, 14 -- 내려와 서는 시간(초) · 그만큼 위에서(도트)

local Grave = {}

function Grave.new(layer: Instance): ImageLabel
	local label = Stage.image(layer, "Grave", ASSETS[SOURCE.props] or "", RECT.w, RECT.h)
	label.ImageRectOffset = Vector2.new(RECT.x, RECT.y)
	label.ImageRectSize = Vector2.new(RECT.w, RECT.h)
	label.Visible = false
	return label
end

-- (x, y) = 쓰러진 사람의 발밑 가운데 · t = 비석이 서기 시작한 뒤 흐른 시간(초)
function Grave.put(label: ImageLabel, x: number, y: number, t: number)
	local k = math.clamp(t / DROP, 0, 1)
	local up = math.floor(FROM * (1 - k) * (1 - k) + 0.5)
	label.Position = UDim2.fromOffset(math.floor(x + 0.5) - math.floor(RECT.w / 2), math.floor(y + 0.5) - RECT.h - up)
	label.ImageTransparency = 1 - k
	label.Visible = true
end

return Grave
