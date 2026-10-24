-- 맵 이름 — 맵에 들어서면 화면 위 가운데에 지역 이름(작은 글)과 맵 이름(본문 글)이 잠깐 떴다가 흐려진다(메이플스토리처럼).
--  2026-10-18: 미니맵을 두지 않기로 해서(사용자 2026-10-07) 지금 어느 맵인지 알려 주는 것이 화면에 없었다 — 월드맵을 열어야만 알았다.
--  자리 = 보스 체력 칸(위 가운데 — 보스와 싸울 때만 쓰는 칸): 보스 체력이나 퀘스트 연출이 떠 있으면 맵 이름은 곧 사라진다.
--  치수 · 시간 = 공방 js/lune/design/ui.js의 UILAYOUT.mapName(시험 탭이 같은 값으로 그린다). 글자(그림)의 투명도를 바꿔 흐리게 한다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local SCENES = require(lune.data["scenes.generated"])
local WMD = require(lune.data["worldmap.generated"])
local WM = require(lune.ui.worldmap)
local Layout = require(lune.ui.layout)
local Stage = require(script.Parent.stage)
local Ui = require(script.Parent.ui.ui)

local C = Ui.COLOR
local L = Layout.MAPNAME

local MapName = {}
local box: Frame? = nil
local region, name
local t = -1
local lastA: number? = nil -- 마지막으로 쓴 보이는 정도(같으면 다시 쓰지 않는다)

function MapName.init(root: Frame)
	box = Stage.place(root, "MapName", "tc", math.floor((Stage.REF_W - L.w) / 2), L.y, L.w, L.h)
	region = Ui.text(box, "", 0, 0, L.w, { align = "center", outline = true, color = C.dim })
	name = Ui.text(box, "", 0, L.nameY, L.w, { font = "body", align = "center", outline = true, color = C.text })
	box.Visible = false
end

-- 장면의 이름표 → (지역 이름, 맵 이름). 지역 이름이 맵 이름과 같으면(은달 항구) 지역 줄은 비운다
function MapName.titleOf(key: string): (string, string)
	local base = string.match(key, "^(.-)#w?[nh]?%d+$") or key
	local sc = SCENES.scenes[base]
	local mapName = if sc then sc.name or "" else ""
	local rid = WM.nodeOf(base)
	local regionName = if rid and WMD.regions[rid] then WMD.regions[rid].name else ""
	if regionName == mapName then
		regionName = ""
	end
	return regionName, mapName
end

-- 그 장면의 이름을 띄운다(장면이 바뀌고 막이 걷힌 뒤)
function MapName.show(key: string?)
	if not box or typeof(key) ~= "string" then
		return
	end
	local r, n = MapName.titleOf(key)
	if n == "" then
		MapName.hide()
		return
	end
	region:set(r)
	name:set(n)
	-- 글자의 처음 투명도(baseT)는 지우지 않는다: 같은 글이면 SetText가 글자를 다시 짓지 않아 지금의 흐려진 값이 남아 있다 — 지우면 그 흐려진 값을 처음 값으로 읽어
	--  같은 지역의 둘째 맵부터 지역 줄이 · 같은 이름의 맵에 다시 들면 맵 이름이 보이지 않았다(2026-10-18 검토). 새로 지은 글자에는 아직 baseT가 없어 fade가 처음 값을 잰다
	t = 0
	box.Visible = true
	lastA = nil -- (글자를 새로 지었을 수 있다 — 한 번은 꼭 쓴다)
	MapName.fade(0)
end

function MapName.hide()
	t = -1
	if box then
		box.Visible = false
	end
end

-- a = 0(안 보임) ~ 1(다 보임). 보이는 정도가 바뀔 때만 글자를 훑는다(다 보이는 2초 남짓 동안은 아무것도 쓰지 않는다 — 2026-10-18 검토)
function MapName.fade(a: number)
	if not box then
		return
	end
	local q = math.floor(a * 64 + 0.5) / 64
	if lastA == q then
		return
	end
	lastA = q
	for _, d in box:GetDescendants() do
		if d:IsA("ImageLabel") then
			local base = d:GetAttribute("baseT")
			if base == nil then
				base = d.ImageTransparency
				d:SetAttribute("baseT", base)
			end
			d.ImageTransparency = base + (1 - base) * (1 - a)
		end
	end
end

-- 지금 보이는 정도(0 ~ 1 · 안 떠 있으면 0) — 자동 검사가 본다
function MapName.alpha(): number
	if t < 0 then
		return 0
	end
	if t < L.fadeIn then
		return t / L.fadeIn
	elseif t < L.fadeIn + L.hold then
		return 1
	end
	return math.max(0, 1 - (t - L.fadeIn - L.hold) / L.fadeOut)
end

-- 장마다: blocked = 그 자리를 다른 것이 쓴다(보스 체력 · 퀘스트 연출) — 그러면 바로 사라진다
function MapName.step(dt: number, blocked: boolean?)
	if t < 0 then
		return
	end
	t += dt
	local a = MapName.alpha()
	if a <= 0 or blocked then
		MapName.hide()
		return
	end
	MapName.fade(a)
end

return MapName
